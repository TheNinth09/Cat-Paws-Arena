# Cat Paws Arena — plan worked backward from the end

## North star

A cat owner starts a short, understandable duel as their own cat, plays against a friend through a six-character code or a clearly identified house cat, sees what happened through fair rules and readable feedback, and has a reason to return tomorrow. Children and adults can participate without advertising, pressure to buy, or free-form messages to other players.

The target is a complete, reviewed Android release for **One Ear Games**, application ID **`games.oneear.catpawsarena`**. This document describes the approved direction and proposed delivery order, not completed functionality. Parked work stays out of the active lanes.

The attached plan PDF was attempted with the available document reader, Windows PDF extraction, and the installed browser library; none could extract its text in this session. This document is based on the explicit decisions in the orchestration brief and does not claim to reproduce the PDF or add its unread contents. No additional PDF software was installed. Unspecified art, exact copy, art budgets, and backend details remain decisions for their owning lanes or the orchestrator rather than invented facts.

## 1. Establish the foundation

Before feature work, record the current analysis and test results, define ownership, publish the shared contract, and split existing tests without changing what they assert. Record the studio identity, version, application ID, and existing release limitations honestly.

The initial baseline has one existing analyzer warning and 19 passing tests; see [baseline.md](baseline.md). These results are not a clean bill of health for the proposed game.

## 2. Make the rules trustworthy

Build the engine as a standalone pure Dart package. Define an immutable configuration, explicit state, legal moves, event-returning transitions, and deterministic replay with hashes. Board dimensions, colour count, rounds, moves per round, and the rainbow rule must be configuration, not hidden constants in the screen.

A local board and a duel are different concepts. The screen may animate events, but it must not be the authority for scoring, move limits, seeds, rewards, or whether an opponent has moved. Pure Dart means no Flutter, Flame, platform channels, network clients, wall-clock randomness, or UI dependencies in the engine. The package must be testable on its own.

The first engine gate is deterministic agreement: the same seed and config, with the same legal move sequence, produce the same final state and hash on every run. A different platform must not change the meaning of a saved move.

## 3. Make a match fair and readable

The duel consists of **five rounds of three moves**, using the same seed for both players. Each round uses its own board. Obstacles earned in a round are queued for the opponent and land at the start of that opponent's next round. A round does not silently become an endless battle because cascades continue or a timer expires.

Scoring uses flat points per piece, without a cascade multiplier. The number of colours (five or six) and the rainbow rule are configurable. A rainbow piece must have an explicit, tested meaning before it is exposed in the duel. Power effects must obey the same move and board rules rather than bypassing them through presentation callbacks.

An invalid move must not consume a turn, mutate the board, or generate rewards. Replaying a saved log must refuse invalid or inconsistent input, not silently correct it. Event ordering must be sufficient for both rendering and cross-device verification.

The visual board supports touch, keyboard/controller accessibility where practical, screen-reader labels, reduced motion, and clear turn/end-of-round feedback. Flame is a renderer; the engine remains usable without it. The lane owns presentation and interaction, not the economic or online rules.

## 4. Give cats identity without creating a shop dependency

Cat selection and preview must work independently of inventory purchases. The lane defines visual variants and local persistence hooks through the shared profile contract; it does not unilaterally add purchasable paws, inventory authority, or backend ownership to its screen.

All three powers are free and equally strong by rule. Existing catalog descriptions and prices must not be interpreted as approval to sell powers. Any currently bundled power artwork is a resource, not evidence that a paid power is permitted.

The profile schema must distinguish the cat identity from mutable loadout fields. Cosmetic ownership and entitlement checks belong to the shared contract and later economy integration. A player's locally displayed cat is not proof of ownership or eligibility for an online match.

## 5. Build the home around one clear action

Home, lobby, profile/settings, progress, and shop navigation must lead to the duel without exposing parked modes as playable promises. Progress explains what has actually been earned and saved. Returning tomorrow should offer a clear next match or friend duel, not a sequence of unavailable-service notices.

Paws are earned through play and are never sold. Cosmetic bundles use explicit LEI prices. There are no advertisements or ad identifiers. There are no countdown offers, fake scarcity, or prompts that pressure a child to buy. A purchase flow must not grant online benefits until its fulfillment is verified by the approved backend and billing integration.

Existing local team/event screens are not the social system in this plan. Until their owning lane removes or replaces them, they must not be represented as working friend matches, live chat, tournaments, or trading. Offline simulations need visible labels and must not create authoritative rewards.

## 6. Make friends playable before matchmaking

Friends join using a six-character code. House cats are visibly labelled as bots. There is no ranked queue and no match against an unlabelled stranger. A friend code is not a secret bearer credential: possession or knowledge of a code must not grant access to another player's profile, history, purchases, or device-local data.

A duel needs an explicit accepted session, both players' agreed loadouts, the match seed/config, an ordered move log per round, pause/disconnect handling, and a result that both clients can reproduce. Both players need to know whether they are playing a friend or a house cat before committing moves.

The online lane proposes the backend and transport; the orchestrator reviews and approves that proposal before it becomes an integration dependency. This plan does not select a hosted vendor or claim that a backend already exists. Device clocks, client scores, and client-generated rewards are not authoritative.

Friend invitations, friend lists, and reconnect behavior are required for the friend-loop acceptance scenario. Merely displaying a code entry field or an online-looking badge is insufficient.

## 7. Keep the child audience safe by construction

No advertising ID or ad SDK is allowed in this product. There is no free-text chat. Social communication uses preset emotes only. Names displayed to other players come from a preset list; arbitrary profile names are local labels, not network identities.

No typed text is shown to other players. This includes messages disguised as names, codes interpreted as chat, or custom payloads forwarded by the backend. The transport must not be treated as a general messaging channel. Friend-code input and ordinary gameplay moves are not a licence to transmit arbitrary strings to peers.

Store declarations, permissions, SDK manifests, network payloads, and tests must agree with these restrictions. A dependency marked “analytics” or “social” is not automatically acceptable. Consent, data collection, account deletion, and child-directed store requirements need a human policy review before release; this plan does not certify compliance.

## 8. Integrate, release, and learn

The orchestrator owns integration, contract changes, shared-file changes, and release assembly. Lanes work in parallel on disjoint ownership, then rebase after each accepted merge. A lane can be functionally complete while the combined product still fails an integration gate.

Every pull request must state its scope, tests, changed files, known limitations, and dependency on other lanes. Cross-lane integration is explicit and reviewed, not hidden in a screen file. New dependencies require justification and a compatible license/version; a lane cannot change another lane's files to make its own tests pass.

The release candidate must use the approved application ID, real billing configuration only if monetization is in scope, privacy disclosures matching actual data flows, and a signed artifact produced by the orchestrator. The existing debug-signed APK and APK committed to `main` are historical artifacts, not the delivery mechanism for this plan. Only the orchestrator builds a release APK and attaches it to a GitHub Release; it is never committed to the repository.

A physical-device performance check is required for release readiness, but passing frame-rate measurements still does not mark a human gate as passed. The team records evidence and limitations instead of claiming an unmeasured guarantee.

## 9. Test the complete loop, not isolated widgets

Engine tests cover move legality, deterministic generation/replay, score and colour configuration, round boundaries, obstacle delivery timing, rainbow behavior, specials, shuffle, extra moves, invalid inputs, event ordering, and hash stability. UI tests cover the duel presentation and interaction, not a second implementation of game rules.

Social tests cover code validation, bot labels, rematch/reconnect, both players' views, event replay, tampered move logs, disconnected players, and the absence of stranger ranking. They also cover preset names/emotes and the absence of free-text or arbitrary player-generated network payloads.

Progress/shop tests cover earned paws, cosmetic prices, ownership, restore/failure behavior, and no sale of paws or powers. Home tests cover the path from launch to a match and back, not just the presence of a button.

Regression tests retain meaningful coverage from the old suite, with ownership assigned to the appropriate lane. Existing tests are split without changing assertions. New tests are added for new behavior; a test that merely mirrors the implementation does not prove fairness.

## 10. Deliver in dependency order

| Stage | Deliverable | Dependency |
| --- | --- | --- |
| 0 | Shared rules, ownership, baseline, contract, tests | Setup PR merged |
| 1 | Pure deterministic engine | Stage 0 |
| 2 | Local duel presentation using engine events | Engine contract |
| 3 | Cat identity and shared profile integration | Profile contract |
| 4 | Home/progress/shop navigation and economy presentation | Profile/catalog contracts |
| 5 | Friend codes, bots, session state, replay, release groundwork | Approved backend proposal and engine/profile contracts |
| 6 | Combined integration, device testing, release candidate | All in-scope lanes |

Stages indicate dependencies, not a promise of calendar time. Online integration should start with a small end-to-end prototype as soon as its contract is approved, rather than waiting for every local screen to be polished. Local work must not invent a fake backend to unblock itself.

## 11. Human gates and evidence

The orchestrator records gate evidence but never marks a human gate as passed. Humans run the playtests and make the acceptance decision.

| Gate | Required human evidence | Current status |
| --- | --- | --- |
| 1 — return without help | 3 of 5 new players start a second match without being asked | Not run; not passed |
| 2 — understandable duel | Players can explain the rules, identify their turn/result, and complete a match | Not run; not passed |
| 3 — safe social loop | Players can find a friend or recognize a house cat and use emotes without text entry | Not run; not passed |
| 4 — fair and reliable | Agreed seeds/replays, interruption handling, and no unexplained score differences | Not run; not passed |
| 5 — release-ready | Device performance, billing/privacy/store review, and human release approval | Not run; not passed |

Gate 2–5 descriptions are proposed acceptance checks from this plan, not claims that those gates were specified or approved elsewhere. Any change to gate meaning requires an explicit orchestrator decision recorded here. A failed or inconclusive playtest remains visible; it is not converted into a pass by automation.

## 12. Active scope and parked scope

Active: pure Dart rules/replay; duel presentation; cats and profile; home/progress/shop; friend codes and labelled house cats; preset emotes; earned paws and cosmetic LEI purchases; safe Android release groundwork; One Ear Games identity.

Parked: ranked matchmaking; server-side validation as a separate deliverable beyond the minimum session integrity agreed here; teams; chat; trading; tournaments; Speed Rush; Survival; High-Stakes; paws packs sold for money; Facebook login; avatar from a photo; iOS; seasons and passes.

“Parked” means no lane builds or re-enables it as part of this plan. It does not mean deleting historical code or assets indiscriminately. Removal or hiding must stay within file ownership and must not break shared navigation or persistence. Existing parked features must not be advertised as available in the new loop.

## 13. Decisions still requiring an explicit owner

- The backend proposal and its approval are pending lane 5 and orchestrator review. No vendor, hosting budget, account system, or data-retention policy is selected here.
- Family-policy compliance, store data-safety declarations, and account/deletion obligations need qualified human review before release.
- Production signing credentials, store listing assets, supported device range beyond the existing Android configuration, and release timing require owner input.
- Art direction beyond the agreed audience and readable presentation, exact reward amounts, and cosmetic catalog contents need product decisions; they must not be inferred from old prices or trophies.

These are open decisions, not permission for lanes to implement them silently. The orchestrator resolves contract-level choices and records them; human policy/business decisions remain visible until answered.
