# Phone Accessories Marketplace (P1 Flutter client)

Android-first demonstration app for a phone-accessories marketplace with
buyers, approved resellers, and administrators. This is a school demonstration
build that uses disposable test data only; it is not a production release.

## API configuration

The app talks to a PHP backend through a Dio client.

Currency estimates use a separate public Frankfurter client:
`GET https://api.frankfurter.dev/v2/rate/PHP/USD` and
`GET https://api.frankfurter.dev/v2/rate/PHP/EUR`.
The rate date is displayed on product details; checkout stays in pesos.

- Development fallback base URL: `http://wbenogsudan.duckdns.org`
- Override at run time with `--dart-define=API_BASE_URL=...` (trailing `/` is
  trimmed automatically). Nothing is committed to source control.

## Run

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://wbenogsudan.duckdns.org
```

For a local browser preview, run `flutter run -d chrome` from this
directory. Sign-in and catalog browsing work in the browser; product image
upload remains an Android workflow. The PHP API permits `http://localhost:<port>` and
`http://127.0.0.1:<port>` browser origins. A hosted web build needs HTTPS for
the API and its exact web origin in `allowed_origins`.

> This school-demo build permits cleartext HTTP only to
> `wbenogsudan.duckdns.org`; do not reuse this configuration for a public or
> production deployment. Access/refresh tokens live only in the OS secure
> storage on the device.

## Test

```bash
flutter analyze
flutter test
```

The automated suite covers model normalization, core screens, and currency
response parsing. The CRUD walkthrough requires a configured backend and an
Android device or emulator with test accounts.

## Demo notes (three-account script)

1. Sign up / sign in a buyer, restore the session after restart, and log out.
2. Browse products, add/update/remove cart items (stock is validated), then
   place one Delivery COD order and one Meet-up COD order with notes.
3. View order list/detail, cancel a pending group, confirm receipt.
4. Submit a reseller application, approve it as admin, create a reseller
   product and upload an image, then update an assigned group.
5. As admin: create an official product, upload its image, and list all orders.
6. In either product management list, create a disposable product, view its detail,
   edit its fields, then confirm Delete. Products with order history are archived.
   Open a product detail to fetch the live Frankfurter rate and dated USD/EUR estimates.
7. Verify no-network, token-expiry, permission-denied, and validation states.

## P1 scope limits

- Delivery/meet-up are client presentation choices; checkout only stores an
  optional `address_id` and free-text `notes`. After reload, a non-null
  `address_id` is just a delivery heuristic.
- Cart lines are grouped as `Official Store` (null `seller_id`) or `Reseller
  order`; no seller name is fabricated.
- Reseller order screens show only assigned group summaries (the API returns no
  item-level detail for resellers).
- **Known backend blocker:** `GET /admin/orders` returns order and buyer fields
  only, with no `order_groups`/group IDs. The admin reasoned order-group status
  override is therefore intentionally unavailable (no hard-coded group IDs) and
  will be enabled only after an authenticated admin group-read endpoint is
  supplied.
- Out of P1 scope: OTP/email verification, password reset, profile editing,
  chats/reviews/favorites, payment gateways, variant
  management, admin metrics, iOS/web, push notifications, and offline persistence.
