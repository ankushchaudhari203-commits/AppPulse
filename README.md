# AppPulse — macOS QE Dashboard

AppPulse is a native macOS dashboard built for QE teams to manage and run all aspects of software quality engineering from one place — functional testing, load testing, API health monitoring, AI-assisted test generation, reporting, and CI integration.

Built with SwiftUI for macOS 13+.

---

## Features

### Functional Tests
- Run Xcode test suites directly from the app using `xcodebuild`
- Import `.xcresult` files (drag & drop or file picker)
- View per-test-case results with pass/fail status and animated pass rate ring
- Live progress sheet with real-time output streaming and cancel support
- Search, rename, add notes, and delete test runs
- Export reports as PDF (⌘E)

### Performance Testing
**JMeter**
- Import `.jtl` result files and view Overview / Stats / Charts
- Run `.jmx` test plans headless from within the app
- Launch JMeter GUI directly
- Add notes to runs, rename, delete, export PDF

**Locust**
- Launch and configure Locust load tests without touching the terminal
- Live stats with Overview / Stats / Charts tabs
- Frozen run snapshots saved to history

**Quick Test** *(no .jmx file needed)*
- Enter a URL and hit Run — JMX generated automatically
- Supports HTTP (GET, POST, PUT, DELETE, PATCH) and WebSocket protocols
- Configure users, ramp-up time, and duration
- Authentication support: Bearer Token, API Key, Basic Auth, Custom Header
- Results automatically imported into the JMeter tab after each run

### API Health
- Monitor multiple endpoints with live sparkline charts
- Auto-refresh on a configurable interval (⌘R to refresh manually)
- Per-endpoint history (up to 200 events), persisted across launches
- Detail view with response time trends

### AI Test Generation
- Describe a feature and generate test cases using Google Gemini
- Export test cases as CSV
- Generate XCTest Swift code ready to copy into your Xcode project

### Reports
- Functional test pass rate trend charts across all runs
- JMeter throughput and error rate trend charts
- Side-by-side run comparison diff view
- Export as PDF (⌘P) or HTML

### CI Watch Folder
- Monitor a folder for new `.xcresult` and `.jtl` files
- Auto-imports new files as test runs — no manual step needed
- Remembers imported files across restarts to avoid duplicates

### Settings (⌘,)
- **General** — appearance, API health auto-refresh interval
- **AI / Gemini** — API key and model selection
- **Tools** — Xcode project path, scheme, destination, JMeter path, Locust defaults
- **CI Watch** — enable/disable, folder picker, import existing files
- **Notifications** — macOS alerts + Slack webhook with test message button
- **Data** — clear data, backup and restore

---

## Requirements

| Requirement | Version |
|---|---|
| macOS | 13.0 Ventura or later |
| Xcode | 15 or later |
| Python | 3.10+ (for Locust) |
| JMeter | 5.6.3 (see setup below) |

---

## Setup

### 1. Clone the repo
```bash
git clone https://github.com/ankushchaudhari203-commits/AppPulse.git
cd AppPulse
```

### 2. Set up JMeter (required for Performance tab)
JMeter is not included in the repository due to its size. Set it up manually:

1. Download **Apache JMeter 5.6.3** from [jmeter.apache.org](https://jmeter.apache.org/download_jmeter.cgi)
2. Extract and place the folder at:
   ```
   AppPulse/jmeter/
   ```
   So the binary is at `AppPulse/jmeter/bin/jmeter`

3. Install the **WebSocket Samplers plugin** (required for WebSocket load testing):
   - Download `jmeter-websocket-samplers-1.3.1.jar` from the [JMeter Plugins site](https://jmeter-plugins.org)
   - Place it at:
     ```
     AppPulse/jmeter/lib/ext/jmeter-websocket-samplers-1.3.1.jar
     ```

### 3. Set up Locust (required for Locust tab)
```bash
pip3 install locust
```

### 4. Configure Gemini API Key (required for AI Tests tab)
1. Get a free API key from [Google AI Studio](https://aistudio.google.com)
2. Open AppPulse → Settings (⌘,) → AI / Gemini
3. Paste your key and select a model

### 5. Open in Xcode and run
```bash
open AppPulse.xcodeproj
```
Press **⌘R** to build and run.

---

## First Launch

On first launch, AppPulse shows an onboarding flow covering all features. You can re-open it anytime via **Help → Show Onboarding… (⌘⇧O)**.

To run functional tests against another project:
1. Open **Settings → Tools**
2. Set the Xcode project path, scheme name, and destination
3. Go to **Functional Tests** and click **Run Tests**

---

## Project Structure

```
AppPulse/
├── AppPulseApp.swift           ← App entry point, Settings scene
├── ContentView.swift           ← Root TabView (6 tabs)
├── Views/
│   ├── OverviewView.swift      ← Dashboard with stat cards and trends
│   ├── FunctionalTestsView.swift
│   ├── PerformanceView.swift   ← JMeter + Locust + Quick Test
│   ├── APIHealthView.swift
│   ├── TestGeneratorView.swift ← AI test generation
│   ├── ReportsView.swift
│   ├── SettingsView.swift
│   ├── OnboardingView.swift
│   └── ...
├── Models/                     ← TestRun, JMeterRun, LocustRun, etc.
├── Services/
│   ├── AppStore.swift          ← Central state, persistence
│   ├── XcodeBuildRunner.swift  ← xcodebuild integration
│   ├── JMeterCLIRunner.swift   ← JMeter headless + JMX generation
│   ├── LocustService.swift
│   ├── APIHealthService.swift
│   ├── GeminiService.swift
│   ├── CIWatcherService.swift
│   ├── SlackNotifier.swift
│   ├── PDFExporter.swift
│   └── ...
└── XcodeFiles/                 ← Sample .jtl files for testing
```

---

## Tech Stack

- **SwiftUI** — native macOS UI
- **Swift Charts** — sparklines, trend charts, pass rate ring
- **xcodebuild** — runs Xcode test suites
- **Apache JMeter 5.6.3** — load testing engine
- **Locust** — Python-based load testing
- **Google Gemini API** — AI test case generation
- **Combine** — reactive state and JSON persistence

---

## Notes

- App Sandbox is disabled to allow running shell tools (xcodebuild, jmeter, locust)
- AppPulse cannot run UI tests against itself — use it to test other projects (e.g. a separate iOS app)
- JSON data files (`test_runs.json`, `jmeter_runs.json`, etc.) are excluded from the repo — they are generated at runtime and stored in `~/Library/Application Support/AppPulse/`

---

## Author

Built by Ankush Chaudhari — Business Systems Analyst
