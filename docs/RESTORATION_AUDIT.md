# Cat Paws Arena — restoration audit

Audit din `main` la `d687b54`. Verificat cu `flutter analyze` (curat), `flutter test` (80/80) și `dart test` în `packages/arena_engine` (36/36). Nu am modificat cod de gameplay.

## 1. Starea actuală a proiectului

- `main` conține lane-1 engine, lane-2 duel, lane-3 cats, lane-4 shell/shop/house-tour, lane-5 online/Firebase.
- Ultimul APK intern: `apk-test-0.2.0-7` (debug, `CPA_ONLINE_BACKEND=firebase`, versionCode 7).
- Navigația e funcțională, dar e **3 tab-uri**, nu cele 5 originale.

## 2. Structura actuală de navigare

`lib/home_screen.dart` → `PageView` cu 3 pagini + `ArenaBottomBar` (3 etichete):

| Index | Tab | Ecran |
|---:|---|---|
| 0 | MAGAZIN | `ShopScreen` |
| 1 | PISICI | `CatsScreen` |
| 2 | LUPTĂ | `LobbyScreen` (nu o arenă completă) |

- HUD sus: `PlayerHud` cu `CatAvatar(p)` (avatarul jucătorului), nume, trofee, lăbuțe, profil (`showPlayerProfile`), drum trofee (`showTrophyRoad`), magazin, meniu.
- Meniu: `endDrawer` cu Setări / Suport / Noutăți.
- `team_screen.dart`, `events_screen.dart`, `local_play.dart` există dar **nu sunt în navigare** (parked).

## 3. Diferențele față de cele cinci tab-uri originale

- Lipsesc **ECHIPĂ** și **EVENIMINTE**.
- Ordinea MAGAZIN → PISICI → LUPTĂ e corectă, dar LUPTĂ e `LobbyScreen`, nu ecranul Arena din referință.
- Nu există tab Profil (corect — profilul e în HUD).

## 4. Pagini și butoane eliminate sau inaccesibile

- **ECHIPĂ / EVENIMINTE**: ecrane parked, fără intrare în UI.
- **TABLA ZILEI**: buton în `LobbyScreen` → `showDailyBoard` (`lib/shell/daily_board.dart`). Trebuie eliminată din UI/nav.
- **Friend Room create/host**: `RoomService.createRoom`/`waitForGuest` există, dar UI are doar join în Setări; nu există creare cameră în Lobby.
- **Restore with Google**: `OnlineAccount.restoreWithGoogle` există în API, dar nu e expus în Setări.
- **Pachete Lăbuțe IAP**: `catalog.dart` are `coinBundles` (500/8.99 … 25.000/224.99) dar nu sunt folosite de `ShopScreen`.
- **Oferte extinse** (Daily Deal, cufere, grilă 3 coloane): lipsesc.

## 5. Funcții care există, dar nu funcționează complet

- **Friend duel end-to-end**: `rooms`/`matches`/`emotes` rules + `onMoveCreated` function există, dar clientul nu are match-sync; `MatchScreen` e local vs bot/house-cat. `createRoom`/`waitForGuest` nefolosite în UI.
- **Cloud save/load**: `CloudProfile` + `OnlineAccount.save/load` există; nu am verificat declanșarea automată în gameplay.
- **Delete account**: funcționează, dar `requiresRecentLogin` doar afișează mesaj (fără retry automat cu Google).
- **Photo avatar**: `image_picker` + `photo` base64 e parked (contract §7: fără poze încărcate, `image_picker` de eliminat înainte release).
- **Team/Events**: conțin simulări locale (`local_play.dart`) — nu sunt servicii live.

## 6. Assets existente și corespondența cu referințele

- `assets/generated/`: `acc_*` (4 accesorii), `tile_*`, `obs_*`, `vfx_*` (3 puteri), `emote_*`, `icon_*` (chest/paw/trophy/fish), `btn_*`, `purr.wav` + 16 SFX, `audio/`.
- `assets/cats/`: doar `README.md` — pisicile sunt desenate procedural în `lib/cat_avatar.dart` (`CatSpec` + `CustomPainter` layers), nu PNG.
- `assets/ui_*.png.jpg`, `assets/sprites_*.png.jpg`: referințe, excluse din bundle.
- `assets/fonts/`: Nunito. `RoomBackground` e pictat din cod (`ui_widgets.dart`).
- Concluzie: identitatea vizuală premium trebuie construită în Flutter peste sprite-urile generate + paintere, nu peste capturi.

## 7. Starea motorului Match-3

`packages/arena_engine/` — pur Dart, determinist, 5 runde × 3 mutări, același seed, obstacole transferate, puncte plate, puteri `zoomies`/`shadowPounce`/`laserChase`, teste 36/36. Conform contractului.

## 8. Starea duelurilor PvP

- `MatchScreen` + `ArenaMatchController`: VS → gameplay → rezultat, evenimente → VFX/SFX/haptics, tutorial, rematch, oponent `HouseCat` (BOT etichetat).
- **Online 1v1 real nu e implementat end-to-end** (lipsește match-sync client + UI host/join în Lobby).

## 9. Starea progresiei și a trofeelor

- `Player.trophies/coins`; `tier` la [300, 800, 1500, 2000]; `houseRooms` la [0, 300, 800, 1500] cu 3 house cats fiecare (Puf/Misu/Toto, Nori/Kiko/Biscuit, Marmalade/Tofu/Crouton, Shadow/Nimbus/Aurora).
- `result()`: +30/-10, floor pe pragul casei atins.
- `claimDaily()` +200 coins; `RewardCalendar` 7 zile [100,150,200,300,400,600,1000].
- **Duplicare**: `showTrophyRoad` (dialog) vs `Turul casei` (House Tour) — de unificat ca **DRUMUL TROFEELOR**.

## 10. Starea Shop-ului și economiei

- `coins` = Lăbuțe (câștigate: +200 daily, +150 win). `owned` = accesorii.
- `ShopScreen`: CADOU ZILNIC + 2 pachete cosmetice LEI (14.99, 17.99), `PurchaseService` indisponibil (fără billing).
- `catalog.coinBundles`: 6 pachete IAP Lăbuțe — **nefolosite**.
- `economy.dart`: propune `pawsPrice` 2500/cosmetic (earned) — **contradice** contractul (paws never sold) și viziunea originală (IAP paws).

## 11. Starea avatarului personalizat

- **Nu există avatar separat de pisica jocului.**
- `Player.photo` (base64) e afișat de `CatAvatar` când `allowPhoto`; `image_picker` în profil — parked.
- `fur/eyes/ears/pattern/power` = personalizarea pisicii de joc (`Custom`), nu avatarul userului.
- `CloudProfile` **nu** sincronizează `name`/`photo` → avatarul rămâne local (nu se pierde la Google link, dar nici nu se sincronizează între dispozitive).

## 12. Starea Firebase și Friend Rooms

- `CPA_ONLINE_BACKEND=firebase`: anonymous auth, Google link/restore (parent gate), cloud profile cu revision, rooms 6-char coduri + claim atomic + expiry client-side (fără TTL — Spark), matches/emotes rules, `onMoveCreated` push.
- **Limită**: `backend/functions` necesită Blaze; pe Spark nu pot rula → FCM push your-turn indisponibil; alternativă = watch client-side.
- Backend **nu e deployat** încă de owner (`firestore.rules` + `functions`).

## 13. Starea Android și release

- `applicationId games.oneear.catpawsarena`, targetSdk 36, `google-services` plugin activ dacă fișierul există.
- Release fallback debug fără `key.properties`; CI are secrete (owner le-a adăugat).
- `google-services.json` cu OAuth client e commitat.

## 14. Riscuri și incompatibilități

1. Team/Events fake locale vs contract parked — restaurarea taburilor nu le poate marca live.
2. Shop paws IAP contrazice contractul (paws earned) — decizie owner.
3. Cloud Functions pe Spark — decizie (fără functions → polling client-side pentru your-turn).
4. Friend duel end-to-end lipsește — P1 mare.
5. Avatar separat lipsește — P2 mare.
6. Photo avatar parked + `image_picker` de eliminat înainte release.
7. Daily Board de eliminat; House Tour/Trophy Road de unificat.
8. Cloud save nu e verificat ca declanșat automat în gameplay.

## 15. Lista de reparații pe lane-uri

Vezi `docs/RESTORATION_PLAN.md`.

## 16. Ordinea recomandată

P0 (eliminări/unificări sigure) → P1 (friend duel + economiei decizie) → P2 (5 tab-uri + redesign + avatar) → P3 (polish + APK final).

## 17. Decizii care necesită aprobarea proprietarului

1. **Economie**: pachete Lăbuțe IAP (viziune originală) vs cosmetics-only (contract). Necesită schimbare de contract + billing.
2. **Team/Evenimente**: conținut sigur de afișat (coming soon / local honest) vs rămân hidden.
3. **Avatar personalizat**: metodă (foto → avatar, editor specii/culori, sau combinat) + sincronizare cloud.
4. **Firebase**: Functions/Blaze pentru push vs Spark + polling client-side.
5. **Deploy** `firestore.rules`/`functions` de către owner.
6. Praguri trofee/camere — neschimbate fără aprobare.
