# Core Loop MVP — Design Spec

**Data:** 2026-06-02
**Status:** Approved, ready for implementation plan
**Milestone:** M1 — Vertical slice

## Cel

Minimalna grywalna pętla testująca core fantasy: *"nigdy nie jesteś bezpieczny, tylko lepiej wybierasz, kiedy się rozproszysz"*.

Sukces = po 2 minutach grania random tester mówi *"chyba tak, mógłbym jeszcze raz"*. Jeśli loop jest płaski, żadne sprite'y go nie uratują — dlatego ten test idzie PRZED art-direction'em.

## Kontekst i scope

Ten MVP redukuje pełen design z `concept.md` / `architecture.md` do **jednej grywalnej sytuacji**:
- jedna strefa (VILLAGE)
- jeden typ hazardu (Tractor)
- jeden typ notyfikacji (Glance / tap-dismiss)
- jeden pas (wiejska ścieżka przez pola)
- placeholdery zamiast art-style

Architektura wszystkich systemów jest jednak **data-driven od początku** — żeby dodanie kolejnych stref/hazardów/notyfikacji w M2-M3 było zmianą danych, nie kodu.

## Założenia wynikające z brainstormingu

1. **Setting wsi = wiejska ścieżka przez pola**, nie chodnik. Hazardy naturalistyczne (traktor, zwierzęta, kałuża). Progresja stref jako progresja biomu: natura → przedmieście → miasto (cywilizacja się zamyka).
2. **Liczba pasów rośnie ze strefą:** VILLAGE 1 → SUBURB 2 → CITY 3. W MVP testujemy core loop bez lane-switchingu.
3. **Willpower = deadline, nie countdown obowiązkowy.** Gracz decyduje *kiedy* w oknie willpower wyciągnąć telefon. Brak decyzji → forced phone na końcu willpower'a.
4. **Stop ma dwa tryby:**
   - ROAD mode: tap STOP → świat stoi *dopóki hazard nie minie*, potem auto-resume
   - PHONE mode: tap STOP → świat stoi *1 sekundę*, potem auto-resume *regardless of obstacle*
   To diegetyczna metafora rozproszonej uwagi.
5. **Powiadomienia jako dane od początku** — content × interaction type. MVP używa jednej kombinacji (`GLANCE` + `TAP_X`), ale model jest extensible bez refaktoringu. To samo API skonsumuje przyszłe reklamy (patrz `memory/project_monetization_ads_as_notifications.md`).

## Pętla rozgrywki

```
START
  ↓
ROAD: auto-walk po wiejskiej ścieżce, świat scrolluje pod graczem
  ↓
[timer ~5-8s] notification arrives → HUD pokazuje ikonkę + willpower bar (3s)
  ↓
  ┌─ Tap CHECK_PHONE wcześnie     ─→ PHONE_INTERRUPT (voluntary)
  └─ Zwlekanie 3s → willpower=0   ─→ PHONE_INTERRUPT (forced)
  ↓
PHONE_INTERRUPT: telefon wjeżdża z góry, zasłania 80% ekranu (bottom 20% nadal widać)
  ↓
Tap DISMISS → telefon zjeżdża → ROAD → następna notyfikacja po 5-8s
```

W dowolnym momencie ROAD lub PHONE_INTERRUPT:
```
Traktor wjeżdża z boku, leci poprzecznie przez ścieżkę
  ↓
Gracz tappuje STOP:
  • ROAD mode  → świat stoi → traktor przejeżdża → auto-resume gdy bezpiecznie
  • PHONE mode → świat stoi 1s → auto-resume *regardless of traktor*
  ↓
Brak STOP w porę → kolizja → GAME_OVER
```

## Gracz, świat, hazard

### Gracz

- Stała pozycja na ekranie (np. y_screen ≈ 70%, x = 0 = środek ścieżki)
- Stan: `WALKING` (świat scrolluje) / `STOPPED` (świat zamarza)
- Placeholder: prostokąt 1×2 jednostek, kolor neutralny
- Brak lane-switchingu w MVP (1 pas)
- Inputy (klawiatura, MVP):
  - `Space` — STOP (działa w obu trybach, różne timeouty)
  - `E` — CHECK_PHONE (działa tylko gdy aktywna notyfikacja)
  - `Esc` — DISMISS (działa tylko w PHONE_INTERRUPT)

### Świat

- Scrolluje pod graczem z prędkością `walk_speed` = 6 u/s (zgodnie z `architecture.md` VILLAGE)
- Chunki ścieżki (recykling): długość 20u, 6 aktywnych jednocześnie, pula 10 (reuse logiki z `architecture.md`)
- Po bokach: pola — placeholder, zielone kafle, brak interakcji

### Hazard: Tractor

- Spawn co `tractor_spawn_interval` = 25-40m (random) od ostatniego hazardu (mierzone w dystansie pokonanym przez gracza)
- Pozycja spawn'a: `tractor_spawn_lookahead` = 12-15m **przed** graczem (oś z), na boku ścieżki (x = -3, czyli poza ścieżką)
- Lateralny ruch z prędkością `tractor_lateral_speed` = 4 u/s, kierunek -x → +x
- Telegram wizualny: spawnuje się widocznie z boku, gracz ma kilka sekund reakcji
- Po wyjściu poza ścieżkę (x > +3): traktor despawn, "safe" signal do logiki STOP
- Collision: AABB overlap Player × Tractor; Tractor należy do Layer 3 (Hazards), Player do Layer 2

**Zachowanie traktora gdy gracz STOPPED:**
- Świat scrolluje = pozycja gracza w przestrzeni świata przestaje się zmieniać
- Traktor wciąż leci lateralnie (jego ruch jest niezależny od world scroll)
- Czyli: stop wystarczająco wcześnie → traktor przejedzie przed graczem → safe

## Notyfikacja, willpower, telefon

### Cykl notyfikacji

- Start gry: `safe_window` = 5s (gracz uczy się sterowania), potem pierwsza notyfikacja
- Po każdym dismiss: nowy `safe_window` = 5-8s random, potem następna
- MVP: jedna treść placeholder ("Mama: zjadłeś coś?")

### Notification model (data)

```gdscript
# resources/notification.gd
class_name Notification extends Resource

enum InteractionType { GLANCE, ACTION, TRAP }
enum DismissAction { TAP_X, SWIPE_LEFT, ANSWER_BUTTON, READ_REPLY }

@export var content_id: String          # ID treści w puli
@export var sender: String              # "Mama"
@export var text: String                # "zjadłeś coś?"
@export var interaction: InteractionType
@export var dismiss_action: DismissAction
```

MVP używa wyłącznie `GLANCE` + `TAP_X`. Pozostałe enumy istnieją jako stuby — zostaną wypełnione w M3 bez refaktoringu.

### Willpower bar (deadline)

- Notyfikacja przychodzi → na HUD:
  - Ikonka powiadomienia (np. kolorowa kropka) — **clickable** (CHECK_PHONE)
  - Pasek willpower obok — startuje pełny, opada `willpower_max → 0`
- `willpower_max` = 3.0s (stała w MVP, krzywa per strefa w M2)
- `E` w dowolnym momencie countdownu (lub click na ikonkę) → PHONE_INTERRUPT (voluntary)
- `willpower_max` minęło bez akcji → PHONE_INTERRUPT (forced, `willpower_expired` sygnał)
- Reset paska po każdym dismiss

### Phone overlay (visualnie)

```
┌─────────────────────┐  ← top of screen
│                     │
│   PHONE FRAME       │  ← CanvasLayer z=10, slide-in z góry
│   (placeholder      │     zasłania ~80% wysokości
│   ciemny prostokąt) │
│                     │
│   [Notification     │  ← treść w środku ramki:
│    card visible]    │     sender + text
│                     │
│   [X dismiss btn]   │  ← top-right corner, ~10% szerokości
│                     │
├─────────────────────┤  ← granica telefon/droga
│ [bottom road strip] │  ← widoczne ~20%, świat scrolluje nadal
└─────────────────────┘
```

- Animacja wjazdu: 0.3s ease-out
- Animacja zjazdu: 0.2s ease-in
- Phase = `PHONE_INTERRUPT` **od pierwszej klatki animacji wjazdu** — gracz może tapnąć dismiss od razu

### Phone mode — dostępne akcje

Wszystkie akcje na klawiaturze (MVP jest keyboard-only; mouse/touch dochodzą w M2-M3):

- `Esc` → DISMISS → telefon zjeżdża → phase = ROAD
- `Space` → STOP → świat stoi 1s → auto-resume *regardless of obstacle*

Wizualnie X w rogu telefonu działa jako **affordance** (gracz widzi gdzie symbolicznie "zamyka" telefon), opcjonalnie też jako clickable button equivalent do `Esc`. W MVP nie ma "tap anywhere = stop" — STOP zawsze przez `Space`, ten sam klawisz działa w obu trybach (różny timeout).

### Metryka time_on_phone

- Akumuluje się każdą klatkę gdy `phase == PHONE_INTERRUPT`
- Liczy także czas animacji wjazdu i zjazdu (uczciwa kara za każde rozproszenie)

## Game Over

### Warunek

- Single kolizja Player × Tractor → `phase = GAME_OVER`
- Detection: AABB overlap; Tractor (Layer 3) vs Player (Layer 2) zgodnie z `architecture.md`

### Sekwencja

1. Świat zamarza natychmiast
2. 1.5s pauzy (placeholder na screen-shake i SFX, nieobowiązkowe w MVP)
3. Przejście na `game_over.tscn` przez `SceneManager.change_to`

### Ekran Game Over

```
Doszedłeś 142m.
Patrzyłeś na telefon 23% czasu.

[Spróbuj jeszcze raz]
```

- Dwie metryki z `GameState`: `distance` (m), `time_on_phone / total_time * 100` (%)
- Retry button → restart `game.tscn`
- Brak zapisu rekordów (dodajemy w M3 z localStorage)

## Architektura

### Maszyna stanów (GameState)

```gdscript
enum GamePhase { ROAD, PHONE_INTERRUPT, GAME_OVER }
```

Przejścia:
```
ROAD ── willpower_expired() OR check_phone_tap ──→ PHONE_INTERRUPT
PHONE_INTERRUPT ── dismiss_tap ──────────────────→ ROAD
ROAD ── tractor_collision ───────────────────────→ GAME_OVER
PHONE_INTERRUPT ── tractor_collision ────────────→ GAME_OVER
```

`PAUSED` z `architecture.md` — **nie w MVP**, dochodzi z app-background handlingiem później.

### Sygnały (loose coupling)

`NotificationManager` emituje:
- `notification_arrived(notification: Notification)` → HUD pokazuje ikonkę + willpower
- `willpower_expired()` → GameState wymusza PHONE_INTERRUPT
- `phone_opened(voluntary: bool)` → telemetria/debug
- `phone_dismissed()` → GameState → ROAD, reset cyklu

`HazardSpawner` emituje:
- `hazard_spawned(node: Node3D)` → opcjonalne (kamera, sfx w przyszłości)
- `hazard_cleared(node: Node3D)` → Player.stop_logic używa do auto-resume w ROAD mode

`Player` emituje:
- `collided_with_hazard()` → GameState → GAME_OVER

### Mapowanie na istniejący scaffold

| Plik | Status | Co dodać w MVP |
|---|---|---|
| `autoloads/game_state.gd` | szkielet | enum `GamePhase`, `distance`, `time_on_phone`, akumulacja w `_process` |
| `autoloads/scene_manager.gd` | szkielet | tylko `change_to(path: String)` |
| `autoloads/notification_manager.gd` | szkielet | timer cyklu, willpower countdown, sygnały |
| `autoloads/hazard_spawner.gd` | szkielet | spawn timer, instancjuje `tractor.tscn`, emit hazard_cleared |
| `autoloads/audio_manager.gd` | szkielet | **POMIJAMY w MVP** (zero SFX) |
| `game/player.gd` | szkielet | `WALKING`/`STOPPED`, kolizja, STOP & CHECK_PHONE input |
| `game/chunk_manager.gd` | szkielet | recykling 6 aktywnych chunków, pula 10 |
| `game/game_camera.gd` | szkielet | statyczna pozycja zza pleców |
| `game/game.gd` | szkielet | spina autoloady, wiąże sygnały |
| `ui/hud.gd` | szkielet | dystans, ikonka powiadomienia (clickable), willpower bar |
| `ui/phone_overlay.gd` | szkielet | slide-in/out tween, dismiss hit-area, notification card |
| `ui/game_over.gd` | szkielet | render dwóch metryk + retry |
| `ui/main_menu.gd` | szkielet | Start button → game.tscn |

### Nowe pliki

- `resources/notification.gd` — Resource model
- `resources/notifications/mama_zjadles.tres` — jedna instancja placeholder
- `hazards/tractor.tscn` + `hazards/tractor.gd` — placeholder scena traktora

## Numerki MVP

| Zmienna | Wartość MVP | Skala docelowa (M2+) |
|---|---|---|
| `walk_speed` | 6 u/s | 6 → 18 (per strefa) |
| `notification_interval` | 5-8s random | 30 → 6s |
| `willpower_max` | 3.0s | krzywa per strefa |
| `phone_stop_timeout` | 1.0s | stała |
| `tractor_spawn_interval` | 25-40m random | maleje ze strefą |
| `tractor_spawn_lookahead` | 12-15m przed graczem | stałe |
| `tractor_lateral_speed` | 4 u/s | rośnie ze strefą |
| `phone_overlay_coverage` | 80% wysokości ekranu | stałe |
| `phone_slide_in_duration` | 0.3s ease-out | stałe |
| `phone_slide_out_duration` | 0.2s ease-in | stałe |
| `game_over_delay` | 1.5s po kolizji | stałe |

Wszystkie wartości w MVP są stałymi w GDScript (`const` w odpowiednich autoloadach). Migracja do tunable Resources idzie w M2.

## Definicja "done"

MVP jest skończone gdy:

- [ ] Auto-walk po ścieżce, świat scrolluje, chunki recyklują się
- [ ] Player input: STOP, CHECK_PHONE, DISMISS — wszystkie 3 działają w odpowiednich fazach
- [ ] Spawn traktora co 25-40m, telegram, lateralny ruch, despawn, sygnał `hazard_cleared`
- [ ] STOP auto-resume działa różnie w ROAD (czeka na clear) vs PHONE (1s timeout)
- [ ] Notification co 5-8s, willpower bar 3s, voluntary CHECK_PHONE i forced expire — oba ścieżki
- [ ] Phone overlay slide-in/out, 80% pokrycia, bottom 20% pokazuje drogę
- [ ] Dismiss hit-area w rogu, reszta phone area triggeruje STOP (1s w phone mode)
- [ ] `time_on_phone` akumuluje się każdą klatkę w PHONE_INTERRUPT (z animacjami)
- [ ] Kolizja → 1.5s pauza → game_over.tscn → "Doszedłeś Xm. Patrzyłeś na telefon Y%."
- [ ] Retry button → game.tscn restart
- [ ] Walidacja `godot --headless --quit` przechodzi bez ERRORów

## Co NIE jest w MVP

Eksplicytnie out-of-scope, żeby uniknąć scope creep:

- ❌ Wiele stref (tylko VILLAGE)
- ❌ Wiele typów hazardów (tylko Tractor)
- ❌ Wiele typów notyfikacji (jedna treść, jeden dismiss gesture)
- ❌ Kolejka >1 notyfikacji jednocześnie (architektura ma queue-of-length-1 zgodnie z `architecture.md`, interfejs queue-ready)
- ❌ Audio (AudioManager pomijamy)
- ❌ Animacje postaci (placeholder bryła)
- ❌ Realistyczna ramka telefonu (placeholder ciemny prostokąt)
- ❌ Save / leaderboard
- ❌ Mobile touch input (klawiatura w MVP; touch w M2-M3)
- ❌ `PAUSED` phase
- ❌ Krzywe willpower per strefa (jedna stała wartość)
- ❌ Tunable Resources dla parametrów (stałe GDScript w MVP)
- ❌ Lane-switching (1 pas)

## Test sukcesu

Gra dwie minuty z dowolną osobą. Po grze pytanie:

> *"Czy ten loop jest dla ciebie wciągający? Zagrałbyś jeszcze raz?"*

- "Tak, jeszcze raz" → core fantasy działa → M2 (strefy, hazardy, krzywe)
- "Meh" → problem w mechanice, nie w sprite'ach → wracamy do brainstormingu

## Referencje

- `doc/concept.md` — pełna koncepcja gry, sekcje "Model rozgrywki", "Dual-view", "Mechanika silnej woli"
- `doc/architecture.md` — autoloady, sceny, system pasów, kolizje
- `doc/milestones.md` — pozycja MVP w roadmapie (M1 Vertical slice)
- `memory/project_lane_progression.md` — uzasadnienie progresji 1→2→3 pasów
- `memory/project_monetization_ads_as_notifications.md` — przyszłe podpięcie ads do tego samego pipeline'u notyfikacji
