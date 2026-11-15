# Shared requests

Lanes submit requests here for orchestrator-owned files or cross-lane contract changes. Do not edit another lane's implementation to work around a request. Include the requesting lane, the blocking PR, exact files/symbols, the requested change, and the reason.

The orchestrator answers requests and announces every contract change. A request is not approval to change `docs/contract.md`.

Format:

```text
Lane: <1-5>
Blocking PR: <URL or branch/commit>
Request: <specific change>
Reason: <dependency or integration need>
Status: open
```

```text
Lane: 4
Blocking PR: lane-4 branch (Slice 1 freeze)
Request: In lib/match_screen.dart, remove the unused top-level `_goldGradient` declaration at line 26 (or use it) so `flutter analyze` is clean.
Reason: `flutter analyze` currently fails with `unused_element` on `_goldGradient`; the file is lane-2 owned and lane 4 cannot edit it. Slice 1 done-when requires a clean analyzer.
Status: open
```
