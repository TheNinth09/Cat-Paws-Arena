# Gameplay, Performance & UI Audit — Cat Paws Arena

Audit efectuat pe codul `main` + verificări pe dispozitiv
(emulator Android 14, 320×640, build `--profile` cu `--dart-define=CPA_FRAME_PROBE=true`).

## Runda 2 (v48) — navigare, audio, căderi, performanță

| Problemă | Gravitate | Cauză exactă | Stare |
|---|---|---|---|
| Bandă maro **în timpul navigării** | **P0** | `AnimatedSwitcher(220ms)` făcea cross-fade între fundalurile paginilor — la mijlocul tranziției ambele imagini ~50% alfa și tavanele se spălau spre maro-ul scaffold-ului; în plus fundalul se schimba instant la `onPageChanged` în timp ce conținutul încă aluneca → tavan gol vizibil | ✅ reparat — fundalurile alunecă sincronizat cu `pages.page` |
| Muzica continuă în background | **P0** | `DuelMusic.sync()` — `_player.play()` e async; dacă `setBackgrounded→pause()` ajungea în timp ce play-ul încă se rezolva (decodare sursă), redarea pornea DUPĂ pauză și rămânea în fundal; `pause()` pe o redare care a fugit de cursă nu mai oprea nimic | ✅ reparat — gard pe promisiunea play() + `stop()` definitiv la background |
| Căderea pieselor nenaturală | **P0** | `Fell` folosea `dur: 0.16` FIX indiferent de distanță (1 sau 6 celule — aceeași durată → teleportare pe căderi lungi, plutire pe cele scurte); curbă `t²` fără aterizare | ✅ reparat — durată proporțională cu distanța + curbă accelerație→deccelerație |
| Pagina PISICI cu conținutul de jos tăiat | **P2** | Padding de jos 24px — ultimul buton părea tranchiat la margine | ✅ padding 72px |

### Fix-uri runda 2 — detalii

**Navigare (`lib/home_screen.dart`):** `AnimatedSwitcher` cross-fade înlocuit cu
`AnimatedBuilder(animation: pages)` — fundalurile paginilor alunecă pe orizontală
în sincron perfect cu `PageController.page`: `bg_base` la `-(pos-i)*w`, `bg_next`
la `(i-pos)*w`. Ambele imagini rămân 100% opace în orice moment → zero spălare
maro; arta se mișcă literalmente odată cu conținutul (comportament tip
Royal Match/Brawl Stars).

**Audio (`lib/duel_audio.dart` `DuelMusic`):**
- `sync()`: după ce promisiunea `play()` se rezolvă, dacă `_started` a căzut
  între timp (pauză/background cerut în cursa decodării sursei) → `stop()`
  imediat — redarea nu mai poate fugi de pauză.
- `setBackgrounded(true)`: `stop()` definitiv (nu doar `pause()`) — curăță
  orice redare activă sau în cursă; la `resumed` `sync()` repornește bucla
  de la început (acceptabil pentru un bed muzical).
- Observatorii existenți (home + match) păstrați; toggle-ul `p.music`
  rămâne sursa de adevăr; fără instanțe duplicate (`_started` guard).

**Căderi (`lib/board_game.dart`):**
- `Fell`: `dur = (0.09 + rows*0.042).clamp(0.11, 0.32)` — 1 celulă ≈ 0.13s,
  6 celule ≈ 0.32s — aceeași gravitație percepută pe orice distanță.
- `Refilled`: spawn deasupra tablei păstrat; durata acum include distanța
  off-board (`row + 1.6`), deci piesele noi "cad" cu aceeași fizică.
- Curbă nouă `_fallCurve`: accelerație pătratică până la 82% (95.5% drum),
  apoi ease-out pătratic până la 100% — aterizare lină; `squash`-ul existent
  (dip 0.24 sin, 0.12s) poartă impactul vizual.

**PISICI (`lib/cats_screen.dart`):** padding de jos al ListView-ului 24→72 —
butoanele de jos nu mai par tranchiate la marginea ecranului.

### Propuneri P1 care așteaptă aprobarea ta (neimplementate)

Mecanici neschimbate — doar straturi vizuale noi, fiecare adaugă cod:

1. **Reacții ale pisicilor în HUD** — avatarurile din colțuri anima scurt
   (bounce/tilt) la cascada proprie ≥x3 sau la power; la atacul advers
   (sabotage) — "flinch". Doar widget, fără reguli noi.
2. **Feedback combo crescător** — etichete "+N puncte" deja existente;
   propun tier-uri vizuale: combo 2 → text mai mare + scântei, combo 3+ →
   flash de ramă aurie (tot în painter, ~40 linii).
3. **Tensiune la final** — în ultimele 15s (deja Fever x2) propun puls
   discret al barei tug-of-war către lider; la scor apropiat (<5% diferență)
   culoarea barei pulsa alb.
4. **Final de meci** — victoria are deja scenă dedicată; propun confetti
   de lăbuțe peste ecranul de rezultat (painter existent reutilizat).

Acestea NU ating regulile, scorul, economia sau puterile — confirmă și le
implementez în runda următoare.

---

## Runda 1 (v47) — rezumat anterior

| Problemă | Gravitate | Cauză exactă | Stare |
|---|---|---|---|
| Bandă maro mare sus pe ecrane | **P0** | `SafeArea` consuma integral `viewPadding.top` (înălțimea status-bar-ului ascuns / a decupajului camerei) + padding-uri fixe suplimentare (`SizedBox(8)`, `Padding(top:10)`) → zonă moartă de artă | ✅ reparat |
| Puterea pisicii greșită în meci | **P0** | `player.power` (alegerea din editor, valabilă doar pentru pisica Custom) era trimis în config-ul engine și în camerele online indiferent de pisica selectată | ✅ reparat |
| Rebuild complet al board-ului la fiecare frame | **P0** | `BoardView._onTick` apela `setState` la fiecare tick de animație → ~60 rebuild-uri/sec ale întregului sub-arbore (LayoutBuilder, Listener, GestureDetector, Stack, bannere) | ✅ reparat |
| „PISICA MEA" ambiguu în profil | **P0** | Eticheta amesteca identitatea jucătorului cu selecția pisicii de duel | ✅ reparat |
| Spațiere dead-zone lăsată de layout | **P1** | HUD împins în jos de inset + gap-uri fixe | ✅ reparat prin același fix |

## Sumar rezultate runda 1

| Problemă | Gravitate | Cauză exactă | Stare |
|---|---|---|---|
| Bandă maro mare sus pe ecrane | **P0** | `SafeArea` consuma integral `viewPadding.top` (înălțimea status-bar-ului ascuns / a decupajului camerei) + padding-uri fixe suplimentare (`SizedBox(8)`, `Padding(top:10)`) → zonă moartă de artă | ✅ reparat |
| Puterea pisicii greșită în meci | **P0** | `player.power` (alegerea din editor, valabilă doar pentru pisica Custom) era trimis în config-ul engine și în camerele online indiferent de pisica selectată | ✅ reparat |
| Rebuild complet al board-ului la fiecare frame | **P0** | `BoardView._onTick` apela `setState` la fiecare tick de animație → ~60 rebuild-uri/sec ale întregului sub-arbore (LayoutBuilder, Listener, GestureDetector, Stack, bannere) | ✅ reparat |
| „PISICA MEA" ambiguu în profil | **P0** | Eticheta amesteca identitatea jucătorului cu selecția pisicii de duel | ✅ reparat |
| Spațiere dead-zone lăsată de layout | **P1** | HUD împins în jos de inset + gap-uri fixe | ✅ reparat prin același fix |

## P0-1 — Bara maro din partea de sus

**Cauză reală (nu un petec de culoare):** `SafeArea` înconjoara conținutul pe toate
paginile full-bleed. Pe Android, `viewPadding.top` raportează înălțimea barei de
stare **chiar și când bara e ascunsă** (immersive), iar pe telefoane cu decupaj al
camerei valoarea e și mai mare (~30–90px). `SafeArea` transforma tot în padding,
deci HUD-ul începea jos iar deasupra rămânea doar fundalul — tavanul lemnului, adică
o bandă maro goală. Peste asta se adăugau gap-uri fixe (`SizedBox(height: 8)` în
`home_screen`, `Padding(top: 10)` în `match_screen`).

**Soluție:** widget nou `HudSafeArea` (`lib/ui_widgets.dart`) — păstrează clearance-ul
real pentru decupajul camerei dar cap-ează insetul raportat (top ≤ 40px, bottom ≤ 24px;
left/right trec neatăinse pentru cutout-uri landscape). Înlocuit `SafeArea` cu
`HudSafeArea` pe paginile full-bleed; eliminate gap-urile fixe suplimentare.

**Fișiere:** `lib/ui_widgets.dart` (widget nou), `lib/home_screen.dart`,
`lib/match_screen.dart` (faza playing), `lib/vs_screen.dart`,
`lib/profile_screen.dart`, `lib/boot_screen.dart`, `lib/house_tour_screen.dart` (2×).

**Test:** captură emulator înainte/după — HUD-ul e lipit de marginea superioară,
fără bandă moartă; conținutul nu intră sub zona camerei (inset real păstrat).
Capturi: `build/perf_base_match.png` vs `build/perf_new_match.png`.

## P0-2 — Puterea pisicii selectate

**Cauză reală:** pagina PISICI afișa puterea per-pisică (Tzuki→0 Zoomies,
Bubble→1 Shadow Pounce, Custom→`player.power` ales în editor), dar
`match_controller.dart` construia `MatchConfig` cu `player.power` brut, iar
`friend_room.dart` trimitea același `player.power` în camerele online. Rezultat:
Tzuki/Bubble afișau o putere și jucau alta (în special Bubble, mereu rupt când
`player.power ≠ 1`).

**Soluție — sursă unică de adevăr:**
- `lib/catalog.dart`: funcția `powerForCat(cat, customPower)` — Tzuki→0,
  Bubble→1, orice altceva (Custom)→`customPower.clamp(0,2)`.
- `lib/profile.dart`: `Player.selectedCatPower` — getter ce rezolvă
  `powerForCat(cat, power)` pentru pisica selectată.
- Consumatori actualizați: `match_controller` (config engine + `playerPower`
  pe calea legacy), `friend_room` (createRoom + joinRoom), `cats_screen`
  (afișarea etichetei folosește aceeași funcție).

Datele salvate nu s-au schimbat — `player.power` rămâne alegerea din editor,
`player.cat` rămâne pisica de duel; doar interpretarea e unificată.

**Test (automat):** `test/duel_test.dart` › grup `selected-cat power resolution`:
- `powerForCat` pentru toate cele 3 pisici × toate alegerile din editor;
- `Player.selectedCatPower` la comutarea pisicii;
- `testWidgets`: engine-ul pornește cu puterea pisicii (Tzuki→zoomies,
  Bubble→shadowPounce, Custom→laserChase cu `power=2`).

**Test (dispozitiv):** pe emulator — selectat BUBBLE din pagina PISICI
(„PUTERE • Shadow Pounce" afișat), pornit meci → butonul de putere arată
„POUNCE 0%" cu iconița Shadow Pounce (înainte ar fi fost ZOOMIES).
Captură: `build/p2_bubble_match.png`.

## P0-3 — Performanța gameplay-ului

**Cauză reală găsită:** `BoardView._onTick` (tickerul de animații) apela
`setState(() {})` ori de câte ori existau fx/meta în desfășurare — adică la
fiecare frame în Frenzy, unde cascada botului + a jucătorului țin fx-uri
aproape continuu active. Rezultat: ~60 rebuild-uri/sec ale sub-arborelui
`LayoutBuilder → Listener → GestureDetector → Stack → CustomPaint + bannere`
— cost de build+layout la fiecare frame deși se schimba doar conținutul pictat.

**Soluție:** repaint fără rebuild —
- `ValueNotifier<double> _frame` (ceasul de frame) în `BoardViewState`;
  `_onTick` îl bumpează în loc de `setState` (inclusiv cât bannerele zboară).
- `_BoardPainter` primește `nowSource` (`ValueListenable<double>`) și îl
  pasează la `super(repaint:)` → `CustomPaint` re-pictează direct la
  notifier, fără rebuild de widget.
- `_bannerLayer` e învelit în `ValueListenableBuilder` pe același `_frame` —
  doar stratul de bannere se reconstruiește per frame (sub-arbore minuscul).
- `setState` rămâne doar pentru schimbări structurale: sprite-uri încărcate,
  `play()`, selectare celulă, `_finishAll`, schimbări de semnale.

**Măsurători (emulator, build --profile, probe activ):**
- Înainte: **~48 FPS** în timpul meciului Frenzy.
- După: **~60 FPS** constant în același scenariu.
- Frame-time: probe-ul nu a raportat spike-uri peste pragul de afișare
  (0.0 ms afișat în ambele; emulatorul SwiftShader denaturează valorile
  absolute — măsurarea pe telefon real rămâne de confirmat).

Alte componente verificate ca sănătoase (fără schimbare): `_boardLayerCache`
+ `RepaintBoundary` (layer-ul board-ului nu se reconstruiește pe notificările
controllerului), `refresh()` coalește notificările în microtask (max 1/frame),
pool de `AudioPlayer` low-latency pentru SFX, imagini board decodate o singură
dată la `targetWidth: 320`.

## P0-4 — Separare profil jucător ↔ pisici de duel

- `lib/profile_screen.dart`: eticheta `PISICA MEA`/`MY CAT` →
  `PISICA EDITATĂ`/`EDITED CAT` (este pisica customizată live — avatarul
  jucătorului, nu selecția de duel). Comentariul documentează acum explicit
  separarea: `avatarArt` = identitatea jucătorului; `Player.cat` = pisica de
  duel, gestionată exclusiv din pagina PISICI.
- `test/cats_test.dart` actualizat pentru noua etichetă.

## P1 — Vizual duel + coerență ecrane

- `battle()`: padding-top redus de la 10 + SafeArea la `HudSafeArea` + 4 —
  HUD-ul (avataruri, tug-of-war, ceas) stă lipit de margine; tabla 7×7 ocupă
  restul prin `Expanded` → focalizarea vizuală e pe tablă, cum se cere.
- Toate paginile full-bleed (VS, profil, boot, drumul trofeelor) folosesc
  același `HudSafeArea` → înălțimea dead-zone-ului e consistentă peste tot.
- Suite de regresie vizuală existente (320×568, 360×640, 390×844, 430×932
  × 1.0/1.5 scale) trec neschimbate — niciun overflow nou.

## Probleme rămase deschise / de verificat pe telefon

- **Măsurătorile FPS** sunt de pe emulator (SwiftShader) — relative, nu
  absolute. Re-măsurarea pe telefon real rămâne obligatorie (nu marcăm
  testarea pe telefon ca făcută).
- `HudSafeArea` cap-ează top-inset la 40px — acoperă toate decupajele Android
  cunoscute (~24–40px); pe un dispozitiv cu raport de inset aberant (>40px)
  HUD-ul ar putea atinge marginea camerei — de verificat fizic.
- Echilibrul botului „Puf" rămâne neschimbat (separat, necesită aprobare).
- Bot-ul joacă simultan — în testul de dispozitiv scorul botului crește în
  timp real, deci Frenzy-ul funcționează ca design.

## Verificări rulate

- `flutter analyze` — curat.
- `flutter test` — 133/133 (inclusiv cele 3 teste noi de putere).
- Build `--profile` instalat pe emulator — lobby, PISICI (Tzuki→Bubble→etape),
  meci Frenzy complet, 60 FPS, putere corectă pe Bubble, zero crash logcat.
