// @ts-nocheck
import { createClient } from "npm:@supabase/supabase-js";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-supabase-api-version, prefer, accept, accept-encoding, accept-language",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Max-Age": "86400",
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

function generateOneTimeBridgePassword(): string {
  const bytes = new Uint8Array(24);
  crypto.getRandomValues(bytes);
  const entropy = Array.from(bytes).map((b) => b.toString(16).padStart(2, "0")).join("");
  return `AnjanamBridge@${entropy}#`;
}

async function sha256Hex(input: string): Promise<string> {
  const enc = new TextEncoder();
  const digest = await crypto.subtle.digest("SHA-256", enc.encode(input));
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
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
  // 204 must have no body; a body can break CORS preflight and surface as OPTIONS 500 / "Failed to fetch".
  const method = (req.method ?? "").toUpperCase();
  if (method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const FIREBASE_WEB_API_KEY = Deno.env.get("FIREBASE_WEB_API_KEY") ?? "";
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !SUPABASE_ANON_KEY) {
      return json(500, { error: "missing_supabase_env" });
    }
    if (!FIREBASE_WEB_API_KEY) {
      return json(500, { error: "missing_firebase_web_api_key" });
    }

    const body = await req.json().catch(() => ({}));
    const idToken = String(body?.id_token ?? body?.firebase_id_token ?? "").trim();
    const clientNonce = String(body?.client_nonce ?? "").trim();
    if (!idToken) return json(400, { error: "missing_firebase_id_token" });
    if (clientNonce.length < 16 || clientNonce.length > 128) return json(400, { error: "invalid_client_nonce" });

    let verified: { localId: string; phoneNumber: string };
    try {
      verified = await verifyFirebaseToken({
        firebaseWebApiKey: FIREBASE_WEB_API_KEY,
        idToken,
      });
    } catch {
      return json(401, { error: "invalid_firebase_id_token" });
    }
    const phone = normalizePhone(verified.phoneNumber);
    const firebaseUid = verified.localId;
    if (!phone || !firebaseUid) return json(400, { error: "invalid_phone_identity" });

    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const rateKey = `phone:${firebaseUid}`;
    const now = new Date();
    const nowIso = now.toISOString();
    const rateLimitResult = await admin.rpc("auth_bridge_increment_and_check_rate_limit", {
      p_key: rateKey,
      p_limit: 20,
      p_window_seconds: 600,
    });
    if (rateLimitResult.error || !rateLimitResult.data) {
      return json(503, { error: "rate_limit_unavailable" });
    }
    const rateData = Array.isArray(rateLimitResult.data) ? rateLimitResult.data[0] : rateLimitResult.data;
    if (!rateData || rateData.allowed !== true) return json(429, { error: "rate_limited" });

    const nonceHash = await sha256Hex(`phone:${firebaseUid}:${clientNonce}`);
    const nonceExpireIso = new Date(now.getTime() + 5 * 60 * 1000).toISOString();
    const nonceInsert = await admin.from("auth_bridge_nonces").insert({
      bridge_type: "phone",
      firebase_uid: firebaseUid,
      nonce_hash: nonceHash,
      expires_at: nonceExpireIso,
    });
    if (nonceInsert.error) {
      return json(409, { error: "nonce_replay_detected" });
    }

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
    // Rotated on every bridge sign-in to avoid static reusable shared-password risk.
    const syntheticPassword = generateOneTimeBridgePassword();

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
    } else {
      await admin.auth.admin.updateUserById(authUserId, {
        password: syntheticPassword,
        email_confirm: true,
      });
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

    const tokenRes = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: SUPABASE_ANON_KEY,
      },
      body: JSON.stringify({ email: syntheticEmail, password: syntheticPassword }),
    });
    const tokenData = await tokenRes.json().catch(() => ({}));
    if (!tokenRes.ok) {
      return json(500, { error: "session_issue_failed" });
    }
    const refreshToken = String(tokenData?.refresh_token ?? "").trim();
    if (!refreshToken) {
      return json(500, { error: "session_issue_failed" });
    }
    await admin.from("auth_bridge_nonces").update({ used_at: new Date().toISOString() }).eq("nonce_hash", nonceHash);

    return json(200, {
      ok: true,
      supabase_uid: authUserId,
      refresh_token: refreshToken,
      expires_in: Number(tokenData?.expires_in ?? 0),
      phone,
    });
  } catch (_) {
    console.error("phone_auth_bridge_error");
    return json(500, { error: "internal_error" });
  }
});
