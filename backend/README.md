# Kelly Elektronik API

Laravel 12 API for the Flutter storefront. It uses PostgreSQL and Laravel
Sanctum bearer tokens.

## Local setup

Requirements: PHP 8.2+, Composer, PostgreSQL 14+, and the PHP `pdo_pgsql`
extension.

On XAMPP, check that `php_pgsql.dll` and `php_pdo_pgsql.dll` exist in
`C:\xampp\php\ext`, then enable `extension=pgsql` and
`extension=pdo_pgsql` in `C:\xampp\php\php.ini` and open a new terminal.

1. Create a PostgreSQL database named `kelly_elektronik`.
2. Copy `.env.example` to `.env` if `.env` does not exist. If Laravel already
   created `.env`, keep its `APP_KEY` and set `DB_CONNECTION=pgsql`,
   `DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USERNAME`, and `DB_PASSWORD` for
   your PostgreSQL installation.
3. Run:

   ```powershell
   composer install
   php artisan key:generate
   php artisan migrate --seed
   php artisan serve --host=0.0.0.0 --port=8000
   ```

The seed command adds sample categories/products, the local demo account
`demo@kelly.test` / `KellyDemo123!`, and one paid demo order with two items.
The order is created once and reserves one unit of each seeded product;
re-running the seed does not add another order, reserve more stock, or reset
existing product stock or demo account credentials. Change or remove the demo
account before deploying anywhere public.

To create a local admin, provide `ADMIN_EMAIL` and `ADMIN_PASSWORD` (at least
12 characters); `ADMIN_NAME` is optional and defaults to `Administrator`.
Set these process environment variables before `php artisan db:seed`. The
admin seeder skips creation unless email and password are provided, and leaves
an existing account (including its password and profile) unchanged. For
example, in PowerShell:

```powershell
$env:ADMIN_EMAIL = "admin@example.test"
$env:ADMIN_NAME = "Local Administrator"
$env:ADMIN_PASSWORD = Read-Host "Admin password"
php artisan db:seed
Remove-Item Env:ADMIN_PASSWORD, Env:ADMIN_EMAIL, Env:ADMIN_NAME
```

Use only a local-development credential, and clear the process environment
after seeding. Do not put admin credentials in `.env.example` or source
control.

## RajaOngkir shipping rates

Set `RAJAONGKIR_API_KEY` in the local `.env` file. Keep the key on the backend;
never add it to Flutter or commit it to source control. The application uses
RajaOngkir Komerce's direct-search endpoints to search Indonesian destinations
and calculate domestic shipping cost. The shipping origin search defaults to
`Tanjung Duren Selatan`; it resolves and caches the RajaOngkir destination ID
for Grogol Petamburan, Jakarta Barat. Override `RAJAONGKIR_ORIGIN_SEARCH` if the
warehouse address changes.

`RAJAONGKIR_COURIERS` is a comma-separated list of courier codes enabled for
the account, for example `jne,jnt,sicepat`. Update it to match the couriers
available in the RajaOngkir account. Products' `weight` values are sent as
grams. Checkout searches destinations across Indonesia, requests available
services for the selected courier, and the backend recalculates the selected
service before creating an order.

## Manual bank-transfer payments

Set `SHOP_BANK_NAME`, `SHOP_BANK_ACCOUNT_NAME`, and `SHOP_BANK_ACCOUNT_NUMBER`
in the local `backend/.env` file. Set them to the real store account before
accepting payments. To grant the admin screen to an existing account, update
that user's role in PostgreSQL, for example:

```sql
UPDATE users SET role = 'admin' WHERE email = 'admin@example.com';
```

These values are returned to authenticated
customers on the order detail screen; do not use placeholder account details
for real payments. Bank-transfer totals include a unique 1–999 rupiah code.
Customers can upload JPG/PNG proof images up to 5 MB. Admin accounts must have
`users.role=admin` to review submitted proofs from the Account screen.

Unpaid bank-transfer orders without a submitted proof, including rejected
proofs awaiting replacement, expire 24 hours after creation. Submitted proofs
remain available for admin review. Laravel's scheduler must run for automatic
expiration. For local development, start
`php artisan schedule:work` from `backend/`; on production, configure the
platform scheduler to run `php artisan schedule:run` every minute. Expiration
returns reserved product stock to inventory.

Keep the API and phone on the same trusted Wi-Fi for local testing. The Flutter
web app derives the API host from the page's host and uses port 8000. Android
emulators use `10.0.2.2`; for a physical Android device, pass the computer's
LAN address, for example:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.17:8000/api
```

CORS permits all origins for local development. Restrict
`config/cors.php` to the deployed app origins before exposing the API publicly.
Bank transfers are confirmed manually; the Midtrans Sandbox flow is described
below.

## Midtrans Snap Sandbox

Set `MIDTRANS_SERVER_KEY` and `MIDTRANS_CLIENT_KEY` in `backend/.env` using the
Sandbox keys from Midtrans MAP, and keep `MIDTRANS_IS_PRODUCTION=false`. The
server key is used only by Laravel. Checkout creates a `midtrans` order; the
order detail screen creates or reuses its Snap transaction and opens the
Midtrans-hosted payment page. Customers can select the available payment
methods there. The app can refresh the transaction status from Midtrans.
Set `APP_PAYMENT_RETURN_URL=http://localhost:3000/#/payment-return` in
`backend/.env`; new Snap transactions send this as their `callbacks.finish`
URL. Start Flutter Web at the matching stable port from the repository root:

```powershell
flutter run -d chrome --web-port 3000
```

The return route uses only the `order_id` query parameter to ask the
authenticated backend to check the transaction with Midtrans. It does not
trust the `transaction_status` query parameter. The backend verifies both
the returned order ID and gross amount before updating payment state.

In the Midtrans Sandbox dashboard, inspect **Settings → Snap Preferences →
Finish Redirect URL**. If it contains a stale URL such as `example.com`,
update it manually to `http://localhost:3000/#/payment-return` and save it.
The application cannot change dashboard settings; keep that setting and the
per-transaction `callbacks.finish` URL in sync.

Configure the Midtrans **Payment Notification URL** to
`https://<public-api-host>/api/payments/midtrans/notification`. The notification
route verifies Midtrans' signature and the order amount before changing an
order to paid. Midtrans cannot send notifications to `localhost`; for local
testing, expose the API through a secure temporary tunnel and use that public
HTTPS URL. A verified settlement (or accepted card capture) marks the order
paid and starts processing. Keep the account in Sandbox until the complete
payment and notification flow has been tested. Only switch
`MIDTRANS_IS_PRODUCTION=true` and use Production keys when the merchant account
is approved and the application is ready for real payments.

## API

All responses are JSON. Protected routes require
`Authorization: Bearer <token>`.

| Method | Endpoint | Access | Purpose |
| --- | --- | --- | --- |
| POST | `/api/register` | Public | Create customer and return token |
| POST | `/api/login` | Public | Authenticate and return token |
| GET | `/api/me` | Token | Current customer |
| POST | `/api/logout` | Token | Revoke current token |
| GET | `/api/categories` | Public | List categories |
| GET | `/api/products` | Public | Search/filter products |
| GET | `/api/products/{id}` | Public | Product detail |
| GET/POST | `/api/cart` | Token | Read/add cart items |
| PUT/DELETE | `/api/cart/{id}` | Token | Change/remove cart item |
| GET | `/api/shipping/destinations?search=...` | Token | Search domestic destinations |
| GET | `/api/shipping/couriers` | Token | List enabled couriers |
| POST | `/api/shipping/quotes` | Token | Calculate current cart shipping rates |
| GET/POST | `/api/orders` | Token | Order history/create checkout order |
| GET | `/api/payments/midtrans/return-status?order_id={midtrans_order_id}` | Token | Verify a Snap finish return with Midtrans and refresh the order |
| GET | `/api/payment-details` | Token | Store bank-transfer account details |
| POST | `/api/orders/{id}/payment-proof` | Owner | Upload JPG/PNG transfer proof (max 5 MB) |
| GET | `/api/orders/{id}/payment-proof` | Owner/Admin | View uploaded transfer proof |
| GET | `/api/admin/orders/pending-confirmation` | Admin | List transfer proofs awaiting review |
| POST | `/api/admin/orders/{id}/confirm-payment` | Admin | Confirm payment and start processing |
| POST | `/api/admin/orders/{id}/reject-payment` | Admin | Reject proof with a reason |
| GET | `/api/orders/{id}` | Token | Order detail |
| GET | `/api/admin/dashboard` | Admin | Sales, orders, users, low stock, recent orders and sales series |
| GET/POST | `/api/admin/products` | Admin | Search, filter, paginate and create products |
| GET/PUT/PATCH/DELETE | `/api/admin/products/{id}` | Admin | Read, edit, deactivate or safely remove a product |
| GET/POST | `/api/admin/categories` | Admin | List and create categories |
| PUT/PATCH/DELETE | `/api/admin/categories/{id}` | Admin | Edit or remove an unused category |
| GET/POST | `/api/admin/orders` | Admin | Filter orders and create a manual order |
| GET/PATCH/DELETE | `/api/admin/orders/{id}` | Admin | Order detail, status/tracking/notes changes and safe cancellation/deletion |
| GET | `/api/admin/payments` | Admin | Filter bank-transfer payments |
| GET/POST | `/api/admin/users` | Admin | Search/list and create users |
| GET/PUT/PATCH/DELETE | `/api/admin/users/{id}` | Admin | User detail, profile/role/password/status management and safe deletion |

Run the feature tests with `php artisan test`. Tests use an in-memory SQLite
database; `.env.example` configures the application runtime for PostgreSQL.
