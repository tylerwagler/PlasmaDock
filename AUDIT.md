# PlasmaDock Codebase Audit — 2026-03-14

Tracking document for all issues found during comprehensive audit.
Mark items `[x]` as they are fixed.

---

## CRITICAL

- [x] **1. License mismatch in Fedora spec** — `17b5b38`
- [x] **2. Wrong project name in root CMakeLists.txt** — `f1192be`
- [x] **3. Contradictory warning message in backend.cpp** — `59948a9`
- [x] **4. Off-by-one skips last task** — `3803dbe`
- [x] **5. Dead code overwrites itself in SmartLauncher backend** — `b051122`

## HIGH

- [x] **6. Null dereference in globalRect()** — `30f71b7`
- [x] **7. Race condition in SmartLauncher singleton** — `3af6959`
- [x] **8. Memory management — jobs without parent** — Skipped (idiomatic KDE pattern; KJob auto-deletes on completion)
- [x] **9. QMenu created without parent** — `0cde2f8`
- [x] **10. Q_ASSERT stripped in release builds** — `9d2a453`
- [x] **11. Unsafe lambda captures of `this`** — `68f35d6`

## MEDIUM

- [x] **12. Unused linked libraries** — `1c2bee8`
- [x] **13. Hardcoded x86_64 architecture in prefix.sh** — `8310010`
- [x] **14. Deprecated Qt5Compat import** — `3bc8bb1`
- [x] **15. ~140 lines commented-out dead code in Task.qml** — `7c90996`
- [x] **16. Fragile string-based type checking** — `691b23c`
- [x] **17. Spanish comments and console output** — `fdc3b0c`, `243caab`
- [x] **18. Outdated or missing SPDX headers** — `755d410`
- [ ] **19. Expensive zoom computation in binding** — Deferred (core feature; already has early-return optimizations and 3σ cutoff)
- [x] **20. isZoomActive iterates all tasks** — `75991e1`
- [x] **21. Hardcoded magic numbers** — `aaae855`

## LOW

- [x] **22. Use std::make_unique** — `3b2a4e1`
- [x] **23. Uninitialized pointer in header** — `9e3d917`
- [x] **24. Silent failure on missing skin** — `ab40e1b`
- [x] **25. Missing explicit CMake includes** — `1c2bee8`
- [ ] **26. Inconsistent QML type annotations** — Deferred (cosmetic; no functional impact)

## Also fixed

- Removed unused `m_activitiesConsumer` member and includes from `backend.h` — `6e69757`
- Fixed unused parameter warning in `plugin.cpp` — `755d410`

## KNOWN BUGS (upstream, not introduced by this project)

- BUG 464597, BUG 466675, BUG 452187, BUG 446105, QTBUG-127600
