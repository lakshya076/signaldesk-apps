# SignalDesk Apps

[![CI](https://github.com/lakshya076/signaldesk-apps/actions/workflows/ci.yml/badge.svg)](https://github.com/lakshya076/signaldesk-apps/actions/workflows/ci.yml)

Flutter clients for **SignalDesk**, a stock-advisory platform for the Indian market (NSE equities). Advisors publish trade signals with an entry, target and stop loss; subscribers follow those trades with live prices; admins approve advisors and watch platform statistics.

The backend and market-data worker live in [signaldesk-server](https://github.com/lakshya076/signaldesk-server).

## The apps

| Folder | Who uses it | What it does |
|---|---|---|
| `advisor/` | Advisors | Watchlist with stock search and price alerts; create Buy or Sell trade cards at the live price; follow open trades with live profit and loss and close them manually; review closed trades and performance stats. Prices and trades are cached on the device |
| `user/` | Subscribers | Browse and search advisors and subscribe to them; follow your advisors' open trades with live prices, progress to target and risk-reward; review closed trades; light and dark theme |
| `admin/` | Admins | Dashboard of users, advisors, subscriptions, trade outcomes, top advisors and most-traded stocks; approve pending advisors |

Each app signs in with Supabase Auth and only lets in accounts with its role. Data comes from Supabase (Postgres plus realtime updates) and the SignalDesk backend (REST). Live prices stream over a WebSocket from the backend (`/ws/prices`), which reconnects on its own and re-subscribes to the stocks on screen.

## Live prices: Dhan then, simulated feed now

Prices originally came from the [Dhan](https://dhanhq.co) NSE market feed. **The project no longer has a Dhan API key**, so the server now runs on a simulated feed in the same format. The apps don't change either way: they receive the same WebSocket messages, only the prices are simulated. See the [server README](https://github.com/lakshya076/signaldesk-server#market-data-dhan-then-simulated-feed-now) for details.

## Tech stack

Flutter (Dart), Supabase (`supabase_flutter`), `web_socket_channel`, `provider` for state, `shared_preferences` for the advisor app's cache.

## Run

Needs Flutter (CI uses 3.47.8) and a running [signaldesk-server](https://github.com/lakshya076/signaldesk-server) backend.

```bash
cd user                      # or advisor / admin
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

`API_BASE_URL` defaults to `http://localhost:8000`. From the Android emulator use `http://10.0.2.2:8000`. For a deployed backend pass its `https://` address; the WebSocket address (`wss://…/ws/prices`) is derived from it.

## Tests and CI

`.github/workflows/ci.yml` runs on every push and pull request, separately for each app: `flutter analyze`, `flutter test`, and a release web build.

The tests cover the backend-address config and the trade math the cards show (live return, estimated gain and risk, risk-reward, progress to target) for both Buy and Sell trades. Run them with `flutter test` in an app folder.
