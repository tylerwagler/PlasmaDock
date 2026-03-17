# PlasmaDock Codebase Audit 2 — 2026-03-17

Second-pass audit tracking document. Follows up on AUDIT.md (2026-03-14).
Mark items `[x]` as they are fixed. Include commit hash when resolved.

---

## BUILD SYSTEM

- [ ] **B1. Missing `.gitignore`** (HIGH)
  40+ untracked build artifacts pollute `git status`. Risk of accidental binary commits.
  Files: repo root

- [ ] **B2. Unused `KWin` dependency in root CMakeLists** (HIGH)
  `find_package(KWin REQUIRED)` at `CMakeLists.txt:27` — found but never linked.
  Adds a false build-time dependency; builds fail on systems without kwin-dev.
  Files: `CMakeLists.txt`

- [ ] **B3. Root vs plugin `find_package` inconsistency** (LOW)
  Root finds `Qt6 Core DBus Qml Widgets` but plugin uses `Qt6::Quick`.
  Root missing KF6 components the plugin uses (CoreAddons, Config, Notifications, KIO).
  Files: `CMakeLists.txt`, `plugin/CMakeLists.txt`

- [ ] **B4. CLAUDE.md lists `KF6::Bookmarks` but it's not a real dependency** (LOW)
  Code uses `KFilePlacesModel` from KIO, not KBookmarks. Documentation is inaccurate.
  Files: `CLAUDE.md`

## QML FRONTEND

- [ ] **Q1. O(n^2) position calculation during zoom** (HIGH)
  Each task's `x` binding iterates all preceding tasks (`main.qml:569-576`).
  `iconsTotalWidth` (`main.qml:486-493`) also iterates all tasks on every width change.
  During zoom animation, every task's width changes every frame -> cascade of rebindings.
  Files: `main.qml`

- [ ] **Q2. Hardcoded magic numbers** (MEDIUM)
  - `main.qml:75`: `+ 14` (panel height padding)
  - `main.qml:120-121`: `iconSize / 2 + 10` (reflection allowance)
  - `main.qml:482`: `iconSize + 14` (task slot width)
  - `Task.qml:578`: `+ 6` (zoomed width padding)
  - `Task.qml:518`: `verticalCenterOffset: -5`
  - `Task.qml:588`: `horizontalCenterOffset: -4`
  Note: Prior audit (#21) fixed some magic numbers but these remain.
  Files: `main.qml`, `Task.qml`

- [ ] **Q3. Reflection always rendered, not configurable** (MEDIUM)
  `Task.qml:583-613` — reflection `visible: true` always. Doubles icon rendering cost.
  No user-facing toggle in ConfigAppearance.qml.
  Files: `Task.qml`, `ConfigAppearance.qml`, `main.xml`

- [ ] **Q4. `ensurePanelFitsZoom` modifies ancestor items** (MEDIUM)
  `main.qml:83-90` — walks entire ancestor tree setting `clip = false`.
  Fragile: modifies items this applet doesn't own. Could break other panel applets.
  Called on a retry timer up to 5 times.
  Files: `main.qml`

- [ ] **Q5. `lookForContainer` fragile parent traversal** (MEDIUM)
  `main.qml:54-62` — walks up to 14 parents to find containment.
  `main.qml:68` — forcibly sets `backgroundHints = 0` on the containment,
  which affects the entire panel (not just this applet).
  Files: `main.qml`

- [ ] **Q6. `groupModeEnumValue` missing default return** (MEDIUM)
  `main.qml:269-276` — returns `undefined` for unexpected input values.
  Files: `main.qml`

- [ ] **Q7. Config `magnification` default/fallback mismatch** (MEDIUM)
  `main.xml:159-161`: default `90.0`
  `ConfigAppearance.qml:86`: fallback `|| 50`
  `main.qml:98`: fallback `|| 0`
  The `||` operator treats `0` as falsy, so setting magnification to 0 gives fallback.
  Files: `main.xml`, `ConfigAppearance.qml`, `main.qml`

- [ ] **Q8. Missing `i18n()` on config labels** (LOW)
  `ConfigAppearance.qml:52`: `"Icon Size:"` (raw string)
  `ConfigAppearance.qml:77`: `"Zoom Percentage:"` (raw string)
  Files: `ConfigAppearance.qml`

## C++ PLUGIN

- [ ] **C1. `parentPid()` creates new process table on every call** (LOW)
  `backend.cpp:494-519` — allocates `KSysGuard::Processes` and queries procfs each time.
  Files: `plugin/backend.cpp`

- [ ] **C2. Redundant `QPointer` guards in SmartLauncher lambdas** (LOW)
  `smartlauncheritem.cpp:39-88` — connections use `this` as context (auto-disconnect on
  destruction), making the QPointer checks unnecessary.
  Files: `plugin/smartlauncheritem.cpp`

## CONFIGURATION

- [ ] **X1. `iconSize` missing min/max in config schema** (MEDIUM)
  `main.xml:156-158` — no `<min>`/`<max>`. Slider constrains 32-64 but hand-edited
  config could set invalid values.
  Files: `main.xml`

- [ ] **X2. Typo in config label** (LOW)
  `main.xml:24`: `"minmized"` should be `"minimized"`.
  Files: `main.xml`

## PACKAGING / GIT HYGIENE

- [ ] **P1. Deleted skin files not committed** (HIGH)
  ~20 deleted files under `package/contents/skins/` show in `git status`.
  These deletions need to be staged and committed.
  Files: `package/contents/skins/`

- [ ] **P2. Fedora spec Source0 uses `main` branch** (LOW)
  Not reproducible. Should reference tagged releases.
  Files: `org.vicko.wavetask_fedora.spec`

## CODE QUALITY

- [ ] **D1. Dead `horizontalMargins()`/`verticalMargins()` functions** (LOW)
  `LayoutMetrics.js:12-18` — both return `0` unconditionally. Called throughout but add
  no value.
  Files: `code/LayoutMetrics.js`

---

## Summary

| Priority | Open | Fixed |
|----------|------|-------|
| HIGH     | 4    | 0     |
| MEDIUM   | 8    | 0     |
| LOW      | 8    | 0     |
| **Total**| **20** | **0** |
