// @ts-nocheck
import { serve } from "https://deno.land/std/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js";
import { JWT } from "npm:google-auth-library";

type Json = Record<string, unknown>;
type FcmFailure = { token: string; status: number; detail: string };
type FcmSendSummary = {
  attempted: number;
  success: number;
  failure: number;
  failures: FcmFailure[];
};

function getAuthHeader(req: Request): string | null {
  const h = req.headers.get("authorization") ?? req.headers.get("Authorization");
  if (!h) return null;
  return h;
}

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-supabase-api-version, prefer",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonRes(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}

function requireString(v: unknown, name: string): string {
  if (typeof v !== "string") {
    throw new Error(`Missing/invalid '${name}'.`);
  }
  const s = v.trim();
  if (!s) throw new Error(`Missing/empty '${name}'.`);
  return s;
}

/** Lowercase UUID strings so device rows and notification inserts always match Map lookups. */
function normUserId(v: unknown): string {
  if (v == null) return "";
  const s = typeof v === "string" ? v.trim() : String(v).trim();
  return s.toLowerCase();
}

/** FCM data values must be strings; keep sizes reasonable. */
function withFcmTextPayload(
  base: Record<string, string>,
  title: string,
  message: string,
): Record<string, string> {
  return {
    ...base,
    title: (title || "").slice(0, 512),
    message: (message || "").slice(0, 2048),
  };
}

async function sendFcm({
  fcmAccessToken,
  firebaseProjectId,
  registrationIds,
  title,
  message,
  data,
}: {
  fcmAccessToken: string;
  firebaseProjectId: string;
  registrationIds: string[];
  title: string;
  message: string;
  data: Record<string, string>;
}): Promise<FcmSendSummary> {
  if (registrationIds.length === 0) {
    return { attempted: 0, success: 0, failure: 0, failures: [] };
  }

  const endpoint = `https://fcm.googleapis.com/v1/projects/${firebaseProjectId}/messages:send`;
  const failures: FcmFailure[] = [];
  let success = 0;

  // HTTP v1 sends one token per call.
  for (const token of registrationIds) {
    const res = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${fcmAccessToken}`,
      },
      body: JSON.stringify({
        message: {
          token,
          notification: {
            title,
            body: message,
          },
          data: Object.fromEntries(
            Object.entries(data).map(([k, v]) => [k, String(v ?? "")]),
          ),
          android: {
            priority: "HIGH",
            notification: {
              // Must match Flutter [LocalNotificationService] channel id (Android 8+).
              channel_id: "high_importance_channel",
              sound: "default",
            },
          },
        },
      }),
    });

    if (!res.ok) {
      const txt = await res.text().catch(() => "");
      console.error("FCM v1 send failed", res.status, txt);
      failures.push({
        token,
        status: res.status,
        detail: txt.slice(0, 1000),
      });
    } else {
      success += 1;
    }
  }

  return {
    attempted: registrationIds.length,
    success,
    failure: failures.length,
    failures,
  };
}

function decodeBase64Utf8(raw: string): string {
  const binary = atob(raw);
  const bytes = Uint8Array.from(binary, (c) => c.charCodeAt(0));
  return new TextDecoder().decode(bytes);
}

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

function getServiceAccountFromEnv(): ServiceAccount {
  const b64 = Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON_BASE64") ?? "";
  if (!b64) throw new Error("Missing GOOGLE_SERVICE_ACCOUNT_JSON_BASE64 secret.");
  const json = decodeBase64Utf8(b64.trim());
  const parsed = JSON.parse(json) as Partial<ServiceAccount>;

  const projectId = parsed.project_id?.trim();
  const clientEmail = parsed.client_email?.trim();
  const privateKey = parsed.private_key;
  if (!projectId || !clientEmail || !privateKey) {
    throw new Error("Invalid service account JSON.");
  }

  return {
    project_id: projectId,
    client_email: clientEmail,
    private_key: privateKey,
  };
}

async function getFcmAccessToken(sa: ServiceAccount): Promise<string> {
  const client = new JWT({
    email: sa.client_email,
    key: sa.private_key,
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });
  const token = await client.getAccessToken();
  if (!token || !token.token) {
    throw new Error("Could not obtain Google OAuth access token.");
  }
  return token.token;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  try {
    if (req.method !== "POST") {
      return jsonRes(405, { error: "Method not allowed" });
    }

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return jsonRes(500, { error: "Missing secrets." });
    }
    const serviceAccount = getServiceAccountFromEnv();
    const fcmAccessToken = await getFcmAccessToken(serviceAccount);

    const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    if (!SUPABASE_ANON_KEY) {
      return jsonRes(500, { error: "Missing SUPABASE_ANON_KEY (needed for JWT verification)." });
    }

    const authHeader = getAuthHeader(req);
    if (!authHeader?.trim()) {
      return jsonRes(401, { error: "Missing Authorization header." });
    }

    // Anon client + forwarded Authorization header (Supabase Edge pattern).
    // service_role + auth.getUser(jwt) often returns 401 for user access tokens
    // (e.g. publishable key / ES256 sessions from supabase-flutter).
    const supabaseAuth = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: {
        headers: {
          Authorization: authHeader,
          apikey: SUPABASE_ANON_KEY,
        },
      },
    });
    const { data: userData, error: authErr } = await supabaseAuth.auth.getUser();
    if (authErr || !userData?.user) {
      return jsonRes(401, {
        error: "Unauthorized.",
        detail: authErr?.message ?? "getUser_failed",
      });
    }
    const requesterId = userData.user.id;

    const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      global: { headers: { "Content-Type": "application/json" } },
    });

    const body: Json = await req.json();
    const action = requireString(body["action"], "action").toLowerCase();

    const { data: isAdminData, error: isAdminErr } = await supabaseAdmin.rpc("is_admin", { uid: requesterId });
    const isAdmin = !isAdminErr && Boolean(isAdminData);

    if (action === "user_notification") {
      if (!isAdmin) {
        return jsonRes(403, { error: "Admin only." });
      }

      const title = requireString(body["title"], "title");
      const message = requireString(body["message"], "message");
      const kind = requireString(body["kind"] ?? "promotion", "kind");
      const redirectType = requireString(body["redirect_type"] ?? "none", "redirect_type");
      const redirectValue = (typeof body["redirect_value"] === "string" ? body["redirect_value"] : null) ?? "";

      const broadcast = Boolean(body["broadcast"] ?? false);
      const targetUserId = typeof body["user_id"] === "string" ? body["user_id"] : "";

      const nowIso = new Date().toISOString();

      if (broadcast) {
        // Build token map first; push is only possible for users with tokens.
        const { data: devices, error: devErr } = await supabaseAdmin
          .from("user_devices")
          .select("user_id,fcm_token");
        if (devErr) throw devErr;

        const userTokens = new Map<string, string[]>();
        for (const d of devices ?? []) {
          const u = normUserId((d as any).user_id);
          const t = (d as any).fcm_token?.toString()?.trim();
          if (!u || !t) continue;
          const prev = userTokens.get(u) ?? [];
          prev.push(t);
          userTokens.set(u, prev);
        }

        // Broadcast should still save in-app notifications for all known users,
        // even when some/all users have no registered device token.
        const { data: profiles, error: profilesErr } = await supabaseAdmin
          .from("profiles")
          .select("id");
        if (profilesErr) throw profilesErr;

        const allUserIds = new Set<string>();
        for (const p of profiles ?? []) {
          const uid = normUserId((p as any).id);
          if (uid) allUserIds.add(uid);
        }
        for (const uid of userTokens.keys()) {
          allUserIds.add(uid);
        }

        const userIds = [...allUserIds];
        if (userIds.length === 0) {
          return jsonRes(200, {
            ok: true,
            fcm: { attempted: 0, success: 0, failure: 0, failures: [] },
            note: "No users found to notify.",
          });
        }

        const insertRows = userIds.map((uid) => ({
          user_id: uid,
          kind,
          title,
          body: message,
          redirect_type: redirectType,
          redirect_value: redirectValue || null,
          order_id: null,
          read_at: null,
          created_at: nowIso,
        }));

        const { data: inserted, error: insErr } = await supabaseAdmin
          .from("user_notifications")
          .insert(insertRows)
          .select("id,user_id");
        if (insErr) throw insErr;

        const insertedByUser = new Map<string, string>();
        for (const r of inserted ?? []) {
          const id = (r as any).id?.toString();
          const uid = normUserId((r as any).user_id);
          if (!id || !uid) continue;
          insertedByUser.set(uid, id);
        }

        // Send per user (still multicast per user for multiple tokens).
        const sendSummaries: FcmSendSummary[] = [];
        for (const [uid, tokens] of userTokens.entries()) {
          const notificationId = insertedByUser.get(uid);
          if (!notificationId) continue;
          const summary = await sendFcm({
            fcmAccessToken,
            firebaseProjectId: serviceAccount.project_id,
            registrationIds: tokens,
            title,
            message,
            data: withFcmTextPayload(
              {
                notification_id: notificationId,
                kind,
                redirect_type: redirectType,
                redirect_value: redirectValue || "",
              },
              title,
              message,
            ),
          });
          sendSummaries.push(summary);
        }

        const aggregate = sendSummaries.reduce<FcmSendSummary>(
          (acc, s) => {
            acc.attempted += s.attempted;
            acc.success += s.success;
            acc.failure += s.failure;
            acc.failures.push(...s.failures);
            return acc;
          },
          { attempted: 0, success: 0, failure: 0, failures: [] },
        );

        const usersWithoutTokens = userIds.length - userTokens.size;
        const note = usersWithoutTokens > 0
          ? `${usersWithoutTokens} user(s) had no device token; in-app notification saved.`
          : undefined;

        return jsonRes(200, { ok: true, fcm: aggregate, note });
      }

      if (!targetUserId) {
        return jsonRes(400, { error: "Missing user_id for target notification." });
      }

      const targetNorm = normUserId(targetUserId);

      const { data: tokensRows } = await supabaseAdmin
        .from("user_devices")
        .select("fcm_token")
        .eq("user_id", targetNorm)
        ;

      const tokens = (tokensRows ?? [])
        .map((r: any) => r.fcm_token?.toString())
        .filter((t: string | undefined) => !!t);

      const { data: inserted, error: insErr } = await supabaseAdmin
        .from("user_notifications")
        .insert({
          user_id: targetNorm,
          kind,
          title,
          body: message,
          redirect_type: redirectType,
          redirect_value: redirectValue || null,
          order_id: null,
          read_at: null,
          created_at: nowIso,
        })
        .select("id")
        .single();
      if (insErr) throw insErr;

      const notificationId = (inserted as any).id?.toString();
      if (!notificationId) return jsonRes(200, { ok: true });

      if (tokens.length === 0) {
        return jsonRes(200, {
          ok: true,
          fcm: { attempted: 0, success: 0, failure: 0, failures: [] },
          note: "Target user has no registered device token; in-app notification saved.",
        });
      }

      const summary = await sendFcm({
        fcmAccessToken,
        firebaseProjectId: serviceAccount.project_id,
        registrationIds: tokens,
        title,
        message,
        data: withFcmTextPayload(
          {
            notification_id: notificationId,
            kind,
            redirect_type: redirectType,
            redirect_value: redirectValue || "",
          },
          title,
          message,
        ),
      });

      return jsonRes(200, { ok: true, fcm: summary });
    }

    if (action === "order_status") {
      const userId = requireString(body["user_id"], "user_id");
      const orderId = requireString(body["order_id"], "order_id");
      const kind = requireString(body["kind"] ?? "order_status", "kind");
      const title = requireString(body["title"], "title");
      const message = requireString(body["message"], "message");
      const redirectType = requireString(body["redirect_type"] ?? "order", "redirect_type");
      const redirectValue = requireString(body["redirect_value"] ?? orderId, "redirect_value");
      const notificationIdRaw = body["notification_id"];
      const notificationId = typeof notificationIdRaw === "string" ? notificationIdRaw.trim() : "";

      // Allow if requester is same user or admin.
      const userNorm = normUserId(userId);
      if (!isAdmin && normUserId(requesterId) !== userNorm) {
        return jsonRes(403, { error: "Unauthorized for this user." });
      }

      const { data: tokensRows, error: tokErr } = await supabaseAdmin
        .from("user_devices")
        .select("fcm_token")
        .eq("user_id", userNorm);
      if (tokErr) throw tokErr;

      const tokens = (tokensRows ?? [])
        .map((r: any) => r.fcm_token?.toString())
        .filter((t: string | undefined) => !!t);

      // Fallback: latest profile-level token for user-specific events.
      if (tokens.length === 0) {
        const { data: profileRow, error: profileErr } = await supabaseAdmin
          .from("profiles")
          .select("fcm_token")
          .eq("id", userNorm)
          .maybeSingle();
        if (profileErr) {
          console.error("FCM token fallback(profile) lookup failed", {
            user_id: userNorm,
            detail: profileErr.message ?? String(profileErr),
          });
        } else {
          const profileToken = (profileRow as any)?.fcm_token?.toString()?.trim();
          if (profileToken) {
            tokens.push(profileToken);
          }
        }
      }

      if (tokens.length === 0) {
        console.error("FCM token missing for user-specific event", {
          user_id: userNorm,
          order_id: orderId,
          action,
        });
      }

      const data: Record<string, string> = withFcmTextPayload(
        {
          kind,
          order_id: orderId,
          redirect_type: redirectType,
          redirect_value: redirectValue,
        },
        title,
        message,
      );
      if (notificationId) data["notification_id"] = notificationId;

      const summary = await sendFcm({
        fcmAccessToken,
        firebaseProjectId: serviceAccount.project_id,
        registrationIds: tokens,
        title,
        message,
        data,
      });

      if (summary.failure > 0) {
        console.error("FCM send had token failures", {
          user_id: userNorm,
          order_id: orderId,
          failures: summary.failures.map((f) => ({
            status: f.status,
            detail: f.detail.slice(0, 200),
          })),
        });
      }

      return jsonRes(200, { ok: true, fcm: summary });
    }

    return jsonRes(400, { error: "Unknown action." });
  } catch (e) {
    console.error(e);
    return jsonRes(500, { error: "Failed.", detail: String(e) });
  }
});

