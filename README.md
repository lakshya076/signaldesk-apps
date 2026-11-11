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

## Run the whole system

SignalDesk is two repos: [signaldesk-server](https://github.com/lakshya076/signaldesk-server) (backend + market-data worker) and [signaldesk-apps](https://github.com/lakshya076/signaldesk-apps) (Flutter apps). Clone both side by side. You need Python 3.12, Docker (for Redis), Flutter 3.47 or newer, and a Supabase project.

Start things in this order: Supabase (once), Redis, backend, worker, then any of the apps.

### 1. Supabase (once)

1. Create a project at [supabase.com](https://supabase.com).
2. In the SQL editor, run `signaldesk-server/supabase/schema.sql`, then each file in `signaldesk-server/supabase/migrations/` in name order.
3. From **Project Settings → API keys**, copy the project URL, the publishable key and the secret (service role) key.
4. Create `signaldesk-server/backend/.env`:

   ```
   URL=https://<project-ref>.supabase.co
   SERVICE_KEY=<secret key>
   ANON_KEY=<publishable key>
   ```

   The secret key bypasses row level security, so keep it on the server; `.env` is gitignored.

### 2. Redis, backend and worker

Use one terminal per long-running command.

**Linux / macOS (bash)**

```bash
# Terminal 1: Redis, then the backend
docker run -d --rm --name redis -p 6379:6379 redis:7-alpine
cd signaldesk-server/backend
python3.12 -m venv .venv
.venv/bin/pip install -r requirements.txt pytest
.venv/bin/uvicorn main:app --port 8000

# Terminal 2: market-data worker on the simulated feed
cd signaldesk-server/redis-worker
python3.12 -m venv .venv
.venv/bin/pip install -r requirements.txt
FEED_MODE=mock MOCK_TICKS_PER_SEC=50 .venv/bin/python dhan_worker.py

# Check: should print "status":"healthy"
curl localhost:8000/health
```

**Windows (PowerShell)**

```powershell
# Window 1: Redis, then the backend
docker run -d --rm --name redis -p 6379:6379 redis:7-alpine
cd signaldesk-server\backend
py -3.12 -m venv .venv
.venv\Scripts\python -m pip install -r requirements.txt pytest
.venv\Scripts\python -m uvicorn main:app --port 8000

# Window 2: market-data worker on the simulated feed
cd signaldesk-server\redis-worker
py -3.12 -m venv .venv
.venv\Scripts\python -m pip install -r requirements.txt
$env:FEED_MODE = "mock"; $env:MOCK_TICKS_PER_SEC = "50"
.venv\Scripts\python dhan_worker.py

# Check: should print "status":"healthy" (curl.exe, because "curl" is a different command in Windows PowerShell)
curl.exe localhost:8000/health
```

Use Python 3.12: some dependencies (pandas) may not ship packages for newer versions yet. If `py` isn't available, `uv venv -p 3.12 .venv` works too. Calling `.venv\Scripts\python` directly avoids PowerShell's script-execution policy blocking `Activate.ps1`.

`MOCK_TICKS_PER_SEC=50` feels like a real market in the apps; raise it (for example to 500) for load testing.

### 3. The apps

```bash
cd signaldesk-apps/user          # or advisor / admin  (Windows: cd signaldesk-apps\user)
flutter pub get
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:8000
```

- Device: `-d windows`, `-d linux`, `-d macos` for a desktop app, `-d chrome` for the browser (no extra setup), or a connected phone or emulator. Desktop builds need the platform toolchain (on Windows, Visual Studio's "Desktop development with C++"); `flutter doctor` shows what's missing.
- Android emulator: use `API_BASE_URL=http://10.0.2.2:8000` (the emulator's address for your computer).
- Your own Supabase project: add `--dart-define=SUPABASE_URL=https://<project-ref>.supabase.co --dart-define=SUPABASE_ANON_KEY=<publishable key>`.
- Run several apps at once by starting each from its own terminal.

### 4. Accounts

1. Sign up in the **advisor** app and in the **user** app (confirm the email if your Supabase project requires it).
2. There is no admin sign-up, on purpose. Sign up any account, then in the Supabase table editor set its `role` in `profiles` to `admin`.
3. Sign in to the **admin** app and approve the advisor. Advisors can't create trades until approved.
4. In the **user** app, subscribe to the advisor to see their trades.

### 5. Market hours

The backend treats the market as open Monday to Friday, 9:15 to 15:30 IST (NSE hours), and only allows creating trades then. Outside those hours, adding a stock to the watchlist asks Dhan for the last prices, which needs Dhan credentials; without them that step fails. Test the trading flows during market hours.

### 6. Tests and benchmark

```bash
# Backend tests (Redis must be running). Windows: .venv\Scripts\python -m pytest test_rate_limit.py
cd signaldesk-server/backend && .venv/bin/pytest test_rate_limit.py

# Latency benchmark (backend and worker running). Windows: backend\.venv\Scripts\python bench\ws_latency.py ...
cd signaldesk-server && backend/.venv/bin/python bench/ws_latency.py --symbols 200 --clients 10 --seconds 30

# App tests, in each of advisor/, user/, admin/
cd signaldesk-apps/user && flutter test
```

Stop everything with Ctrl+C in each terminal, then `docker stop redis`.

## Tests and CI

`.github/workflows/ci.yml` runs on every push and pull request, separately for each app: `flutter analyze`, `flutter test`, and a release web build.

The tests cover the backend-address config and the trade math the cards show (live return, estimated gain and risk, risk-reward, progress to target) for both Buy and Sell trades. Run them with `flutter test` in an app folder.
