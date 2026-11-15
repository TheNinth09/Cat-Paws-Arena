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
Lane: 3
Blocking PR: lane-3 slice 2 (creator)
Request: Stop selling powers in the shop. In lib/shop_screen.dart remove `...powers` from the 'ACCESORII & PUTERI' grid (line ~100) and stop granting `powers[0]` in `buyCombo` (line ~37); if catalog.dart pricing treats powers as buyable items, mark them non-purchasable. Powers must stay free for every cat, per contract decision 4 and the Families policy.
Reason: The contract states "Three free powers of equal strength; none is sold." Lane 3's creator already lets the custom cat equip any of the three powers for free, but the shop still lists them at 300 paws, which contradicts the contract.
Status: open
```

```text
Lane: 3
Blocking PR: lane-3 slice 3 (share card)
Request: Review the new dependency line `share_plus: 13.3.1` added to pubspec.yaml (orchestrator-owned file). It is the standard Flutter Community plugin for the platform share sheet, published 44 days ago, supports Android/iOS/Web/Windows/macOS/Linux, requires Flutter >=3.38.1 / Dart >=3.10 (project has 3.47.7 / 3.13.5). No other dependency was added; `XFile` is re-exported by share_plus so `cross_file` is not needed as a direct dependency.
Reason: Slice 3 requires sending the share card "through the phone's share sheet". share_plus is the maintained, families-policy-safe choice (no ads, no tracking). pubspec.yaml may only be changed by the orchestrator, so this line needs review/approval.
Status: open
```
