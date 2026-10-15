# MTD Buddy

A native SwiftUI app for Champaign-Urbana MTD buses, built around getting you to class on time:
live stops/routes, a Home-screen "leave in mm:ss" countdown for your next Bus class, automatic
leave-time notifications, and a Home Screen / Lock Screen widget + Live Activity.

## Requirements

- Xcode 16+ (this was built and verified against Xcode's iOS 17 SDK)
- A free Apple ID (Personal Team) for running on your iPhone from Xcode, or AltStore/SideStore
  for installing the unsigned `.ipa`
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) and [`ldid`](https://github.com/ProcursusTeam/ldid)
  — `scripts/generate.sh` installs XcodeGen via Homebrew automatically; `ldid` is only needed
  for `scripts/build_ipa.sh` (`brew install ldid`)
- An MTD Developer API key from https://developer.cumtd.com/
- A Google Cloud OAuth client ID (free) for Google Calendar sign-in — see "Google Calendar
  setup" below

The project is generated from `project.yml` rather than committing an `.xcodeproj` — this keeps
the two targets (app + widget extension) easy to review in a diff and avoids Xcode-project merge
conflicts. Run `scripts/generate.sh` (or just open the project once via Xcode after running it)
any time you add/remove files or change `project.yml`.

## Setup

1. Copy `Secrets.xcconfig.example` to `Secrets.xcconfig` and put your real MTD API key in it.
   This file is git-ignored; it's substituted into both targets' Info.plist as `MTD_API_KEY`.
2. Follow "Google Calendar setup" below and add `GOOGLE_CLIENT_ID`/`GOOGLE_REVERSED_CLIENT_ID`
   to the same `Secrets.xcconfig`.
3. Run `./scripts/generate.sh` to produce `MTDBuddy.xcodeproj`.
4. Open `MTDBuddy.xcodeproj` in Xcode.

## Google Calendar setup

The Classes tab reads your classes from Google Calendar (read-only) instead of the device's
Apple Calendar. This needs an OAuth client you create yourself — it's free, takes a few minutes,
and there's no backend server involved (the app talks to Google directly using the Authorization
Code + PKCE flow for installed apps, via `ASWebAuthenticationSession` — no GoogleSignIn SDK
dependency).

1. Go to [Google Cloud Console](https://console.cloud.google.com/) and create a project (or use
   an existing one).
2. **APIs & Services → Library** → enable the **Google Calendar API**.
3. **APIs & Services → OAuth consent screen** → External → fill in the required fields (app
   name, your email). Leave it in **Testing** status — add your own Google account under **Test
   users** so you can sign in without Google's app-verification review (that review is only
   needed to publish to the public; for your own personal use, Testing mode is permanent and
   fine).
4. **APIs & Services → Credentials → Create Credentials → OAuth client ID**.
   - Application type: **iOS**
   - Bundle ID: `com.rexlan.mtdbuddy`
5. Copy the generated Client ID (looks like `123456-abc.apps.googleusercontent.com`) into
   `Secrets.xcconfig` as `GOOGLE_CLIENT_ID`.
6. Set `GOOGLE_REVERSED_CLIENT_ID` to the same value with its dot-segments reversed — e.g.
   `123456-abc.apps.googleusercontent.com` becomes `com.googleusercontent.apps.123456-abc`. This
   becomes the custom URL scheme iOS uses to hand the OAuth redirect back to the app
   (`project.yml` registers it as `CFBundleURLTypes`); it must match exactly or sign-in will
   silently fail to return to the app.
7. Re-run `./scripts/generate.sh` so the new Info.plist values take effect.

Sign-in happens from Settings or the Classes tab ("Connect Google Calendar"), opens a system
browser sheet (shares cookies with Safari, so if you're already signed into Google there it's
one tap), and stores only a refresh token in the Keychain (`MTDBuddy/Services/KeychainStore.swift`)
— access tokens are kept in memory and refreshed on demand. Scope is
`calendar.readonly`; the app never writes to your calendar.

## Running on your iPhone (free Apple ID)

1. In Xcode, select the `MTDBuddy` target → Signing & Capabilities → set your team to your
   personal Apple ID ("Personal Team"). `project.yml` already sets `CODE_SIGN_STYLE: Automatic`
   so Xcode will manage provisioning itself.
2. Plug in your iPhone, select it as the run destination, and press Run.
3. This build expires after 7 days (a free-account limitation) — just re-run from Xcode to
   refresh it.

No paid-only capabilities are used anywhere in this project (no Push Notifications, iCloud,
Sign in with Apple, or Associated Domains) — only local notifications, CoreLocation, MapKit,
WidgetKit, ActivityKit, App Intents, BackgroundTasks, and a plain OAuth sign-in via
`ASWebAuthenticationSession` for Google Calendar (a system browser sheet + a custom URL scheme —
no entitlement needed), all of which work fine on a free Personal Team.

## Building the unsigned IPA for AltStore/SideStore

```bash
./scripts/build_ipa.sh
```

This regenerates the project, archives `Release` for `iphoneos` with `CODE_SIGNING_ALLOWED=NO`,
copies `MTDBuddy.app` into a `Payload/` folder, fake-signs the entitlements with `ldid` (so the
App Group entitlement survives AltStore's re-signing — without this step AltStore strips
entitlements it doesn't understand), and zips the result to `~/Desktop/MTDBuddy.ipa`. Install it
with AltStore/SideStore using your own Apple ID as usual.

If `ldid` isn't installed, the script still produces a working IPA — it just prints a warning,
since the app and widget are both written to work correctly even without the App Group (see
"Known MTD API issues" below, degradation is intentional, not a bug).

## Running in the Simulator

```bash
./scripts/build_simulator.sh
```

Builds for `generic/platform=iOS Simulator`. CoreLocation/notifications/Google sign-in all work
in the Simulator (grant permissions when prompted); Live Activities render in the Simulator too
as of recent Xcode versions.

## Project layout

- `Shared/` — code compiled into **both** the app and widget extension targets: API models,
  `MTDService` (the network layer), the on-disk cache, `UserSettings`/`BusClassConfig`/
  `TodayPlan` (persisted via the App Group), color/date helpers, and small shared SwiftUI views
  (`RouteBadge`, etc).
- `MTDBuddy/` — the app target: all four tab screens, onboarding, settings, Google Calendar
  OAuth/CoreLocation/notification/BGTask/Live-Activity managers, and the "Plan today's bus
  alerts" / "Next bus" App Intents.
- `MTDBuddyWidget/` — the widget extension target: the Home Screen + Lock Screen widget (one
  `WidgetConfiguration` across all six families), its `AppIntent`-based stop picker, and the
  Live Activity UI.

## Switching to MTD API v3

Every network call goes through the `MTDService` protocol (`Shared/Services/MTDService.swift`).
`MTDServiceV2` is the only conformer today. To move to v3 (https://mtd.dev):

1. Write `MTDServiceV3: MTDService` against the new base URL/auth scheme.
2. Swap the one line in `AppEnvironment.swift` (`let mtdService: MTDService = MTDServiceV2()`)
   to `MTDServiceV3()`.
3. Everything else — views, view models, the widget, the alert planner — is unaffected, since
   none of them reference `MTDServiceV2` directly.

## Beyond the original spec

A few additions made after comparing this app against what students actually complain about in
other campus transit apps (My Bus Helper: MTD reviews, Daily Illini/CU-CitizenAccess coverage of
MTD, and other schools' shuttle-tracker complaints — Harvard, UConn, Cal Poly Pomona, Troy,
Montclair State):

- **"Find stops near a place" (Stops tab, pin icon)** — a Google-Maps-style search: type an
  address, building, or landmark (`LocalSearchCompleter`, MapKit autocomplete scoped to
  Champaign-Urbana) and it calls MTD's own `GetStopsByLatLon` for that location instead of your
  current GPS position. This directly answers a recurring complaint (Troy University students
  couldn't find their pickup location in their transit app) and complements "Nearest to me",
  which only works for *your* current location, not a destination or a friend's address.
- **Proactive service-alert notifications** (`BusAlertPlanner.checkServiceAlerts`) — MTD's own
  site (mtd.org/UIUC) advertises route-specific service-change notifications as a feature riders
  want; this app already fetched reroute data for the Detours tab but never surfaced it
  proactively. It now checks for reroutes on any route serving your home/favorite/class stops
  and fires a one-time local notification the first time it sees a new one.
- **Honest empty states for Route Detail** (see "Known MTD API issues" below) — the single most
  common complaint across every campus transit app reviewed was "shows nothing" or "says it's
  wrong" with no explanation. When MTD's live feed has nothing to report, this app now says why
  instead of reading as broken.

**Found but not implemented — rider counts / overcrowding.** The single most specific complaint
across this research (UIUC students telling local news they'd stopped riding because buses were
too full to board; UConn students citing "rider counts" as a feature they valued in a better
app) is bus overcrowding. MTD's v2.2 API exposes no occupancy or capacity field anywhere in any
endpoint used here — confirmed by inspecting every real response captured while building this,
not assumed — so there's no live data this app could use to warn about it. Flagging this
honestly rather than faking a feature with no real signal behind it.

## Known MTD API issues (found while building this, not guessed)

All field names and JSON shapes in `Shared/Models/MTDModels.swift` were captured from live calls
made during development on **2026-10-14** with a real API key — not guessed from docs. Specific
findings:

- **`GetPlannedTripsByStops` and `GetPlannedTripsByLatLon` are currently broken.** Every call —
  different stop pairs, with and without `date`/`time`, JSON and XML — returned HTTP-body
  `status.code: 500` ("Internal server error"), including with no query params echoed back at
  all. This is MTD's server, not this app; there's nothing to fix on our end. Because the rest
  of the "Automatic alerts" feature depends on this for long-range planning, `BusAlertPlanner`
  (`MTDBuddy/Services/BusAlertPlanner.swift`) falls back to a single alert at class start − 25
  minutes whenever planning fails — which, right now, is every time. The real trip-planner call
  is still fully wired up behind `MTDService.getPlannedTripsByStops`, so alerts should start
  arriving on time automatically the moment MTD fixes their server — no app update needed.
  **Re-check**: `curl "https://developer.cumtd.com/api/v2.2/json/GetPlannedTripsByStops?key=YOUR_KEY&origin_stop_id=IU&destination_stop_id=PLAZA"` — if `status.code` is `200`, the feature should start working; sanity-check `MTDTripPlannerParser.firstBusLeg` in
  `Shared/Services/MTDTripPlanner.swift` against the real response shape you get back, since it
  was written defensively against prose docs (no literal example was ever available to test).
- **`GetReroutes`/`GetReroutesByRoute` returned zero active reroutes** the whole time this was
  built, so `MTDReroute.affectedRouteIds` (in `MTDModels.swift`) was written to decode either a
  list of route objects or a list of plain route-ID strings, since the docs describe the field
  but never show a live example either way. Worth re-verifying against a real reroute next time
  MTD has one active.
- Every other endpoint used (`GetRoutes`, `GetStops`, `GetStopsByLatLon`, `GetDeparturesByStop`,
  `GetVehiclesByRoute`, `GetStopTimesByTrip`) was verified against real responses and the models
  match exactly what MTD returns.
- **`GetVehiclesByRoute` legitimately returns an empty list for most routes most of the time** —
  confirmed by calling it directly: at 8pm on a Wednesday, the high-frequency Illini route had
  live buses but Gold/Brown/Green had none. This is MTD's real service pattern (many routes
  reduce or stop entirely outside peak hours), not a bug — Route Detail's "Live Buses" and
  "Stops in Order" sections now say so explicitly instead of reading as broken. There's no
  "stops for this route" endpoint in v2.2 independent of an active vehicle's trip, so "Stops in
  Order" is unavoidably empty whenever nothing is running on that route.

## Things I couldn't verify

- **Running on a physical iPhone from Xcode** — I don't have access to your iPhone from this
  environment. The project is set to `CODE_SIGN_STYLE: Automatic`, so plugging in your phone and
  pressing Run in Xcode should "just work" once you pick your Personal Team, but I haven't seen
  it happen. If Xcode complains about a missing provisioning profile, open Signing &
  Capabilities and re-select your team — that's the usual fix.
- **Live Activities and widgets on a real device** — verified these compile and the API usage is
  correct, but Live Activity rendering, Dynamic Island behavior, and widget refresh timing are
  only really trustworthy on-device, not in the Simulator.
- **AltStore/SideStore install + re-sign** — I built and fake-signed the `.ipa`, but installing
  it through AltStore and confirming the App Group entitlement actually survives the re-sign
  needs AltServer running on this Mac paired with your phone, which I can't drive from here.
- **The trip-planner response shape** — see "Known MTD API issues" above; this is a real
  external blocker, not something that can be resolved by writing more code.
- **The Google Calendar OAuth flow end-to-end** — I don't have a Google Cloud project or OAuth
  client ID, so I wrote `GoogleOAuthManager` against Google's documented PKCE flow for installed
  apps but couldn't actually sign in and confirm a token exchange works. Once you add your
  `GOOGLE_CLIENT_ID`/`GOOGLE_REVERSED_CLIENT_ID`, test "Connect Google Calendar" from Settings
  first — if it fails, the most likely causes are the Bundle ID not matching what you entered in
  Cloud Console, or `GOOGLE_REVERSED_CLIENT_ID` not exactly matching the reversed Client ID (see
  "Google Calendar setup" above).
- **The search field in "Find Stops Near a Place" and the stop pickers, specifically typing
  into them** — the Simulator automation available to me can reliably tap buttons (confirmed
  repeatedly — Cancel, row selection, etc. all work) but consistently failed to focus the
  `.searchable` text field itself in every sheet that has one, even after I found and fixed a
  real bug along the way (a `ContentUnavailableView` `.overlay` was eating taps meant for the
  field underneath it — now fixed with `.allowsHitTesting(false)`). This looks like a
  limitation of synthetic-touch text-field focus in this tool rather than an app bug — the
  underlying pieces are each independently verified (`MKLocalSearchCompleter` is standard
  MapKit API; `GetStopsByLatLon` was called successfully via curl earlier in this session; the
  Stops tab's own list search uses the same `.searchable` pattern). Please type into these
  fields on your device/the Simulator yourself as a first check.
