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

function requireString(v: unknown, name: string): string {
  if (typeof v !== "string") {
    throw new Error(`Missing/invalid '${name}'.`);
  }
  const s = v.trim();
  if (!s) throw new Error(`Missing/empty '${name}'.`);
  return s;
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
          data,
          android: {
            priority: "HIGH",
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
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405 });
    }

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return new Response(JSON.stringify({ error: "Missing secrets." }), { status: 500 });
    }
    const serviceAccount = getServiceAccountFromEnv();
    const fcmAccessToken = await getFcmAccessToken(serviceAccount);

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      global: { headers: { "Content-Type": "application/json" } },
    });

    const authHeader = getAuthHeader(req);
    const accessToken = authHeader?.replace(/^Bearer\s+/i, "") ?? "";
    if (!accessToken) {
      return new Response(JSON.stringify({ error: "Missing Authorization header." }), { status: 401 });
    }

    // Verify requester.
    const { data: authUser, error: authErr } = await supabase.auth.getUser(accessToken);
    if (authErr || !authUser?.user) {
      return new Response(JSON.stringify({ error: "Unauthorized." }), { status: 401 });
    }
    const requesterId = authUser.user.id;

    const body: Json = await req.json();
    const action = requireString(body["action"], "action").toLowerCase();

    const { data: isAdminData, error: isAdminErr } = await supabase.rpc("is_admin", { uid: requesterId });
    const isAdmin = !isAdminErr && Boolean(isAdminData);

    if (action === "user_notification") {
      if (!isAdmin) {
        return new Response(JSON.stringify({ error: "Admin only." }), { status: 403 });
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
        const { data: devices, error: devErr } = await supabase
          .from("user_devices")
          .select("user_id,fcm_token");
        if (devErr) throw devErr;

        const userTokens = new Map<string, string[]>();
        for (const d of devices ?? []) {
          const u = (d as any).user_id?.toString();
          const t = (d as any).fcm_token?.toString();
          if (!u || !t) continue;
          const prev = userTokens.get(u) ?? [];
          prev.push(t);
          userTokens.set(u, prev);
        }

        // Broadcast should still save in-app notifications for all known users,
        // even when some/all users have no registered device token.
        const { data: profiles, error: profilesErr } = await supabase
          .from("profiles")
          .select("id");
        if (profilesErr) throw profilesErr;

        const allUserIds = new Set<string>();
        for (const p of profiles ?? []) {
          const uid = (p as any).id?.toString();
          if (uid) allUserIds.add(uid);
        }
        for (const uid of userTokens.keys()) {
          allUserIds.add(uid);
        }

        const userIds = [...allUserIds];
        if (userIds.length === 0) {
          return new Response(
            JSON.stringify({
              ok: true,
              fcm: { attempted: 0, success: 0, failure: 0, failures: [] },
              note: "No users found to notify.",
            }),
          );
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

        const { data: inserted, error: insErr } = await supabase
          .from("user_notifications")
          .insert(insertRows)
          .select("id,user_id");
        if (insErr) throw insErr;

        const insertedByUser = new Map<string, string>();
        for (const r of inserted ?? []) {
          const id = (r as any).id?.toString();
          const uid = (r as any).user_id?.toString();
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
            data: {
              notification_id: notificationId,
              kind,
              redirect_type: redirectType,
              redirect_value: redirectValue || "",
            },
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

        return new Response(JSON.stringify({ ok: true, fcm: aggregate, note }));
      }

      if (!targetUserId) {
        return new Response(JSON.stringify({ error: "Missing user_id for target notification." }), { status: 400 });
      }

      const { data: tokensRows } = await supabase
        .from("user_devices")
        .select("fcm_token")
        .eq("user_id", targetUserId)
        ;

      const tokens = (tokensRows ?? [])
        .map((r: any) => r.fcm_token?.toString())
        .filter((t: string | undefined) => !!t);

      const { data: inserted, error: insErr } = await supabase
        .from("user_notifications")
        .insert({
          user_id: targetUserId,
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
      if (!notificationId) return new Response(JSON.stringify({ ok: true }));

      if (tokens.length === 0) {
        return new Response(
          JSON.stringify({
            ok: true,
            fcm: { attempted: 0, success: 0, failure: 0, failures: [] },
            note: "Target user has no registered device token; in-app notification saved.",
          }),
        );
      }

      const summary = await sendFcm({
        fcmAccessToken,
        firebaseProjectId: serviceAccount.project_id,
        registrationIds: tokens,
        title,
        message,
        data: {
          notification_id: notificationId,
          kind,
          redirect_type: redirectType,
          redirect_value: redirectValue || "",
        },
      });

      return new Response(JSON.stringify({ ok: true, fcm: summary }));
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
      if (!isAdmin && requesterId !== userId) {
        return new Response(JSON.stringify({ error: "Unauthorized for this user." }), { status: 403 });
      }

      const { data: tokensRows, error: tokErr } = await supabase
        .from("user_devices")
        .select("fcm_token")
        .eq("user_id", userId);
      if (tokErr) throw tokErr;

      const tokens = (tokensRows ?? [])
        .map((r: any) => r.fcm_token?.toString())
        .filter((t: string | undefined) => !!t);

      const data: Record<string, string> = {
        kind,
        order_id: orderId,
        redirect_type: redirectType,
        redirect_value: redirectValue,
      };
      if (notificationId) data["notification_id"] = notificationId;

      const summary = await sendFcm({
        fcmAccessToken,
        firebaseProjectId: serviceAccount.project_id,
        registrationIds: tokens,
        title,
        message,
        data,
      });

      return new Response(JSON.stringify({ ok: true, fcm: summary }));
    }

    return new Response(JSON.stringify({ error: "Unknown action." }), { status: 400 });
  } catch (e) {
    console.error(e);
    return new Response(JSON.stringify({ error: "Failed.", detail: String(e) }), { status: 500 });
  }
});

