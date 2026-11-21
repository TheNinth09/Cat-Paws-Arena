# Audit APK și reparații — Cat Paws Arena

**Data auditului:** 2026-11-21 · **Auditor:** Devin (orchestrator)
**APK auditat:** `apk-test-0.7.0-45` (98,857,339 bytes, SHA-256 `9cfe06b1…bd61b9`), construit din `main@205b9f5`
**APK reparat:** `apk-test-0.7.0-46`, construit din `main` după fixurile de mai jos

> Notă de stoc: ultimul release publicat este **v45**, nu v32 cum indica cerința — lista completă de release-uri a fost verificată prin GitHub API. APK-ul v45 corespunde exact commit-ului `205b9f5` de pe `main` (working tree curat la build).

---

## A. Probleme CONFIRMATE (cu dovezi)

### P0 — Online oprit în toate APK-urile publicate (v40–v45)

| | |
|---|---|
| **Problemă** | Duelurile cu prietenii sunt moarte în APK-urile publicate: camera afișează „Această funcție necesită configurarea serviciilor online". |
| **Fișier / zonă** | `lib/online/online_config.dart:13` — `String.fromEnvironment('CPA_ONLINE_BACKEND')` |
| **Cauză** | Comanda de build `flutter build apk --release` nu a primit niciodată `--dart-define=CPA_ONLINE_BACKEND=firebase`; în release, `OnlineMode.configured` ⇒ `none` ⇒ `OnlineServices.start()` returnează `null` ⇒ `OnlinePlay.services` neinițializat ⇒ `showFriendRoom` afișează „indisponibil" (`lib/shell/friend_room.dart:18-21`). |
| **Gravitate** | **P0** — funcție-cheie (duel prieten) nefuncțională în livrabilele publicate. |
| **Soluție aplicată** | Build v46 cu `--dart-define=CPA_ONLINE_BACKEND=firebase`; instrucțiunea fixată în `AGENTS.md` pentru toate build-urile viitoare. |
| **Dovada reparației** | Pe emulator (Android 14): `FirebaseApp` se inițializează la boot, auth anonim reușește (`FirebaseAuth: …user 983fpqpA0HRg2ZTfiahpHAA2zw42`), camera reală afișează codul **4K2CFX** + „Așteptăm prietenul să intre…" — scrierea Firestore trece regulile fără `PERMISSION_DENIED`. |
| **Config externă** | Da — flag de build. `google-services.json` există deja în repo. |

### P1 — Semnare release cu cheia de debug

| | |
|---|---|
| **Problemă** | APK-urile release sunt semnate cu certificatul `CN=Android Debug`. |
| **Fișier / zonă** | `android/app/build.gradle.kts:62-72` — fallback explicit la `signingConfigs.debug` când `android/key.properties` lipsește. |
| **Cauză** | `key.properties` nu există pe mașina de build (verificat). |
| **Gravitate** | **P1** — funcționează pentru sideload/test, dar nu poate urca în Play Console și orice schimbare ulterioară de cheie va bloca update-urile peste instalare. |
| **Soluție aplicată** | Documentat; **necesită decizia proprietarului** — generarea unui keystore de release + `key.properties` (nu generez secrete fără aprobare). |
| **Dovada** | `apksigner verify --print-certs` ⇒ `Signer #1 certificate DN: C=US, O=Android, CN=Android Debug`. |
| **Config externă** | Da — keystore release + parole; de aprobat. |

### P2 — Produsele cu LEI nu erau marcate preventiv ca indisponibile

| | |
|---|---|
| **Problemă** | Cardurile cu preț în LEI (pachete lăbuțe, pachete cosmetice, hero deal) arătau ca butoane de cumpărare active; abia la tap apărea mesajul „Achizițiile nu sunt disponibile încă". |
| **Fișier / zonă** | `lib/shop_screen.dart` — `_PackCard`, `ShopOfferCard`, `_HeroDealCard` |
| **Cauză** | `UnavailablePurchaseService` refuza corect tranzacția (zero acordare de produse, zero simulare), dar UI-ul nu marca starea înainte de tap. |
| **Gravitate** | **P2** — onest la tap, dar poate părea cumpărabil; politica Families cere claritate. |
| **Soluție aplicată** | Chip `ÎN CURÂND` pe fiecare card cu LEI (paw packs), badge `ÎN CURÂND` pe ofertele cosmetice, text `8.99 LEI • ÎN CURÂND` pe hero deal. Prețul rămâne vizibil ca informație; tap-ul încă afișează mesajul onest. |
| **Dovada reparației** | `flutter analyze` curat; testele shop 35/35 trec (prețurile rămân `find.text`, comportamentul la tap neschimbat). |
| **Config externă** | Integrarea Google Play Billing rămâne nefăcută — **raport în secțiunea D**. |

### P2 — Documentele contractau modul vechi (ture), codul livrează Frenzy

| | |
|---|---|
| **Problemă** | `AGENTS.md` decizia 1 și `docs/contract.md` §3 descriau duelul cu ture (3×30s, tablă comună); implementarea curentă e Frenzy (60s simultan, table separate) — aprobat explicit de proprietar ulterior scrierii documentelor. |
| **Fișier / zonă** | `AGENTS.md:13`, `docs/contract.md:69-76` |
| **Gravitate** | **P2** — contradicție contract ↔ cod; orice lane care citește contractul reconstruia reguli greșite. |
| **Soluție aplicată** | **Documente actualizate** (nu cod — comanda proprietarului pentru Frenzy e ulterioară și explicită): decizia 1 rescrisă pentru Frenzy; contractul poartă revizia „Frenzy — simultaneous 60s" cu semantica veche păstrată ca notă legacy pentru `MatchConfig.duel()` / replay. |
| **Config externă** | Nu. |

---

## B. Verificări făcute pe emulator (Android 14, x86_64, 320×640)

Dovezi — capturi în `build/audit_*.png`:

| Flux | Rezultat |
|---|---|
| Instalare + lansare | ✅ `Success`, fără FATAL/exception în logcat |
| Fullscreen imersiv | ✅ zero bară status/navigație; arta la pixelul 0 sus/jos |
| Lobby / MAGAZIN / PISICI | ✅ randare curată la 320×640 |
| ECHIPĂ blocată | ✅ „SE DEBLOCHEAZĂ LA 500 TROFEE" + progres 0/500 |
| Dialog moduri | ✅ „CONTRA PISICILOR CASEI — marcați BOT" / „CAMERĂ DE PRIETEN — ONLINE când serviciul este configurat" |
| Meci Frenzy vs bot | ✅ ceas 00:59→00:42, scor live 215→880, sabotaj 4 cutii pe tabla mea, ZOOMIES 60% |
| FEVER | ✅ `00:03` roșu + badge `x2` + „ZOOMIES FEVER x2!" + ramă flăcări |
| Rezultat | ✅ „ÎNFRÂNGERE 215—4445, -25 Trofee", REVANȘĂ/ACASĂ |
| Profil | ✅ SCOR MAXIM 215 + 1 meci jucat persistă |
| Restart forțat | ✅ datele jucătorului păstrate (SharedPreferences) |
| Firebase (v46) | ✅ auth anonim real + cameră 4K2CFX creată + anulare curată |

## C. Verificări statice ale build-ului

| Check | v45 publicat | v46 reparat |
|---|---|---|
| applicationId | `games.oneear.catpawsarena` ✅ | idem |
| versionCode / versionName | 45 / 0.7.0 ✅ | **46** / 0.7.0 |
| targetSdk / compileSdk | 36 / 37 ✅ | idem |
| `AD_ID` / SDK-uri reclame | absent ✅ (manifest `tools:node="remove"`) | idem |
| Permisiuni | INTERNET, POST_NOTIFICATIONS, WAKE_LOCK, ACCESS_NETWORK_STATE, VIBRATE, USE_BIOMETRIC, C2DM, GSF — fără AD_ID ✅ | idem |
| Semnare | debug ⚠️ | debug ⚠️ (P1 deschis) |
| Online flag | **lipsă (P0)** | **firebase ✅** |
| CI | build doar debug ⚠️ | neschimbat |

**Dimensiune (v45, ~97 MB):** `lib/` 50.7 MB (3 ABI-uri), `assets/` 40.6 MB, dex 4 MB. Optimizări sigure propuse: `--split-per-abi` (arm64 singur ≈ −33 MB) sau AAB la publicare; ~2.0 MB asset-uri nereferențiate (`music_battle.wav`, `paws_pack_*`, câteva `sfx_` din `generated/audio`, `icon_*` nefolosite) — ștergere opțională, asset-urile originale rămân neatinse.

## D. Ce NU funcționează încă / riscuri

| Element | Stare |
|---|---|
| **Google Play Billing** | Neimplementat — `UnavailablePurchaseService` returnează eșec onest. Pentru vânzări reale: `in_app_purchase`/`purchases_flutter`, produse în Play Console, cheie de upload, testeri licențați. **Nu activ fără aprobare.** |
| **Semnare release** | Necesită keystore + `key.properties` + parole — **de aprobat** (P1). |
| **Cloud Functions** (`onMoveCreated` push) | Scrisă, type-check în CI, dar **nedeployabilă pe Spark** — push „e rândul tău" rămâne indisponibil până la Blaze sau polling client. Frenzy e real-time, deci nu blochează. |
| **Join room al doilea dispozitiv** | Crearea camerei e verificată pe un singur emulator; **alăturarea reală + sincronizare între două telefoane** necesită test cu două dispozitive. Testele `online_test.dart` (FakeCloud, 41) acoperă convergența logică, nu radio-ul real. |
| **FPS pe hardware real** | SwiftShader pe emulator nu e reprezentativ — 60 FPS trebuie reconfirmat pe telefon fizic. |
| **Echilibru bot** | Botul „Puf" (nivel 0) a produs ~4.400 puncte/60s — prea puternic pentru primul adversar; risc pentru gate-ul 1 (jucători noi). Schimbarea echilibrului = decizia proprietarului. |
| **Deadline forfeit 24h** | `match_store.dart:16` — păstrat din designul lent; în Frenzy are rol marginal (meciul e sincron). Inofensiv, documentat. |
| **Cod mort** | `lib/shell/daily_board.dart` — UI eliminat, fișierul rămâne doar pentru testul store-ului (P3). |
| **Play Store upload** | Necesită AAB + keystore release + `in_app_purchase` dacă monetizarea intră în scope — totul de aprobat. |
| **Firebase reguli deploy** | `backend/firestore.rules` e testat pe emulator (teste JS); deploy-ul pe proiectul real nu e verificabil fără consolă — camera creată pe dispozitiv a trecut regulile live ✅. |

## E. Inventar teste automate

- `flutter analyze` — curat (0 issues) pe `main` după fixuri.
- `flutter test` — 130/130 la ultimul run complet (inclusiv 35 shop+shell după marcajele `ÎN CURÂND`).
- `dart test` engine — 71/71 (11 teste Frenzy: ceas, fever ×2, sabotaj, determinism).
- `backend` rules tests — nu rulate local (emulatorul Firebase nu e instalat aici); sintaxa validată cu `node --check`; CI le rulează pe emulator.
- `flutter build web --release` ✅; `flutter build apk --release --dart-define=…` ✅ v46.

## F. Reparat în acest ciclu

1. Build republicat **cu** `CPA_ONLINE_BACKEND=firebase` — online viu (P0).
2. `ÎN CURÂND` vizibil pe toate produsele cu LEI (P2).
3. `AGENTS.md` decizia 1 + `docs/contract.md` §3 — reconcileiate cu Frenzy aprobat (P2).
4. `AGENTS.md` workflow — flag-ul online trecut explicit în instrucțiunea de build (prevenție P0).

## G. Rămas deschis (așteaptă decizie/aprobare)

- Keystore release + `key.properties` (P1).
- Google Play Billing real (P2, costuri/console).
- Blaze pentru push `onMoveCreated` — sau acceptăm „fără push" (P3 în Frenzy).
- Echilibru bot nivel 0 (P3, gate 1).
- Test cu **două dispozitive reale** pentru join/sincronizare radio reală (P1 de verificat uman).
- `--split-per-abi` sau AAB pentru următorul APK publicat (P3, ~−33 MB).
