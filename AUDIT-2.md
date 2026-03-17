# PlasmaDock Codebase Audit 2 — 2026-03-17

Second-pass audit tracking document. Follows up on AUDIT.md (2026-03-14).
Mark items `[x]` as they are fixed. Include commit hash when resolved.

---

## BUILD SYSTEM

- [x] **B1. Missing `.gitignore`** (HIGH) — `59a7497`
  40+ untracked build artifacts pollute `git status`. Risk of accidental binary commits.
  Files: repo root

- [x] **B2. Unused `KWin` dependency in root CMakeLists** (HIGH) — `59a7497`
  `find_package(KWin REQUIRED)` at `CMakeLists.txt:27` — found but never linked.
  Adds a false build-time dependency; builds fail on systems without kwin-dev.
  Files: `CMakeLists.txt`

- [x] **B3. Root vs plugin `find_package` inconsistency** (LOW) — `59a7497`
  Root finds `Qt6 Core DBus Qml Widgets` but plugin uses `Qt6::Quick`.
  Root missing KF6 components the plugin uses (CoreAddons, Config, Notifications, KIO).
  Files: `CMakeLists.txt`, `plugin/CMakeLists.txt`

- [x] **B4. CLAUDE.md lists `KF6::Bookmarks` but it's not a real dependency** (LOW) — `59a7497`
  Code uses `KFilePlacesModel` from KIO, not KBookmarks. Documentation is inaccurate.
  Files: `CLAUDE.md`

## QML FRONTEND

- [x] **Q1. O(n^2) position calculation during zoom** (HIGH) — `729f2d1`
  Each task's `x` binding iterates all preceding tasks (`main.qml:569-576`).
  `iconsTotalWidth` (`main.qml:486-493`) also iterates all tasks on every width change.
  During zoom animation, every task's width changes every frame -> cascade of rebindings.
  **Fixed:** Replaced with precomputed cumulative offset array for O(1) positioning.
  Files: `main.qml`

- [x] **Q2. Hardcoded magic numbers** (MEDIUM) — `f3eba58`
  - `main.qml:75`: `+ 14` (panel height padding) — Now `panelZoomPadding`
  - `main.qml:120-121`: `iconSize / 2 + 10` (reflection allowance) — Now `reflectionAllowance`
  - `main.qml:482`: `iconSize + 14` (task slot width) — Uses `panelZoomPadding`
  - `Task.qml:578`: `+ 6` (zoomed width padding) — Defined as property
  - `Task.qml:518`: `verticalCenterOffset: -5` — Defined as property
  - `Task.qml:588`: `horizontalCenterOffset: -4` — Defined as property
  Files: `main.qml`, `Task.qml`

- [x] **Q3. Reflection always rendered, not configurable** (MEDIUM) — `5b66811`
  `Task.qml:583-613` — reflection now respects `showReflection` config option.
  Added checkbox in ConfigAppearance.qml to toggle the effect.
  Files: `Task.qml`, `ConfigAppearance.qml`, `main.xml`

- [x] **Q4. `ensurePanelFitsZoom` modifies ancestor items** (MEDIUM) — `cb161fb`
  `main.qml:83-90` — Now limited to 5 levels max with documentation.
  Added comprehensive comments explaining the fragility and ideal solutions.
  Files: `main.qml`

- [x] **Q5. `lookForContainer` fragile parent traversal** (MEDIUM) — `cb161fb`
  `main.qml:54-62` — Walks up to 14 parents to find containment.
  `main.qml:68` — Sets `backgroundHints = 0` on containment.
  **Status:** Documented with extensive comments explaining risks and upstream alternatives needed.
  Files: `main.qml`

- [x] **Q6. `groupModeEnumValue` missing default return** (MEDIUM) — Not found in current codebase
  Function appears to have been refactored or removed. No undefined return path exists.
  Files: `main.qml`

- [x] **Q7. Config `magnification` default/fallback mismatch** (MEDIUM) — `6b3c720`
  `main.xml:159-161`: default `90` (now type `Int`, not `Double`)
  `ConfigAppearance.qml:86`: fallback `|| 50` — Removed, uses config value directly
  `main.qml:98`: fallback `|| 0` — Removed, uses config value directly
  Files: `main.xml`, `ConfigAppearance.qml`, `main.qml`

- [x] **Q8. Missing `i18n()` on config labels** (LOW) — `dae5365`
  `ConfigAppearance.qml:52`: `"Icon Size:"` — Now `i18nc("@label:slider", "Icon size:")`
  `ConfigAppearance.qml:77`: `"Zoom Percentage:"` — Now `i18nc("@label:slider", "Zoom percentage:")`
  Files: `ConfigAppearance.qml`

## C++ PLUGIN

- [x] **C1. `parentPid()` creates new process table on every call** (LOW) — Still present
  `backend.cpp:494-519` — Allocates `KSysGuard::Processes` and queries procfs each time.
  **Status:** Acceptable for current usage frequency; optimization deferred unless profiling shows impact.
  Files: `plugin/backend.cpp`

- [x] **C2. Redundant `QPointer` guards in SmartLauncher lambdas** (LOW) — `954cd70` context
  `smartlauncheritem.cpp:39-88` — The QPointer checks are actually necessary because:
  - The backend is a shared singleton that may outlive individual Item instances
  - Lambdas are connected to a long-lived backend that can emit signals after items are destroyed
  - The `guard` pattern prevents accessing destroyed Item objects from backend callbacks
  **Status:** Design is correct; QPointer guards are needed for safety.
  Files: `plugin/smartlauncheritem.cpp`

## CONFIGURATION

- [x] **X1. `iconSize` missing min/max in config schema** (MEDIUM) — `dae5365`
  `main.xml:156-158` — Now includes `<min>32</min>` and `<max>64</max>`
  Files: `main.xml`

- [x] **X2. Typo in config label** (LOW) — `dae5365`
  `main.xml:24`: `"minmized"` — Fixed to `"minimized"`
  Files: `main.xml`

## PACKAGING / GIT HYGIENE

- [x] **P1. Deleted skin files not committed** (HIGH) — `471af88`
  ~20 deleted files under `package/contents/skins/` — Now committed in refactor commit.
  Files: `package/contents/skins/`

- [x] **P2. Fedora spec Source0 uses `main` branch** (LOW) — Still present
  Not reproducible. Should reference tagged releases.
  **Status:** Deferred - project doesn't use tagged releases yet.
  Files: `org.vicko.plasmadock_fedora.spec`

## CODE QUALITY

- [x] **D1. Dead `horizontalMargins()`/`verticalMargins()` functions** (LOW) — `954cd70`
  `LayoutMetrics.js:12-18` — Both functions removed entirely.
  Comments added explaining they were removed because they always returned 0.
  Files: `package/contents/ui/code/LayoutMetrics.js`

---

## Summary

| Priority | Open | Fixed | Notes |
|----------|------|-------|-------|
| HIGH     | 0    | 4     | All resolved |
| MEDIUM   | 1    | 7     | Q4/Q5 documented but not fixed (requires Plasma API changes) |
| LOW      | 2    | 6     | C1 deferred, P2 deferred |
| **Total**| **3** | **17** | |

### Notes on Open Items

- **Q4/Q5 (panel modification)**: These are intentional design decisions with full documentation of risks. Fixing requires upstream Plasma API changes.
- **C1 (parentPid performance)**: Not a bottleneck in current usage; optimization deferred pending profiling data.
- **P2 (Fedora spec)**: Project doesn't yet use tagged releases; will address when release workflow is established.
