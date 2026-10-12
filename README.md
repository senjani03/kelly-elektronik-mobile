# Kelly Elektronik - Mobile (Flutter)

The Flutter app and its Laravel API are in this repository. See
[backend/README.md](./backend/README.md) for PostgreSQL and API setup.
See [CONFIGURATION.md](./CONFIGURATION.md) for the complete local setup,
credential configuration, dependency installation, and Flutter API URL guide.

## Run the API

From `backend/`, start PostgreSQL, migrate/seed, then run
`php artisan serve --host=0.0.0.0 --port=8000`.

## Run the Flutter app

Run `flutter pub get`, then start the web app on its stable local port with
`flutter run -d chrome --web-port 3000`. The app uses the API on the same host
at port 8000. Android emulators use `10.0.2.2`; physical Android devices need
the computer's LAN IP via `--dart-define=API_BASE_URL=...`.

Midtrans Sandbox returns the browser to
`http://localhost:3000/#/payment-return`. The return screen sends only the
Midtrans `order_id` to the authenticated backend; payment status is fetched
from Midtrans by the backend and checked against the stored order ID and
amount.

Android payment returns are not wired yet. They will require an Android
App Link/deep link (including an intent filter and a reachable HTTPS domain)
or a Custom Tabs flow that hands the finish URL back to the app; no Android
deep-link configuration has been added.

The Android manifest permits internet access and cleartext HTTP for local
development. Use HTTPS and restrict CORS before deploying publicly.
