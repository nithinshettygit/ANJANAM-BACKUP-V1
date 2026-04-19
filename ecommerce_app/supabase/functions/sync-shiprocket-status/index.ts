// @ts-nocheck
import { createClient } from "npm:@supabase/supabase-js";
import { resolveRequesterIdentity } from "../_shared/auth.ts";
import { devLog } from "../_shared/dev_log.ts";

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
  if (s.includes("CANCEL") || s.includes("VOIDED") || /\bVOID\b/.test(s)) {
    return { shipmentStatus: "cancelled", deliveryStatus: "cancelled", orderStatus: "cancelled" };
  }
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

function compactOrderId(uuid: string): string {
  return uuid.replace(/-/g, "").toLowerCase();
}

/** Adhoc Shiprocket `order_id` is often stored as `order_id` on list rows, not only `channel_order_id`. */
function rowMatchesOurOrderRef(r: Record<string, unknown>, want: string): boolean {
  const ch = (r.channel_order_id ?? r.channel_order ?? "").toString().trim().replace(/-/g, "").toLowerCase();
  const ordRef = (r.order_id ?? "").toString().trim().replace(/-/g, "").toLowerCase();
  return (ch.length > 0 && ch === want) || (ordRef.length > 0 && ordRef === want);
}

/** Shiprocket GET /orders list: find row matching our channel_order_id (compact UUID). */
function pickStatusFromOrdersListResponse(json: unknown, channelCompact: string): string {
  const want = channelCompact.toLowerCase();
  const root = json as Record<string, unknown>;
  const candidates: unknown[] = [];
  if (Array.isArray(root.data)) candidates.push(...root.data);
  else if (root.data && typeof root.data === "object") {
    const d = root.data as Record<string, unknown>;
    if (Array.isArray(d.data)) candidates.push(...d.data);
  }
  if (Array.isArray(root.orders)) candidates.push(...root.orders);
  for (const row of candidates) {
    if (!row || typeof row !== "object") continue;
    const r = row as Record<string, unknown>;
    if (!rowMatchesOurOrderRef(r, want)) continue;
    const st = (r.status ?? r.order_status ?? r.shipment_status ?? "").toString().trim();
    if (st) return st;
    const shipments = r.shipments;
    if (Array.isArray(shipments)) {
      for (const sh of shipments) {
        if (!sh || typeof sh !== "object") continue;
        const sr = sh as Record<string, unknown>;
        const sub = (sr.status ?? sr.shipment_status ?? sr.current_status ?? "").toString().trim();
        if (sub) return sub;
      }
    }
  }
  return "";
}

function orderListDateRange(createdAtIso: string | null | undefined): { fromStr: string; toStr: string } {
  const now = new Date();
  const to = new Date(now);
  to.setDate(to.getDate() + 1);
  const toStr = to.toISOString().slice(0, 10);
  let from = new Date(now);
  from.setDate(from.getDate() - 180);
  if (createdAtIso) {
    const c = new Date(createdAtIso);
    if (!Number.isNaN(c.getTime())) {
      const c2 = new Date(c);
      c2.setDate(c2.getDate() - 2);
      if (c2 < from) from = c2;
    }
  }
  const fromStr = from.toISOString().slice(0, 10);
  return { fromStr, toStr };
}

async function fetchShiprocketOrdersListStatus(
  srToken: string,
  orderId: string,
  createdAtIso: string | null | undefined,
): Promise<{ ok: boolean; listJson: Record<string, unknown>; statusLine: string }> {
  const search = compactOrderId(orderId);
  const { fromStr, toStr } = orderListDateRange(createdAtIso);
  const listUrl =
    `${SHIPROCKET_BASE}/v1/external/orders?from=${encodeURIComponent(fromStr)}` +
    `&to=${encodeURIComponent(toStr)}&search=${encodeURIComponent(search)}&per_page=50`;
  const listRes = await fetch(listUrl, {
    method: "GET",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${srToken}` },
  });
  const listJson = (await listRes.json().catch(() => ({}))) as Record<string, unknown>;
  const statusLine = listRes.ok ? pickStatusFromOrdersListResponse(listJson, search) : "";
  return { ok: listRes.ok, listJson, statusLine };
}

function trackFailureLooksLikeMissingShipment(httpStatus: number, body: Record<string, unknown>): boolean {
  if (httpStatus === 404) return true;
  const msg = (body?.message ?? body?.Message ?? "").toString().toUpperCase();
  if (msg.includes("NOT FOUND")) return true;
  if (msg.includes("INVALID SHIPMENT")) return true;
  if (msg.includes("DOES NOT EXIST")) return true;
  if (msg.includes("NO DATA FOUND")) return true;
  return false;
}

function listJsonMessage(j: Record<string, unknown>): string {
  return typeof j?.message === "string" ? j.message : "";
}

function buildShiprocketCancelledPatch(order: {
  status?: string;
  delivery_method?: string | null;
}): Record<string, unknown> {
  const nowIso = new Date().toISOString();
  const patch: Record<string, unknown> = {
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
  const ord = (order.status ?? "").toString().trim().toLowerCase();
  const dm = (order.delivery_method ?? "").toString().trim().toLowerCase();
  if (ord === "cancelled" && dm === "shiprocket_delivery") {
    patch.status = "processing";
  } else if (ord === "shipped" || ord === "out_for_delivery") {
    patch.status = "packed";
  }
  return patch;
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
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders });
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
    const auth = await resolveRequesterIdentity(req, {
      supabaseUrl: SUPABASE_URL,
      supabaseAnonKey: SUPABASE_ANON_KEY,
    });
    if (!auth.ok) return json(auth.code, { error: auth.error });
    const requesterId = auth.userId;
    devLog(`auth_ok user_id=${requesterId}`);

    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const { data: prof } = await adminClient.from("profiles").select("role").eq("id", requesterId).maybeSingle();
    if ((prof?.role ?? "").toString().trim().toLowerCase() !== "admin") return json(403, { error: "not_admin" });

    const orderId = typeof body?.order_id === "string" ? body.order_id.trim() : "";
    if (!orderId) return json(400, { error: "missing_order_id" });

    const forceClear =
      body?.force_clear_shiprocket_booking === true || body?.force_clear_shiprocket_booking === "true";

    const { data: order, error: orderErr } = await adminClient
      .from("orders")
      .select("id, user_id, awb_code, shipment_id, delivery_method, status, delivery_status, last_tracking_update, created_at")
      .eq("id", orderId)
      .single();
    if (orderErr || !order) return json(404, { error: "order_not_found" });
    if ((order.delivery_method ?? "").toString().trim().toLowerCase() !== "shiprocket_delivery") {
      return json(400, { error: "not_shiprocket_order" });
    }

    if (forceClear) {
      const patch = buildShiprocketCancelledPatch(order);
      const { error: upErr } = await adminClient.from("orders").update(patch).eq("id", orderId);
      if (upErr) return json(500, { error: "persist_failed", detail: upErr.message });
      await insertStatusNotificationIfNeeded(
        adminClient,
        {
          id: order.id,
          user_id: (order.user_id ?? null) as string | null,
          delivery_status: (order.delivery_status ?? null) as string | null,
        },
        "cancelled",
      );
      await writeWebhookLog(adminClient, {
        shipmentId: (order.shipment_id ?? null) as string | null,
        status: "cancelled",
        happenedAt: new Date().toISOString(),
        source: "fallback_sync",
        action: "admin_force_clear",
      });
      return json(200, {
        synced: true,
        force_cleared: true,
        track_source: "admin_force_clear",
        shipment_status: "cancelled",
        delivery_status: "cancelled",
      });
    }

    const awb = (order.awb_code ?? "").toString().trim();
    const shipmentId = (order.shipment_id ?? "").toString().trim();
    const createdAtIso = (order.created_at ?? null) as string | null | undefined;

    const srToken = await shiprocketLogin(SHIPROCKET_EMAIL, SHIPROCKET_PASSWORD);

    let trackJson: Record<string, unknown> = {};
    let trackSource:
      | "awb"
      | "shipment"
      | "orders_search"
      | "orders_search_after_track_fail"
      | "missing_shipment_assumed_cancelled" = "orders_search";

    if (awb) {
      const trackRes = await fetch(`${SHIPROCKET_BASE}/v1/external/courier/track/awb/${encodeURIComponent(awb)}`, {
        method: "GET",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${srToken}` },
      });
      trackJson = (await trackRes.json().catch(() => ({}))) as Record<string, unknown>;
      if (trackRes.ok) {
        trackSource = "awb";
      } else {
        devLog("shiprocket_track_awb_failed", { status: trackRes.status });
        const list = await fetchShiprocketOrdersListStatus(srToken, orderId, createdAtIso);
        if (list.ok && list.statusLine) {
          trackJson = { data: { shipment_status: list.statusLine } };
          trackSource = "orders_search_after_track_fail";
        } else if (trackFailureLooksLikeMissingShipment(trackRes.status, trackJson)) {
          trackJson = { data: { shipment_status: "CANCELLED" } };
          trackSource = "missing_shipment_assumed_cancelled";
        } else if (!list.ok) {
          const msg = listJsonMessage(list.listJson) || "orders_list_failed";
          return json(502, { error: "shiprocket_orders_search_failed", detail: msg });
        } else {
          const msg = typeof trackJson?.message === "string" ? trackJson.message : "track_failed";
          return json(502, { error: "shiprocket_track_failed", detail: msg });
        }
      }
    } else if (shipmentId) {
      const trackRes = await fetch(
        `${SHIPROCKET_BASE}/v1/external/courier/track/shipment/${encodeURIComponent(shipmentId)}`,
        {
          method: "GET",
          headers: { "Content-Type": "application/json", Authorization: `Bearer ${srToken}` },
        },
      );
      trackJson = (await trackRes.json().catch(() => ({}))) as Record<string, unknown>;
      if (trackRes.ok) {
        trackSource = "shipment";
      } else {
        devLog("shiprocket_track_shipment_failed", { status: trackRes.status });
        const list = await fetchShiprocketOrdersListStatus(srToken, orderId, createdAtIso);
        if (list.ok && list.statusLine) {
          trackJson = { data: { shipment_status: list.statusLine } };
          trackSource = "orders_search_after_track_fail";
        } else if (trackFailureLooksLikeMissingShipment(trackRes.status, trackJson)) {
          trackJson = { data: { shipment_status: "CANCELLED" } };
          trackSource = "missing_shipment_assumed_cancelled";
        } else if (!list.ok) {
          const msg = listJsonMessage(list.listJson) || "orders_list_failed";
          return json(502, { error: "shiprocket_orders_search_failed", detail: msg });
        } else {
          const msg = typeof trackJson?.message === "string" ? trackJson.message : "track_shipment_failed";
          return json(502, { error: "shiprocket_track_failed", detail: msg });
        }
      }
    } else {
      const list = await fetchShiprocketOrdersListStatus(srToken, orderId, createdAtIso);
      if (!list.ok) {
        const msg = listJsonMessage(list.listJson) || "orders_list_failed";
        return json(502, { error: "shiprocket_orders_search_failed", detail: msg });
      }
      if (!list.statusLine) {
        return json(200, {
          synced: false,
          detail: "No AWB yet. Create or link a Shiprocket shipment, or wait for assignment.",
        });
      }
      trackJson = { data: { shipment_status: list.statusLine } };
      trackSource = "orders_search";
    }

    const td = pickTrackData(trackJson);
    const shipmentTrack = Array.isArray(td?.shipment_track) ? td?.shipment_track : [];
    const latest = shipmentTrack.length > 0 && typeof shipmentTrack[0] === "object"
      ? shipmentTrack[0] as Record<string, unknown>
      : {};
    let currentStatusRaw =
      (td?.shipment_status as string | undefined) ??
      (latest.current_status as string | undefined) ??
      "";
    if (!currentStatusRaw && trackJson.data && typeof trackJson.data === "object") {
      const d = trackJson.data as Record<string, unknown>;
      currentStatusRaw =
        (d.shipment_status ?? d.status ?? d.current_status ?? "").toString().trim();
    }
    const trackUrl = (td?.track_url as string | undefined) ?? null;
    const courier = (td?.courier_name as string | undefined) ?? (latest.courier_name as string | undefined) ?? null;

    const mapped = mapShiprocketStatus(currentStatusRaw || "");
    const isShipmentCancelled = mapped.shipmentStatus === "cancelled";

    const existingDelivery = (order.delivery_status ?? "").toString().trim().toLowerCase();
    if (isShipmentCancelled && existingDelivery === "delivered") {
      return json(200, { synced: false, ignored: "delivered_order_ignore_shipment_cancel" });
    }

    const resumeAfterCancelled =
      existingDelivery === "cancelled" && mapped.shipmentStatus !== "cancelled";

    const incomingAt = new Date();
    const existingTrackAt = order.last_tracking_update ? new Date(order.last_tracking_update) : null;
    const bypassStale = isShipmentCancelled || resumeAfterCancelled;
    if (
      !bypassStale &&
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

    const existingPriority = deliveryStatusPriority[existingDelivery] ?? 0;
    const incomingPriority = deliveryStatusPriority[mapped.deliveryStatus] ?? 0;
    if (!resumeAfterCancelled && incomingPriority < existingPriority) {
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
    let patch: Record<string, unknown>;
    if (isShipmentCancelled) {
      patch = buildShiprocketCancelledPatch(order);
    } else {
      patch = {
        shipment_status: mapped.shipmentStatus,
        delivery_status: mapped.deliveryStatus,
        tracking_url: trackUrl,
        courier_name: courier ?? null,
        last_tracking_update: nowIso,
      };
      if (awb) patch.tracking_number = awb;
      if (mapped.shipmentStatus === "delivered") patch.delivered_at = nowIso;
    }

    if (!isShipmentCancelled && mapped.orderStatus) {
      const currentRank = orderStatusRank((order.status ?? "").toString());
      const nextRank = orderStatusRank(mapped.orderStatus);
      const currentStatus = (order.status ?? "").toString().trim().toLowerCase();
      const isTerminal = currentStatus === "delivered" || currentStatus === "cancelled";
      if (!isTerminal && nextRank > currentRank && currentRank >= 0 && currentRank < 99) {
        patch.status = mapped.orderStatus;
        const nextSt = (mapped.orderStatus ?? "").toString().trim().toLowerCase();
        if (nextSt === "shipped") {
          patch.shipped_at = nowIso;
        }
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

    devLog("shiprocket_fallback_sync_processed", {
      shipment_id: (order.shipment_id ?? null) as string | null,
      status: mapped.shipmentStatus,
      at: nowIso,
    });

    return json(200, {
      synced: true,
      track_source: trackSource,
      awb_code: awb || null,
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
