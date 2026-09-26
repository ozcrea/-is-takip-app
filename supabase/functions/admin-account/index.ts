// autowerk.app — Zugänge verwalten (nur Admin)
//
// Setzt ein neues Passwort für ein Mitarbeiterkonto. Hat das Konto noch
// keinen echten Login (employees.auth_user_id leer — z. B. Chef, W3), wird
// es dabei aktiviert: ein Supabase-Auth-Konto wird mit dem NEUEN Passwort
// angelegt und mit dem Mitarbeiter verknüpft. Das alte Klartext-Passwort in
// employees.password wird dafür NICHT benutzt und NICHT verändert.
//
// Warum eine eigene Funktion: die Mitarbeiter-E-Mails
// (<akt>@mitarbeiter.autowerk.app) sind keine echten Postfächer — die
// "Passwort vergessen"-Mail von Supabase kann nicht ankommen.
//
// Sicherheit: nur ein angemeldeter echter Admin (employees.is_admin = true,
// verknüpft über auth_user_id). Das eigene Admin-Konto kann hier NICHT
// geändert werden (das bleibt im Supabase-Dashboard — kein Aussperren).
//
// Anfrage (POST, JSON): { "employee_id": "<uuid>", "password": "<neu>" }
// Antwort: { "ok": true, "activated": boolean, "akt_no": "..." }

import { createClient } from "npm:@supabase/supabase-js@2"

function resolveServiceKey(): string {
  const raw = (Deno.env.get("SUPABASE_SECRET_KEYS") ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "").trim()
  if (!raw) throw new Error("SUPABASE_SECRET_KEYS veya SUPABASE_SERVICE_ROLE_KEY bulunamadı")
  try {
    if (raw.startsWith("{")) {
      const obj = JSON.parse(raw)
      return String(obj?.default ?? obj?.api_key ?? obj?.key ?? obj?.secret ?? Object.values(obj)[0])
    }
    if (raw.startsWith("[")) {
      const first = JSON.parse(raw)[0]
      return String(typeof first === "string" ? first : (first?.default ?? first?.api_key ?? first?.key ?? first?.secret))
    }
  } catch { /* kein JSON → als Klartext verwenden */ }
  return raw
}

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!
const SERVICE_KEY = resolveServiceKey()
const EMAIL_DOMAIN = "mitarbeiter.autowerk.app" // = AUTH_EMAIL_DOMAIN in index.html

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
}

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { ...CORS, "Content-Type": "application/json" } })
}

// Gleiche Regel wie im Admin-Formular (index.html: passwordProblem).
function passwordProblem(pw: string, aktNo: string): string | null {
  if (pw.length < 10) return "Mindestens 10 Zeichen"
  if (pw.length > 72) return "Höchstens 72 Zeichen"
  if (!/[A-Za-z]/.test(pw) || !/[0-9]/.test(pw)) return "Buchstaben und Ziffern verwenden"
  if (aktNo && pw.toLowerCase().includes(aktNo.toLowerCase())) return "Darf die AKT-Nummer nicht enthalten"
  return null
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS })
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405)

  const supabase = createClient(SUPABASE_URL, SERVICE_KEY)

  // --- Nur echte Admins ---
  const token = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "")
  if (!token) return json({ error: "Nicht angemeldet" }, 401)
  const { data: userData, error: userError } = await supabase.auth.getUser(token)
  if (userError || !userData?.user) return json({ error: "Nicht angemeldet" }, 401)
  const { data: caller, error: callerError } = await supabase
    .from("employees").select("id, is_admin, active").eq("auth_user_id", userData.user.id).maybeSingle()
  if (callerError) return json({ error: "Prüfung fehlgeschlagen: " + callerError.message }, 500)
  if (!caller?.is_admin || !caller?.active) return json({ error: "Nur für Admin" }, 403)

  // --- Eingabe prüfen ---
  let input: any
  try { input = await req.json() } catch { return json({ error: "Ungültige Anfrage" }, 400) }
  const employeeId = typeof input?.employee_id === "string" ? input.employee_id : ""
  const password = typeof input?.password === "string" ? input.password : ""
  if (!employeeId || !password) return json({ error: "Mitarbeiter und Passwort erforderlich" }, 400)

  const { data: emp, error: empError } = await supabase
    .from("employees").select("id, name, akt_no, auth_user_id, is_admin").eq("id", employeeId).maybeSingle()
  if (empError) return json({ error: "Mitarbeiter konnte nicht geladen werden: " + empError.message }, 500)
  if (!emp) return json({ error: "Mitarbeiter nicht gefunden" }, 404)
  if (emp.id === caller.id || emp.is_admin) {
    return json({ error: "Admin-Konten werden nur im Supabase-Dashboard geändert" }, 400)
  }

  const problem = passwordProblem(password, emp.akt_no)
  if (problem) return json({ error: "Passwort ungültig: " + problem }, 400)

  // --- Bestehendes Konto: nur Passwort ändern ---
  if (emp.auth_user_id) {
    const { error } = await supabase.auth.admin.updateUserById(emp.auth_user_id, { password })
    if (error) return json({ error: "Passwort konnte nicht gesetzt werden: " + error.message }, 500)
    return json({ ok: true, activated: false, akt_no: emp.akt_no })
  }

  // --- Noch kein echter Login: Konto aktivieren ---
  const email = `${String(emp.akt_no).toLowerCase()}@${EMAIL_DOMAIN}`
  const { data: created, error: createError } = await supabase.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { employee_id: emp.id, akt_no: emp.akt_no, name: emp.name },
  })
  if (createError || !created?.user) {
    return json({ error: "Konto konnte nicht aktiviert werden: " + (createError?.message || "unbekannt") }, 500)
  }
  const { error: linkError, count: linked } = await supabase
    .from("employees").update({ auth_user_id: created.user.id }, { count: "exact" })
    .eq("id", emp.id).is("auth_user_id", null)
  if (linkError || !linked) {
    // Verknüpfung fehlgeschlagen (Fehler oder 0 Zeilen, z. B. parallel schon
    // aktiviert) → angelegtes Auth-Konto wieder entfernen, damit kein
    // verwaistes Konto zurückbleibt.
    await supabase.auth.admin.deleteUser(created.user.id)
    return json({ error: "Konto konnte nicht verknüpft werden: " + (linkError?.message || "0 Zeilen geändert") }, 500)
  }
  return json({ ok: true, activated: true, akt_no: emp.akt_no })
})
