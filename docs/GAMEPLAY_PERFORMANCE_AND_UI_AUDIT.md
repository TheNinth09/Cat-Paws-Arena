# Gameplay, Performance & UI Audit — Cat Paws Arena

Audit efectuat pe codul `main` (post v46, `fa7ae21`) + verificări pe dispozitiv
(emulator Android 14, 320×640, build `--profile` cu `--dart-define=CPA_FRAME_PROBE=true`).

## Sumar rezultate

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
