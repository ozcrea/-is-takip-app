// Atölye İş Takip — Otomatik Gün Sonu Bildirimi (Web Push)
//
// Bu fonksiyon pg_cron tarafından günde iki kez tetiklenir (15:30 ve 16:30 UTC —
// bkz. schema_v9.sql). Almanya'nın yaz/kış saati (CEST/CET) arasında elle
// ayarlama gerekmesin diye, fonksiyon kendi içinde gerçek Berlin saatinin
// 17:30 civarında olup olmadığını kontrol eder; değilse hiçbir şey yapmadan
// çıkar. Yani iki tetiklemeden sadece biri gerçekten bildirim gönderir.
//
// Not: Bu bildirim BİLEREK sadece Gesamtumsatz (toplam ciro) gösteriyor.
// Önceden şube bazlı kırılım da vardı, ama şube ataması o günkü
// daily_hours'a bağlı olduğu için (çalışan henüz saatini girmemişse veya
// Fotoservice gibi sabit-şube atamaları için) şef panelindeki gerçek
// zamanlı rakamlarla tutarsız kalabiliyordu. Detaylı/şube bazlı rapor
// için şef panelindeki "Zusammenfassung pro Mitarbeiter" ve "Tägliche
// Aufschlüsselung" kullanılmalı — onlar canlı veriden hesaplanıyor.
//
// Gerekli secret'lar (Supabase Dashboard > Edge Functions > Secrets'tan
// elle eklenmeli — SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY zaten otomatik
// tanımlıdır, bunları eklemenize gerek yok):
//   VAPID_PUBLIC_KEY
//   VAPID_PRIVATE_KEY

import { createClient } from "npm:@supabase/supabase-js@2"
import webpush from "npm:web-push@3.6.7"

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const VAPID_PUBLIC_KEY = Deno.env.get("VAPID_PUBLIC_KEY")!
const VAPID_PRIVATE_KEY = Deno.env.get("VAPID_PRIVATE_KEY")!

const REGIESTUNDE_RATE = 33.28

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

// Belirtilen (Berlin yerel) tarihin gece yarısının UTC karşılığını hesaplar.
// Öğlen saatindeki ofseti kullanır, böylece gün dönümü/saat değişimi
// anındaki belirsizlikten etkilenmez.
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
  const hour = parseInt(berlin.hour)
  const minute = parseInt(berlin.minute)
  const minutesSince1730 = (hour * 60 + minute) - (17 * 60 + 30)

  // Sadece 17:25–17:39 Berlin saati penceresinde gerçekten gönder.
  if (minutesSince1730 < -5 || minutesSince1730 > 9) {
    return new Response(
      JSON.stringify({ skipped: true, berlinTime: `${berlin.hour}:${berlin.minute}` }),
      { headers: { "Content-Type": "application/json" } },
    )
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY)
  const todayStr = `${berlin.year}-${berlin.month}-${berlin.day}`
  const startISO = new Date(berlinMidnightUTC(todayStr)).toISOString()
  const endISO = new Date(berlinMidnightUTC(todayStr) + 86400000).toISOString()

  const { data: records } = await supabase.from("records")
    .select("*, job_types(is_variable_price, price_eur)")
    .gte("created_at", startISO).lt("created_at", endISO)

  let total = 0
  for (const r of (records ?? []) as any[]) {
    const base = r.job_types.is_variable_price ? (r.custom_price || 0) : (r.job_types.price_eur || 0)
    // extra_arbeit_price: Extra Arbeit ile eklenen ek hizmetlerin fiyatı,
    // Regiestunde gibi ana kayda toplanıyor — bkz. index.html insertJobRecord().
    total += base + (r.regiestunde || 0) * REGIESTUNDE_RATE + (r.extra_arbeit_price || 0)
  }

  const bodyLines = [`Gesamtumsatz: ${fmtEur(total)}`]

  const { data: subs } = await supabase.from("push_subscriptions").select("*")

  webpush.setVapidDetails("mailto:kontakt@autowerk.app", VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY)

  const payload = JSON.stringify({
    title: `Tagesabschluss ${todayStr}`,
    body: bodyLines.join("\n"),
  })

  const results = await Promise.allSettled(
    (subs ?? []).map(async (sub: any) => {
      try {
        await webpush.sendNotification(
          { endpoint: sub.endpoint, keys: { p256dh: sub.p256dh, auth: sub.auth } },
          payload,
        )
      } catch (err: any) {
        if (err?.statusCode === 404 || err?.statusCode === 410) {
          await supabase.from("push_subscriptions").delete().eq("endpoint", sub.endpoint)
        }
        throw err
      }
    }),
  )

  return new Response(
    JSON.stringify({ sent: results.length, todayStr, total }),
    { headers: { "Content-Type": "application/json" } },
  )
})
