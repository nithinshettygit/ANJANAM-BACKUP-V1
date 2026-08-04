# APPLICATION MASTER REPORT

## 1) Project Overview

- **Project name:** `ecommerce_app` (repo root: `D:/ANJANAM-NEW`)
- **Architecture type:** Modular monolith (single Flutter app + Supabase backend services)
- **Tech stack:**
  - **Frontend/App:** Flutter (`lib/`), Riverpod state management
  - **Backend/API:** Supabase Edge Functions (`supabase/functions/*.ts`)
  - **Database:** Supabase Postgres (`supabase/migrations/*.sql`)
  - **Auth:** Firebase Auth bridged to Supabase sessions
  - **Payments:** Razorpay
  - **Shipping:** Shiprocket
  - **Hosting/Deploy:** Firebase Hosting + GitHub Actions (`.github/workflows/deploy-admin-web.yml`)
- **Delivery targets:** Android + Web storefront/admin

### Folder Structure Summary

- `ecommerce_app/lib/` - Flutter application code (user + admin + shared core)
- `ecommerce_app/supabase/functions/` - backend Edge Functions
- `ecommerce_app/supabase/migrations/` - DB schema, RPCs, RLS, lifecycle logic
- `ecommerce_app/scripts/` - build/deploy scripts
- `ecommerce_app/web/` - web shell + legal/support pages
- `ecommerce_app/android`, `ecommerce_app/ios` - platform runners
- `.github/workflows/` - CI/CD pipelines

---

## 2) Full File Structure Breakdown

This section is complete for application/business logic files (non-generated source). Platform boilerplate under `android/` and `ios/` is summarized because most files are Flutter-generated scaffolding.

### Root (`D:/ANJANAM-NEW`)

- `.github/workflows/deploy-admin-web.yml` - CI deploy workflow for admin web
- `ecommerce_app/` - primary app + backend code
- `app-icon-all/`, `banner image.png`, `banner-2-app.png` - design/asset files

### `ecommerce_app/lib` (280 Dart files; business core)

- `main.dart` - app bootstrap; initializes Firebase/Supabase and platform startup mode
- `app.dart` - root `MaterialApp` wiring and route entry
- `firebase_options.dart` - Firebase config values

#### `lib/presentation` (user-facing UI shell)
- `routing/app_router.dart` - central route map (user + admin + deep links)
- `routing/auth_guard.dart` - authenticated route guard
- `pages/*.dart` - screen-level user UI (checkout, cart, profile, orders, etc.)
- `widgets/*.dart` - reusable storefront components
- `providers/*.dart` - UI state providers for presentation layer
- `utils/*.dart` - navigation/share/category helpers

#### `lib/features` (domain modules)
- `auth/` - signup/login, phone/google bridge clients, auth state/actions
- `catalog/` - product listing, filters, fetch models/services
- `cart/` - cart entity/repository/provider/service stack
- `checkout/` - place-order and payment orchestration
- `order_history/` - orders query + detail domain models
- `returns/` - customer return request and replacement tracking data
- `reviews/` - review CRUD/moderation flows
- `videos/`, `articles/` - media/content modules
- `notifications/` - push/in-app notifications state + sender service
- `search/`, `wishlist/`, `product_questions/` - additional storefront features

#### `lib/admin` (admin panel)
- `pages/admin_shell_page.dart` - admin route-to-page dispatcher
- `pages/admin_dashboard_page.dart` - dashboard KPIs
- `pages/admin_products_page.dart` - catalog management UI
- `pages/admin_orders_page.dart` / `order_details_page.dart` - order operations
- `pages/admin_returns_page.dart` - returns/replacements workflow UI
- `pages/admin_inventory_page.dart` - stock and inventory actions
- `pages/admin_users_page.dart` / `user_details_page.dart` - user operations
- `pages/admin_notifications_page.dart` / `admin_alerts_page.dart` - outbound and admin alerts
- `services/admin_service.dart` - primary admin backend interaction layer
- `providers/admin_providers.dart` - admin state providers
- `widgets/admin_guard.dart`, `admin_shell_layout.dart` - admin access + shell layout
- `utils/admin_order_status_workflow.dart` - frontend status transition rules

#### `lib/core` (shared infrastructure)
- `config/` - app env, legal URLs, app-link and auth redirect config
- `notifications/` - local notification handling and tap routing
- `payments/` - Razorpay wrappers (`*_io.dart`, `*_web.dart`)
- `network/` - resilient HTTP and guard logic
- `theme/`, `constants/`, `invoice/`, `web/`, `supabase/` - cross-cutting utilities

### `ecommerce_app/supabase/functions` (Edge Functions)

- `create_payment_order/index.ts` - creates or reuses Razorpay order for app order
- `verify_payment/index.ts` - payment verification + order payment finalization
- `check-payment-status/index.ts` - polling endpoint for payment status
- `verify-razorpay-payment/index.ts` - fallback verifier
- `create-razorpay-order/index.ts` - legacy create endpoint
- `capture-razorpay-payment/index.ts` - manual capture endpoint
- `refund-payment/index.ts` - admin-initiated refund endpoint
- `razorpay-webhook/index.ts` - webhook processor for payment/refund events
- `create_shiprocket_shipment/index.ts` - creates shipment + AWB allocation
- `sync-shiprocket-status/index.ts` - shipment status sync endpoint
- `sync_shiprocket_shipment_status/index.ts` - legacy/manual sync endpoint
- `shiprocket-webhook/index.ts` - shipping webhook receiver + order updates
- `delivery-webhook/index.ts` - alias wrapper for shiprocket webhook
- `phone-auth-bridge/index.ts` - Firebase phone token -> Supabase session
- `google-auth-bridge/index.ts` - Firebase Google token -> Supabase session
- `send-notification/index.ts` - FCM/in-app notification sender
- `_shared/auth.ts`, `_shared/dev_log.ts` - shared auth/log helpers

### `ecommerce_app/supabase/migrations` (85 SQL migrations)

- `001_ecommerce_schema.sql` - base tables (`products`, `orders`, `order_items`, etc.)
- `008_store_settings.sql`, `010_checkout_user_addresses.sql` - pricing/address settings
- `016`, `019`, `020`, `022`, `036`, `037`, `040`, `047`, `048` - content/catalog/UX modules
- `030`, `031`, `034`, `046`, `084`, `085` - returns/refunds/replacements lifecycle
- `033`, `042`, `049`, `050`, `055`-`058`, `060`, `074`, `078`, `083` - payment hardening and recovery
- `052`, `053`, `073`, `079` - notification and token management
- `061`, `062`, `065`, `075` - admin order transition and cancellation controls
- `076` - auth bridge nonce/rate limits
- `080`, `081`, `082`, `064` - shipping/webhook security and logs

### Config/Build/Hosting

- `ecommerce_app/firebase.json` - Hosting routes/headers
- `ecommerce_app/.firebaserc` - Firebase project mapping
- `ecommerce_app/supabase/config.toml` - function runtime config (`verify_jwt` behavior)
- `ecommerce_app/scripts/*.ps1|*.sh` - local build/deploy commands

---

## 3) Page / Feature Mapping

## User Pages

- **Home / Main Shell**
  - Route: `/`
  - Files: `lib/presentation/pages/main_shell.dart`, `lib/presentation/routing/app_router.dart`, feature providers under `lib/features/*/state`
  - Data flow: Home widgets -> feature providers -> Supabase table reads -> UI render
- **Catalog**
  - Route: `/catalog`, `/products?category=...`, `/catalog/browse`
  - Files: `lib/presentation/pages/catalog_page.dart`, `lib/features/catalog/*`, `app_router.dart`
  - Logic: category normalization, recommendation/popular/festival/new-arrivals filtering
- **Product Details**
  - Route: `/catalog/details`, `/product/<id>`
  - Files: `lib/presentation/pages/product_details_page.dart`, `lib/features/catalog/*`, `lib/features/reviews/*`
  - Flow: Product fetch -> variant/stock logic -> cart/wishlist/review operations
- **Cart**
  - Route: `/cart`
  - Files: `lib/presentation/pages/cart_page.dart`, `lib/features/cart/*`
  - Flow: UI qty actions -> cart repository/service -> `carts` + `cart_items`
- **Checkout**
  - Route: `/checkout`
  - Files: `lib/presentation/pages/checkout_page.dart`, `lib/features/checkout/state/checkout_actions_controller.dart`, `lib/features/checkout/data/services/supabase_checkout_service.dart`, `lib/features/checkout/data/services/order_payment_service.dart`
  - Flow: UI validate -> RPC `place_order_checkout` -> `orders` + `order_items` + inventory reservation -> Razorpay/COD branch
- **Order History / Details**
  - Route: `/orders`, `/order-details`, `/order-success`
  - Files: `lib/presentation/pages/order_history_page.dart`, `order_details_page.dart`, `order_success_page.dart`, `lib/features/order_history/*`
  - Flow: provider -> orders join query -> item/track/status projection
- **Returns**
  - Route: `/orders/request-return`
  - Files: `lib/presentation/pages/request_return_page.dart`, `lib/features/returns/data/returns_service.dart`
  - Flow: upload evidence -> RPC `create_customer_return` -> `returns` + status propagation
- **Wishlist**
  - Route: `/wishlist`
  - Files: `lib/presentation/pages/wishlist_page.dart`, `lib/features/wishlist/*`
  - Flow: toggle wishlist -> `wishlist_items`
- **Auth**
  - Routes: `/login`, `/login/email`, `/login/phone`, `/signup`
  - Files: `lib/presentation/pages/auth_choice_page.dart`, `login_page.dart`, `phone_login_page.dart`, `signup_page.dart`, `lib/features/auth/*`
  - Integrations: Firebase Auth + bridge functions
- **Articles / Videos**
  - Routes: `/articles`, `/article/<id>`, `/videos`, `/video/<id>`
  - Files: `lib/features/articles/*`, `lib/features/videos/*`, `app_router.dart`
  - Flow: media/content fetch -> detail page -> gated access rules for purchases where applied
- **Notifications**
  - Route: `/notifications`
  - Files: `lib/presentation/pages/notifications_page.dart`, `lib/features/notifications/*`, `lib/core/notifications/*`
  - Flow: FCM/local notification -> in-app routing + read-state sync

## Admin Pages

- **Admin Shell / Dashboard**
  - Routes: `/admin`, `/admin/dashboard`
  - Files: `lib/admin/pages/admin_shell_page.dart`, `admin_dashboard_page.dart`, `lib/admin/widgets/admin_guard.dart`
- **Products / QA / Reviews**
  - Routes: `/admin/products`, `/admin/product-qa`, `/admin/product-reviews`
  - Files: `admin_products_page.dart`, feature moderation pages, `admin_service.dart`
  - Flow: CRUD/moderation requests -> Supabase tables/functions -> UI refresh providers
- **Orders**
  - Routes: `/admin/orders`, `/admin/orders/details(/<id>)`
  - Files: `admin_orders_page.dart`, `order_details_page.dart`, `admin_service.dart`, `admin_order_status_workflow.dart`
  - Flow: list/detail fetch -> status/cancel/refund/shipment actions -> DB + edge function updates
- **Returns & Replacements**
  - Route: `/admin/returns`
  - Files: `admin_returns_page.dart`, `admin_service.dart`
  - Flow: return approval -> replacement RPCs -> replacement order/pickup/logistics tables
- **Users**
  - Routes: `/admin/users`, `/admin/users/details(/<id>)`
  - Files: `admin_users_page.dart`, `user_details_page.dart`, `admin_service.dart`
- **Inventory / Categories / Homepage / Content**
  - Routes: `/admin/inventory`, `/admin/categories`, `/admin/homepage`, `/admin/videos`, `/admin/articles`, `/admin/explore-suggestions`
  - Files: corresponding admin pages + `admin_service.dart`
- **Notifications**
  - Routes: `/admin/notifications`, `/admin/admin-notifications`
  - Files: `admin_notifications_page.dart`, `admin_alerts_page.dart`, notification service files

---

## 4) Admin Panel Breakdown

- **Orders**
  - Files: `lib/admin/pages/admin_orders_page.dart`, `lib/admin/pages/order_details_page.dart`, `lib/admin/services/admin_service.dart`
  - Backend APIs: `refund-payment`, `create_shiprocket_shipment`, `sync-shiprocket-status`
  - Tables: `orders`, `order_items`, `order_status_history`, `refunds`
  - Critical logic: status transitions, cancellation gating, refund eligibility, shipment synchronization

- **Inventory**
  - Files: `lib/admin/pages/admin_inventory_page.dart`, `admin_service.dart`
  - Tables: `products`, `product_variants`
  - Critical logic: stock updates aligned with checkout and replacement deductions

- **Returns / Replacement Orders**
  - Files: `lib/admin/pages/admin_returns_page.dart`, `admin_service.dart`
  - APIs/RPCs: replacement approval and logistics RPCs, refund endpoint
  - Tables: `returns`, `refunds`, `replacement_cases`, `replacement_pickups`, `replacement_case_events`
  - Critical logic: state transitions + dual-leg logistics completion conditions

- **Notifications**
  - Files: `admin_notifications_page.dart`, `admin_alerts_page.dart`, `features/notifications/*`
  - API: `send-notification`
  - Tables: `admin_notifications`, `user_notifications`, `user_devices`
  - Critical logic: targeted vs broadcast delivery; failure tracking

---

## 5) User App Breakdown

- **Browse / Search**
  - Files: catalog and search features under `lib/features/catalog/*`, `lib/features/search/*`
  - APIs: Supabase table reads, search suggestions RPC/table
  - State: Riverpod providers for list/detail/filter
  - Validation: category filters, active product and availability checks

- **Cart**
  - Files: `lib/features/cart/*`, `cart_page.dart`
  - Tables/APIs: `carts`, `cart_items`
  - State: cart providers + repository/service
  - Validation: quantity and variant compatibility checks

- **Checkout**
  - Files: checkout page + checkout service + order payment service
  - APIs: RPC `place_order_checkout`, edge functions `create_payment_order`, `verify_payment`, `check-payment-status`
  - State: checkout action providers
  - Validation: shipping address/phone/pincode, auth/session, stock, currency, variant constraints

- **Orders**
  - Files: order history/details pages + `lib/features/order_history/*`
  - APIs: Supabase orders queries + status history
  - State: provider-driven list/detail cache
  - Validation: user ownership and auth guard

- **Returns**
  - Files: `request_return_page.dart`, `returns_service.dart`
  - APIs: storage upload + `create_customer_return` RPC
  - State: request form + order/return refresh
  - Validation: delivery window, duplicate active return prevention, evidence requirement

---

## 6) API & Backend Documentation

### Authentication Bridges

- `POST /functions/v1/phone-auth-bridge`
  - Request: `id_token|firebase_id_token`, `client_nonce`
  - Response: `ok`, `supabase_uid`, `refresh_token`, `expires_in`, `phone`
  - Implemented: `supabase/functions/phone-auth-bridge/index.ts`
  - Called from: `lib/features/auth/data/services/firebase_phone_auth_service.dart`

- `POST /functions/v1/google-auth-bridge`
  - Request: Firebase token + nonce (+ optional profile hints)
  - Response: `ok`, `supabase_uid`, `refresh_token`, `expires_in`
  - Implemented: `supabase/functions/google-auth-bridge/index.ts`
  - Called from: `lib/features/auth/data/services/firebase_google_auth_service.dart`

### Payment APIs

- `POST /functions/v1/create_payment_order`
  - Request: `order_id` (+ authenticated user context)
  - Response: `ok`, `razorpay_order_id`, `amount`, `currency`, `key_id`
  - File: `supabase/functions/create_payment_order/index.ts`
  - Caller: `lib/features/checkout/data/services/order_payment_service.dart`

- `POST /functions/v1/verify_payment`
  - Request: `order_id`, `razorpay_payment_id`, optional `razorpay_order_id`, `razorpay_signature`
  - Response: success/pending/auto-refund outcomes
  - File: `supabase/functions/verify_payment/index.ts`
  - Caller: `order_payment_service.dart`

- `GET /functions/v1/check-payment-status?order_id=...`
  - Response: `pending|paid|failed`
  - File: `supabase/functions/check-payment-status/index.ts`
  - Caller: `order_payment_service.dart`

- `POST /functions/v1/refund-payment`
  - Request: `order_id`, optional refund amount/reason
  - Response: refund creation status
  - File: `supabase/functions/refund-payment/index.ts`
  - Caller: `lib/admin/services/admin_service.dart`

- Webhooks:
  - `POST /functions/v1/razorpay-webhook` (`supabase/functions/razorpay-webhook/index.ts`)
  - Called by Razorpay server (not app client)

### Shipping APIs

- `POST /functions/v1/create_shiprocket_shipment`
  - Request: `order_id`, pickup info
  - Response: shipment/AWB/tracking payload
  - File: `supabase/functions/create_shiprocket_shipment/index.ts`
  - Caller: `lib/admin/services/admin_service.dart`

- `POST /functions/v1/sync-shiprocket-status`
  - Request: `order_id`
  - Response: normalized shipment sync state
  - File: `supabase/functions/sync-shiprocket-status/index.ts`
  - Caller: `admin_service.dart`

- Webhooks:
  - `POST /functions/v1/shiprocket-webhook` (`shiprocket-webhook/index.ts`)
  - `POST /functions/v1/delivery-webhook` (`delivery-webhook/index.ts`)
  - Called by Shiprocket server

### Notification API

- `POST /functions/v1/send-notification`
  - Request: action-based payload (`user_notification`, `order_status`, `admin_notification`)
  - Response: `ok`, FCM delivery stats
  - File: `supabase/functions/send-notification/index.ts`
  - Caller: `lib/features/notifications/data/services/fcm_edge_function_notification_sender.dart`

---

## 7) Database Structure

## Core Tables

- `products`, `product_variants`, `categories`
- `profiles`, `user_addresses`, `user_devices`
- `carts`, `cart_items`
- `orders`, `order_items`, `order_status_history`
- `returns`, `refunds`
- `replacement_cases`, `replacement_pickups`, `replacement_case_events`
- `wishlist_items`, `reviews`, `product_questions`, `product_answers`
- `videos`, `articles`, `article_purchases`, `explore_suggestions`
- `homepage_hero_banners`, `homepage_top_categories`, `search_suggestions`
- `user_notifications`, `admin_notifications`, `admin_logs`
- `webhook_events`, `shiprocket_webhook_logs`, `system_error_logs`
- `store_settings`, `auth_bridge_nonces`, `auth_bridge_rate_limits`

## Key Relationships

- `profiles.id -> auth.users.id`
- `carts.user_id -> auth.users.id`
- `cart_items.cart_id -> carts.id`, `cart_items.product_id -> products.id`
- `orders.user_id -> auth.users.id`
- `order_items.order_id -> orders.id`, `order_items.product_id -> products.id`, optional `variant_id -> product_variants.id`
- `returns.order_id -> orders.id` and associated item/user references
- `refunds` linked to returns/orders
- `replacement_*` linked to returns/orders and logistics progression

## Fields (critical, frequently used)

- `orders`: payment fields (`payment_status`, `razorpay_*`, `paid_at`), shipping fields (`shipment_id`, `awb_code`, `tracking_url`, `delivery_status`), refund fields (`refund_status`, `refund_amount`, `refund_id`), status fields (`status`, cancellation/refund lifecycle columns), address snapshot fields
- `order_items`: `order_id`, `product_id`, `variant_id`, `unit_price`, `quantity`, `title`
- `products/product_variants`: availability, stock/reserved stock, pricing, shipping dimensions
- `returns/refunds/replacement_*`: lifecycle statuses, reason/evidence, replacement shipment/pickup metadata

---

## 8) External Integrations

- **Razorpay**
  - Files: `create_payment_order`, `verify_payment`, `razorpay-webhook`, `refund-payment`
  - App callers: `order_payment_service.dart`, `admin_service.dart`
  - Flow: create Razorpay order -> checkout -> verify/webhook -> order update/refund lifecycle

- **Shiprocket**
  - Files: `create_shiprocket_shipment`, `sync-shiprocket-status`, `shiprocket-webhook`, `delivery-webhook`
  - App callers: `admin_service.dart`
  - Flow: admin creates shipment -> provider assigns AWB -> webhook/status sync updates order delivery state

- **Auth (Firebase + Supabase)**
  - Files: phone/google bridge edge functions + auth service files in `lib/features/auth/data/services`
  - Flow: Firebase identity token validated -> Supabase auth/user profile synchronized -> session used for app API calls

- **FCM Notifications**
  - Files: `send-notification` edge function + notification sender in app
  - Flow: app/admin action -> edge function -> FCM push + DB notification row

---

## 9) Critical Flows (Step-by-Step)

## A) Order Placement

1. `checkout_page.dart` validates form and triggers checkout action.
2. `checkout_actions_controller.dart` calls `supabase_checkout_service.dart`.
3. Service calls RPC `place_order_checkout` with `p_items`, `p_shipping`, `p_currency`.
4. RPC validates stock/shipping/currency and inserts `orders` + `order_items`; reserves stock.
5. App clears cart, refreshes providers, enters payment branch.

## B) Payment Verification

1. App requests payment order from `create_payment_order`.
2. Razorpay checkout returns payment result to app.
3. App calls `verify_payment` with payment identifiers/signature.
4. Server validates with Razorpay APIs/signature and marks order paid/processing.
5. Webhook `razorpay-webhook` acts as safety net for async capture/failure/refund events.

## C) Return & Replacement

1. User submits return request from `request_return_page.dart`.
2. Evidence images upload to storage bucket; service calls return RPC.
3. DB validates policy window + delivered condition + duplicate constraints; inserts return.
4. Admin approves replacement; replacement RPC creates replacement case/order/pickups and updates inventory.
5. Logistics updates and completion statuses sync through replacement and order tables.

## D) Admin Order Processing

1. Admin list/detail pages load order data via `admin_service.dart`.
2. Admin action triggers status/cancel/refund/shipment operation.
3. Operation uses RPC or edge function and persists to order/refund/logistics tables.
4. Providers invalidate/reload and UI reflects updated workflow state.

---

## 10) Safe Edit Guide (Most Important)

- **Checkout contract edits** (`checkout_page.dart` + `supabase_checkout_service.dart` + `place_order_checkout` migration/RPC)
  - Risk: order creation fails silently or inventory desync
  - Safe edit: update UI payload keys and RPC parameters together; test variant and non-variant carts

- **Payment logic edits** (`order_payment_service.dart` + `create_payment_order` + `verify_payment` + webhook + payment lock RPCs)
  - Risk: duplicate charges, stuck pending payments, replay races
  - Safe edit: keep amount calculation and state transitions aligned across all payment entry points

- **Order status transition edits** (`admin_order_status_workflow.dart` + DB transition function migrations + `admin_service.dart`)
  - Risk: UI allows invalid actions; server rejects updates
  - Safe edit: adjust frontend allowed actions and SQL transition rules in same change

- **Returns/replacements edits** (`returns_service.dart`, `admin_returns_page.dart`, migrations `046`, `084`, `085`)
  - Risk: replacement loops, wrong inventory deductions, broken case completion
  - Safe edit: validate full lifecycle transitions in DB and matching UI enum mapping

- **Auth bridge edits** (Firebase auth services + `phone-auth-bridge`/`google-auth-bridge`)
  - Risk: login success in Firebase but no Supabase session
  - Safe edit: keep nonce, rate-limit, token validation, and response contract unchanged unless all clients are updated

- **Notification edits** (`send-notification` + app notification parser/router)
  - Risk: malformed payloads and dead navigation targets
  - Safe edit: preserve action payload schema and test tap-navigation flows

---

## 11) Quick Edit Cheat Sheet

| Change Needed | Files to Edit | Risk Level | Notes |
| --- | --- | --- | --- |
| Change UI text | `lib/presentation/pages/*`, `lib/admin/pages/*` | Low | Avoid modifying business logic blocks while editing labels |
| Add storefront route | `lib/presentation/routing/app_router.dart` + target page/provider | Medium | Include auth guard if protected route |
| Modify checkout validation | `checkout_page.dart`, `supabase_checkout_service.dart`, checkout domain models | High | Keep UI + RPC validation messages in sync |
| Modify payment logic | `order_payment_service.dart`, `create_payment_order`, `verify_payment`, webhook | High | Test web + mobile and duplicate-submit scenarios |
| Change order status flow | `admin_order_status_workflow.dart`, `admin_service.dart`, SQL transition migration | High | Frontend and DB transition graphs must match |
| Update return policy window | return RPC migration (`046_*`) + `returns_service.dart` + return UI text | High | Policy mismatch creates false rejections/approvals |
| Change replacement processing | `admin_returns_page.dart`, `admin_service.dart`, `084_*`, `085_*` | High | Validate both reverse and forward logistics legs |
| Update shipping provider behavior | shiprocket functions + `admin_service.dart` | High | Keep webhook parser and manual sync schema compatible |
| Add notification type | `send-notification` + app notification model/router | Medium | Backward compatibility for older app payloads |
| Change auth flow | auth services + bridge functions + profile mapping | High | Nonce/rate-limit and token contract cannot drift |

---

## 12) Future AI Usage Format

Use this section when asking ChatGPT/Codex to make precise edits safely.

### Template Prompt

`Modify this feature without breaking existing logic. Keep API contract same. Preserve DB/RPC compatibility and existing state transitions.`

### Feature-wise Copy-Paste File Packs

- **Checkout + Order Creation**
  - `lib/presentation/pages/checkout_page.dart`
  - `lib/features/checkout/state/checkout_actions_controller.dart`
  - `lib/features/checkout/data/services/supabase_checkout_service.dart`
  - Latest migration defining `place_order_checkout` (currently `supabase/migrations/068_product_variants.sql`, with hardening in `077_*`)

- **Razorpay Payment Flow**
  - `lib/features/checkout/data/services/order_payment_service.dart`
  - `supabase/functions/create_payment_order/index.ts`
  - `supabase/functions/verify_payment/index.ts`
  - `supabase/functions/check-payment-status/index.ts`
  - `supabase/functions/razorpay-webhook/index.ts`
  - `supabase/migrations/083_payment_order_creation_lock_and_active_admin_notifications.sql`

- **Returns + Replacements**
  - `lib/presentation/pages/request_return_page.dart`
  - `lib/features/returns/data/returns_service.dart`
  - `lib/admin/pages/admin_returns_page.dart`
  - `lib/admin/services/admin_service.dart`
  - `supabase/migrations/046_standardize_return_lifecycle_v2.sql`
  - `supabase/migrations/084_replacement_exchange_cases.sql`
  - `supabase/migrations/085_replacement_dual_leg_logistics.sql`

- **Admin Order Processing**
  - `lib/admin/pages/admin_orders_page.dart`
  - `lib/admin/pages/order_details_page.dart`
  - `lib/admin/services/admin_service.dart`
  - `lib/admin/utils/admin_order_status_workflow.dart`
  - `supabase/migrations/061_admin_cancel_reject_status_transitions.sql`
  - `supabase/migrations/062_block_cancel_request_after_shipped.sql`
  - `supabase/functions/refund-payment/index.ts`

- **Authentication**
  - `lib/features/auth/data/services/firebase_phone_auth_service.dart`
  - `lib/features/auth/data/services/firebase_google_auth_service.dart`
  - `supabase/functions/phone-auth-bridge/index.ts`
  - `supabase/functions/google-auth-bridge/index.ts`
  - `supabase/migrations/076_auth_bridge_nonce_rate_limit.sql`

- **Notifications**
  - `lib/features/notifications/data/services/fcm_edge_function_notification_sender.dart`
  - `lib/features/notifications/state/notifications_controller.dart`
  - `lib/core/notifications/notification_message_router.dart`
  - `supabase/functions/send-notification/index.ts`

---

## Appendix: Operational Notes for Future Developers

- Prefer editing latest migrations/new migrations rather than changing historic migrations already applied in production.
- For payment/returns/order status changes, always test these scenarios:
  - Success path
  - Retry/double-click path
  - Failure + rollback/refund path
  - Webhook delayed/out-of-order delivery
- Preserve route names in `app_router.dart`; route renames can break deep links and admin navigation.
- Keep Flutter model fields and Supabase response fields backward-compatible.

---

## 13) Security & Attack Resilience Plan (Mandatory)

This project already has multiple hardening controls (RLS, webhook signature checks, payment lock/dedup), but you should treat this section as a required security baseline before production scale.

## Current Security Posture (Code-Verified)

- **Good controls present**
  - RLS is enabled and policies exist for core transactional tables (`orders`, `order_items`, `cart_*`, `profiles`, `returns`, `refunds`, etc.)
  - Razorpay webhook validates HMAC signature and uses dedup table (`webhook_events`)
  - Shiprocket webhook validates shared secret header
  - Payment flow includes replay/race hardening migrations (`074`, `083`)
  - Auth-bridge nonce/rate-limit tables exist (`076_auth_bridge_nonce_rate_limit.sql`)

- **High-risk areas to treat immediately**
  - All Edge Functions are configured with `verify_jwt = false` in `supabase/config.toml`
  - Several privileged functions depend on in-function auth checks only (safe only if every code path validates auth/role)
  - CORS allows wildcard origin (`*`) in some functions; acceptable for public webhooks, risky for privileged endpoints if auth checks regress

## Priority Hardening Backlog

## P0 (Do First - High Risk)

- **Enforce auth boundary per function**
  - Keep `verify_jwt = false` only for endpoints that genuinely require anonymous/provider callbacks:
    - `phone-auth-bridge`, `google-auth-bridge`, webhook endpoints
  - For authenticated app endpoints, switch to `verify_jwt = true` where feasible and validate with web/mobile smoke tests.
  - If gateway JWT must remain false for compatibility, mandate strict in-function checks:
    - Validate bearer token
    - Resolve user from token
    - Re-check ownership/admin role at DB layer (RPC/security definer)

- **Lock service-role usage**
  - Ensure client code never embeds service role keys.
  - Restrict all service-role DB writes to Edge Functions only.
  - Add CI secret scanning on push for accidental key leaks.

- **Webhook integrity**
  - Keep signature verification mandatory.
  - Add timestamp tolerance and replay window checks where provider supports it.
  - Keep dedup IDs immutable and indexed.

## P1 (Next - Strongly Recommended)

- **Rate limiting and abuse controls**
  - Extend nonce/rate-limit pattern from auth bridge to payment creation and order placement.
  - Add per-IP and per-user limits for checkout, login, and notification-trigger endpoints.

- **Strict input schemas**
  - Add explicit schema validation in each Edge Function (required fields, type checks, length caps).
  - Reject unknown fields for sensitive endpoints (`refund-payment`, shipment updates, admin actions).

- **Admin privilege hardening**
  - Ensure all admin actions rely on DB `is_active_admin` checks (not UI role alone).
  - Audit fallback code paths in `admin_service.dart` for any direct table write that might bypass RPC business controls.

## P2 (Defense in Depth)

- **Audit and alerting**
  - Centralize security logs for:
    - failed auth checks
    - repeated webhook signature failures
    - refund and status transition anomalies
  - Alert on unusual spikes (refund attempts, payment verify failures, auth bridge failures).

- **Dependency and supply-chain hygiene**
  - Add weekly dependency audit (Flutter/Dart + Deno/npm packages used in functions).
  - Pin critical backend dependency versions where possible.

- **Data protection**
  - Minimize PII in logs (phone/address/order notes).
  - Ensure retention rules for webhook/system logs.

## Security Regression Checklist (Run Before Release)

- **Auth & access**
  - Unauthenticated user cannot read/write other users' cart, order, return, address, profile data.
  - Non-admin user cannot execute admin transitions/refunds/shipment updates.

- **Payment integrity**
  - Cannot mark order `paid` from client without server verification.
  - Duplicate verify/webhook events do not duplicate captures/status transitions.

- **Webhook security**
  - Invalid/missing signature always rejected.
  - Replay payload produces dedup-safe result, not duplicate side effects.

- **Returns/refunds abuse**
  - Duplicate active returns blocked.
  - Refund endpoint rejects non-admin and invalid order states.

- **Operational resilience**
  - Edge Function timeout/error paths do not leave orders in inconsistent state.
  - Retry logic remains idempotent for payment, shipment, and notification actions.

## Incident Readiness (Minimum)

- Keep runbooks for:
  - payment mismatch (charged but order not paid)
  - webhook outage/replay storm
  - abusive refund attempts
  - compromised admin account
- Prepare immediate controls:
  - rotate secrets (Razorpay, Shiprocket, internal function secret, Firebase service creds)
  - temporarily disable vulnerable function route
  - replay reconciliation scripts for affected orders
