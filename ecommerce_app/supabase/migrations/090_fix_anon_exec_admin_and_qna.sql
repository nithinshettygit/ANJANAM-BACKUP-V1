-- Fix unauthenticated storefront errors:
-- - Logged-out users (role: anon) can reach Product Details which calls RPCs that
--   reference public.is_admin(auth.uid()).
-- - Later migrations redefined public.is_admin(...) and fetch_product_questions_page(...)
--   without restoring anon execute privileges, causing "permission denied" errors.

-- Allow anon to evaluate current-user admin status (auth.uid() will be null for anon).
revoke all on function public.is_admin(uuid) from public;
grant execute on function public.is_admin(uuid) to anon, authenticated;

-- Ensure public product Q&A fetch RPC remains callable by logged-out users.
revoke all on function public.fetch_product_questions_page(uuid, int, int) from public;
grant execute on function public.fetch_product_questions_page(uuid, int, int) to anon, authenticated;

