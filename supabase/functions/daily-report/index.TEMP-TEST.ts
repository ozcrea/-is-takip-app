// ⚠️ GEÇİCİ TEST VERSİYONU — SADECE BİR KERELİK MANUEL TEST İÇİN ⚠️
//
// Bu dosya normal index.ts'in saat kontrolü KALDIRILMIŞ halidir.
// Amaç: 17:30'u beklemeden "Invoke" ile elle tetikleyip gerçek bir
// bildirim gelip gelmediğini hemen görmek.
//
// KULLANIM:
// 1. Bu dosyanın İÇERİĞİNİ kopyalayın.
// 2. Supabase Dashboard > Edge Functions > daily-report > Edit/Deploy
//    ekranına gidin, mevcut kodun ÜZERİNE bu içeriği yapıştırıp deploy edin.
// 3. "Invoke" butonuna basın.
// 4. Bildirim geldi mi kontrol edin.
// 5. TEST BİTER BİTMEZ: normal index.ts dosyasının (bu klasördeki asıl
//    index.ts) içeriğini AYNI ekrana yapıştırıp tekrar deploy edin —
//    yoksa günlük otomatik gönderim saat kontrolü olmadan HER pg_cron
//    tetiklemesinde (günde 2 kez) bildirim göndermeye devam eder.

import { createClient } from "npm:@supabase/supabase-js@2"
import webpush from "npm:web-push@3.6.7"

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const VAPID_PUBLIC_KEY = Deno.env.get("VAPID_PUBLIC_KEY")!
const VAPID_PRIVATE_KEY = Deno.env.get("VAPID_PRIVATE_KEY")!

const REGIESTUNDE_RATE = 33.28
const BRANCHES = ["Ausschläger Weg", "Horn", "Wiesendamm"]

function getBerlinParts(date: Date) {
  const fmt = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/Berlin",
    year: "numeric", month: "2-digit", day: "2-digit",
    hour: "2-digit", minute: "2-digit", hour12: false,
  })
  const parts: Record<string, string> = {}
  fmt.formatToParts(date).forEach((p) => { parts[p.type] = p.value })
  return parts
}

function berlinMidnightUTC(dateStr: string) {
  const noon = new Date(dateStr + "T12:00:00Z")
  const p = getBerlinParts(noon)
  const berlinHourAtNoonUTC = parseInt(p.hour) + parseInt(p.minute) / 60
  const offsetHours = berlinHourAtNoonUTC - 12
  return new Date(dateStr + "T00:00:00Z").getTime() - offsetHours * 3600000
}

function fmtEur(n: number) {
  return "€" + n.toLocaleString("de-DE", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

Deno.serve(async () => {
  const now = new Date()
  const berlin = getBerlinParts(now)

  // ⚠️ SAAT KONTROLÜ BİLEREK KALDIRILDI (sadece bu test dosyasında) ⚠️
  // Normal index.ts'te burada "17:30 civarı değilse skip et" kontrolü var.

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY)
  const todayStr = `${berlin.year}-${berlin.month}-${berlin.day}`
  const startISO = new Date(berlinMidnightUTC(todayStr)).toISOString()
  const endISO = new Date(berlinMidnightUTC(todayStr) + 86400000).toISOString()

  const [{ data: records }, { data: hours }] = await Promise.all([
    supabase.from("records")
      .select("*, employees(akt_no), job_types(code, is_mts, is_variable_price, price_eur)")
      .gte("created_at", startISO).lt("created_at", endISO),
    supabase.from("daily_hours")
      .select("branch, employees(akt_no)")
      .eq("work_date", todayStr),
  ])

  const branchMap: Record<string, string> = {}
  for (const h of hours ?? []) {
    branchMap[(h as any).employees.akt_no] = (h as any).branch
  }

  let normal = 0, mts = 0, privat = 0
  const branchRevenue: Record<string, number> = {}
  BRANCHES.forEach((b) => { branchRevenue[b] = 0 })

  for (const r of (records ?? []) as any[]) {
    const base = r.job_types.is_variable_price ? (r.custom_price || 0) : (r.job_types.price_eur || 0)
    const price = base + (r.regiestunde || 0) * REGIESTUNDE_RATE
    if (r.job_types.is_mts) mts += price
    else if (r.job_types.code === "Privat") privat += price
    else normal += price
    const branch = branchMap[r.employees.akt_no]
    if (branch && branchRevenue[branch] !== undefined) branchRevenue[branch] += price
  }

  const total = normal + mts + privat
  const netto = normal * 0.75 + mts + privat

  const bodyLines = [
    `[TEST] Gesamtumsatz: ${fmtEur(total)}`,
    `Netto Umsatz: ${fmtEur(netto)}`,
    ...BRANCHES.map((b) => `${b}: ${fmtEur(branchRevenue[b])}`),
  ]

  const { data: subs } = await supabase.from("push_subscriptions").select("*")

  webpush.setVapidDetails("mailto:kontakt@autowerk.app", VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY)

  const payload = JSON.stringify({
    title: `[TEST] Tagesabschluss ${todayStr}`,
    body: bodyLines.join("\n"),
  })

  const results = await Promise.allSettled(
    (subs ?? []).map(async (sub: any) => {
      try {
        await webpush.sendNotification(
          { endpoint: sub.endpoint, keys: { p256dh: sub.p256dh, auth: sub.auth } },
          payload,
        )
        return { ok: true }
      } catch (err: any) {
        if (err?.statusCode === 404 || err?.statusCode === 410) {
          await supabase.from("push_subscriptions").delete().eq("endpoint", sub.endpoint)
        }
        return { ok: false, statusCode: err?.statusCode, message: err?.message }
      }
    }),
  )

  return new Response(
    JSON.stringify({ test: true, subscriberCount: (subs ?? []).length, results, total, netto, berlinTime: `${berlin.hour}:${berlin.minute}` }),
    { headers: { "Content-Type": "application/json" } },
  )
})
