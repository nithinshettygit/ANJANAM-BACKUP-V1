-- =============================================================================
-- ANJANAM — Pre-production / staging data cleanup (MANUAL SCRIPT)
-- =============================================================================
--
-- Run in Supabase SQL Editor (or psql) as a role that can modify auth + public
-- (typically postgres / service role). NOT a migration — do not add to
-- supabase/migrations/ unless you intend every new environment to auto-wipe.
--
-- BEFORE RUNNING:
--   1) Create a backup or Supabase database branch / point-in-time snapshot.
--   2) Confirm you are on STAGING or a disposable clone — NOT production with
--      real customers unless you intentionally want a full wipe.
--   3) Review optional SELECTIVE section at bottom (commented) if you need
--      partial cleanup instead of full wipe.
--
-- PRESERVES:
--   • public.products, categories, store_settings, articles metadata, schema
--   • Users with profiles.role IN ('admin', 'super_admin')
--
-- REMOVES (full wipe path below):
--   • All orders + dependents, reviews, Q&A, notifications, webhook dedupe log
--   • All customer auth users (and cascaded profile/cart/wishlist/…)
--
-- INVENTORY NOTE:
--   Deleting orders does NOT automatically reverse inventory_count changes from
--   fulfilled test orders. If you had real-looking stock movements, restore
--   inventory from backup or adjust manually after cleanup.
--
-- =============================================================================

BEGIN;

DO $guard$
DECLARE
  n int;
BEGIN
  SELECT count(*) INTO n
  FROM public.profiles p
  WHERE lower(trim(coalesce(p.role, 'customer'))) IN ('admin', 'super_admin');

  IF coalesce(n, 0) < 1 THEN
    RAISE EXCEPTION
      'pre_production_cleanup: no admin or super_admin profile found — aborting (protects against locking everyone out).';
  END IF;
END
$guard$;

-- ---------------------------------------------------------------------------
-- 1) Order-related dependents (explicit order avoids FK surprises)
-- ---------------------------------------------------------------------------
DELETE FROM public.refunds;

DELETE FROM public.returns;

DELETE FROM public.order_status_history;

DELETE FROM public.user_notifications;

UPDATE public.article_purchases
SET order_id = NULL
WHERE order_id IS NOT NULL;

DELETE FROM public.system_error_logs;

DELETE FROM public.order_items;

DELETE FROM public.orders;

-- ---------------------------------------------------------------------------
-- 2) Reviews & Q&A (product rows kept; aggregates refresh via review triggers)
-- ---------------------------------------------------------------------------
DELETE FROM public.reviews;

DELETE FROM public.product_answers;

DELETE FROM public.product_questions;

-- ---------------------------------------------------------------------------
-- 3) Notifications & webhook ledger
-- ---------------------------------------------------------------------------
DELETE FROM public.admin_notifications;

DELETE FROM public.webhook_events;

-- ---------------------------------------------------------------------------
-- 4) Per-user data (before auth delete; safe with or without user cascade)
-- ---------------------------------------------------------------------------
DELETE FROM public.cart_items;
DELETE FROM public.carts;

DELETE FROM public.wishlist_items;

DELETE FROM public.user_addresses;

DELETE FROM public.user_devices;

DELETE FROM public.article_purchases;

-- ---------------------------------------------------------------------------
-- 5) Auth users — keep admins only (matches public.profiles.role)
-- ---------------------------------------------------------------------------
DELETE FROM auth.users au
WHERE au.id NOT IN (
  SELECT p.id
  FROM public.profiles p
  WHERE lower(trim(coalesce(p.role, 'customer'))) IN ('admin', 'super_admin')
);

-- ---------------------------------------------------------------------------
-- 6) Post-wipe consistency helpers (no-op if you skipped order deletes)
-- ---------------------------------------------------------------------------
-- No pending reservations once all orders are gone.
UPDATE public.products
SET reserved_quantity = 0
WHERE NOT EXISTS (
  SELECT 1
  FROM public.order_items oi
  WHERE oi.product_id = products.id
);

-- Recompute review aggregates (covers bulk delete edge cases).
UPDATE public.products p
SET
  average_rating = sub.avg_r,
  total_reviews = sub.cnt,
  total_written_reviews = sub.txt
FROM (
  SELECT
    pr.id AS product_id,
    CASE WHEN count(r.*) = 0 THEN NULL ELSE round(avg(r.rating::numeric), 2) END AS avg_r,
    count(r.*)::int AS cnt,
    count(r.*) FILTER (
      WHERE nullif(trim(coalesce(r.review_text, '')), '') IS NOT NULL
    )::int AS txt
  FROM public.products pr
  LEFT JOIN public.reviews r ON r.product_id = pr.id AND r.is_visible = true
  GROUP BY pr.id
) sub
WHERE p.id = sub.product_id;

-- ---------------------------------------------------------------------------
-- 7) Verification queries (inspect result before COMMIT)
-- ---------------------------------------------------------------------------
-- SELECT count(*) AS orders_remaining FROM public.orders;
-- SELECT count(*) AS order_items_remaining FROM public.order_items;
-- SELECT count(*) AS reviews_remaining FROM public.reviews;
-- SELECT count(*) AS questions_remaining FROM public.product_questions;
-- SELECT count(*) AS admin_notifications_remaining FROM public.admin_notifications;
-- SELECT count(*) AS user_notifications_remaining FROM public.user_notifications;
-- SELECT id, email, raw_user_meta_data FROM auth.users;
-- SELECT id, role, full_name FROM public.profiles ORDER BY role, created_at;

COMMIT;

-- If anything looks wrong after step 7, run instead of COMMIT above:
-- ROLLBACK;


-- =============================================================================
-- OPTIONAL — SELECTIVE cleanup (copy/adapt; do NOT run full script + this)
-- =============================================================================
--
-- Example: only test-looking customers (uncomment and merge into a custom tx):
--
-- WITH victim_users AS (
--   SELECT au.id
--   FROM auth.users au
--   JOIN public.profiles p ON p.id = au.id
--   WHERE lower(coalesce(p.role, 'customer')) NOT IN ('admin', 'super_admin')
--     AND (
--       lower(au.email) LIKE '%test%'
--       OR lower(au.email) LIKE '%@example.com'
--     )
-- )
-- DELETE FROM public.orders o WHERE o.user_id IN (SELECT id FROM victim_users);
--
-- Then delete victim_users from auth (after their orders are gone), etc.
--
-- Example: only tiny-value orders (tune threshold for your currency):
--
-- DELETE FROM public.orders o
-- WHERE o.id IN (
--   SELECT o2.id
--   FROM public.orders o2
--   WHERE (
--     SELECT coalesce(sum(oi.unit_price * oi.quantity), 0) + coalesce(o2.delivery_fee, 0)
--     FROM public.order_items oi
--     WHERE oi.order_id = o2.id
--   ) <= 10
-- );
--
-- (If you use selective deletes, you must still respect FK order or use a
--  temp table + delete in the same order as section 1.)
