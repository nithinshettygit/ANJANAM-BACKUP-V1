// @ts-nocheck
import { createClient } from "npm:@supabase/supabase-js";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-supabase-api-version, prefer",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}

function normalizePhone(raw: unknown): string {
  let value = String(raw ?? "").trim();
  value = value.replace(/[^\d+]/g, "");
  if (value.startsWith("00")) value = `+${value.slice(2)}`;
  if (!value.startsWith("+")) {
    if (value.length === 10) return `+91${value}`;
    return `+${value}`;
  }
  return value;
}

function syntheticEmailFromPhone(phone: string): string {
  const digits = phone.replace(/[^\d]/g, "");
  return `phone_${digits}@phone.anjanam.app`;
}

function syntheticPasswordFromPhone(phone: string): string {
  const digits = phone.replace(/[^\d]/g, "");
  return `AnjanamPhoneAuth@${digits}#v1`;
}

async function verifyFirebaseToken({
  firebaseWebApiKey,
  idToken,
}: {
  firebaseWebApiKey: string;
  idToken: string;
}): Promise<{ localId: string; phoneNumber: string }> {
  const res = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${encodeURIComponent(firebaseWebApiKey)}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ idToken }),
    },
  );
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(`firebase_token_invalid:${res.status}`);
  }
  const user = Array.isArray(data?.users) ? data.users[0] : null;
  const localId = String(user?.localId ?? "").trim();
  const phoneNumber = normalizePhone(user?.phoneNumber);
  if (!localId || !phoneNumber) {
    throw new Error("firebase_token_missing_user_data");
  }
  return { localId, phoneNumber };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 204, headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const FIREBASE_WEB_API_KEY = Deno.env.get("FIREBASE_WEB_API_KEY") ?? "";
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return json(500, { error: "missing_supabase_env" });
    }
    if (!FIREBASE_WEB_API_KEY) {
      return json(500, { error: "missing_firebase_web_api_key" });
    }

    const body = await req.json().catch(() => ({}));
    const idToken = String(body?.firebase_id_token ?? "").trim();
    const requestedPhone = normalizePhone(body?.phone);
    const requestedUid = String(body?.firebase_uid ?? "").trim();
    if (!idToken) return json(400, { error: "missing_firebase_id_token" });

    const verified = await verifyFirebaseToken({
      firebaseWebApiKey: FIREBASE_WEB_API_KEY,
      idToken,
    });
    const phone = normalizePhone(requestedPhone || verified.phoneNumber);
    const firebaseUid = requestedUid || verified.localId;
    if (!phone || !firebaseUid) return json(400, { error: "invalid_phone_identity" });

    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    let profile = null;
    const byFirebase = await admin
      .from("profiles")
      .select("id, email, full_name")
      .eq("firebase_uid", firebaseUid)
      .maybeSingle();
    if (byFirebase.data) {
      profile = byFirebase.data;
    } else {
      const byPhone = await admin
        .from("profiles")
        .select("id, email, full_name")
        .eq("phone", phone)
        .maybeSingle();
      if (byPhone.data) profile = byPhone.data;
    }

    const syntheticEmail = syntheticEmailFromPhone(phone);
    const syntheticPassword = syntheticPasswordFromPhone(phone);

    let authUserId = String(profile?.id ?? "").trim();
    if (authUserId) {
      const existing = await admin.auth.admin.getUserById(authUserId);
      if (existing.error || !existing.data?.user) {
        authUserId = "";
      }
    }

    if (!authUserId) {
      const created = await admin.auth.admin.createUser({
        email: syntheticEmail,
        password: syntheticPassword,
        email_confirm: true,
        user_metadata: { full_name: String(profile?.full_name ?? "User").trim() || "User" },
      });
      if (created.error || !created.data?.user?.id) {
        return json(500, {
          error: "auth_user_create_failed",
          detail: created.error?.message ?? "unknown",
        });
      }
      authUserId = created.data.user.id;
    }

    // Ensure profile exists + linked to phone/firebase identity.
    const upsertData: Record<string, unknown> = {
      id: authUserId,
      full_name: String(profile?.full_name ?? "User").trim() || "User",
      email: (String(profile?.email ?? "").trim() || syntheticEmail),
      phone,
      firebase_uid: firebaseUid,
      login_type: "phone",
      role: "customer",
    };
    await admin.from("profiles").upsert(upsertData, { onConflict: "id" });

    return json(200, {
      ok: true,
      supabase_uid: authUserId,
      email: syntheticEmail,
      password: syntheticPassword,
      phone,
    });
  } catch (e) {
    console.error("phone_auth_bridge_error", String(e));
    return json(500, { error: "internal_error" });
  }
});
