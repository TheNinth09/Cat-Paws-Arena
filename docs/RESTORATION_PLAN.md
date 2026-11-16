# Cat Paws Arena — restoration plan

Bazat pe `docs/RESTORATION_AUDIT.md`. Nu se implementează nimic din P1+ până la deciziile owner din §17 ale auditului. P0 sunt eliminări/unificări sigure, fără schimbare de contract.

## P0 — blocaje și curățenie (fără decizie economică)

| # | Sarcină | Lane | Fișiere | Dep. | Risc | Teste | Acceptare | Owner? |
|---|---|---|---|---|---|---|---|---|
| P0-1 | Eliminate TABLA ZILEI din UI/nav | 4 | `lobby_screen.dart`, `shell/daily_board.dart` (dezactivat) | — | mic | shell_test | butonul nu mai apare; calendarul rămâne | nu |
| P0-2 | Unifică Turul Casei + Trofee ca DRUMUL TROFEELOR | 4 | `lobby_screen.dart`, `app_dialogs.dart` (`showTrophyRoad`), `shell/house_tour.dart` | P0-1 | mediu | shell_test | un singur sistem, praguri neschimbate, camera următoare vizibilă | nu |
| P0-3 | Restaurare schelet 5 tab-uri cu Team/Events safe | 4 | `home_screen.dart`, `ui_widgets.dart` (`ArenaBottomBar`), `team_screen.dart`, `events_screen.dart` | decizie #2 | mediu | shell_test | 5 tab-uri; Team/Events nu par live | parțial |
| P0-4 | Wiring cloud save/load la gameplay + status online corect | orch + 5 | `main.dart`, `online_account.dart`, `match_controller.dart` | — | mediu | online_test | save/load apelat la final de meci; offline = unavailable | nu |
| P0-5 | Expunere „Restore with Google" în Setări | 4 | `app_dialogs.dart` | API existent | mic | shell_test | buton + gate + restore | nu |

## P1 — funcții esențiale (necesită decizie #1, #4)

| # | Sarcină | Lane | Fișiere | Dep. | Risc | Teste | Acceptare | Owner? |
|---|---|---|---|---|---|---|---|---|
| P1-1 | Friend duel end-to-end: match doc, sync mutări/hash, VS online, rezultat, emote preset | 2 + 5 | `match_screen.dart`, `match_controller.dart`, `online/*`, `backend/firestore.rules` | P0-4, decizie #4 | mare | duel_test + online_test | doi clienți termină meciul corect | da (Blaze/polling) |
| P1-2 | UI create/join room în Lobby + label BOT/online corect | 4 + 5 | `lobby_screen.dart`, `app_dialogs.dart`, `rooms.dart` | P1-1 | mediu | shell_test | host creează cod, guest join, amândoi în meci | nu |
| P1-3 | Economie: implementare pachete Lăbuțe IAP **sau** cosmetics-only actualizat | 4 + orch | `shop_screen.dart`, `catalog.dart`, `economy.dart`, `contract.md` | decizie #1 | mare | shell_test + contract | fără simulare IAP; prețurile din brief | da |
| P1-4 | Shop: grilă 3 coloane, oferte, Daily Deal, cufere (design din referință) | 4 | `shop_screen.dart`, `cosmetic_offers.dart` | P1-3 | mediu | shell_test + screenshot | structură ca referința, fără countdown | nu |

## P2 — restaurare interfață și personalizare

| # | Sarcină | Lane | Fișiere | Dep. | Risc | Teste | Acceptare | Owner? |
|---|---|---|---|---|---|---|---|---|
| P2-1 | Avatar personalizat separat de pisica jocului (editor specii/culoare și/sau foto→avatar) | 3 + orch | `cat_avatar.dart`, `cats_screen.dart`, `profile.dart`, `cloud_profile.dart` | decizie #3 | mare | cats_test + online_test | avatar ≠ pisică de duel; persistă + sincronizează | da |
| P2-2 | Redesign Arena/Lobby după referință: cameră, pisică mare, trofee/lăbuțe, progres camera următoare, cufăr, LUPTĂ mare | 4 | `lobby_screen.dart`, `ui_widgets.dart`, `house_tour.dart` | P0-2 | mediu | shell_test + screenshot | compoziție ca referința, responsive | nu |
| P2-3 | Pisici: colecție + selecție + Tzuki/Bubble + accesorii + puteri (verify complet) | 3 | `cats_screen.dart`, `catalog.dart` | — | mic | cats_test | toate funcțiile verificate | nu |
| P2-4 | Team/Events: conținut safe onest (coming soon / local clar etichetat) | 4 | `team_screen.dart`, `events_screen.dart`, `local_play.dart` | decizie #2 | mediu | shell_test | nimic parcat nu pare live | da |
| P2-5 | Eliminare `image_picker`/photo parked înainte release | orch + 5 | `app_dialogs.dart`, `pubspec.yaml`, `profile.dart` | decizie #3 | mic | analyze | fără photo upload; câmp parked eliminat | nu |

## P3 — finisaje și release

| # | Sarcină | Lane | Dep. | Acceptare |
|---|---|---|---|---|
| P3-1 | Verificare vizuală: screenshots reale vs referințe pentru toate paginile | orch + 4 | P2 | structură/compoziție corecte, nu doar culori |
| P3-2 | Polish animații/feedback VS, powers, results | 2 | P1-1 | fluent, fairness vizibilă |
| P3-3 | APK final semnat (release, nu debug) după gates umane | orch + 5 | toate P0-P2 + gates | GitHub Release, nu commit |
| P3-4 | Deploy `firestore.rules` (+functions dacă Blaze) de către owner | owner | P1-1 | backend reachable |

## Reguli de execuție

- Un PR pe rând, verify `flutter analyze` + `flutter test` + `dart test` engine după fiecare merge.
- Lanes nu ating fișierele altor lane-uri; contractele comune (`profile.dart`, `catalog.dart`, `contract.md`) = orchestrator.
- Nicio funcție online nu e marcată live până e testată fizic pe două dispozitive.
