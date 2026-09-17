// Atölye İş Takip — Otomatik Gün Sonu Bildirimi (Web Push)
//
// Bu fonksiyon pg_cron tarafından günde iki kez tetiklenir (15:45 ve 16:45 UTC —
// bkz. schema_v34.sql, eski 15:30/16:30'u değiştirdi). Almanya'nın yaz/kış
// saati (CEST/CET) arasında elle ayarlama gerekmesin diye, fonksiyon kendi
// içinde gerçek Berlin saatinin 17:45 civarında olup olmadığını kontrol
// eder; değilse hiçbir şey yapmadan çıkar. Yani iki tetiklemeden sadece
// biri gerçekten bildirim gönderir.
//
// NOT: bu pencere schema_v34.sql'deki cron saatleriyle BİRLİKTE
// değiştirilmeli — sadece biri güncellenirse (cron yeni saatte tetikler
// ama fonksiyon eski pencereyi beklerse, veya tam tersi) bildirim hiç
// gitmez, sessizce "skipped" döner.
//
// KRİTİK HATA DÜZELTMESİ (bu sürüm): önceki sürüm Supabase sorgularının
// SADECE `data` alanını okuyup `error`'u tamamen görmezden geliyordu. Bir
// sorgu (ör. geçici bir DB hatası, yanlış yapılandırılmış bir secret,
// join/embed hatası) başarısız olursa `data` undefined olur, `?? []` ile
// SESSİZCE boş diziye düşer ve bildirim "her şey €0,00" gibi görünür —
// gerçek bir hata olduğu HİÇBİR yerde görünmez. Bu sürüm artık her
// sorgunun `error`'unu kontrol ediyor; biri hata verirse sahte bir "€0,00"
// raporu göndermek yerine açık bir hata bildirimi gönderiyor VE hatayı
// JSON yanıtına (Supabase Dashboard > Edge Functions > Logs'ta görünür)
// yazıyor.
//
// Gerekli secret'lar (Supabase Dashboard > Edge Functions > Secrets'tan
// elle eklenmeli — SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY(veya yeni
// SUPABASE_SECRET_KEYS) zaten otomatik tanımlıdır, bunları eklemenize
// gerek yok):
//   VAPID_PUBLIC_KEY
//   VAPID_PRIVATE_KEY
//
// NOT (17.09.2026): "JWT issued at future" hatası görüldü — Supabase
// panelinde SUPABASE_SERVICE_ROLE_KEY artık "Deprecated" işaretli, yerine
// yeni JWT Signing Keys sistemi (SUPABASE_SECRET_KEYS) öneriliyor. Hata
// ~5 dakika içinde kendiliğinden düzeliyor — bu, anahtar ROTASYONU
// sırasında kısa süreli bir clock-skew/propagation penceresine işaret
// ediyor (kalıcı bir yanlış yapılandırma değil). Aşağıdaki kod artık
// mevcutsa YENİ anahtarı (düz metin veya JSON dizi olabilir) tercih
// ediyor, yoksa eski değişkene düşüyor; ayrıca bu spesifik hata için
// birkaç kez otomatik yeniden deniyor (bkz. fetchReportDataWithRetry).

import { createClient } from "npm:@supabase/supabase-js@2"
import webpush from "npm:web-push@3.6.7"

// TANI AMAÇLI: hangi env var'ın bulunduğunu, JSON dizi mi düz metin mi
// olduğunu ve çözümlenen anahtarın SADECE ilk birkaç karakterini/uzunluğunu
// kaydeder — gerçek secret DEĞERİ hiçbir zaman loglanmaz/döndürülmez, sadece
// bu güvenli özet bilgisi, Supabase panelindeki değerle karşılaştırma
// yapabilmek için her yanıta ekleniyor (bkz. Deno.serve içindeki kullanım).
let keyDiagnostics: {
  source: "SUPABASE_SECRET_KEYS" | "SUPABASE_SERVICE_ROLE_KEY" | "none"
  wasJsonArray: boolean
  arrayElementType: string | null
  resolvedPrefix: string
  resolvedLength: number
} = { source: "none", wasJsonArray: false, arrayElementType: null, resolvedPrefix: "", resolvedLength: 0 }

function resolveServiceKey(): string {
  const secretKeys = Deno.env.get("SUPABASE_SECRET_KEYS")
  const legacyKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
  const raw = secretKeys ?? legacyKey
  const source: typeof keyDiagnostics.source = secretKeys ? "SUPABASE_SECRET_KEYS" : (legacyKey ? "SUPABASE_SERVICE_ROLE_KEY" : "none")
  if (!raw) {
    keyDiagnostics = { source, wasJsonArray: false, arrayElementType: null, resolvedPrefix: "", resolvedLength: 0 }
    throw new Error("SUPABASE_SECRET_KEYS veya SUPABASE_SERVICE_ROLE_KEY bulunamadı")
  }
  const trimmed = raw.trim()
  let resolved = trimmed
  let wasArray = false
  let arrayElementType: string | null = null
  if (trimmed.startsWith("[")) {
    try {
      const arr = JSON.parse(trimmed)
      if (Array.isArray(arr) && arr.length > 0) {
        wasArray = true
        const first = arr[0]
        arrayElementType = typeof first
        // Dizi elemanları düz metin string olabilir, veya {api_key:...} /
        // {key:...} gibi bir obje olabilir — ikisini de dene, olmazsa
        // JSON.stringify ile en azından çökmeden devam et (yanlış ama
        // teşhis edilebilir bir sonuç verir).
        resolved = typeof first === "string"
          ? first
          : (first?.api_key ?? first?.key ?? first?.secret ?? JSON.stringify(first))
      }
    } catch {
      // JSON değilse düz metin olarak devam et.
    }
  }
  keyDiagnostics = {
    source,
    wasJsonArray: wasArray,
    arrayElementType,
    resolvedPrefix: resolved.slice(0, 12),
    resolvedLength: resolved.length,
  }
  return resolved
}

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!
const SERVICE_ROLE_KEY = resolveServiceKey()
const VAPID_PUBLIC_KEY = Deno.env.get("VAPID_PUBLIC_KEY")!
const VAPID_PRIVATE_KEY = Deno.env.get("VAPID_PRIVATE_KEY")!

const REGIESTUNDE_RATE = 33.28
const BRANCHES = ["Ausschläger Weg", "Horn", "Wiesendamm"]
// index.html'deki BRANCH_FOTOSERVICE_OWNER'ın tersi — A3A/W1S/H1A o gün
// kendi daily_hours'unu (branch) girmemiş olsa bile, bu hesaplar zaten
// SABİT olarak bir şubeye bağlı, o yüzden şubeleri her zaman bilinir.
// Bu harita güncellenirse index.html'dekiyle senkron tutulmalı.
const FIXED_BRANCH_BY_AKT: Record<string, string> = {
  "A3A": "Ausschläger Weg",
  "W1S": "Wiesendamm",
  "H1A": "Horn",
}

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

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

// "JWT issued at future" gibi geçici anahtar-rotasyonu hatalarında birkaç
// kez yeniden dener (toplam ~45 saniye) — gözlemlenen ~5 dakikalık
// kendiliğinden-düzelme penceresinin tamamını garanti edemez ama Edge
// Function'ın çalışma süresi sınırları içinde makul bir ilk savunma
// katmanı. Başka türden bir hata (ör. gerçek bir yetki sorunu) ise hemen
// çıkar, gereksiz yere beklemez.
async function fetchReportDataWithRetry(
  supabase: ReturnType<typeof createClient>,
  startISO: string,
  endISO: string,
  todayStr: string,
  maxAttempts = 3,
  delayMs = 15000,
) {
  let recordsRes: any, hoursRes: any
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    ;[recordsRes, hoursRes] = await Promise.all([
      supabase.from("records")
        .select("*, employees(akt_no), job_types(code, is_mts, is_variable_price, price_eur)")
        .gte("created_at", startISO).lt("created_at", endISO),
      supabase.from("daily_hours")
        .select("branch, employees(akt_no)")
        .eq("work_date", todayStr),
    ])
    const err = recordsRes.error || hoursRes.error
    if (!err) return { recordsRes, hoursRes, attempts: attempt }
    const msg = (err.message || "").toLowerCase()
    const isTransientJwtIssue = msg.includes("jwt")
    if (!isTransientJwtIssue || attempt === maxAttempts) return { recordsRes, hoursRes, attempts: attempt }
    await sleep(delayMs)
  }
  return { recordsRes, hoursRes, attempts: maxAttempts }
}

async function sendToAllSubscriptions(
  supabase: ReturnType<typeof createClient>,
  title: string,
  body: string,
) {
  const { data: subs } = await supabase.from("push_subscriptions").select("*")
  webpush.setVapidDetails("mailto:kontakt@autowerk.app", VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY)
  const payload = JSON.stringify({ title, body })
  return Promise.allSettled(
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
}

Deno.serve(async () => {
  const now = new Date()
  const berlin = getBerlinParts(now)
  const hour = parseInt(berlin.hour)
  const minute = parseInt(berlin.minute)
  const minutesSince1745 = (hour * 60 + minute) - (17 * 60 + 45)

  // Sadece 17:40–17:54 Berlin saati penceresinde gerçekten gönder.
  // keyDiagnostics buraya da eklendi: böylece pencere dışında elle
  // "Invoke" edilse bile (ör. TANI amaçlı), hangi anahtarın okunduğu
  // görülebilir — gerçek gönderimi beklemeye gerek kalmaz.
  if (minutesSince1745 < -5 || minutesSince1745 > 9) {
    return new Response(
      JSON.stringify({ skipped: true, berlinTime: `${berlin.hour}:${berlin.minute}`, keyDiagnostics }),
      { headers: { "Content-Type": "application/json" } },
    )
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY)
  const todayStr = `${berlin.year}-${berlin.month}-${berlin.day}`
  const startISO = new Date(berlinMidnightUTC(todayStr)).toISOString()
  const endISO = new Date(berlinMidnightUTC(todayStr) + 86400000).toISOString()

  const { recordsRes, hoursRes, attempts } = await fetchReportDataWithRetry(supabase, startISO, endISO, todayStr)

  // Sorgulardan biri hata verdiyse (yeniden denemelerden sonra bile)
  // SESSİZCE €0,00 raporu göndermek yerine açık bir hata bildirimi gönder
  // — aksi halde gerçek bir DB/config hatası, "bugün hiç iş yapılmamış"
  // ile ayırt edilemez hale gelir.
  if (recordsRes.error || hoursRes.error) {
    const errMsg = [recordsRes.error?.message, hoursRes.error?.message]
      .filter(Boolean).join(" / ")
    await sendToAllSubscriptions(
      supabase,
      `Tagesabschluss ${todayStr} — FEHLER`,
      `Bericht konnte nicht erstellt werden (${attempts} Versuch(e)): ${errMsg}`,
    )
    return new Response(
      JSON.stringify({ error: errMsg, attempts, recordsError: recordsRes.error, hoursError: hoursRes.error, keyDiagnostics }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    )
  }

  const records = recordsRes.data
  const hours = hoursRes.data

  const branchMap: Record<string, string> = {}
  for (const h of hours ?? []) {
    branchMap[(h as any).employees.akt_no] = (h as any).branch
  }

  let normal = 0, mts = 0, privat = 0, unassigned = 0
  const branchRevenue: Record<string, number> = {}
  BRANCHES.forEach((b) => { branchRevenue[b] = 0 })

  for (const r of (records ?? []) as any[]) {
    const base = r.job_types.is_variable_price ? (r.custom_price || 0) : (r.job_types.price_eur || 0)
    // extra_arbeit_price: Extra Arbeit ile eklenen ek hizmetlerin fiyatı,
    // Regiestunde gibi ana kayda toplanıyor — bkz. index.html insertJobRecord().
    const price = base + (r.regiestunde || 0) * REGIESTUNDE_RATE + (r.extra_arbeit_price || 0)
    if (r.job_types.is_mts) mts += price
    else if (r.job_types.code === "Privat") privat += price
    else normal += price
    // Önce o günkü daily_hours'a bakılır; yoksa (örn. Fotoservice'in
    // otomatik atandığı A3A/W1S/H1A o gün kendi saatini girmemişse) sabit
    // şube eşlemesine düşülür. İkisi de yoksa "Nicht zugeordnet"a düşer —
    // Gesamtumsatz ile şube toplamlarının HER ZAMAN eşleşmesini sağlar.
    const branch = branchMap[r.employees.akt_no] || FIXED_BRANCH_BY_AKT[r.employees.akt_no]
    if (branch && branchRevenue[branch] !== undefined) branchRevenue[branch] += price
    else unassigned += price
  }

  const total = normal + mts + privat

  const bodyLines = [
    `Gesamtumsatz: ${fmtEur(total)}`,
    ...BRANCHES.map((b) => `${b}: ${fmtEur(branchRevenue[b])}`),
  ]
  if (unassigned > 0.001) {
    bodyLines.push(`Nicht zugeordnet (keine Filiale erfasst): ${fmtEur(unassigned)}`)
  }

  const results = await sendToAllSubscriptions(
    supabase,
    `Tagesabschluss ${todayStr}`,
    bodyLines.join("\n"),
  )

  return new Response(
    JSON.stringify({ sent: results.length, todayStr, total, branchRevenue, unassigned, keyDiagnostics }),
    { headers: { "Content-Type": "application/json" } },
  )
})
