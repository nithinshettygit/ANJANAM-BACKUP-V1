// @ts-nocheck
import { createClient } from "npm:@supabase/supabase-js";
import { devLog } from "../_shared/dev_log.ts";

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

function ok(body: Record<string, unknown>) {
  return json(200, body);
}

function readShiprocketSignature(req: Request): string {
  return (
    req.headers.get("x-shiprocket-signature") ??
    req.headers.get("x-webhook-secret") ??
    req.headers.get("x-hook-secret") ??
    ""
  ).trim();
}

function str(v: unknown): string {
  return typeof v === "string" ? v.trim() : "";
}

function pickFirstString(root: Record<string, unknown>, keys: string[]): string {
  for (const k of keys) {
    const val = root[k];
    if (typeof val === "string" && val.trim()) return val.trim();
    if (typeof val === "number" && Number.isFinite(val)) return String(val);
  }
  return "";
}

function pickFromAny(obj: unknown, keys: string[]): string {
  if (!obj || typeof obj !== "object") return "";
  const rec = obj as Record<string, unknown>;
  const direct = pickFirstString(rec, keys);
  if (direct) return direct;
  for (const k of ["data", "payload", "response", "tracking_data", "order", "body", "shipment", "event"]) {
    const nested = pickFromAny(rec[k], keys);
    if (nested) return nested;
  }
  if (Array.isArray(rec.shipments)) {
    for (const it of rec.shipments) {
      const nested = pickFromAny(it, keys);
      if (nested) return nested;
    }
  }
  if (Array.isArray(rec.shipment_track)) {
    for (const it of rec.shipment_track) {
      const nested = pickFromAny(it, keys);
      if (nested) return nested;
    }
  }
  return "";
}

const WEBHOOK_STATUS_KEYS = [
  "current_status",
  "shipment_status",
  "current_status_name",
  "status",
  "new_status",
  "sr_status",
  "order_status",
  "orderStatus",
  "tracking_status",
];

function shipmentObjectFromPayload(payload: Record<string, unknown>): Record<string, unknown> | null {
  const top = payload.shipment ?? payload.Shipment;
  if (top && typeof top === "object" && !Array.isArray(top)) return top as Record<string, unknown>;
  const p = payload.payload;
  if (p && typeof p === "object" && !Array.isArray(p)) {
    const pr = p as Record<string, unknown>;
    const s = pr.shipment ?? pr.Shipment;
    if (s && typeof s === "object" && !Array.isArray(s)) return s as Record<string, unknown>;
  }
  const d = payload.data;
  if (d && typeof d === "object" && !Array.isArray(d)) {
    const dr = d as Record<string, unknown>;
    const s = dr.shipment ?? dr.Shipment;
    if (s && typeof s === "object" && !Array.isArray(s)) return s as Record<string, unknown>;
  }
  return null;
}

/** Prefer nested `shipment` so a generic root `status` does not mask shipment cancel. */
function resolveWebhookStatusRaw(payload: Record<string, unknown>): string {
  const sh = shipmentObjectFromPayload(payload);
  if (sh) {
    const st = pickFirstString(sh, WEBHOOK_STATUS_KEYS);
    if (st) return st;
  }
  const fromAny = pickFromAny(payload, WEBHOOK_STATUS_KEYS);
  if (fromAny) return fromAny;
  const eventish = pickFromAny(payload, ["event", "event_name", "event_type", "type", "topic", "action"]);
  if (eventish && eventish.toUpperCase().includes("CANCEL")) return "CANCELLED";
  return "";
}

function extractWebhookShipmentId(payload: Record<string, unknown>): string {
  const keys = ["shipment_id", "shipmentId", "sr_shipment_id", "shiprocket_shipment_id"];
  const fromRoot = pickFromAny(payload, keys);
  if (fromRoot) return fromRoot;
  const sh = shipmentObjectFromPayload(payload);
  if (sh) {
    const sid = pickFirstString(sh, [...keys, "id"]);
    if (sid) return sid;
  }
  return "";
}

function extractWebhookAwb(payload: Record<string, unknown>): string {
  const keys = ["awb_code", "awb", "awbCode", "airway_bill_number", "airwaybill_number", "AWB"];
  const fromRoot = pickFromAny(payload, keys);
  if (fromRoot) return fromRoot;
  const sh = shipmentObjectFromPayload(payload);
  if (sh) {
    const a = pickFirstString(sh, keys);
    if (a) return a;
  }
  return "";
}

function mapShiprocketStatus(statusRaw: string): {
  shipmentStatus: string;
  deliveryStatus: string;
  orderStatus: string | null;
} {
  const s = statusRaw.trim().toUpperCase();
  if (!s) return { shipmentStatus: "created", deliveryStatus: "created", orderStatus: null };
  if (s.includes("DELIVERED")) {
    return { shipmentStatus: "delivered", deliveryStatus: "delivered", orderStatus: "delivered" };
  }
  if (s.includes("OUT_FOR_DELIVERY")) {
    return {
      shipmentStatus: "out_for_delivery",
      deliveryStatus: "out_for_delivery",
      orderStatus: "out_for_delivery",
    };
  }
  if (s.includes("IN_TRANSIT") || s.includes("SHIPPED")) {
    return { shipmentStatus: "in_transit", deliveryStatus: "in_transit", orderStatus: "shipped" };
  }
  if (s.includes("AWB")) return { shipmentStatus: "shipped", deliveryStatus: "shipped", orderStatus: "shipped" };
  if (s.includes("RTO_INITIATED")) {
    return { shipmentStatus: "rto_initiated", deliveryStatus: "rto_initiated", orderStatus: null };
  }
  if (s.includes("RTO_DELIVERED")) {
    return { shipmentStatus: "rto_completed", deliveryStatus: "rto_completed", orderStatus: null };
  }
  if (s.includes("CANCEL") || s.includes("VOIDED") || /\bVOID\b/.test(s)) {
    return { shipmentStatus: "cancelled", deliveryStatus: "cancelled", orderStatus: "cancelled" };
  }
  if (s.includes("NEW") || s.includes("CREATED")) {
    return { shipmentStatus: "created", deliveryStatus: "created", orderStatus: null };
  }
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
  if (s === "pending_payment") return -1;
  if (s === "payment_failed") return -1;
  if (s === "processing") return 0;
  if (s === "packed") return 1;
  if (s === "shipped") return 2;
  if (s === "out_for_delivery") return 3;
  if (s === "delivered") return 4;
  if (s === "cancel_requested") return 99;
  if (s === "cancelled") return 100;
  return -1;
}

/** Shiprocket adhoc uses UUID without dashes as `order_id` / channel_order_id (see create_shiprocket_shipment). */
function normalizeChannelOrderRefToUuid(raw: string): string | null {
  const t = raw.trim().toLowerCase().replace(/-/g, "");
  if (!/^[0-9a-f]{32}$/.test(t)) return null;
  return `${t.slice(0, 8)}-${t.slice(8, 12)}-${t.slice(12, 16)}-${t.slice(16, 20)}-${t.slice(20, 32)}`;
}

function parseIncomingEventAt(payload: Record<string, unknown>): Date | null {
  const candidates = [
    payload.event_time,
    payload.event_at,
    payload.event_timestamp,
    payload.timestamp,
    payload.updated_at,
    payload.created_at,
    (payload.data as Record<string, unknown> | undefined)?.event_time,
    (payload.data as Record<string, unknown> | undefined)?.updated_at,
    (payload.payload as Record<string, unknown> | undefined)?.event_time,
    (payload.payload as Record<string, unknown> | undefined)?.updated_at,
  ];
  for (const c of candidates) {
    if (typeof c === "string" && c.trim()) {
      const d = new Date(c.trim());
      if (!Number.isNaN(d.getTime())) return d;
    }
    if (typeof c === "number" && Number.isFinite(c)) {
      const ms = c > 1e12 ? c : c * 1000;
      const d = new Date(ms);
      if (!Number.isNaN(d.getTime())) return d;
    }
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
  devLog("shiprocket_webhook_hit", { method: req.method });
  if (req.method === "OPTIONS") {
    return ok({ ok: true, received: true, method: "OPTIONS" });
  }
  if (req.method !== "POST") {
    return ok({ ok: true, received: true, method: req.method });
  }

  try {
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const SHIPROCKET_WEBHOOK_SECRET = Deno.env.get("SHIPROCKET_WEBHOOK_SECRET") ?? "";
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      console.error("shiprocket_webhook_missing_supabase_env");
      return ok({ ok: false, received: true, ignored: "missing_supabase_env" });
    }
    const incoming = readShiprocketSignature(req);
    if (!SHIPROCKET_WEBHOOK_SECRET.trim().length || !incoming || incoming !== SHIPROCKET_WEBHOOK_SECRET.trim()) {
      return json(401, { error: "unauthorized" });
    }

    let payload: Record<string, unknown> = {};
    try {
      const raw = await req.json();
      if (Array.isArray(raw) && raw.length > 0 && raw[0] && typeof raw[0] === "object") {
        payload = raw[0] as Record<string, unknown>;
      } else if (raw && typeof raw === "object" && !Array.isArray(raw)) {
        payload = raw as Record<string, unknown>;
      } else {
        payload = {};
      }
      devLog("shiprocket_webhook_payload_parsed");
    } catch (_) {
      devLog("shiprocket_webhook_invalid_or_empty_json");
      payload = {};
    }
    const statusRaw = resolveWebhookStatusRaw(payload);
    if (!statusRaw) {
      return ok({
        ok: true,
        received: true,
        ignored: "invalid_webhook_payload",
      });
    }

    const mappedPreview = mapShiprocketStatus(statusRaw);
    const isCancelPreview = mappedPreview.shipmentStatus === "cancelled";

    const shipmentId = extractWebhookShipmentId(payload);
    const awbCode = extractWebhookAwb(payload);
    const channelRefRaw = pickFromAny(payload, [
      "channel_order_id",
      "channelOrderId",
      "channel_order",
      "channelOrder",
      "customer_order_id",
    ]);
    const adhocOrderRefRaw = pickFromAny(payload, [
      "order_id",
      "orderId",
      "client_order_id",
      "clientOrderId",
    ]);
    const channelOrderUuid =
      normalizeChannelOrderRefToUuid(channelRefRaw) ?? normalizeChannelOrderRefToUuid(adhocOrderRefRaw);

    const courierName = pickFromAny(payload, ["courier_name", "courier"]);
    const trackingUrl = pickFromAny(payload, ["tracking_url", "track_url", "etrack_url"]);

    if (!shipmentId && !awbCode && !(isCancelPreview && channelOrderUuid)) {
      return ok({
        ok: true,
        received: true,
        ignored: "invalid_webhook_payload",
      });
    }

    const mapped = mappedPreview;
    const isShipmentCancelled = isCancelPreview;
    const nowIso = new Date().toISOString();

    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    type MatchRow = {
      id: string;
      user_id: string | null;
      status: string;
      delivery_method: string | null;
      delivery_status: string | null;
      last_tracking_update: string | null;
      shipment_id?: string | null;
      awb_code?: string | null;
    };

    let matchOrder: MatchRow | null = null;
    if (shipmentId) {
      const byShipment = await admin
        .from("orders")
        .select("id, user_id, status, delivery_method, delivery_status, last_tracking_update")
        .eq("shipment_id", shipmentId)
        .limit(1)
        .maybeSingle();
      if (!byShipment.error && byShipment.data?.id) {
        matchOrder = byShipment.data as MatchRow;
      }
    }
    if (!matchOrder && awbCode) {
      const byAwb = await admin
        .from("orders")
        .select("id, user_id, status, delivery_method, delivery_status, last_tracking_update")
        .eq("awb_code", awbCode)
        .limit(1)
        .maybeSingle();
      if (!byAwb.error && byAwb.data?.id) {
        matchOrder = byAwb.data as MatchRow;
      }
    }
    if (!matchOrder && isShipmentCancelled && channelOrderUuid) {
      const byChannel = await admin
        .from("orders")
        .select("id, user_id, status, delivery_method, delivery_status, last_tracking_update, shipment_id, awb_code")
        .eq("id", channelOrderUuid)
        .limit(1)
        .maybeSingle();
      if (!byChannel.error && byChannel.data?.id) {
        const row = byChannel.data as MatchRow;
        const dm = (row.delivery_method ?? "").toString().trim().toLowerCase();
        const sid = (row.shipment_id ?? "").toString().trim();
        const awbRow = (row.awb_code ?? "").toString().trim();
        if (dm === "shiprocket_delivery" || sid.length > 0 || awbRow.length > 0) {
          matchOrder = row;
        }
      }
    }
    if (!matchOrder) {
      return ok({
        ok: true,
        received: true,
        ignored: "order_not_found_for_shipment",
      });
    }

    const existingDelivery = (matchOrder.delivery_status ?? "").toString().trim().toLowerCase();
    if (isShipmentCancelled && existingDelivery === "delivered") {
      return ok({
        ok: true,
        received: true,
        ignored: "delivered_order_ignore_shipment_cancel",
      });
    }

    const resumeAfterCancelled =
      existingDelivery === "cancelled" && mapped.shipmentStatus !== "cancelled";

    const incomingAt = parseIncomingEventAt(payload) ?? new Date();
    const existingTrackAt = matchOrder.last_tracking_update
      ? new Date(matchOrder.last_tracking_update)
      : null;
    const bypassStale = isShipmentCancelled || resumeAfterCancelled;
    if (
      !bypassStale &&
      existingTrackAt &&
      !Number.isNaN(existingTrackAt.getTime()) &&
      incomingAt.getTime() <= existingTrackAt.getTime()
    ) {
      await writeWebhookLog(admin, {
        shipmentId: shipmentId || null,
        status: mapped.shipmentStatus,
        happenedAt: incomingAt.toISOString(),
        source: "webhook",
        action: "ignored_stale_or_duplicate",
      });
      devLog("shiprocket_webhook_ignored_stale", {
        shipment_id: shipmentId || null,
        status: mapped.shipmentStatus,
        at: incomingAt.toISOString(),
      });
      return ok({ ok: true, received: true, ignored: "stale_or_duplicate_event" });
    }

    const existingPriority = deliveryStatusPriority[existingDelivery] ?? 0;
    const incomingPriority = deliveryStatusPriority[mapped.deliveryStatus] ?? 0;
    if (!resumeAfterCancelled && incomingPriority < existingPriority) {
      await writeWebhookLog(admin, {
        shipmentId: shipmentId || null,
        status: mapped.shipmentStatus,
        happenedAt: incomingAt.toISOString(),
        source: "webhook",
        action: "ignored_downgrade",
      });
      devLog("shiprocket_webhook_ignored_priority", {
        shipment_id: shipmentId || null,
        status: mapped.shipmentStatus,
        at: incomingAt.toISOString(),
      });
      return ok({ ok: true, received: true, ignored: "status_downgrade_blocked" });
    }

    let updateRow: Record<string, unknown>;
    if (isShipmentCancelled) {
      updateRow = {
        shipment_status: "cancelled",
        delivery_status: "cancelled",
        shipment_id: null,
        awb_code: null,
        tracking_number: null,
        tracking_url: null,
        delivery_method: null,
        shipping_provider: null,
        courier_name: null,
        shipped_at: null,
        last_tracking_update: nowIso,
      };
      const ord = (matchOrder.status ?? "").toString().trim().toLowerCase();
      const dm = (matchOrder.delivery_method ?? "").toString().trim().toLowerCase();
      if (ord === "cancelled" && dm === "shiprocket_delivery") {
        updateRow.status = "processing";
      } else if (ord === "shipped" || ord === "out_for_delivery") {
        updateRow.status = "packed";
      }
    } else {
      updateRow = {
        shipment_status: mapped.shipmentStatus,
        ...(awbCode ? { awb_code: awbCode, tracking_number: awbCode } : {}),
        ...(courierName ? { courier_name: courierName } : {}),
        ...(trackingUrl ? { tracking_url: trackingUrl } : {}),
        delivery_status: mapped.deliveryStatus,
        last_tracking_update: nowIso,
      };
      if (mapped.shipmentStatus === "delivered") updateRow.delivered_at = nowIso;
    }

    if (!isShipmentCancelled && mapped.orderStatus) {
      const currentRank = orderStatusRank(matchOrder.status ?? "");
      const nextRank = orderStatusRank(mapped.orderStatus);
      const currentStatus = (matchOrder.status ?? "").toString().trim().toLowerCase();
      const isTerminal = currentStatus === "delivered" || currentStatus === "cancelled";
      if (!isTerminal && nextRank > currentRank && currentRank >= 0 && currentRank < 99) {
        updateRow.status = mapped.orderStatus;
        const nextSt = (mapped.orderStatus ?? "").toString().trim().toLowerCase();
        if (nextSt === "shipped") {
          updateRow.shipped_at = nowIso;
        }
      }
    }

    const { error } = await admin.from("orders").update(updateRow).eq("id", matchOrder.id);
    if (error) {
      console.error("shiprocket_webhook_update_failed", error.message);
      return ok({ ok: false, received: true, ignored: "db_update_failed" });
    }
    devLog("shiprocket_webhook_db_update_executed", { order_id: matchOrder.id });

    await insertStatusNotificationIfNeeded(admin, matchOrder, mapped.deliveryStatus);
    await writeWebhookLog(admin, {
      shipmentId: shipmentId || null,
      status: mapped.shipmentStatus,
      happenedAt: nowIso,
      source: "webhook",
      action: "applied",
    });

    devLog("shiprocket_webhook_processed", {
      shipment_id: shipmentId || null,
      status: mapped.shipmentStatus,
      at: nowIso,
    });

    return ok({
      ok: true,
      received: true,
      order_id: matchOrder.id,
      shipment_id: shipmentId || null,
      awb_code: awbCode || null,
      shipment_status: mapped.shipmentStatus,
    });
  } catch (e) {
    console.error("shiprocket_webhook_error", String(e));
    return ok({ ok: false, received: true, ignored: "internal_error" });
  }
});

