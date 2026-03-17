# PlasmaDock Audit 2 — Implementation Plan

Step-by-step plan for resolving all findings in AUDIT-2.md.
Grouped into phases by dependency and risk. Each step is independently committable.

---

## Phase 1: Git Hygiene & Build (no functional changes)

These are safe, non-functional changes that clean up the repo and build system.

### Step 1.1 — Create `.gitignore` [B1]
- [ ] Create `.gitignore` at repo root with standard CMake/C++/Qt patterns:
  ```
  # Build artifacts
  CMakeCache.txt
  CMakeFiles/
  Makefile
  cmake_install.cmake
  ecm_uninstall.cmake
  CTestTestfile.cmake
  install_manifest.txt
  bin/
  .qt/
  .rcc/

  # Plugin build output
  plugin/*.so
  plugin/*.h (generated: log_settings.h, kactivitymanagerd_plugins_settings.h)
  plugin/*.cpp (generated: log_settings.cpp, kactivitymanagerd_plugins_settings.cpp,
                wavetask_qmltyperegistrations.cpp, *_in.cpp)
  plugin/.qt/
  plugin/.rcc/
  plugin/CMakeFiles/
  plugin/CTestTestfile.cmake
  plugin/Makefile
  plugin/cmake_install.cmake
  plugin/qmldir
  plugin/qmltypes/
  plugin/meta_types/
  plugin/*_autogen/
  plugin/*.qrc
  plugin/*.qmltypes
  ```
- [ ] Verify with `git status` that build artifacts are now ignored
- [ ] Commit: `chore: add .gitignore for CMake/Qt build artifacts`

### Step 1.2 — Commit deleted skin files [P1]
- [ ] Stage all deleted skin files: `git add package/contents/skins/`
- [ ] Commit: `refactor: remove legacy skin system files`

### Step 1.3 — Remove unused KWin dependency [B2]
- [ ] Remove `find_package(KWin REQUIRED)` from `CMakeLists.txt:27`
- [ ] Test: `cmake . && make -j$(nproc)` still succeeds
- [ ] Commit: `fix(build): remove unused KWin find_package`

### Step 1.4 — Fix CLAUDE.md documentation [B4]
- [ ] Remove `Bookmarks` from the Key Dependencies list in CLAUDE.md
- [ ] Commit: `docs: remove non-existent KBookmarks dependency from CLAUDE.md`

**Phase 1 verification**: `cmake . -DCMAKE_BUILD_TYPE=Debug && make -j$(nproc)` succeeds.

---

## Phase 2: Config Schema Fixes (low risk, data-layer)

Fix configuration defaults and schema constraints before touching QML that reads them.

### Step 2.1 — Fix `magnification` default/fallback chain [Q7]
- [ ] In `main.xml:159-161`:
  - Change type from `Double` to `Int` (slider uses integer steps of 5)
  - Set `<default>90</default>` (matches current Double default)
  - Add `<min>0</min>` and `<max>100</max>`
- [ ] In `ConfigAppearance.qml:86`: remove `|| 50` fallback
  - Change to: `value: Plasmoid.configuration.magnification`
- [ ] In `main.qml:98`: remove `|| 0` fallback
  - Change to: `Plasmoid.configuration.magnification / 100`
  (already `0` when config is `0`, no need for `||`)
- [ ] In `main.qml:100` (Task.qml _amplitude): same fix
- [ ] In `main.qml:480` (taskList zoomOverflow): same fix
- [ ] Test: set magnification to 0 in config UI, verify zoom is disabled (not fallback)
- [ ] Commit: `fix(config): align magnification type, defaults, and fallbacks`

### Step 2.2 — Add `iconSize` min/max constraints [X1]
- [ ] In `main.xml`, add to `iconSize` entry:
  ```xml
  <min>32</min>
  <max>64</max>
  ```
- [ ] Commit: `fix(config): add min/max constraints for iconSize`

### Step 2.3 — Fix config typo [X2]
- [ ] In `main.xml:24`: change `"minmized"` to `"minimized"`
- [ ] Commit: `fix(config): correct typo in showOnlyMinimized label`

### Step 2.4 — Add i18n to config labels [Q8]
- [ ] In `ConfigAppearance.qml:52`:
  `Kirigami.FormData.label: "Icon Size:"` -> `Kirigami.FormData.label: i18nc("@label:slider", "Icon size:")`
- [ ] In `ConfigAppearance.qml:77`:
  `Kirigami.FormData.label: "Zoom Percentage:"` -> `Kirigami.FormData.label: i18nc("@label:slider", "Zoom percentage:")`
- [ ] Commit: `fix(i18n): wrap config labels in i18nc()`

**Phase 2 verification**: open config dialog, change icon size and magnification,
confirm values persist correctly. Set magnification to 0, confirm no zoom.

---

## Phase 3: QML Correctness Fixes (targeted, low risk)

### Step 3.1 — Add default to `groupModeEnumValue` [Q6]
- [ ] In `main.qml:269-276`, add after `case 1:`:
  ```qml
  default:
      return TaskManager.TasksModel.GroupDisabled;
  ```
- [ ] Commit: `fix: add default return to groupModeEnumValue`

### Step 3.2 — Extract magic numbers into named properties [Q2]
- [ ] In `main.qml`, add near the top of `PlasmoidItem`:
  ```qml
  // Spacing between task slots (accounts for padding around each icon)
  readonly property int taskSlotPadding: 6
  // Vertical padding below panel edge for zoom overflow
  readonly property int panelZoomPadding: 14
  // Extra space for icon reflection below dock
  readonly property int reflectionAllowance: Plasmoid.configuration.iconSize / 2 + 10
  ```
- [ ] Replace `+ 14` at line 75 with `+ panelZoomPadding`
- [ ] Replace `iconSize / 2 + 10` at lines 120-121, 142 with `reflectionAllowance`
- [ ] Replace `iconSize + 14` at line 482 with `iconSize + panelZoomPadding`
- [ ] In `Task.qml`:
  ```qml
  readonly property int _taskWidthPadding: 6
  readonly property int _iconBottomOffset: -5
  readonly property int _reflectionHorizontalOffset: -4
  ```
- [ ] Replace `+ 6` at line 578 with `+ _taskWidthPadding`
- [ ] Replace `-5` at line 518 with `_iconBottomOffset`
- [ ] Replace `-4` at line 588 with `_reflectionHorizontalOffset`
- [ ] Commit: `refactor: extract magic numbers into named properties`

**Phase 3 verification**: build, install, restart plasmashell. Verify dock looks identical.

---

## Phase 4: Performance (highest impact, needs careful testing)

### Step 4.1 — Optimize task position calculation [Q1]
This is the most impactful change. Replace O(n^2) binding with O(n) approach.

**Strategy**: Compute a cumulative offset array in a single JS function called from
`taskList`, then have each task look up its position by index.

- [ ] In `main.qml`, add a helper function to the `taskList` (or `tasks` root):
  ```qml
  // Precomputed cumulative X offsets, updated when any task width changes
  property var taskOffsets: {
      let offsets = [taskList.centerOffset];
      for (let i = 0; i < taskRepeater.count; ++i) {
          let item = taskRepeater.itemAt(i);
          let w = item ? item.width : 60;
          if (i + 1 <= taskRepeater.count) {
              offsets.push(offsets[i] + w);
          }
      }
      return offsets;
  }
  ```
- [ ] Replace task delegate `x` binding (`main.qml:569-576`) with:
  ```qml
  x: taskList.taskOffsets[index] ?? taskList.centerOffset
  ```
- [ ] Remove the separate `iconsTotalWidth` property (line 486-493);
  derive it from `taskOffsets`:
  ```qml
  readonly property real iconsTotalWidth: {
      let offsets = taskOffsets;
      return offsets.length > 0 ? offsets[offsets.length - 1] - offsets[0] : 0;
  }
  ```
- [ ] Test with 1, 5, 15, and 25 tasks. Verify:
  - Icons are correctly positioned
  - Zoom animation is smooth (no jitter)
  - Adding/removing tasks repositions correctly
  - Drag-and-drop reorder still works
- [ ] Commit: `perf: replace O(n^2) task positioning with cumulative offset array`

**Phase 4 verification**: add 20+ launchers, hover across dock, confirm smooth animation
without frame drops. Compare before/after if possible.

---

## Phase 5: Configurable Reflection [Q3]

### Step 5.1 — Add `showReflection` config entry
- [ ] In `main.xml`, add new entry in `<group name="General">`:
  ```xml
  <entry name="showReflection" type="Bool">
    <label>Whether to show a reflection of the icon below the dock.</label>
    <default>true</default>
  </entry>
  ```
- [ ] Commit: `feat(config): add showReflection config entry`

### Step 5.2 — Wire reflection visibility
- [ ] In `Task.qml`, change `reflectionContainer` (line 584-613):
  ```qml
  visible: Plasmoid.configuration.showReflection
  ```
- [ ] In `main.qml`, make `reflectionAllowance` conditional:
  ```qml
  readonly property int reflectionAllowance: Plasmoid.configuration.showReflection
      ? Plasmoid.configuration.iconSize / 2 + 10 : 0
  ```
- [ ] Commit: `feat: make icon reflection conditional on showReflection config`

### Step 5.3 — Add UI toggle in ConfigAppearance.qml
- [ ] Add checkbox after the magnification slider:
  ```qml
  QQC2.CheckBox {
      id: showReflection
      Kirigami.FormData.label: i18nc("@label", "Effects:")
      text: i18nc("@option:check", "Show icon reflection below dock")
  }
  ```
- [ ] Add property alias: `property alias cfg_showReflection: showReflection.checked`
- [ ] Test: toggle on/off, confirm reflection appears/disappears and layout adjusts
- [ ] Commit: `feat(config): add reflection toggle to appearance settings`

**Phase 5 verification**: toggle reflection off, confirm icons don't have reflections
and the panel height adjusts correctly.

---

## Phase 6: Panel Integration Hardening [Q4, Q5]

These are the riskiest changes — modifying how the applet interacts with the panel.

### Step 6.1 — Document the transparency hack
- [ ] Add comments to `lookForContainer` and `ensurePanelFitsZoom` explaining:
  - Why this hack exists (Plasma doesn't expose a proper API for applets to control panel transparency)
  - What could break (Plasma updates changing containment hierarchy)
  - What the ideal solution would be (upstream Plasma API)
- [ ] Commit: `docs: document panel transparency and clip-disable hacks`

### Step 6.2 — Limit ancestor clip-disable scope
- [ ] In `ensurePanelFitsZoom` (`main.qml:83-90`), limit the ancestor walk to a
  reasonable depth (e.g., 5 levels) instead of walking the entire tree:
  ```qml
  let item = tasks.parent;
  let depth = 0;
  while (item && depth < 5) {
      if (item.clip !== undefined) {
          item.clip = false;
      }
      item = item.parent;
      depth++;
  }
  ```
- [ ] Test on horizontal and vertical panels
- [ ] Commit: `fix: limit ancestor clip-disable walk to 5 levels`

**Phase 6 verification**: add widget to panel, confirm transparent background
still works. Test on both horizontal and vertical panels.

---

## Phase 7: Low-Priority Cleanup (optional, safe)

### Step 7.1 — Remove dead margin functions [D1]
- [ ] In `LayoutMetrics.js`, remove `horizontalMargins()` and `verticalMargins()`
- [ ] Replace all call sites with `0`:
  - `LayoutMetrics.js:21` (`verticalMargins()` in `adjustMargin`)
  - `LayoutMetrics.js:67,72` (`verticalMargins()`/`horizontalMargins()` in `preferredMaxWidth`)
  - `LayoutMetrics.js:126-127,133` (`verticalMargins()` in `preferredMaxHeight`)
  - `LayoutMetrics.js:141` (`verticalMargins()` in `preferredHeightInPopup`)
  - `LayoutMetrics.js:155` (`horizontalMargins()` in `preferredMinLauncherWidth`)
  - `Task.qml:538` (`horizontalMargins()`/`verticalMargins()` in `adjustMargin`)
- [ ] Commit: `refactor: remove always-zero margin functions from LayoutMetrics`

### Step 7.2 — Note redundant QPointer guards [C2]
- [ ] Add a brief comment in `smartlauncheritem.cpp` noting the guards are defensive:
  ```cpp
  // Note: QPointer guard is technically redundant since `this` is used as
  // the connection context (Qt auto-disconnects on destruction), but kept
  // as a safety net for the shared_ptr-based singleton pattern.
  ```
- [ ] Commit: `docs: note redundant QPointer guards in SmartLauncher`

### Step 7.3 — Fix root CMakeLists consistency [B3]
- [ ] In `CMakeLists.txt`, update root find_package calls to match what plugin uses:
  ```cmake
  find_package(Qt6 ${QT_MIN_VERSION} REQUIRED COMPONENTS Core DBus Qml Quick Widgets)
  find_package(KF6 ${KF6_MIN_VERSION} REQUIRED COMPONENTS
      CoreAddons I18n Service WindowSystem Config Notifications KIO)
  ```
- [ ] Commit: `fix(build): align root find_package with plugin dependencies`

### Step 7.4 — Fedora spec source URL [P2]
- [ ] Update Source0 to use `%{version}` tag reference instead of `main` branch
- [ ] Commit: `fix(packaging): use release tags in Fedora spec Source0`

---

## Execution Order & Dependencies

```
Phase 1 (Git/Build)  ──> can start immediately, no dependencies
  1.1 .gitignore
  1.2 deleted skins
  1.3 remove KWin
  1.4 CLAUDE.md

Phase 2 (Config)     ──> no dependencies
  2.1 magnification defaults  ──> must precede Phase 4 (reads magnification)
  2.2 iconSize constraints
  2.3 config typo
  2.4 i18n labels

Phase 3 (QML fixes)  ──> after Phase 2.1
  3.1 groupModeEnumValue default
  3.2 magic numbers           ──> must precede Phase 5 (reflection constants)

Phase 4 (Performance) ──> after Phase 3.2
  4.1 O(n) positioning

Phase 5 (Reflection)  ──> after Phase 3.2
  5.1 config entry
  5.2 wire visibility
  5.3 UI toggle

Phase 6 (Panel hacks) ──> after Phase 4 (avoid conflicts in main.qml)
  6.1 document hacks
  6.2 limit clip walk

Phase 7 (Cleanup)     ──> after all above
  7.1-7.4 independent
```

## Progress Tracker

| Phase | Steps | Done | Status      |
|-------|-------|------|-------------|
| 1     | 4     | 0    | Not started |
| 2     | 4     | 0    | Not started |
| 3     | 2     | 0    | Not started |
| 4     | 1     | 0    | Not started |
| 5     | 3     | 0    | Not started |
| 6     | 2     | 0    | Not started |
| 7     | 4     | 0    | Not started |
| **Total** | **20** | **0** | |
