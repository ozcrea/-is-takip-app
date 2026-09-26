// autowerk.app — Einmalige Mitteilung per Web Push (z. B. "Version 7.2")
//
// Wird NUR manuell aus der App aufgerufen (Admin → Chef-Panel → Berichte →
// "Mitteilung senden"). Kein Cron, läuft nie automatisch — der tägliche
// 17:45-Bericht (daily-report) ist davon völlig unabhängig.
//
// Sicherheit: Der Aufrufer muss mit einem echten Admin-Konto angemeldet
// sein (employees.is_admin = true, verknüpft über auth_user_id). Chef
// (is_chef_viewer, nur Ansicht) und Mitarbeiter werden abgewiesen.
//
// Anfrage (POST, JSON):
//   { "messages": { "boss": { "title": "...", "body": "..." },
//                   "emp":  { "title": "...", "body": "..." } } }
//   Nur die angegebenen Gruppen bekommen eine Mitteilung.
//   boss = Chef/Admin-Geräte, emp = Mitarbeiter-Geräte (schema_v37.sql).
//
// Antwort: { "boss": { "sent": n, "failed": n }, "emp": { ... } }
//
// Benötigte Secrets: dieselben wie daily-report (VAPID_PUBLIC_KEY,
// VAPID_PRIVATE_KEY; SUPABASE_URL + Service-Key sind automatisch gesetzt).

import { createClient } from "npm:@supabase/supabase-js@2"
import webpush from "npm:web-push@3.6.7"

// Gleiche Schlüssel-Auflösung wie in daily-report: SUPABASE_SECRET_KEYS
// ist ein JSON-Objekt { "default": "<key>" }, ältere Projekte haben nur
// SUPABASE_SERVICE_ROLE_KEY.
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
const VAPID_PUBLIC_KEY = Deno.env.get("VAPID_PUBLIC_KEY")!
const VAPID_PRIVATE_KEY = Deno.env.get("VAPID_PRIVATE_KEY")!

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
}

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { ...CORS, "Content-Type": "application/json" } })
}

function cleanText(v: unknown, max: number) {
  return typeof v === "string" ? v.trim().slice(0, max) : ""
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
  const { data: emp, error: empError } = await supabase
    .from("employees").select("id, is_admin").eq("auth_user_id", userData.user.id).maybeSingle()
  if (empError) return json({ error: "Prüfung fehlgeschlagen: " + empError.message }, 500)
  if (!emp?.is_admin) return json({ error: "Nur für Admin" }, 403)

  // --- Nachrichten prüfen ---
  let input: any
  try { input = await req.json() } catch { return json({ error: "Ungültige Anfrage" }, 400) }
  const messages: Record<string, { title: string; body: string }> = {}
  for (const audience of ["boss", "emp"]) {
    const m = input?.messages?.[audience]
    if (!m) continue
    const title = cleanText(m.title, 80)
    const body = cleanText(m.body, 240)
    if (!title || !body) return json({ error: `Titel und Text für "${audience}" erforderlich` }, 400)
    messages[audience] = { title, body }
  }
  if (!Object.keys(messages).length) return json({ error: "Keine Empfängergruppe ausgewählt" }, 400)

  webpush.setVapidDetails("mailto:kontakt@autowerk.app", VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY)

  const result: Record<string, { sent: number; failed: number }> = {}
  for (const [audience, msg] of Object.entries(messages)) {
    const { data: subs, error: subsError } = await supabase
      .from("push_subscriptions").select("*").eq("audience", audience)
    if (subsError) return json({ error: "Empfänger konnten nicht geladen werden (schema_v37.sql ausgeführt?): " + subsError.message }, 500)
    const payload = JSON.stringify({ title: msg.title, body: msg.body, url: "/" })
    const settled = await Promise.allSettled(
      (subs ?? []).map(async (sub: any) => {
        try {
          await webpush.sendNotification(
            { endpoint: sub.endpoint, keys: { p256dh: sub.p256dh, auth: sub.auth } },
            payload,
          )
        } catch (err: any) {
          // Abgelaufene Abos aufräumen (wie in daily-report).
          if (err?.statusCode === 404 || err?.statusCode === 410) {
            await supabase.from("push_subscriptions").delete().eq("endpoint", sub.endpoint)
          }
          throw err
        }
      }),
    )
    result[audience] = {
      sent: settled.filter((s) => s.status === "fulfilled").length,
      failed: settled.filter((s) => s.status === "rejected").length,
    }
  }
  return json(result)
})
