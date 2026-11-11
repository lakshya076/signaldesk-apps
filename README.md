# SignalDesk Apps

Flutter clients for SignalDesk, a stock-advisory platform. The backend and market-data worker live in [signaldesk-server](https://github.com/lakshya076/signaldesk-server).

| Folder | App |
|---|---|
| `advisor/` | Advisors: watchlist, create and close trade cards, performance stats |
| `user/` | Subscribers: follow advisors, track open and closed trades with live prices |
| `admin/` | Admins: approve advisors, view platform statistics |

Sign-in and data go through Supabase. Live prices arrive over a WebSocket from the backend (`/ws/prices`).

## Run

Needs Flutter and a running [signaldesk-server](https://github.com/lakshya076/signaldesk-server) backend.

```bash
cd user   # or advisor / admin
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

`API_BASE_URL` defaults to `http://localhost:8000`. From the Android emulator use `http://10.0.2.2:8000`; for a deployed backend pass its `https://` URL (the WebSocket URL is derived from it).
