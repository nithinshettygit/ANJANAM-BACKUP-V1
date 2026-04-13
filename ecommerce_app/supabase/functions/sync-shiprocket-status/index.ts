// @ts-nocheck
import { createClient } from "npm:@supabase/supabase-js";

const SHIPROCKET_BASE = "https://apiv2.shiprocket.in";

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

function authBearer(req: Request): string {
  const h = req.headers.get("authorization") ?? req.headers.get("Authorization") ?? "";
  return h.replace(/^Bearer\s+/i, "").trim();
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

function mapShiprocketStatus(statusRaw: string): {
  shipmentStatus: string;
  deliveryStatus: string;
  orderStatus: string | null;
} {
  const s = statusRaw.trim().toUpperCase();
  if (!s) return { shipmentStatus: "created", deliveryStatus: "created", orderStatus: null };
  if (s.includes("DELIVERED")) return { shipmentStatus: "delivered", deliveryStatus: "delivered", orderStatus: "delivered" };
  if (s.includes("OUT_FOR_DELIVERY")) {
    return { shipmentStatus: "out_for_delivery", deliveryStatus: "out_for_delivery", orderStatus: "out_for_delivery" };
  }
  if (s.includes("IN_TRANSIT") || s.includes("SHIPPED")) {
    return { shipmentStatus: "in_transit", deliveryStatus: "in_transit", orderStatus: "shipped" };
  }
  if (s.includes("AWB")) return { shipmentStatus: "shipped", deliveryStatus: "shipped", orderStatus: "shipped" };
  if (s.includes("RTO_INITIATED")) return { shipmentStatus: "rto_initiated", deliveryStatus: "rto_initiated", orderStatus: null };
  if (s.includes("RTO_DELIVERED")) return { shipmentStatus: "rto_completed", deliveryStatus: "rto_completed", orderStatus: null };
  if (s.includes("CANCEL")) return { shipmentStatus: "cancelled", deliveryStatus: "cancelled", orderStatus: "cancelled" };
  if (s.includes("NEW") || s.includes("CREATED")) return { shipmentStatus: "created", deliveryStatus: "created", orderStatus: null };
  return { shipmentStatus: "in_transit", deliveryStatus: "in_transit", orderStatus: null };
}

const deliveryStatusPriority: Record<string, number> = {
  created: 1,
  shipped: 2,
  in_transit: 3,
  out_for_delivery: 4,
  delivered: 5,
  cancelled: 6,
  rto_initiated: 7,
  rto_completed: 8,
};

function orderStatusRank(statusRaw: string): number {
  const s = statusRaw.trim().toLowerCase();
  if (s === "processing") return 0;
  if (s === "packed") return 1;
  if (s === "shipped") return 2;
  if (s === "out_for_delivery") return 3;
  if (s === "delivered") return 4;
  if (s === "cancel_requested") return 99;
  if (s === "cancelled") return 100;
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

async function insertStatusNotificationIfNeeded(
  admin: ReturnType<typeof createClient>,
  row: { id: string; user_id: string | null; delivery_status: string | null },
  newDeliveryStatus: string,
) {
  const userId = (row.user_id ?? "").toString().trim();
  if (!userId) return;
  const prev = (row.delivery_status ?? "").toString().trim().toLowerCase();
  const next = newDeliveryStatus.trim().toLowerCase();
  if (!next || prev === next) return;

  const kind = `delivery_status_${next}`;
  const messageByStatus: Record<string, { title: string; body: string }> = {
    in_transit: { title: "Shipment Update", body: "Your order is on the way." },
    out_for_delivery: { title: "Shipment Update", body: "Out for delivery today." },
    delivered: { title: "Shipment Update", body: "Order delivered successfully." },
    cancelled: { title: "Shipment Update", body: "Shipment cancelled." },
  };
  const msg = messageByStatus[next];
  if (!msg) return;

  const existing = await admin
    .from("user_notifications")
    .select("id")
    .eq("user_id", userId)
    .eq("order_id", row.id)
    .eq("kind", kind)
    .limit(1);
  if (!existing.error && Array.isArray(existing.data) && existing.data.length > 0) return;

  await admin.from("user_notifications").insert({
    user_id: userId,
    kind,
    title: msg.title,
    body: msg.body,
    order_id: row.id,
  });
}

async function writeWebhookLog(
  admin: ReturnType<typeof createClient>,
  row: { shipmentId: string | null; status: string; happenedAt: string; source: string; action: string },
) {
  await admin.from("shiprocket_webhook_logs").insert({
    shipment_id: row.shipmentId,
    status: row.status,
    occurred_at: row.happenedAt,
    source: row.source,
    action: row.action,
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { status: 204, headers: corsHeaders });
  try {
    if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
    const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const SHIPROCKET_EMAIL = Deno.env.get("SHIPROCKET_EMAIL") ?? "";
    const SHIPROCKET_PASSWORD = Deno.env.get("SHIPROCKET_PASSWORD") ?? "";
    if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) return json(500, { error: "missing_supabase_env" });
    if (!SHIPROCKET_EMAIL || !SHIPROCKET_PASSWORD) return json(500, { error: "missing_shiprocket_secrets" });

    const body = await req.json().catch(() => ({}));
    const jwtFromBody = typeof body?.access_token === "string" ? body.access_token.trim() : "";
    const jwt = authBearer(req) || jwtFromBody;
    if (!jwt) return json(401, { error: "missing_authorization" });

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
    });
    const { data: userData, error: userErr } = await userClient.auth.getUser(jwt);
    if (userErr || !userData?.user?.id) return json(401, { error: "invalid_token" });
    const { data: prof } = await userClient.from("profiles").select("role").eq("id", userData.user.id).maybeSingle();
    if ((prof?.role ?? "").toString().trim().toLowerCase() !== "admin") return json(403, { error: "not_admin" });

    const orderId = typeof body?.order_id === "string" ? body.order_id.trim() : "";
    if (!orderId) return json(400, { error: "missing_order_id" });

    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const { data: order, error: orderErr } = await adminClient
      .from("orders")
      .select("id, user_id, awb_code, shipment_id, delivery_method, status, delivery_status, last_tracking_update")
      .eq("id", orderId)
      .single();
    if (orderErr || !order) return json(404, { error: "order_not_found" });
    if ((order.delivery_method ?? "").toString().trim().toLowerCase() !== "shiprocket_delivery") {
      return json(400, { error: "not_shiprocket_order" });
    }

    const awb = (order.awb_code ?? "").toString().trim();
    if (!awb) return json(200, { synced: false, detail: "AWB not available yet. Sync after courier assignment." });

    const srToken = await shiprocketLogin(SHIPROCKET_EMAIL, SHIPROCKET_PASSWORD);
    const trackRes = await fetch(`${SHIPROCKET_BASE}/v1/external/courier/track/awb/${encodeURIComponent(awb)}`, {
      method: "GET",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${srToken}` },
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
    const trackUrl = (td?.track_url as string | undefined) ?? null;
    const courier = (td?.courier_name as string | undefined) ?? (latest.courier_name as string | undefined) ?? null;

    const mapped = mapShiprocketStatus(currentStatusRaw || "");

    const incomingAt = new Date();
    const existingTrackAt = order.last_tracking_update ? new Date(order.last_tracking_update) : null;
    if (
      existingTrackAt &&
      !Number.isNaN(existingTrackAt.getTime()) &&
      incomingAt.getTime() <= existingTrackAt.getTime()
    ) {
      await writeWebhookLog(adminClient, {
        shipmentId: (order.shipment_id ?? null) as string | null,
        status: mapped.shipmentStatus,
        happenedAt: incomingAt.toISOString(),
        source: "fallback_sync",
        action: "ignored_stale_or_duplicate",
      });
      return json(200, { synced: false, ignored: "stale_or_duplicate_event" });
    }

    const existingDelivery = (order.delivery_status ?? "").toString().trim().toLowerCase();
    const existingPriority = deliveryStatusPriority[existingDelivery] ?? 0;
    const incomingPriority = deliveryStatusPriority[mapped.deliveryStatus] ?? 0;
    if (incomingPriority < existingPriority) {
      await writeWebhookLog(adminClient, {
        shipmentId: (order.shipment_id ?? null) as string | null,
        status: mapped.shipmentStatus,
        happenedAt: incomingAt.toISOString(),
        source: "fallback_sync",
        action: "ignored_downgrade",
      });
      return json(200, { synced: false, ignored: "status_downgrade_blocked" });
    }

    const nowIso = new Date().toISOString();
    const patch: Record<string, unknown> = {
      shipment_status: mapped.shipmentStatus,
      delivery_status: mapped.deliveryStatus,
      tracking_url: trackUrl,
      courier_name: courier ?? null,
      tracking_number: awb,
      last_tracking_update: nowIso,
    };
    if (mapped.shipmentStatus === "delivered") patch.delivered_at = nowIso;
    if (mapped.shipmentStatus === "cancelled") patch.cancelled_at = nowIso;

    if (mapped.orderStatus) {
      const currentRank = orderStatusRank((order.status ?? "").toString());
      const nextRank = orderStatusRank(mapped.orderStatus);
      const currentStatus = (order.status ?? "").toString().trim().toLowerCase();
      const isTerminal = currentStatus === "delivered" || currentStatus === "cancelled";
      if (!isTerminal && mapped.orderStatus === "cancelled") {
        patch.status = "cancelled";
      } else if (!isTerminal && nextRank > currentRank && currentRank >= 0 && currentRank < 99) {
        patch.status = mapped.orderStatus;
      }
    }

    const { error: upErr } = await adminClient.from("orders").update(patch).eq("id", orderId);
    if (upErr) return json(500, { error: "persist_failed", detail: upErr.message });

    await insertStatusNotificationIfNeeded(
      adminClient,
      {
        id: order.id,
        user_id: (order.user_id ?? null) as string | null,
        delivery_status: (order.delivery_status ?? null) as string | null,
      },
      mapped.deliveryStatus,
    );
    await writeWebhookLog(adminClient, {
      shipmentId: (order.shipment_id ?? null) as string | null,
      status: mapped.shipmentStatus,
      happenedAt: nowIso,
      source: "fallback_sync",
      action: "applied",
    });

    console.log("shiprocket_fallback_sync_processed", {
      shipment_id: (order.shipment_id ?? null) as string | null,
      status: mapped.shipmentStatus,
      at: nowIso,
    });

    return json(200, {
      synced: true,
      awb_code: awb,
      shipment_status: mapped.shipmentStatus,
      delivery_status: mapped.deliveryStatus,
      tracking_url: trackUrl,
      courier_name: courier,
      raw_status: currentStatusRaw,
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : "internal_error";
    if (msg.startsWith("shiprocket_auth_failed")) {
      return json(502, { error: "shiprocket_auth_failed", detail: msg.split(":").slice(1).join(":").trim() || "auth_failed" });
    }
    return json(500, { error: "internal_error", detail: String(e) });
  }
});
