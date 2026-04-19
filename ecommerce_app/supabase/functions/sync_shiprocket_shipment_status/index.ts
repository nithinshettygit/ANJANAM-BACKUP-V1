// @ts-nocheck
import { createClient } from "npm:@supabase/supabase-js";

const SHIPROCKET_BASE = "https://apiv2.shiprocket.in";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-supabase-api-version, prefer",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Max-Age": "86400",
};

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}

function authBearer(req: Request): string {
  const h = req.headers.get("authorization") ?? req.headers.get("Authorization") ?? "";
  return h.replace(/^Bearer\s+/i, "").trim();
}

function webhookSecret(req: Request): string {
  return (
    req.headers.get("x-webhook-secret") ??
    req.headers.get("x-hook-secret") ??
    ""
  ).trim();
}

async function shiprocketLogin(email: string, password: string): Promise<string> {
  const res = await fetch(`${SHIPROCKET_BASE}/v1/external/auth/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const msg = typeof data?.message === "string" ? data.message : "auth_failed";
    throw new Error(`shiprocket_auth_failed:${msg}`);
  }
  const token = data?.token ?? data?.data?.token;
  if (typeof token !== "string" || !token.trim()) {
    throw new Error("shiprocket_auth_failed:missing_token");
  }
  return token.trim();
}

function mapShipmentStatus(raw: string): {
  shipmentStatus: string;
  deliveryStatus: string | null;
} {
  const v = raw.trim().toLowerCase();
  if (!v) return { shipmentStatus: "in_transit", deliveryStatus: null };
  if (v.includes("delivered")) return { shipmentStatus: "delivered", deliveryStatus: "delivered" };
  if (v.includes("out for delivery")) {
    return { shipmentStatus: "out_for_delivery", deliveryStatus: "out_for_delivery" };
  }
  if (v.includes("pickup")) return { shipmentStatus: "pickup_scheduled", deliveryStatus: null };
  if (v.includes("transit") || v.includes("shipped")) {
    return { shipmentStatus: "in_transit", deliveryStatus: null };
  }
  if (v.includes("failed") || v.includes("undelivered") || v.includes("rto")) {
    return { shipmentStatus: "failed", deliveryStatus: "failed" };
  }
  return { shipmentStatus: "in_transit", deliveryStatus: null };
}

function orderStatusRank(statusRaw: string): number {
  const s = statusRaw.trim().toLowerCase();
  if (s === "processing") return 0;
  if (s === "packed") return 1;
  if (s === "shipped") return 2;
  if (s === "out_for_delivery") return 3;
  if (s === "delivered") return 4;
  return -1;
}

function pickTrackData(data: unknown): Record<string, unknown> | null {
  if (!data || typeof data !== "object") return null;
  const root = data as Record<string, unknown>;
  const td = root.tracking_data as Record<string, unknown> | undefined;
  if (td) return td;
  const d = root.data as Record<string, unknown> | undefined;
  if (d?.tracking_data && typeof d.tracking_data === "object") {
    return d.tracking_data as Record<string, unknown>;
  }
  return null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  try {
    if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
    const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const SHIPROCKET_WEBHOOK_SECRET = Deno.env.get("SHIPROCKET_WEBHOOK_SECRET") ?? "";
    const SHIPROCKET_EMAIL = Deno.env.get("SHIPROCKET_EMAIL") ?? "";
    const SHIPROCKET_PASSWORD = Deno.env.get("SHIPROCKET_PASSWORD") ?? "";
    if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
      return json(500, { error: "missing_supabase_env" });
    }
    if (!SHIPROCKET_EMAIL || !SHIPROCKET_PASSWORD) {
      return json(500, { error: "missing_shiprocket_secrets" });
    }

    const body = await req.json().catch(() => ({}));
    const incomingWebhookSecret = webhookSecret(req);
    const hasValidWebhookSecret =
      SHIPROCKET_WEBHOOK_SECRET.trim().length > 0 &&
      incomingWebhookSecret.length > 0 &&
      incomingWebhookSecret === SHIPROCKET_WEBHOOK_SECRET.trim();

    const jwt = authBearer(req);
    if (!hasValidWebhookSecret && !jwt) return json(401, { error: "missing_authorization" });

    if (!hasValidWebhookSecret) {
      const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
        global: { headers: { Authorization: `Bearer ${jwt}` } },
      });
      const { data: userData, error: userErr } = await userClient.auth.getUser(jwt);
      if (userErr || !userData?.user?.id) return json(401, { error: "invalid_token" });
      const uid = userData.user.id;

      const { data: prof } = await userClient
        .from("profiles")
        .select("role")
        .eq("id", uid)
        .maybeSingle();
      const role = (prof?.role ?? "").toString().trim().toLowerCase();
      if (role !== "admin") return json(403, { error: "not_admin" });
    }

    const orderId = typeof body?.order_id === "string" ? body.order_id.trim() : "";
    if (!orderId) return json(400, { error: "missing_order_id" });

    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const { data: order, error: orderErr } = await adminClient
      .from("orders")
      .select("id, awb_code, shipment_id, delivery_method, status")
      .eq("id", orderId)
      .single();
    if (orderErr || !order) return json(404, { error: "order_not_found" });
    if ((order.delivery_method ?? "").toString().trim().toLowerCase() !== "shiprocket_delivery") {
      return json(400, { error: "not_shiprocket_order" });
    }

    const awb = (order.awb_code ?? "").toString().trim();
    if (!awb) {
      return json(200, {
        synced: false,
        detail: "AWB not available yet. Sync after courier assignment.",
      });
    }

    const srToken = await shiprocketLogin(SHIPROCKET_EMAIL, SHIPROCKET_PASSWORD);
    const trackRes = await fetch(`${SHIPROCKET_BASE}/v1/external/courier/track/awb/${encodeURIComponent(awb)}`, {
      method: "GET",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${srToken}`,
      },
    });
    const trackJson = await trackRes.json().catch(() => ({}));
    if (!trackRes.ok) {
      const msg = typeof trackJson?.message === "string" ? trackJson.message : "track_failed";
      return json(502, { error: "shiprocket_track_failed", detail: msg });
    }

    const td = pickTrackData(trackJson);
    const shipmentTrack = Array.isArray(td?.shipment_track) ? td?.shipment_track : [];
    const latest = shipmentTrack.length > 0 && typeof shipmentTrack[0] === "object"
      ? shipmentTrack[0] as Record<string, unknown>
      : {};
    const currentStatusRaw =
      (td?.shipment_status as string | undefined) ??
      (latest.current_status as string | undefined) ??
      "";
    const etrack = (td?.track_url as string | undefined) ??
      (latest.edd as string | undefined) ??
      null;
    const courier =
      (td?.courier_name as string | undefined) ??
      (latest.courier_name as string | undefined) ??
      null;

    const mapped = mapShipmentStatus(currentStatusRaw || "");
    const patch: Record<string, unknown> = {
      shipment_status: mapped.shipmentStatus,
      tracking_url: etrack,
      courier_name: courier ?? null,
      tracking_number: awb,
    };
    if (mapped.deliveryStatus) patch.delivery_status = mapped.deliveryStatus;

    // Progress the order state so DB trigger creates in-app notifications.
    const currentOrderStatus = (order.status ?? "").toString();
    let targetOrderStatus: string | null = null;
    if (mapped.deliveryStatus === "out_for_delivery") {
      targetOrderStatus = "out_for_delivery";
    } else if (mapped.deliveryStatus === "delivered") {
      targetOrderStatus = "delivered";
    } else if (mapped.shipmentStatus === "in_transit") {
      targetOrderStatus = "shipped";
    }
    if (targetOrderStatus) {
      const curRank = orderStatusRank(currentOrderStatus);
      const nextRank = orderStatusRank(targetOrderStatus);
      if (nextRank > curRank) {
        patch.status = targetOrderStatus;
      }
    }

    const { error: upErr } = await adminClient.from("orders").update(patch).eq("id", orderId);
    if (upErr) return json(500, { error: "persist_failed" });

    return json(200, {
      synced: true,
      awb_code: awb,
      shipment_status: mapped.shipmentStatus,
      delivery_status: mapped.deliveryStatus,
      tracking_url: etrack,
      courier_name: courier,
      raw_status: currentStatusRaw,
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : "internal_error";
    if (msg.startsWith("shiprocket_auth_failed")) {
      const detail = msg.split(":").slice(1).join(":").trim();
      return json(502, { error: "shiprocket_auth_failed", detail: detail || "auth_failed" });
    }
    return json(500, { error: "internal_error" });
  }
});

