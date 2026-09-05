// Atölye İş Takip — TEK SEFERLİK migrasyon fonksiyonu
//
// Ne yapar: `employees` tablosunda `auth_user_id` boş olan her satır için
// gerçek bir Supabase Auth hesabı oluşturur (aynı mevcut şifreyle), ve
// oluşan hesabın id'sini geri employees.auth_user_id'ye yazar.
//
// Güvenli/tekrar-çalıştırılabilir: sadece auth_user_id'si HÂLÂ boş olan
// satırları işler. İki kere çalıştırmak sorun çıkarmaz, zaten taşınmış
// çalışanları tekrar işlemez.
//
// Kullanım: Bu fonksiyonu deploy ettikten sonra Supabase Dashboard'daki
// "Invoke" (test çağırma) butonuyla BİR KEZ çalıştırın. Yanıtta her
// çalışan için ok:true/false göreceksiniz.
//
// Sahibin (owner) gizli admin hesabını da employees tablosuna elle
// eklediyseniz (schema_v11.sql, madde 3), bu fonksiyonu TEKRAR
// çalıştırdığınızda o hesap için de otomatik olarak Auth hesabı
// oluşturulur — ayrı bir işlem yapmanıza gerek yok.

import { createClient } from "npm:@supabase/supabase-js@2"

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const EMAIL_DOMAIN = "mitarbeiter.autowerk.app"

Deno.serve(async () => {
  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY)

  const { data: emps, error } = await supabase
    .from("employees")
    .select("*")
    .is("auth_user_id", null)

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    })
  }

  const results: any[] = []

  for (const emp of emps ?? []) {
    if (!emp.password) {
      results.push({ akt_no: emp.akt_no, ok: false, error: "employees.password boş, atlandı" })
      continue
    }

    const email = `${emp.akt_no.toLowerCase()}@${EMAIL_DOMAIN}`

    const { data: created, error: createErr } = await supabase.auth.admin.createUser({
      email,
      password: emp.password,
      email_confirm: true,
      user_metadata: { employee_id: emp.id, akt_no: emp.akt_no, name: emp.name },
    })

    if (createErr) {
      results.push({ akt_no: emp.akt_no, ok: false, error: createErr.message })
      continue
    }

    const { error: updateErr } = await supabase
      .from("employees")
      .update({ auth_user_id: created.user.id })
      .eq("id", emp.id)

    results.push({ akt_no: emp.akt_no, email, ok: !updateErr, error: updateErr?.message ?? null })
  }

  return new Response(JSON.stringify({ migrated: results }), {
    headers: { "Content-Type": "application/json" },
  })
})
