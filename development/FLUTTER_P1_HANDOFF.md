# Flutter P1 Marketplace Implementation Handoff

## Purpose

This document is the implementation contract for the Flutter/Dart P1 client in
this `development` folder. It replaces the generated Flutter counter app with
an Android-only mobile marketplace for buyers, approved resellers, and
administrators. Implement exactly the supported PHP API behaviors described
here. Do not modify the backend as part of this task and do not invent UI
actions for routes the API does not expose.

## Definition of Done

The P1 application is ready when a disposable buyer, approved reseller, and
administrator can complete the following live, HTTPS-backed flow on an Android
emulator or device:

1. Buyer registers or logs in, browses seeded catalog data, adds an item to
   the cart, creates a COD or meet-up order, and views its seller-group status.
2. Reseller applies, is approved by the administrator, creates an own product,
   uploads a product image, and progresses only an assigned order group.
3. Administrator approves/rejects/suspends reseller applications, creates an
   official-store product, and lists all orders. A reasoned order-group status
   override is conditional on the documented API blocker being resolved.
4. Authentication refresh, role guards, loading, empty, validation, timeout,
   network, authorization, and stock errors all have predictable UI behavior.

P1 is not a production release. Use disposable test data only.

## Verified API Constraints and One P1 Blocker

The implementation must follow the deployed PHP route contract, including its
limits. The following are intentional P1 constraints, not Flutter defects:

1. `GET /admin/orders` returns order rows and buyer fields only. It does not
   return `order_groups`, group IDs, items, status histories, or a fulfillment
   summary. The buyer-only `GET /orders/:id` cannot be used by an admin.
2. Therefore, `PATCH /admin/order-groups/:id` cannot be reached from normal
   admin UI data. Do **not** hard-code or manually request a group ID. The
   implementation agent must complete the admin order list, then leave the
   override control unavailable with an explicit developer note until a minimal
   authenticated `GET /admin/orders/:id` (or equivalent admin group-list)
   endpoint returns the order's group IDs. This is the sole P1 backend blocker.
3. `GET /reseller/orders` returns an assigned order-group summary but no order
   items or status history. Build a group summary/action screen only; do not
   promise an item-level reseller order detail view.
4. `GET /cart` exposes `seller_id` but not seller/store names. Group cart lines
   as `Official Store` for null seller IDs and `Reseller order` otherwise; do
   not fabricate a seller name.
5. Checkout stores an optional `address_id` and free-text `notes`; it does not
   persist a structured delivery/meet-up mode. Delivery and meet-up are client
   validation and presentation choices. After reload, `address_id != null` is
   only a delivery heuristic.
6. All server validation failures provide a top-level `message`, not a
   field-specific validation map. Display it as a form/action-level error.

## Fixed Product and Technical Decisions

| Area | Decision |
| --- | --- |
| Target | Android only for the school demonstration. |
| App identity | Display name `Phone Accessories Marketplace`; Android application ID `com.wbenogsudan.phoneaccessories`. |
| API | `https://wbenogsudan.duckdns.org`, passed through `--dart-define=API_BASE_URL`; this URL is the development fallback. |
| UI | Polished, accessible Material 3 application with teal seed color and light/dark themes. |
| State | `flutter_riverpod` with repository providers and `AsyncValue`/notifier command states. |
| Routing | `go_router`, with session and role redirects. |
| HTTP | `dio`, one configured client, a bearer-token interceptor, one refresh/replay attempt, and centralized API error mapping. |
| Secure persistence | `flutter_secure_storage` for access and refresh tokens only. Do not store passwords or order/customer data locally. |
| Images | `image_picker` plus multipart upload to the existing product-image endpoint. |
| Currency/date | `intl`; format amounts in Philippine pesos and present timestamps in the device locale. |
| Registration consent | Two required checkboxes with in-app P1 Terms and Privacy pages; submit both versions as `2026-09-19`. |
| Checkout | COD/meet-up only. Delivery requires a saved address; meet-up requires location/contact instructions in order notes. |

Add current compatible versions of these dependencies: `flutter_riverpod`,
`go_router`, `dio`, `flutter_secure_storage`, `image_picker`,
`cached_network_image`, and `intl`. Do not add Firebase, a database/cache,
code generation, BLoC, or packages not needed by P1.

## Scope Boundaries

### Implement in P1

- Registration, login, session restore, token refresh, and logout.
- Public catalog browse/search/category filtering, product detail, variants,
  and product images.
- Address creation/listing, cart management, COD/meet-up checkout, order
  history/detail, buyer cancellation, and buyer receipt confirmation.
- Reseller application/status, own product list/creation, image upload, own
  order list/detail, and valid status changes.
- Admin reseller application decisions, official product creation, all-order
  list, and reasoned order-group override.

### Explicitly defer

- OTP/email verification, password reset, account deletion, profile editing.
- Chat, reviews, favorites, banners, notifications center, earnings, analytics,
  user management, store settings, seller storefronts, phone compatibility,
  and product moderation.
- Payment gateways, transfer proofs, payment verification queues, refunds, and
  payment-method choice other than `cod_meetup`.
- Product update/delete, variant creation/editing, category/brand CRUD,
  address update/delete, and admin dashboard metrics; the PHP API has no P1
  route for these.
- iOS, web, Play Store publishing, release signing, push notifications,
  offline persistence, production monitoring, and new backend endpoints.

## Project Structure

Replace `lib/main.dart` with a minimal bootstrap that creates a root
`ProviderScope` and launches the app. Organize the app as follows:

```text
lib/
  app/
    app.dart                 # MaterialApp.router, themes, title
    router.dart              # guarded route tree and app shell
    theme.dart               # Material 3 light/dark themes
  core/
    config/                  # compile-time API configuration
    errors/                  # ApiException and error-to-message mapping
    network/                 # Dio factory, interceptor, response helpers
    session/                 # token store, session model, restore controller
  shared/
    formatters/              # peso, date/time, status-label helpers
    widgets/                 # loading, error, empty, submit, image widgets
  features/
    auth/
    catalog/
    addresses/
    cart/
    orders/
    reseller/
    admin/
```

Within each feature, keep API service/repository code, Dart models, providers,
and screens together. Widgets must call controllers/providers, never construct
Dio or issue network requests directly.

## Android and Configuration Requirements

1. Change the Android display label and application ID to the fixed values.
2. Add `android.permission.INTERNET` to the main Android manifest; debug-only
   permission is insufficient for a distributable demonstration build.
3. Do not enable cleartext traffic: the configured endpoint is HTTPS.
4. Define `API_BASE_URL` with `String.fromEnvironment`. Trim any trailing `/`
   before it reaches Dio.
5. Support normal invocation with the fallback URL and an override such as:
   `flutter run --dart-define=API_BASE_URL=https://example.invalid`.
6. Never commit tokens, account credentials, private test data, or a `.env`
   file. Build configuration contains no secret.

## Navigation and Access Control

Use a single adaptive shell. The shell must not briefly show protected content
while session restoration is loading.

| Audience | Navigation and access |
| --- | --- |
| Guest | Home, Browse, Account. Cart/order/address actions redirect to Login and retain the intended destination where practical. |
| Customer | Home, Browse, Cart, Orders, Account. Account includes reseller application entry when no approved reseller profile exists. |
| Pending/rejected/suspended reseller | Customer navigation plus application status; no reseller inventory/orders. |
| Approved reseller | Customer navigation plus `Reseller Center` in Account. |
| Admin | Customer navigation plus `Admin Console` in Account. |

Required top-level route groups:

- `/splash`, `/login`, `/register`, `/terms`, `/privacy`
- `/home`, `/catalog`, `/products/:id`
- `/cart`, `/addresses`, `/addresses/new`, `/checkout`, `/orders`,
  `/orders/:id`
- `/reseller/application`, `/reseller/center`, `/reseller/products`,
  `/reseller/products/new`, `/reseller/orders`, `/reseller/orders/:id`
- `/admin`, `/admin/reseller-applications`, `/admin/products/new`,
  `/admin/orders`

Use redirects based on the restored session's user role and reseller profile
status. Define `/` as a redirect to `/splash`; `/splash` restores the session
and then replaces itself with `/home` or `/login`. A login `from` query may be
used only when it matches an internal allowlisted protected route; discard all
external or malformed redirect values. Do not trust route guards for
authorization; the API response remains the final security decision.

## Networking and Authentication Contract

Every API response is treated as an envelope containing a `success` boolean
and usually `message`, `data`, `user`, `tokens`, or `order`. Repositories map
that envelope to typed models or throw a typed `ApiException`.

### Dio behavior

- Configure JSON `Accept` headers and use JSON `Content-Type` only for JSON
  requests. Multipart image uploads must use Dio `FormData` and let Dio set the
  multipart boundary.
- Use 15-second connect, send, and receive timeouts.
- Attach `Authorization: Bearer <access token>` only after a valid token is
  loaded and never attach it to public routes unless harmless.
- When a protected request returns 401, start or await one shared refresh
  operation using `POST /auth/refresh` and `{ "refresh_token": "..." }`.
- Save the rotated access and refresh tokens before replaying the original
  request exactly once.
- Do not refresh `/auth/login`, `/auth/register`, `/auth/refresh`, or a replay
  attempt. A failing refresh clears session storage and routes to Login.
- During debug builds, log method, path, status, and safe error metadata only;
  redact password, tokens, authorization headers, and image body contents.

### Error mapping

| Condition | UI behavior |
| --- | --- |
| No network, timeout, DNS, TLS failure | Show a retryable connection message; keep current content where possible. |
| 401 after failed refresh | Clear session and show Login with a session-expired message. |
| 403 | Show a permission message and return to an allowed destination. |
| 404 | Show not-found/unavailable state; product/order actions return to their list. |
| 422 | Show the server `message` as a form/action-level error; do not discard form entries. |
| Other server/invalid response | Show a generic retryable error without exposing stack traces. |

### Session endpoints

| Operation | API contract | Client behavior |
| --- | --- | --- |
| Register | `POST /auth/register`: `full_name`, `email`, optional `phone_number`, `password`, `terms_version`, `privacy_version` | Validate locally, submit consent versions, save returned tokens/session, then route to Home. |
| Login | `POST /auth/login`: `email`, `password` | Save returned tokens/user; load `/me` before applying role navigation. |
| Restore | `GET /me` with bearer token | Restore `user`, reseller profile status, and store name; failure follows refresh/logout policy. |
| Refresh | `POST /auth/refresh`: `refresh_token` | Internal interceptor operation only. |
| Logout | `POST /auth/logout`: `refresh_token` | Attempt remotely, then clear storage whether online or offline. |

## Buyer P1

### Registration and login

- Registration fields: full name, email, optional phone number, password,
  confirm password, Terms consent, Privacy consent.
- Enforce a non-empty name, valid email, eight-character password with a
  number, matching confirmation, and both consent checkboxes before submit.
- In-app Terms/Privacy pages are short, read-only P1 policy summaries. No
  OTP, password reset, social sign-in, or profile edit UI exists in P1.
- Login presents generic server failures exactly as returned; do not reveal
  whether an account exists.

### Catalog

| Feature | Endpoint and behavior |
| --- | --- |
| Categories | `GET /categories`; show category cards and apply `category_id` to product list. |
| Brands | `GET /brands`; show brand chips. The existing server does not filter by brand, so filter the current up-to-100 product response in memory by `brand_id`. |
| Products | `GET /products?q=&category_id=`; debounce search input, refresh on submitted query/category, and show grid cards with image, name, price, stock, seller, and condition. |
| Detail | `GET /products/:id`; show ordered image gallery, category/brand, seller, description, variants, stock, and quantity. |

- Use `cached_network_image` with a placeholder and error fallback for every
  product image.
- If variants exist, force an in-stock variant selection before adding to cart.
- Quantity starts at one and cannot exceed selected variant stock, otherwise
  product stock. The server remains the stock authority.
- Guests may view detail; Add to Cart redirects them to Login.

### Addresses, cart, checkout, and order history

| Feature | Endpoint and behavior |
| --- | --- |
| Address list | `GET /addresses`; list saved addresses ordered with the default first. |
| Add address | `POST /addresses`; collect recipient name, phone, street, optional barangay/zip, city, province, and default switch. |
| Cart | `GET /cart`, `POST /cart/items`, `PATCH /cart/items/:id`, `DELETE /cart/items/:id`; group visual rows as official/reseller and refresh after mutations. |
| Checkout | `POST /orders`; send `payment_method: "cod_meetup"`, optional `address_id`, and `notes`. |
| Orders | `GET /orders`, `GET /orders/:id`; show one order with independently tracked seller groups. |
| Buyer actions | `POST /order-groups/:id/cancel` for pending groups only; `POST /order-groups/:id/received` only when shipped or ready for meet-up. |

Checkout UX is fixed:

1. The user chooses **Delivery** or **Meet-up**.
2. Delivery requires selecting a saved address and may include optional notes.
3. Meet-up sends no `address_id`; location/contact instructions in `notes` are
   required and clearly labeled as agreed meet-up details.
4. The order-review screen shows seller grouping, subtotal, shipping (as
   returned by server), total, and `COD / Meet-up` only.
5. On success, clear/invalidate cart state, show returned order number and
   totals, then route to that order detail.

Do not add an address edit/delete UI because no endpoint supports it. Do not
claim a payment is paid: COD remains unpaid until server-side fulfillment
workflows record otherwise.

The cart endpoint does not return reseller/store names. Use `Official Store`
only for a null `seller_id`; label all other groups `Reseller order` rather
than fabricating a seller name.

## Reseller P1

### Application and access

- `POST /reseller/apply` sends `store_name`, `store_description`,
  `contact_number`, and `document_url`.
- `GET /reseller/application` drives the application status screen.
- Pending, rejected, and suspended accounts remain buyer accounts and see an
  explanatory status/rejection reason. Only `approved` opens Reseller Center.

### Inventory and images

- `GET /reseller/products` lists only products owned by the current approved
  reseller.
- `POST /reseller/products` creates a product with `name`, `category_id`,
  optional `brand_id`, `description`, `base_price`, `stock_quantity`, and
  `condition` (`new` or `used`).
- After product creation succeeds, open an optional image-upload step. Pick
  gallery images, validate each is at most 5 MB and is JPEG, PNG, or WebP, and upload sequentially to
  `POST /upload/product-image` as multipart fields `image`, `product_id`, and
  an increasing `sort_order` starting at zero.
- Continue after an individual image fails; show which upload failed and offer
  a retry. Refresh reseller products when the step finishes.
- Do not offer product editing, deletion, variants, compatibility assignment,
  or store settings.

### Fulfillment

- `GET /reseller/orders` loads only order groups assigned to the reseller.
- `PATCH /reseller/order-groups/:id` accepts `status` and optional
  `tracking_number`.
- Offer only valid next actions from the current status:
  - `pending`: confirmed, cancelled
  - `confirmed`: to_ship, ready_for_meetup, cancelled
  - `to_ship`: shipped, cancelled
  - `ready_for_meetup`: completed, cancelled
  - `shipped`: completed
- When selecting `shipped`, require a tracking number in the UI even though
  the server treats it as optional. Explain any API rejection without losing
  the current order view.

## Admin P1

### Reseller applications

- `GET /admin/reseller-applications` shows application, applicant, store, and
  status information.
- `PATCH /admin/reseller-applications/:id` accepts `approved`, `rejected`, or
  `suspended`, plus `reason` where applicable.
- Require a non-empty reason for rejection. Use a confirmation dialog for all
  privileged decisions and refresh the list on success.

### Official catalog and orders

- `POST /admin/products` creates official products using name, category,
  optional brand, description, base price, and stock quantity.
- Use the public product list to display active official products
  (`seller_id == null`) for P1 viewing only. It cannot show newly created
  zero-stock or non-active official products without an admin list endpoint.
  Do not imply edit/delete or category/brand management.
- `GET /admin/orders` displays all orders with buyer, order number, totals,
  payment state, notes, and creation date. It has no group or fulfillment data.
- `PATCH /admin/order-groups/:id` requires a `status` and a non-empty `reason`,
  but do not render an operational override action until an admin read endpoint
  provides group IDs. See **Verified API Constraints and One P1 Blocker**.
- After an official product is created, use the same optional image-upload
  sequence available to admins through `POST /upload/product-image`.

## UI State and Accessibility Requirements

- Each remote screen has an initial loading state, pull-to-refresh where a
  list is displayed, empty state, retry action, and readable error state.
- Disable submit buttons only while that specific request is in flight; keep
  form values following a validation or network error.
- Use `Semantics` labels for icon-only controls, visible text for destructive
  actions, at least 48dp touch targets, and error text associated with inputs.
- Format status values for people (`ready_for_meetup` → `Ready for meet-up`)
  without changing the API value.
- Use confirmation dialogs for cart item removal, buyer cancellation, receipt
  confirmation, reseller status updates, admin application decisions, and
  admin order overrides.

## State Refresh and Data Normalization Rules

- Parse server timestamps as UTC, then render them in device-local time.
- Normalize SQL JSON values defensively: IDs and stock as integers, prices as
  decimals, `is_default` as boolean, and nullable `seller_id`, `brand_id`,
  image URLs, variant IDs, and tracking values as nullable model fields.
- After cart mutations, invalidate cart plus the relevant product detail and
  product-list providers so stock/cart badges refresh.
- After checkout, invalidate cart, order list, and affected product providers.
- After buyer cancellation/receipt, invalidate order list and current order
  detail.
- After reseller application submission, refresh session and reseller-profile
  state. After reseller product/image/status mutations, refresh reseller lists
  and any affected public catalog/detail state.
- After admin reseller decisions or official-product creation/image upload,
  refresh the affected admin list and session/profile state when appropriate.
- Never display stale optimistic status as final truth; wait for successful API
  response, then reload the affected server-backed provider.

## Implementation Sequence and Exit Gates

### Phase A — Foundation

Implement app identity, dependencies, configuration, Material 3 theme, shared
states/widgets, Dio, secure token storage, session restore, routing, and role
guards. Begin with manual `GET /health`, `GET /categories`, and `GET /products`
checks against the configured URL; retain the dart-define override if the live
host is unavailable from the implementation environment.

**Exit gate:** App launches on Android, calls `/health` or catalog data through
Dio, restores a saved session, protects routes, and handles refresh/logout.

### Phase B — Authentication and catalog

Implement consent pages, registration/login, catalog list, search, category and
client-side brand filtering, product detail, variants, and guest redirects.

**Exit gate:** A disposable user can register/login and browse live seeded data
through all catalog screens.

### Phase C — Buyer transaction flow

Implement addresses, cart mutations, checkout modes, confirmation, order list,
order detail/timelines, cancellation, and receipt confirmation.

**Exit gate:** A buyer completes one delivery and one meet-up COD order and
sees seller-group-specific status behavior.

### Phase D — Reseller flow

Implement application, approval-aware access, own inventory creation, image
upload, own order-group summary/action screen, and status transitions.

**Exit gate:** An approved reseller creates a product with an image and updates
only a group assigned to that reseller.

### Phase E — Admin flow

Implement application decisions, official product creation with optional image
upload, and all-orders list. Document and surface the group-ID API blocker;
implement a reasoned group override only after the required admin read endpoint
is supplied and verified.

**Exit gate:** An admin approves a reseller, creates an official product, and
records a status override with a reason.

### Phase F — Regression and demo

Run automated tests and the complete three-account manual script below. Fix
defects before handing off a demo build.

**Exit gate:** All tests pass, all listed regression scenarios pass on the
actual presentation emulator/device, and the app contains no starter counter
UI or inaccessible P1 dead ends.

## Required Tests

### Unit and repository tests

- API response/error mapping: 401, 403, 404, 422, timeout, network failure,
  malformed body, and generic 5xx; normalize nullable SQL JSON fields and
  numeric/string/bool representations for IDs, price, stock, and `is_default`.
- Auth interceptor: bearer attachment, one shared refresh, rotated-token save,
  successful original-request replay, and clearing session after refresh fails.
- Router guards: guest, customer, pending reseller, approved reseller, and
  administrator.
- Registration, address, product, checkout, image multipart, and admin-override
  payload mapping.
- Client validation: password/confirmation/consent, stock quantity, meet-up
  notes, image size/type, reseller shipping tracking number, and admin reason.

### Widget tests

- Login and registration validation/errors/loading state.
- Catalog loading/empty/error/product card state.
- Cart stock error and remove confirmation.
- Delivery address requirement and meet-up notes requirement.
- Product-image upload progress/failure retry display and unsupported MIME type.
- Reseller allowed-next-status controls.
- Admin reject/override reason requirements.

### Manual three-account regression

1. Create or reset disposable buyer, reseller, and admin accounts.
2. Verify health, categories, brands, products, product details, login, and
   protected profile requests in Postman before app testing.
3. Register/login buyer, restore session after restart, refresh session, and
   log out.
4. Browse products, select an in-stock variant, add/update/remove cart items,
   and confirm stock validation.
5. Create an address and make a delivery COD order; make a separate meet-up
   COD order with notes.
6. View order list/details, cancel a pending group, and confirm a shipped or
   ready-for-meet-up group was received.
7. Submit reseller application, approve it with admin, create a reseller
   product, upload an image, and update an assigned group.
8. Create an official product as admin, upload its image, and list all orders.
   Attempt the override only after the required admin group-read endpoint has
   been added and verified; otherwise record the blocker as expected evidence.
9. Test no network, token expiration, permission denial, server validation,
   missing image, and empty list states.
10. Keep Postman request/result evidence and perform one uninterrupted demo
    dry run on the target Android device/emulator.

## Final Implementation Deliverables

- Functional Flutter P1 source replacing the starter app.
- Updated `pubspec.yaml`, Android application identity, and required manifest
  permission.
- Focused unit/widget/repository tests replacing the starter counter test.
- A concise `README.md` update covering API configuration, run command, test
  command, and P1 scope limits.
- No backend modifications, no committed credentials/tokens, and no generated
  build output added to source control.
