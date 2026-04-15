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

function syntheticPasswordFromUid(firebaseUid: string): string {
  return `AnjanamGoogleAuth@${firebaseUid}#v1`;
}

async function verifyFirebaseToken({
  firebaseWebApiKey,
  idToken,
}: {
  firebaseWebApiKey: string;
  idToken: string;
}): Promise<{ localId: string; email: string; name: string; photoUrl: string }> {
  const res = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${encodeURIComponent(firebaseWebApiKey)}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ idToken }),
    },
  );
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(`firebase_token_invalid:${res.status}`);
  const user = Array.isArray(data?.users) ? data.users[0] : null;
  const localId = String(user?.localId ?? "").trim();
  const email = String(user?.email ?? "").trim().toLowerCase();
  const name = String(user?.displayName ?? "").trim();
  const photoUrl = String(user?.photoUrl ?? "").trim();
  if (!localId || !email) throw new Error("firebase_token_missing_user_data");
  return { localId, email, name, photoUrl };
}

Deno.serve(async (req) => {
  if ((req.method ?? "").toUpperCase() === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
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
    const requestedEmail = String(body?.email ?? "").trim().toLowerCase();
    const requestedUid = String(body?.firebase_uid ?? "").trim();
    const requestedName = String(body?.display_name ?? "").trim();
    const requestedPhoto = String(body?.photo_url ?? "").trim();
    if (!idToken) return json(400, { error: "missing_firebase_id_token" });

    const verified = await verifyFirebaseToken({
      firebaseWebApiKey: FIREBASE_WEB_API_KEY,
      idToken,
    });
    const firebaseUid = requestedUid || verified.localId;
    const email = requestedEmail || verified.email;
    const displayName = requestedName || verified.name || "User";
    const photoUrl = requestedPhoto || verified.photoUrl || null;
    if (!firebaseUid || !email) return json(400, { error: "invalid_google_identity" });

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
      const byEmail = await admin
        .from("profiles")
        .select("id, email, full_name")
        .ilike("email", email)
        .maybeSingle();
      if (byEmail.data) profile = byEmail.data;
    }

    let authUserId = String(profile?.id ?? "").trim();
    if (!authUserId) {
      const listed = await admin.auth.admin.listUsers({ page: 1, perPage: 200 });
      if (listed.data?.users?.length) {
        const exact = listed.data.users.find((u) => String(u.email ?? "").trim().toLowerCase() === email);
        if (exact?.id) authUserId = exact.id;
      }
    }

    const bridgePassword = syntheticPasswordFromUid(firebaseUid);
    if (!authUserId) {
      const created = await admin.auth.admin.createUser({
        email,
        password: bridgePassword,
        email_confirm: true,
        user_metadata: { full_name: String(profile?.full_name ?? displayName).trim() || "User" },
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
        password: bridgePassword,
        email_confirm: true,
      });
    }

    await admin.from("profiles").upsert(
      {
        id: authUserId,
        full_name: String(profile?.full_name ?? displayName).trim() || "User",
        email,
        avatar_url: photoUrl,
        firebase_uid: firebaseUid,
        login_type: "google",
        role: "customer",
      },
      { onConflict: "id" },
    );

    return json(200, {
      ok: true,
      supabase_uid: authUserId,
      email,
      password: bridgePassword,
    });
  } catch (e) {
    console.error("google_auth_bridge_error", String(e));
    return json(500, { error: "internal_error" });
  }
});
