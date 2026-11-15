# Cat Paws Arena

A portrait Android cat duel by One Ear Games, built with Flutter. The game brings together five rounds of three moves, friends joining by a six-character code, and clearly labelled house cats.

This repository is currently the pre-lane baseline, not the completed duel. Online services, billing fulfillment, release signing, and human playtest acceptance are not established by the presence of UI screens or local simulations.

## Product direction

A short, fair duel as the player's own cat; flat scoring; configurable colour count and rainbow rules; three free powers; earned paws and cosmetic bundles priced in LEI. No ads, no paid paws, no free-text chat, trading, teams, ranked stranger matchmaking, or countdown purchase pressure.

Read [the plan](docs/plan.md) for the end state, delivery stages, ownership, parked scope, and human gates. Read [the engineering contract](docs/contract.md) for the proposed pure Dart engine, events, replay, profile fields, and acceptance checks. Read [the setup baseline](docs/baseline.md) for the recorded starting state and its limitations.

## Working in parallel

[AGENTS.md](AGENTS.md) contains the agreed decisions, parked list, file ownership, and review rules. Only the orchestrator changes the shared contract; lanes submit cross-lane requests through [docs/requests.md](docs/requests.md). Lanes do not push to `main`.

Use the Flutter/Dart installation and Android toolchain documented in `AGENTS.md` for this workspace. Standard verification commands are `flutter analyze` and `flutter test`. Do not treat historical build artifacts or APKs committed before this setup as the current release process; only the orchestrator builds a release APK and attaches it to a GitHub Release.

## Release status

No release candidate or Gate 1 playtest has been approved by this setup. Production signing, store declarations, billing configuration, privacy review, and backend approval remain explicit release prerequisites. Existing local/offline behavior must not be presented as live multiplayer, cloud sync, or a completed purchase flow.
