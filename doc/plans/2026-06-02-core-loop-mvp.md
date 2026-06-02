# Distracted MVP Core Loop — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement playable M1 vertical slice — auto-walking pedestrian on rural village path, willpower-driven phone interrupts with voluntary/forced trigger, single Tractor hazard, distance + time-on-phone metrics on game over.

**Architecture:** Godot 4.4 / GDScript (typed). Adapt existing scaffold (autoloads + scene shells) rather than rebuild. Data-driven systems even in MVP — Notification as Resource (single instance), parametric values as constants ready to migrate to per-zone resources in M2. Loose coupling via signals. State machine in GameState autoload.

**Tech Stack:** Godot 4.4 (gl_compatibility renderer), GDScript typed. No GUT/test framework in MVP (per project plan, formal testing arrives in M5). Validation = `godot --headless --quit` zero ERRORs + manual playtest per task.

---

## Spec reference

Pełny spec: `doc/specs/2026-06-02-core-loop-mvp-design.md`. Plan implementuje go 1:1.

## Branch strategy

Per `CLAUDE.md`: każde zadanie developerskie = osobny branch (`feature/<issue-number>-opis`). MVP mapuje się na wiele istniejących issues (#2-#7) plus zadania bez issue. Sugerowana strategia: jedna gałąź `feature/m1-core-loop` dla całego MVP (Tasks 1-16). Alternatywa: osobne PR-y dla podzbiorów (Tasks 1-3 setup, 4-7 notifications/UI, 8-12 hazard/stop, 13-16 finish).

Pierwsza komenda po przyjściu na ten plan:
```bash
git checkout -b feature/m1-core-loop
```

## File Structure

### Modyfikowane pliki (istniejący scaffold)

| Plik | Co zmieniamy w MVP |
|---|---|
| `src/project.godot` | Dodać InputMap: `stop`, `check_phone`. Zachować `dismiss_notification`. Usunąć `lane_left`/`lane_right` (nie są w MVP). |
| `src/scripts/autoloads/game_state.gd` | Dodać `time_on_phone`, akumulację w `_process`, `reset_metrics()`. Uprościć GamePhase (zachowujemy PHONE, NIE zmieniamy na PHONE_INTERRUPT — kod krótszy, semantyka ta sama). |
| `src/scripts/autoloads/scene_manager.gd` | Dodać `change_to(path: String)`. |
| `src/scripts/autoloads/notification_manager.gd` | Refactor: usunąć JSON loading, przejść na Notification Resource. Dodać willpower countdown (`_process` lub Timer). Dodać `request_check_phone()` (voluntary trigger). Sygnały: `notification_arrived`, `willpower_expired`, `phone_opened(voluntary)`. |
| `src/scripts/autoloads/hazard_spawner.gd` | Dodać distance-based spawn (`tractor_spawn_interval` w metrach). Instancjuje `Tractor.tscn`. Forward sygnał `hazard_cleared`. |
| `src/scripts/game/player.gd` | Usunąć lane-switching (LANE_POSITIONS, touch swipe). Dodać `WalkState { WALKING, STOPPED }`. Inputy: `stop`, `check_phone`. Stop dual-mode (ROAD czeka na cleared, PHONE 1s). Kolizja z hazardem → GAME_OVER. |
| `src/scripts/game/chunk_manager.gd` | Bez zmian (działa). Może visual polish (kolor ścieżki). |
| `src/scripts/game/game_camera.gd` | Statyczna pozycja zza pleców (już ma). Bez zmian funkcjonalnych. |
| `src/scripts/game/game.gd` | Wire autoload signals do scene nodes (przy refactor NotificationManager / HazardSpawner / Player). |
| `src/scripts/ui/hud.gd` | Dystans label, notification icon (clickable + reagujący na `notification_arrived`), willpower bar. |
| `src/scripts/ui/phone_overlay.gd` | Slide-in/out tween, notification card render, dismiss button hit-area. |
| `src/scripts/ui/game_over.gd` | Render `distance` + `time_on_phone / total_time * 100` %. Retry button. |
| `src/scripts/ui/main_menu.gd` | Start button → `SceneManager.change_to("res://scenes/game/game.tscn")`. |
| Sceny `.tscn` w `src/scenes/ui/` i `src/scenes/game/` | Dodać node trees pod wymagane UI (label dystansu, willpower bar, ikonka, ramka telefonu, X button). Sceny już istnieją — uzupełniamy strukturę. |

### Nowe pliki

| Plik | Cel |
|---|---|
| `src/resources/notification.gd` | `class_name Notification extends Resource` — content/sender/text/interaction/dismiss_action |
| `src/resources/notifications/mama_zjadles.tres` | Placeholder instancja (sender="Mama", text="zjadłeś coś?", interaction=GLANCE, dismiss_action=TAP_X) |
| `src/scenes/hazards/tractor.tscn` | Tractor scene (MeshInstance3D + StaticBody3D + CollisionShape3D, Layer 3) |
| `src/scripts/hazards/tractor.gd` | Lateral motion, despawn po wyjściu poza ścieżkę, emit `cleared` signal |

### Pomijane (poza scope MVP, nie ruszamy)

- `src/scripts/autoloads/audio_manager.gd` — zostaje shell
- `src/data/notifications/notifications.json` — porzucamy (przechodzimy na Resource)

## Walidacja per task

Każdy task kończy się:
1. `cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1` — zero linii ERRORów. Warningi OK jeśli celowe.
2. Specyficzny manual check (definiowany per task).
3. `git commit` z opisem.

W MVP nie ma GUT — testy formalne w M5. Logika walidowana przez headless run + obserwację behavioru.

---

## Task 1: Foundation — InputMap + GameState metrics

**Files:**
- Modify: `src/project.godot`
- Modify: `src/scripts/autoloads/game_state.gd`

- [ ] **Step 1: Update InputMap w `project.godot`**

W sekcji `[input]` usunąć `lane_left` i `lane_right` (nie w MVP), zachować `dismiss_notification` (Escape), dodać `stop` (Space) i `check_phone` (E).

Otwórz `src/project.godot` i zamień całą sekcję `[input]`:

```ini
[input]

stop={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":32,"physical_keycode":0,"key_label":0,"unicode":32,"location":0,"echo":false,"script":null)
]
}
check_phone={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":69,"physical_keycode":0,"key_label":0,"unicode":101,"location":0,"echo":false,"script":null)
]
}
dismiss_notification={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194305,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
```

Keycode 32 = Space, 69 = E, 4194305 = Escape.

- [ ] **Step 2: Add `time_on_phone` i `reset_metrics()` do GameState**

Zamień zawartość `src/scripts/autoloads/game_state.gd` na:

```gdscript
extends Node

enum GamePhase { ROAD, PHONE, GAME_OVER }
enum Zone { VILLAGE, SUBURB, TOWN, CITY }

const ZONE_THRESHOLDS: Array[float] = [0.0, 500.0, 1500.0, 3000.0]
const ZONE_SPEEDS: Array[float] = [6.0, 9.0, 13.0, 18.0]
const ZONE_NOTIFICATION_INTERVALS: Array[float] = [30.0, 20.0, 12.0, 6.0]

signal phase_changed(new_phase: GamePhase)
signal zone_changed(new_zone: Zone)
signal score_changed(new_score: int)

var phase: GamePhase = GamePhase.ROAD
var zone: Zone = Zone.VILLAGE
var distance: float = 0.0
var time_on_phone: float = 0.0
var total_time: float = 0.0
var score: int = 0
var speed: float = 6.0

func _ready() -> void:
	reset_metrics()

func _process(delta: float) -> void:
	if phase == GamePhase.GAME_OVER:
		return
	total_time += delta
	if phase == GamePhase.PHONE:
		time_on_phone += delta

func reset_metrics() -> void:
	phase = GamePhase.ROAD
	zone = Zone.VILLAGE
	distance = 0.0
	time_on_phone = 0.0
	total_time = 0.0
	score = 0
	speed = ZONE_SPEEDS[0]

func set_phase(new_phase: GamePhase) -> void:
	if phase == new_phase:
		return
	phase = new_phase
	phase_changed.emit(phase)

func add_distance(delta_distance: float) -> void:
	distance += delta_distance
	score = int(distance)
	score_changed.emit(score)
	_update_zone()

func get_phone_percentage() -> float:
	if total_time <= 0.0:
		return 0.0
	return (time_on_phone / total_time) * 100.0

func _update_zone() -> void:
	var new_zone: Zone = Zone.CITY
	for i in range(ZONE_THRESHOLDS.size() - 1, -1, -1):
		if distance >= ZONE_THRESHOLDS[i]:
			new_zone = i as Zone
			break
	if new_zone == zone:
		return
	zone = new_zone
	speed = ZONE_SPEEDS[zone]
	zone_changed.emit(zone)
```

Zmiany vs poprzednia wersja:
- usunięte `PAUSED` z enum GamePhase (poza scope MVP)
- usunięte `reset()` → przemianowane na `reset_metrics()` z `total_time` i `time_on_phone`
- dodane `_process` z akumulacją
- dodane `get_phone_percentage()` helper

- [ ] **Step 3: Walidacja headless**

Run:
```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

Expected: zero linii zawierających "ERROR". Mogą być warningi typu "PHONE_INTERRUPT" w innych plikach (player.gd używa starej semantyki) — to OK, naprawimy w następnym tasku. Sprawdzamy że NIE pojawia się żaden error wynikający z naszych zmian.

Jeśli ERROR mówi że `phase = GamePhase.PAUSED` w jakimś pliku — sprawdź `notification_manager.gd` lub inne autoloady, zaktualizuj.

- [ ] **Step 4: Commit**

```bash
git add src/project.godot src/scripts/autoloads/game_state.gd
git commit -m "feat(state): metrics tracking — time_on_phone + total_time, reset_metrics

Dropped PAUSED phase (out of scope MVP). Added _process accumulator
for time_on_phone (during PHONE phase) and total_time. Helper
get_phone_percentage() for game over screen.

InputMap: dropped lane_left/lane_right (1-lane MVP), added stop
(Space) and check_phone (E). Kept dismiss_notification (Esc).

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 2: Simplify Player for 1-lane village

**Files:**
- Modify: `src/scripts/game/player.gd`

- [ ] **Step 1: Replace player.gd with 1-lane MVP version**

Zamień zawartość `src/scripts/game/player.gd` na:

```gdscript
extends CharacterBody3D

enum WalkState { WALKING, STOPPED }

const GRAVITY: float = 9.8

signal collided_with_hazard
signal stop_pressed
signal check_phone_pressed

var walk_state: WalkState = WalkState.WALKING

func _physics_process(delta: float) -> void:
	if GameState.phase == GameState.GamePhase.GAME_OVER:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var effective_speed: float = GameState.speed if walk_state == WalkState.WALKING else 0.0
	velocity.z = -effective_speed
	if walk_state == WalkState.WALKING:
		GameState.add_distance(effective_speed * delta)

	velocity.y -= GRAVITY * delta
	move_and_slide()

func _input(event: InputEvent) -> void:
	if GameState.phase == GameState.GamePhase.GAME_OVER:
		return
	if event.is_action_pressed("stop"):
		stop_pressed.emit()
	elif event.is_action_pressed("check_phone"):
		check_phone_pressed.emit()
	elif event.is_action_pressed("dismiss_notification"):
		if GameState.phase == GameState.GamePhase.PHONE:
			NotificationManager.dismiss_current()

func set_walking() -> void:
	walk_state = WalkState.WALKING

func set_stopped() -> void:
	walk_state = WalkState.STOPPED
```

Co usunęliśmy:
- LANE_POSITIONS / LANE_TWEEN_DURATION / SWIPE_THRESHOLD
- current_lane / _lane_tween / touch state
- _change_lane(), _handle_touch()
- lane_left / lane_right handling

Co dodaliśmy:
- WalkState enum, walk_state property
- Sygnały: collided_with_hazard, stop_pressed, check_phone_pressed
- Input handling: stop, check_phone, dismiss_notification

Stop dual-mode (auto-resume vs 1s) **nie tutaj** — to Task 12. Tutaj `Player` emituje sygnał, logikę "kiedy wrócić do WALKING" trzyma `Game.gd` lub osobny `StopController`.

- [ ] **Step 2: Walidacja headless**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

Expected: zero ERRORów.

- [ ] **Step 3: Manual playtest — auto-walk**

```bash
godot --path /Users/kamil/Projects/distracted/src/
```

Oczekiwane zachowanie:
- Game scene startuje (z main_menu jeszcze nie ma start buttona — uruchom Game scene bezpośrednio: w edytorze Project → Run Specific Scene → game.tscn). Albo tymczasowo zmień `run/main_scene` w `project.godot` na `res://scenes/game/game.tscn`, zwróć później.
- Postać startuje na środku, idzie do przodu, chunki się recyklują.
- `Space` powoduje (na razie) tylko `stop_pressed` signal (nie ma jeszcze odbiorcy) — postać nie staje, to OK na ten task.

Jeśli postać nie idzie do przodu, sprawdź czy `GameState.phase` == ROAD i czy `GameState.speed > 0`.

- [ ] **Step 4: Commit**

```bash
git add src/scripts/game/player.gd
git commit -m "refactor(player): 1-lane MVP — drop lane-switching, add WalkState

Removed: LANE_POSITIONS, current_lane, lane tween, touch swipe code.
1-lane village doesn't need lane-switching; will come back in M2
with SUBURB (per project_lane_progression memory).

Added: WalkState enum (WALKING/STOPPED), signals stop_pressed,
check_phone_pressed, collided_with_hazard. Input map updated for
new actions. Stop dual-mode logic lives outside Player (Task 12).

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 3: SceneManager.change_to

**Files:**
- Modify: `src/scripts/autoloads/scene_manager.gd`

- [ ] **Step 1: Zapisz minimal SceneManager**

Zamień zawartość `src/scripts/autoloads/scene_manager.gd` na:

```gdscript
extends Node

func change_to(scene_path: String) -> void:
	GameState.reset_metrics()
	NotificationManager.stop()
	get_tree().change_scene_to_file(scene_path)
```

Co robi: reset metryk (na wypadek retry), zatrzymanie cyklu notyfikacji, change scene. Notification cycle restartuje się przez `start()` w `Game._ready()` (Task 5 wire).

- [ ] **Step 2: Walidacja**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

Expected: zero ERRORów.

- [ ] **Step 3: Commit**

```bash
git add src/scripts/autoloads/scene_manager.gd
git commit -m "feat(scenes): SceneManager.change_to with metrics reset

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 4: Notification Resource model + placeholder

**Files:**
- Create: `src/resources/notification.gd`
- Create: `src/resources/notifications/mama_zjadles.tres`

- [ ] **Step 1: Stwórz katalogi**

```bash
mkdir -p /Users/kamil/Projects/distracted/src/resources/notifications
```

- [ ] **Step 2: Zapisz Notification Resource class**

Stwórz `src/resources/notification.gd`:

```gdscript
class_name Notification
extends Resource

enum InteractionType { GLANCE, ACTION, TRAP }
enum DismissAction { TAP_X, SWIPE_LEFT, ANSWER_BUTTON, READ_REPLY }

@export var content_id: String = ""
@export var sender: String = ""
@export var text: String = ""
@export var interaction: InteractionType = InteractionType.GLANCE
@export var dismiss_action: DismissAction = DismissAction.TAP_X
```

W MVP używamy tylko GLANCE + TAP_X. Pozostałe enumy istnieją jako stuby pod M3.

- [ ] **Step 3: Stwórz placeholder instancję**

Stwórz `src/resources/notifications/mama_zjadles.tres`:

```ini
[gd_resource type="Resource" script_class="Notification" load_steps=2 format=3]

[ext_resource type="Script" path="res://resources/notification.gd" id="1_notification"]

[resource]
script = ExtResource("1_notification")
content_id = "mama_zjadles"
sender = "Mama"
text = "zjadłeś coś?"
interaction = 0
dismiss_action = 0
```

(`interaction = 0` to GLANCE, `dismiss_action = 0` to TAP_X — pierwsze enum values.)

- [ ] **Step 4: Walidacja**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

Expected: zero ERRORów. Jeśli "class_name Notification" konfliktuje z czymś — przemianować na `GameNotification` (Godot ma globalny `Notification`? Nie, ale dla pewności). Jeśli konflikt → użyj `class_name GameNotification` w `notification.gd` i wszystkich referencjach.

- [ ] **Step 5: Commit**

```bash
git add src/resources/
git commit -m "feat(notifications): Notification Resource model + placeholder instance

class_name Notification with content/sender/text + interaction enum
(GLANCE/ACTION/TRAP) + dismiss_action enum (TAP_X/SWIPE_LEFT/...).
MVP uses GLANCE+TAP_X only; other enum values are extension stubs
for M3 per spec.

Placeholder: mama_zjadles.tres ('Mama: zjadłeś coś?').

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 5: NotificationManager — willpower deadline + signals

**Files:**
- Modify: `src/scripts/autoloads/notification_manager.gd`

- [ ] **Step 1: Replace NotificationManager**

Zamień zawartość `src/scripts/autoloads/notification_manager.gd` na:

```gdscript
extends Node

signal notification_arrived(notification: Notification)
signal willpower_expired
signal phone_opened(voluntary: bool)
signal phone_dismissed

const NOTIFICATION_PATHS: Array[String] = [
	"res://resources/notifications/mama_zjadles.tres",
]
const SAFE_WINDOW_MIN: float = 5.0
const SAFE_WINDOW_MAX: float = 8.0
const WILLPOWER_MAX_MVP: float = 3.0

var willpower_remaining: float = 0.0
var willpower_active: bool = false
var current_notification: Notification = null

var _all: Array[Notification] = []
var _interval_timer: Timer
var _running: bool = false

func _ready() -> void:
	_load_pool()
	_interval_timer = Timer.new()
	_interval_timer.one_shot = true
	_interval_timer.timeout.connect(_on_safe_window_elapsed)
	add_child(_interval_timer)
	GameState.phase_changed.connect(_on_phase_changed)

func start() -> void:
	_running = true
	_schedule_next_safe_window()

func stop() -> void:
	_running = false
	_interval_timer.stop()
	willpower_active = false
	current_notification = null

func request_check_phone() -> void:
	if not willpower_active:
		return
	_open_phone(true)

func dismiss_current() -> void:
	if current_notification == null:
		return
	current_notification = null
	phone_dismissed.emit()
	if GameState.phase == GameState.GamePhase.PHONE:
		GameState.set_phase(GameState.GamePhase.ROAD)
	_schedule_next_safe_window()

func _process(delta: float) -> void:
	if not willpower_active:
		return
	willpower_remaining -= delta
	if willpower_remaining <= 0.0:
		willpower_active = false
		willpower_remaining = 0.0
		willpower_expired.emit()
		_open_phone(false)

func _load_pool() -> void:
	for path in NOTIFICATION_PATHS:
		var n: Notification = load(path)
		if n == null:
			push_error("NotificationManager: cannot load " + path)
			continue
		_all.append(n)

func _schedule_next_safe_window() -> void:
	if not _running:
		return
	var interval: float = randf_range(SAFE_WINDOW_MIN, SAFE_WINDOW_MAX)
	_interval_timer.wait_time = interval
	_interval_timer.start()

func _on_safe_window_elapsed() -> void:
	if GameState.phase != GameState.GamePhase.ROAD:
		return
	if _all.is_empty():
		return
	current_notification = _all.pick_random()
	willpower_remaining = WILLPOWER_MAX_MVP
	willpower_active = true
	notification_arrived.emit(current_notification)

func _open_phone(voluntary: bool) -> void:
	if current_notification == null:
		return
	willpower_active = false
	GameState.set_phase(GameState.GamePhase.PHONE)
	phone_opened.emit(voluntary)

func _on_phase_changed(new_phase: GameState.GamePhase) -> void:
	if new_phase == GameState.GamePhase.GAME_OVER:
		stop()
```

Co zmieniliśmy vs poprzedni scaffold:
- Wywaliliśmy JSON loading (`_load_data`, `DATA_PATH`)
- Przejście na Notification Resource (pula `_all: Array[Notification]`)
- Willpower jako **countdown w _process**, nie statyczna wartość
- Dodane `request_check_phone()` dla voluntary trigger
- Sygnały: `notification_arrived(Notification)`, `willpower_expired`, `phone_opened(bool)`, `phone_dismissed`
- Safe window jest randf_range(5, 8) — zgodnie ze speccem

- [ ] **Step 2: Walidacja headless**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

Expected: zero ERRORów. Jeśli error "Cannot find class Notification" — sprawdź czy `notification.gd` ma `class_name Notification` na pierwszej linii.

- [ ] **Step 3: Manual smoke test — willpower countdown**

Tymczasowo dodaj w `_ready()` po linii `GameState.phase_changed.connect`:

```gdscript
call_deferred("start")  # TEMP: usunąć w Task 10 (Game._ready przejmuje)
```

Uruchom grę. Po 5-8s powinno wyemitować `notification_arrived`, po kolejnych 3s — `willpower_expired`. Brak UI jeszcze, więc obserwacja przez `print` statements (tymczasowo).

Tymczasowy debug print po Step 1 (dodaj na początku `_on_safe_window_elapsed` i `_open_phone`):

```gdscript
print("[NM] safe window elapsed, notification:", current_notification.content_id if current_notification else "null")
# i:
print("[NM] phone opened, voluntary:", voluntary)
```

Po obserwacji **usuń tylko debug printy**. `call_deferred("start")` ZOSTAJE do Task 10 — Tasks 6-9 zakładają że NotificationManager startuje sam. Task 10 zastępuje to wireringiem w `Game._ready()`.

- [ ] **Step 4: Commit**

```bash
git add src/scripts/autoloads/notification_manager.gd
git commit -m "refactor(notifications): willpower as countdown deadline, Resource-based

Replaced JSON loading with Notification Resource pool (_all). Added
willpower countdown in _process (deadline semantics: voluntary tap
or forced expire). New signals: notification_arrived(Notification),
willpower_expired, phone_opened(voluntary: bool), phone_dismissed.

request_check_phone() handles voluntary entry to PHONE phase;
_process expire triggers forced entry. Safe window between cycles
is randf_range(SAFE_WINDOW_MIN, SAFE_WINDOW_MAX).

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 6: HUD — distance, notification icon, willpower bar

**Files:**
- Modify: `src/scenes/game/hud.tscn`
- Modify: `src/scripts/ui/hud.gd`

- [ ] **Step 1: Sprawdź obecny stan hud.tscn**

Otwórz `src/scenes/game/hud.tscn` w edytorze albo czytaj plik. Cel: wiedzieć co już tam jest. Najpewniej tylko CanvasLayer z szkielet.

- [ ] **Step 2: Zapisz hud.tscn — pełna struktura**

Zamień zawartość `src/scenes/game/hud.tscn` na:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/hud.gd" id="1_hud"]

[node name="HUD" type="CanvasLayer"]
script = ExtResource("1_hud")

[node name="DistanceLabel" type="Label" parent="."]
offset_left = 16.0
offset_top = 16.0
offset_right = 200.0
offset_bottom = 48.0
text = "0 m"
theme_override_font_sizes/font_size = 24

[node name="NotificationArea" type="Control" parent="."]
visible = false
offset_left = 16.0
offset_top = 64.0
offset_right = 374.0
offset_bottom = 112.0

[node name="NotificationIcon" type="Button" parent="NotificationArea"]
offset_left = 0.0
offset_top = 0.0
offset_right = 48.0
offset_bottom = 48.0
text = "!"

[node name="WillpowerBar" type="ProgressBar" parent="NotificationArea"]
offset_left = 56.0
offset_top = 8.0
offset_right = 358.0
offset_bottom = 40.0
min_value = 0.0
max_value = 3.0
value = 3.0
show_percentage = false
```

- [ ] **Step 3: Zapisz hud.gd**

Zamień zawartość `src/scripts/ui/hud.gd` na:

```gdscript
extends CanvasLayer

@onready var _distance_label: Label = $DistanceLabel
@onready var _notification_area: Control = $NotificationArea
@onready var _notification_icon: Button = $NotificationArea/NotificationIcon
@onready var _willpower_bar: ProgressBar = $NotificationArea/WillpowerBar

func _ready() -> void:
	GameState.score_changed.connect(_on_score_changed)
	NotificationManager.notification_arrived.connect(_on_notification_arrived)
	NotificationManager.phone_dismissed.connect(_on_phone_dismissed)
	NotificationManager.phone_opened.connect(_on_phone_opened)
	_notification_icon.pressed.connect(_on_notification_icon_pressed)
	_willpower_bar.max_value = NotificationManager.WILLPOWER_MAX_MVP

func _process(_delta: float) -> void:
	if NotificationManager.willpower_active:
		_willpower_bar.value = NotificationManager.willpower_remaining

func _on_score_changed(new_score: int) -> void:
	_distance_label.text = "%d m" % new_score

func _on_notification_arrived(_notification: Notification) -> void:
	_willpower_bar.value = NotificationManager.WILLPOWER_MAX_MVP
	_notification_area.visible = true

func _on_phone_opened(_voluntary: bool) -> void:
	_notification_area.visible = false

func _on_phone_dismissed() -> void:
	_notification_area.visible = false

func _on_notification_icon_pressed() -> void:
	NotificationManager.request_check_phone()
```

- [ ] **Step 4: Walidacja headless**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

Expected: zero ERRORów.

- [ ] **Step 5: Manual playtest**

Uruchom grę (Game scene). Najpewniej `NotificationManager.start()` nie jest jeszcze wywołany — patrz Task 13. Tymczasowo (jak w Task 5 Step 3) dodaj w `_ready()` NotificationManager `call_deferred("start")`.

Oczekiwane:
- Distance label na górze rośnie ("0 m", "1 m", ...).
- Po ~5-8s pojawia się NotificationArea: ikonka `!` + willpower bar startujący od 3.0
- Pasek opada w czasie do 0
- Klik na ikonkę → znika NotificationArea (phone_opened obsłużone)
- Po dismiss (Esc): NotificationArea zniknie (już ukryta), za 5-8s pojawia się znowu

- [ ] **Step 6: Commit**

```bash
git add src/scenes/game/hud.tscn src/scripts/ui/hud.gd
git commit -m "feat(hud): distance label, notification icon, willpower bar

HUD reaguje na: score_changed (distance label), notification_arrived
(reveal area + reset bar), phone_opened/dismissed (hide area).
Willpower bar value updated each _process tick from
NotificationManager.willpower_remaining. Icon button triggers
NotificationManager.request_check_phone() (voluntary entry).

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 7: PhoneOverlay — slide in/out + dismiss

**Files:**
- Modify: `src/scenes/game/phone_overlay.tscn`
- Modify: `src/scripts/ui/phone_overlay.gd`

- [ ] **Step 1: Zapisz phone_overlay.tscn**

Zamień zawartość `src/scenes/game/phone_overlay.tscn` na:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/phone_overlay.gd" id="1_phone"]

[node name="PhoneOverlay" type="CanvasLayer"]
script = ExtResource("1_phone")

[node name="PhoneFrame" type="ColorRect" parent="."]
offset_left = 0.0
offset_top = -675.0
offset_right = 390.0
offset_bottom = 0.0
color = Color(0.07, 0.07, 0.1, 1)

[node name="NotificationCard" type="VBoxContainer" parent="PhoneFrame"]
offset_left = 24.0
offset_top = 120.0
offset_right = 366.0
offset_bottom = 280.0

[node name="SenderLabel" type="Label" parent="PhoneFrame/NotificationCard"]
text = "Mama"
theme_override_font_sizes/font_size = 28

[node name="TextLabel" type="Label" parent="PhoneFrame/NotificationCard"]
text = "zjadłeś coś?"
theme_override_font_sizes/font_size = 22
autowrap_mode = 3

[node name="DismissButton" type="Button" parent="PhoneFrame"]
offset_left = 326.0
offset_top = 24.0
offset_right = 374.0
offset_bottom = 64.0
text = "X"
theme_override_font_sizes/font_size = 24
```

PhoneFrame zaczyna się offset_top = -675 — całość za ekranem (viewport ma 844 wysokości, telefon to ~80% czyli 675). Slide-in tween przesuwa offset_top do 0.

- [ ] **Step 2: Zapisz phone_overlay.gd**

Zamień zawartość `src/scripts/ui/phone_overlay.gd` na:

```gdscript
extends CanvasLayer

const SLIDE_IN_DURATION: float = 0.3
const SLIDE_OUT_DURATION: float = 0.2
const FRAME_HEIGHT: float = 675.0

@onready var _frame: ColorRect = $PhoneFrame
@onready var _sender_label: Label = $PhoneFrame/NotificationCard/SenderLabel
@onready var _text_label: Label = $PhoneFrame/NotificationCard/TextLabel
@onready var _dismiss_button: Button = $PhoneFrame/DismissButton

var _tween: Tween

func _ready() -> void:
	NotificationManager.phone_opened.connect(_on_phone_opened)
	NotificationManager.phone_dismissed.connect(_on_phone_dismissed)
	NotificationManager.notification_arrived.connect(_on_notification_arrived)
	_dismiss_button.pressed.connect(_on_dismiss_pressed)
	_frame.offset_top = -FRAME_HEIGHT
	_frame.offset_bottom = 0.0

func _on_notification_arrived(notification: Notification) -> void:
	_sender_label.text = notification.sender
	_text_label.text = notification.text

func _on_phone_opened(_voluntary: bool) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(_frame, "offset_top", 0.0, SLIDE_IN_DURATION)
	_tween.parallel().tween_property(_frame, "offset_bottom", FRAME_HEIGHT, SLIDE_IN_DURATION)

func _on_phone_dismissed() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(_frame, "offset_top", -FRAME_HEIGHT, SLIDE_OUT_DURATION)
	_tween.parallel().tween_property(_frame, "offset_bottom", 0.0, SLIDE_OUT_DURATION)

func _on_dismiss_pressed() -> void:
	NotificationManager.dismiss_current()
```

- [ ] **Step 3: Walidacja headless**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

Expected: zero ERRORów.

- [ ] **Step 4: Manual playtest**

Uruchom Game scene (z tymczasowym `start()` w NotificationManager wciąż aktywnym).

Oczekiwane:
- Po willpower expire (lub kliknięciu ikonki): telefon zjeżdża z góry przez 0.3s, pokazuje "Mama / zjadłeś coś?" + X.
- Klik X (lub Esc) → telefon zjeżdża z powrotem przez 0.2s.
- Cykl się powtarza.

Jeśli telefon nie zjeżdża — sprawdź czy `_frame.offset_top = -675` w `_ready()` rzeczywiście ustawiło frame poza ekranem.

- [ ] **Step 5: Commit**

```bash
git add src/scenes/game/phone_overlay.tscn src/scripts/ui/phone_overlay.gd
git commit -m "feat(phone): overlay slide in/out with dismiss button

PhoneFrame ColorRect starts offscreen (-675 top), tween in on
phone_opened (0.3s ease-out), tween out on phone_dismissed (0.2s
ease-in). Notification card renders Notification.sender + .text
on notification_arrived. Dismiss button triggers
NotificationManager.dismiss_current().

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 8: Player STOP — stub (bez dual-mode)

**Files:**
- Modify: `src/scripts/game/player.gd`

W tym tasku dodajemy podstawową obsługę STOP — pressed = STOPPED, second press = WALKING. Dual-mode (auto-resume na clear vs 1s w PHONE) dochodzi w Task 12.

- [ ] **Step 1: Rozszerz player.gd o tymczasowy toggle stop**

W `src/scripts/game/player.gd`, w `_input(event)` zamień blok dla `stop`:

```gdscript
	if event.is_action_pressed("stop"):
		stop_pressed.emit()
		if walk_state == WalkState.WALKING:
			set_stopped()
		else:
			set_walking()
```

(Tymczasowo toggle. Sygnał `stop_pressed` zostaje na potem — w Task 12 wykorzystamy go w StopController.)

- [ ] **Step 2: Walidacja**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

- [ ] **Step 3: Manual playtest**

Uruchom Game scene. Wciśnij Space — postać powinna się zatrzymać (świat już nie scrolluje). Wciśnij Space ponownie — postać znowu idzie.

- [ ] **Step 4: Commit**

```bash
git add src/scripts/game/player.gd
git commit -m "feat(player): stop toggle stub (Space = WALKING<->STOPPED)

Quick toggle for early playtest; dual-mode auto-resume (ROAD: wait
hazard cleared, PHONE: 1s) comes in Task 12 via StopController.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 9: Tractor hazard scene + script

**Files:**
- Create: `src/scenes/hazards/tractor.tscn`
- Create: `src/scripts/hazards/tractor.gd`

- [ ] **Step 1: Stwórz katalogi**

```bash
mkdir -p /Users/kamil/Projects/distracted/src/scenes/hazards
mkdir -p /Users/kamil/Projects/distracted/src/scripts/hazards
```

- [ ] **Step 2: Zapisz tractor.gd**

Stwórz `src/scripts/hazards/tractor.gd`:

```gdscript
extends Area3D

signal cleared(node: Node3D)

const LATERAL_SPEED: float = 4.0
const PATH_HALF_WIDTH: float = 1.8

var _direction: float = 1.0
var _emitted_cleared: bool = false

func _ready() -> void:
	collision_layer = 4  # Layer 3 (Hazards)
	collision_mask = 2   # Layer 2 (Player)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	position.x += LATERAL_SPEED * _direction * delta
	if not _emitted_cleared and position.x > PATH_HALF_WIDTH:
		_emitted_cleared = true
		cleared.emit(self)
	if position.x > PATH_HALF_WIDTH + 2.0:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		var player := body as Node
		if player.has_signal("collided_with_hazard"):
			player.emit_signal("collided_with_hazard")
```

Tractor leci z lewa na prawo (x rośnie). Emituje `cleared` gdy wyjdzie poza ścieżkę (x > 1.8), despawnuje przy x > 3.8.

- [ ] **Step 3: Zapisz tractor.tscn**

Stwórz `src/scenes/hazards/tractor.tscn`:

```ini
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/hazards/tractor.gd" id="1_tractor"]

[sub_resource type="BoxMesh" id="BoxMesh_1"]
size = Vector3(1.5, 1.5, 2.0)

[sub_resource type="BoxShape3D" id="BoxShape3D_1"]
size = Vector3(1.5, 1.5, 2.0)

[node name="Tractor" type="Area3D"]
script = ExtResource("1_tractor")
collision_layer = 4
collision_mask = 2

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
mesh = SubResource("BoxMesh_1")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
shape = SubResource("BoxShape3D_1")
```

Placeholder: 1.5×1.5×2 box. Renderowany czerwono via material później (post-MVP polish).

- [ ] **Step 4: Player musi być w grupie "player"**

Sprawdź `src/scenes/game/player.tscn` — czy root node ma `groups=["player"]`. Jeśli nie, otwórz i dodaj w sekcji root node:

```
[node name="Player" type="CharacterBody3D" groups=["player"]]
```

Oraz upewnij się że collision_layer Player = 2 (Layer 2). Jeśli player.tscn nie ma jeszcze collision shape — dodaj prostą BoxShape3D w CollisionShape3D node.

Pełny placeholder Player scene (jeśli pusty):

```ini
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/game/player.gd" id="1_player"]

[sub_resource type="BoxMesh" id="BoxMesh_1"]
size = Vector3(0.8, 1.8, 0.8)

[sub_resource type="BoxShape3D" id="BoxShape3D_1"]
size = Vector3(0.8, 1.8, 0.8)

[node name="Player" type="CharacterBody3D" groups=["player"]]
collision_layer = 2
collision_mask = 1
script = ExtResource("1_player")

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.9, 0)
mesh = SubResource("BoxMesh_1")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.9, 0)
shape = SubResource("BoxShape3D_1")
```

- [ ] **Step 5: Walidacja**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

Expected: zero ERRORów.

- [ ] **Step 6: Manual smoke test**

W edytorze: otwórz tractor.tscn jako stand-alone scene i wciśnij Play (F6). Powinieneś zobaczyć biały box. Brak ruchu (bo `_process` zaczyna od `position.x += ...` — przesunie się ale niewidocznie bez camera).

Lepszy test: w Task 10 dodamy spawner — wtedy zobaczymy traktor w Game scene.

- [ ] **Step 7: Commit**

```bash
git add src/scenes/hazards/ src/scripts/hazards/ src/scenes/game/player.tscn
git commit -m "feat(hazard): Tractor scene with lateral motion + collision

Area3D moves x at LATERAL_SPEED, emits 'cleared' signal when past
PATH_HALF_WIDTH, queue_frees beyond. body_entered triggers
collided_with_hazard on Player (group 'player', collision Layer 2).
Tractor at Layer 3 (Hazards) per architecture.md.

Player scene updated: group 'player', collision_layer 2, collision
shape + mesh placeholder.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 10: HazardSpawner — distance-based spawn

**Files:**
- Modify: `src/scripts/autoloads/hazard_spawner.gd`

- [ ] **Step 1: Replace hazard_spawner.gd**

Zamień zawartość `src/scripts/autoloads/hazard_spawner.gd` na:

```gdscript
extends Node

signal hazard_spawned(node: Node3D)
signal hazard_cleared(node: Node3D)

const TRACTOR_SCENE: PackedScene = preload("res://scenes/hazards/tractor.tscn")
const SPAWN_INTERVAL_MIN: float = 25.0
const SPAWN_INTERVAL_MAX: float = 40.0
const SPAWN_LOOKAHEAD_MIN: float = 12.0
const SPAWN_LOOKAHEAD_MAX: float = 15.0
const SPAWN_X: float = -3.0

var _container: Node3D = null
var _player: Node3D = null
var _next_spawn_distance: float = 0.0
var _running: bool = false

func _ready() -> void:
	GameState.phase_changed.connect(_on_phase_changed)

func bind_scene(container: Node3D, player: Node3D) -> void:
	_container = container
	_player = player

func start() -> void:
	_running = true
	_schedule_next_spawn()

func stop() -> void:
	_running = false

func _process(_delta: float) -> void:
	if not _running:
		return
	if _container == null or _player == null:
		return
	if GameState.distance >= _next_spawn_distance:
		_spawn_tractor()
		_schedule_next_spawn()

func _spawn_tractor() -> void:
	var tractor: Node3D = TRACTOR_SCENE.instantiate()
	var lookahead: float = randf_range(SPAWN_LOOKAHEAD_MIN, SPAWN_LOOKAHEAD_MAX)
	tractor.position = Vector3(SPAWN_X, 0.75, _player.global_position.z - lookahead)
	_container.add_child(tractor)
	tractor.cleared.connect(_on_tractor_cleared)
	hazard_spawned.emit(tractor)

func _on_tractor_cleared(node: Node3D) -> void:
	hazard_cleared.emit(node)

func _schedule_next_spawn() -> void:
	_next_spawn_distance = GameState.distance + randf_range(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_MAX)

func _on_phase_changed(new_phase: GameState.GamePhase) -> void:
	if new_phase == GameState.GamePhase.GAME_OVER:
		stop()
```

Spawner trzyma referencje do HazardContainer + Player (otrzymuje przez `bind_scene` z Game.gd). Tracking dystansu dla spawnu: gdy `GameState.distance` przekracza `_next_spawn_distance`, instancjuje traktora. Forward `cleared` z każdego traktora.

- [ ] **Step 2: Wire up w game.gd**

Sprawdź obecną zawartość `src/scripts/game/game.gd`. Najpewniej szkielet. Zamień całość na:

```gdscript
extends Node3D

@onready var _world_container: Node3D = $WorldContainer
@onready var _hazard_container: Node3D = $WorldContainer/HazardContainer
@onready var _player: Node3D = $Player

func _ready() -> void:
	GameState.reset_metrics()
	HazardSpawner.bind_scene(_hazard_container, _player)
	HazardSpawner.start()
	NotificationManager.start()
	_player.collided_with_hazard.connect(_on_player_collided)

func _on_player_collided() -> void:
	GameState.set_phase(GameState.GamePhase.GAME_OVER)
```

To zastępuje też tymczasowy `call_deferred("start")` w NotificationManager (jeśli wciąż jest — **usuń**).

- [ ] **Step 3: Walidacja**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

- [ ] **Step 4: Manual playtest**

Uruchom Game scene. Idź do przodu (auto). Po ~25-40m dystansu powinien wyjść traktor z lewa. Powinien przesunąć się na prawo i zniknąć (queue_free).

Jeśli traktor nie pojawia się — sprawdź `HazardSpawner._next_spawn_distance` w debug (dodaj `print` w `_schedule_next_spawn`).

Jeśli traktor widoczny ale nie rusza się lateralnie — sprawdź `tractor.gd._process`.

- [ ] **Step 5: Commit**

```bash
git add src/scripts/autoloads/hazard_spawner.gd src/scripts/game/game.gd
git commit -m "feat(hazards): distance-based Tractor spawning

HazardSpawner tracks GameState.distance and spawns Tractor at
SPAWN_LOOKAHEAD ahead of player every SPAWN_INTERVAL meters.
Forwards 'cleared' signal from each tractor for StopController
auto-resume (Task 12).

Game._ready wires HazardSpawner.bind_scene + start, plus
NotificationManager.start. Removed temporary call_deferred from
NotificationManager.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 11: Player collision → GAME_OVER (wired)

W Task 10 już wyemitowaliśmy `collided_with_hazard` z Player przez Tractor.body_entered (Task 9), i podłączyliśmy w Game.gd `_on_player_collided`. Ten task zostaje jako **walidacja end-to-end zagrania śmiertelnego**.

**Files:** (no code changes — verification only)

- [ ] **Step 1: Manual playtest — śmierć**

Uruchom Game scene. Idź na traktor (bez Space). Po kolizji:
- `phase` → GAME_OVER
- Postać zamarza (`velocity.z = 0`)
- Brak crashu

Console powinno pokazać `phase_changed(GAME_OVER)`.

- [ ] **Step 2: Sprawdź że nie ma double-collisionów**

Player ma collision_mask = 1 (czyli widzi World Layer 1), więc nie powinien collide'ować z traktor poprzez `move_and_slide`. Detection idzie przez Area3D body_entered.

Sprawdź czy Tractor współpracuje:
- `collision_layer = 4` (Layer 3)
- `collision_mask = 2` (Layer 2 czyli Player)
- Player `collision_layer = 2`

Jeśli kolizja nie triggeruje się — w edytorze otwórz Project Settings → Layer Names → 3D Physics i upewnij się że Layer 2 = "Player", Layer 3 = "Hazards". (Same names; numbery powinny pasować.)

- [ ] **Step 3: Commit (no changes; mark verified)**

Brak zmian — task czysto walidacyjny. **Pomiń commit jeśli żadnych zmian.** Jeśli musiałeś poprawić collision layers w project.godot — commit te zmiany:

```bash
git add -u
git commit -m "fix(collisions): collision layer names + masks verification

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 12: Stop dual-mode (ROAD wait-for-clear vs PHONE 1s)

**Files:**
- Create: `src/scripts/game/stop_controller.gd`
- Modify: `src/scenes/game/game.tscn` (dodaj StopController jako child node)
- Modify: `src/scripts/game/player.gd` (usuń tymczasowy toggle z Task 8)

Wydzielamy logikę stopu z Playera do osobnego controllera. Player tylko emituje `stop_pressed`; StopController decyduje kiedy wrócić do WALKING.

- [ ] **Step 1: Stwórz stop_controller.gd**

Stwórz `src/scripts/game/stop_controller.gd`:

```gdscript
extends Node

const PHONE_STOP_TIMEOUT: float = 1.0

var _player: Node3D = null
var _active_hazards: Array[Node] = []
var _phone_timer: Timer

func _ready() -> void:
	_phone_timer = Timer.new()
	_phone_timer.one_shot = true
	_phone_timer.timeout.connect(_on_phone_timer_elapsed)
	add_child(_phone_timer)
	HazardSpawner.hazard_spawned.connect(_on_hazard_spawned)
	HazardSpawner.hazard_cleared.connect(_on_hazard_cleared)
	GameState.phase_changed.connect(_on_phase_changed)

func bind_player(player: Node3D) -> void:
	_player = player
	if not _player.stop_pressed.is_connected(_on_stop_pressed):
		_player.stop_pressed.connect(_on_stop_pressed)

func _on_stop_pressed() -> void:
	if _player == null:
		return
	_player.set_stopped()
	if GameState.phase == GameState.GamePhase.PHONE:
		_phone_timer.start(PHONE_STOP_TIMEOUT)
	# in ROAD mode auto-resume happens via _on_hazard_cleared

func _on_hazard_spawned(node: Node) -> void:
	_active_hazards.append(node)

func _on_hazard_cleared(node: Node) -> void:
	_active_hazards.erase(node)
	if _player == null:
		return
	if GameState.phase == GameState.GamePhase.ROAD and _player.walk_state == _player.WalkState.STOPPED and _active_hazards.is_empty():
		_player.set_walking()

func _on_phone_timer_elapsed() -> void:
	if _player == null:
		return
	if _player.walk_state == _player.WalkState.STOPPED:
		_player.set_walking()

func _on_phase_changed(new_phase: GameState.GamePhase) -> void:
	if new_phase == GameState.GamePhase.ROAD:
		# phone closed: if no hazards active, auto-resume; if hazards active, stay stopped until cleared
		if _player == null:
			return
		if _player.walk_state == _player.WalkState.STOPPED and _active_hazards.is_empty():
			_player.set_walking()
	elif new_phase == GameState.GamePhase.GAME_OVER:
		_phone_timer.stop()
```

Logika:
- ROAD + stop → STOPPED do momentu, aż wszystkie aktywne traktory się `cleared` (`_active_hazards.is_empty()`).
- PHONE + stop → STOPPED na 1s (timer), potem WALKING regardless of hazards.
- Po dismiss (PHONE → ROAD) → jeśli graczy jest STOPPED i nie ma hazardów → wróć do WALKING. Jeśli są hazardy → pozostaje STOPPED (ROAD logic przejmuje).

- [ ] **Step 2: Usuń toggle stub z player.gd**

W `src/scripts/game/player.gd` _input(), zamień blok dla `stop` z Task 8 z powrotem na sam emit:

```gdscript
	if event.is_action_pressed("stop"):
		stop_pressed.emit()
```

(Bez `set_stopped/set_walking` toggle.)

- [ ] **Step 3: Add StopController do game.tscn + wire**

Otwórz `src/scenes/game/game.tscn`. Dodaj na końcu (przed ostatnim `]` jeśli jest, albo po `PhoneOverlay` node):

```ini
[node name="StopController" type="Node" parent="."]
script = ExtResource("7_stopctrl")
```

I dodaj `ext_resource` na górze:

```ini
[ext_resource type="Script" path="res://scripts/game/stop_controller.gd" id="7_stopctrl"]
```

(W zależności od istniejącej numeracji `id`, użyj następnego wolnego.)

Pełny game.tscn po edycji powinien wyglądać tak:

```ini
[gd_scene load_steps=8 format=3]

[ext_resource type="Script" path="res://scripts/game/game.gd" id="1_game"]
[ext_resource type="Script" path="res://scripts/game/game_camera.gd" id="2_cam"]
[ext_resource type="PackedScene" path="res://scenes/game/hud.tscn" id="3_hud"]
[ext_resource type="PackedScene" path="res://scenes/game/phone_overlay.tscn" id="4_phone"]
[ext_resource type="PackedScene" path="res://scenes/game/player.tscn" id="5_player"]
[ext_resource type="PackedScene" path="res://scenes/game/chunk_manager.tscn" id="6_chunks"]
[ext_resource type="Script" path="res://scripts/game/stop_controller.gd" id="7_stopctrl"]

[node name="Game" type="Node3D"]
script = ExtResource("1_game")

[node name="WorldContainer" type="Node3D" parent="."]

[node name="ChunkManager" parent="WorldContainer" instance=ExtResource("6_chunks")]

[node name="HazardContainer" type="Node3D" parent="WorldContainer"]

[node name="Player" parent="." instance=ExtResource("5_player")]

[node name="GameCamera" type="Camera3D" parent="."]
script = ExtResource("2_cam")
position = Vector3(0, 4, 8)

[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.866, -0.433, 0.25, 0, 0.5, 0.866, -0.5, -0.75, 0.433, 0, 10, 0)
shadow_enabled = true

[node name="HUD" parent="." instance=ExtResource("3_hud")]

[node name="PhoneOverlay" parent="." instance=ExtResource("4_phone")]
layer = 10

[node name="StopController" type="Node" parent="."]
script = ExtResource("7_stopctrl")
```

- [ ] **Step 4: Wire StopController w game.gd**

W `src/scripts/game/game.gd`, dodaj bind_player przy starcie. Pełna zawartość:

```gdscript
extends Node3D

@onready var _world_container: Node3D = $WorldContainer
@onready var _hazard_container: Node3D = $WorldContainer/HazardContainer
@onready var _player: Node3D = $Player
@onready var _stop_controller: Node = $StopController

func _ready() -> void:
	GameState.reset_metrics()
	HazardSpawner.bind_scene(_hazard_container, _player)
	HazardSpawner.start()
	NotificationManager.start()
	_stop_controller.bind_player(_player)
	_player.collided_with_hazard.connect(_on_player_collided)

func _on_player_collided() -> void:
	GameState.set_phase(GameState.GamePhase.GAME_OVER)
```

Player type = Node3D (CharacterBody3D extends Node3D), spójne z Task 10 i `HazardSpawner.bind_scene` signature. GDScript dynamic dispatch obsłuży `_player.walk_state` / `_player.set_stopped()` przez Node3D reference.

- [ ] **Step 5: Walidacja**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

Expected: zero ERRORów.

- [ ] **Step 6: Manual playtest — dual-mode stop**

Test ROAD mode:
1. Idź do momentu spawn traktora.
2. Wciśnij Space PRZED kolizją.
3. Świat stoi. Traktor leci dalej (lateralnie).
4. Traktor wyjeżdża z prawej (cleared) → gracz powinien automatycznie ruszyć.

Test PHONE mode:
1. Czekaj na notyfikację, pozwól willpower spaść (lub kliknij ikonkę).
2. Telefon wjeżdża.
3. Wciśnij Space.
4. Świat stoi 1.0s.
5. Po 1.0s gracz automatycznie rusza (nawet jeśli traktor jeszcze nie wyjechał).

Jeśli (Test PHONE mode) gracz nie rusza po 1s — sprawdź czy `_phone_timer` startuje (`print` w `_on_stop_pressed`).

- [ ] **Step 7: Commit**

```bash
git add src/scripts/game/stop_controller.gd src/scripts/game/player.gd src/scripts/game/game.gd src/scenes/game/game.tscn
git commit -m "feat(stop): StopController with dual-mode auto-resume

ROAD mode: stop_pressed → STOPPED until all active hazards emit
'cleared' → WALKING. PHONE mode: stop_pressed → STOPPED for 1s
(PHONE_STOP_TIMEOUT) → WALKING regardless of hazards.

Logic isolated in StopController node (subscribes to HazardSpawner
+ GameState signals). Player only emits stop_pressed (toggle stub
from Task 8 removed). Wired via Game._ready.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 13: time_on_phone metric — full coverage

W Task 1 dodaliśmy akumulację `time_on_phone` w `GameState._process` (delta dodawany gdy `phase == PHONE`). Ten task to walidacja end-to-end + edge case'y.

- [ ] **Step 1: Verify accumulation timing**

Sprawdź obecny `game_state.gd`:

```gdscript
func _process(delta: float) -> void:
	if phase == GamePhase.GAME_OVER:
		return
	total_time += delta
	if phase == GamePhase.PHONE:
		time_on_phone += delta
```

To OK. Akumulacja zaczyna się PIERWSZĄ klatkę PHONE phase. Animacja slide-in trwa 0.3s — ten czas jest LICZONY do `time_on_phone` (uczciwa kara, per spec).

Animacja slide-out — phase wraca na ROAD od razu po `dismiss_current()`, więc 0.2s slide-out NIE liczy się. To akceptowalne — alternative: liczy się; aktualny kod jest prostszy.

**Decyzja:** zostawiamy obecne zachowanie (slide-out NIE liczy się). Per spec to drobny niuans, można poprawić w polish.

- [ ] **Step 2: Manual playtest — time_on_phone**

Tymczasowo dodaj do `hud.gd._process`:

```gdscript
	_distance_label.text = "%d m | phone: %.1fs (%.0f%%)" % [GameState.score, GameState.time_on_phone, GameState.get_phone_percentage()]
```

Uruchom grę. Powinien rosnąć dystans, a phone time rosnąć tylko gdy telefon jest na ekranie. Po dismiss — phone time stoi.

Po teście **usuń debug format z hud.gd._process** — w Task 14 zrobimy proper formatting w GameOver.

- [ ] **Step 3: Commit (jeśli tweak)**

Brak zmian funkcjonalnych spodziewanych. Jeśli musiałeś poprawić akumulację (edge case z animacją) — commit:

```bash
git add src/scripts/autoloads/game_state.gd
git commit -m "fix(metrics): time_on_phone accumulation edge cases

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 14: GameOver scene — metrics + retry

**Files:**
- Modify: `src/scenes/ui/game_over.tscn`
- Modify: `src/scripts/ui/game_over.gd`

- [ ] **Step 1: Zapisz game_over.tscn**

Zamień zawartość `src/scenes/ui/game_over.tscn` na:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/game_over.gd" id="1_gameover"]

[node name="GameOver" type="Control"]
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_gameover")

[node name="Background" type="ColorRect" parent="."]
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0.05, 0.05, 0.08, 1)

[node name="VBox" type="VBoxContainer" parent="."]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -160.0
offset_top = -120.0
offset_right = 160.0
offset_bottom = 120.0

[node name="DistanceLabel" type="Label" parent="VBox"]
text = "Doszedłeś 0 m."
theme_override_font_sizes/font_size = 28
horizontal_alignment = 1

[node name="PhoneLabel" type="Label" parent="VBox"]
text = "Patrzyłeś na telefon 0% czasu."
theme_override_font_sizes/font_size = 22
horizontal_alignment = 1

[node name="Spacer" type="Control" parent="VBox"]
custom_minimum_size = Vector2(0, 32)

[node name="RetryButton" type="Button" parent="VBox"]
text = "Spróbuj jeszcze raz"
theme_override_font_sizes/font_size = 22
```

- [ ] **Step 2: Zapisz game_over.gd**

Zamień zawartość `src/scripts/ui/game_over.gd` na:

```gdscript
extends Control

@onready var _distance_label: Label = $VBox/DistanceLabel
@onready var _phone_label: Label = $VBox/PhoneLabel
@onready var _retry_button: Button = $VBox/RetryButton

func _ready() -> void:
	_distance_label.text = "Doszedłeś %d m." % int(GameState.distance)
	_phone_label.text = "Patrzyłeś na telefon %d%% czasu." % int(round(GameState.get_phone_percentage()))
	_retry_button.pressed.connect(_on_retry_pressed)
	_retry_button.grab_focus()

func _on_retry_pressed() -> void:
	SceneManager.change_to("res://scenes/game/game.tscn")
```

Renderuje metryki natychmiast w `_ready()`, bo `GameState` autoload persists between scenes — kolizja → `change_scene_to_file` → GameOver `_ready` czyta `distance` i `time_on_phone` zanim `SceneManager.change_to` zresetuje je dla retry. (Ważne: `reset_metrics` wywołujemy w `change_to`, więc GameOver ma stare dane do display'u, a nowe metryki zaczynają się przy retry.)

- [ ] **Step 3: Trigger przejścia GAME_OVER → game_over.tscn z game.gd**

W `src/scripts/game/game.gd` rozszerz `_on_player_collided`:

```gdscript
func _on_player_collided() -> void:
	GameState.set_phase(GameState.GamePhase.GAME_OVER)
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://scenes/ui/game_over.tscn")
```

1.5s opóźnienie zgodnie ze speccem. **Nie używamy** `SceneManager.change_to` tutaj — to wywołałoby `reset_metrics()` które zniweczyłoby dane do display'u w GameOver. Bezpośrednie `change_scene_to_file` zachowuje metryki.

- [ ] **Step 4: Walidacja**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

- [ ] **Step 5: Manual playtest — full death flow**

1. Uruchom Game scene.
2. Pozwól traktorowi cię zabić (lub klauziwo wjedź).
3. 1.5s pauza, świat zamarznięty.
4. Przejście na GameOver scene.
5. Widzisz "Doszedłeś X m." i "Patrzyłeś na telefon Y% czasu."
6. Klik retry → wracasz do gry, dystans od zera.

- [ ] **Step 6: Commit**

```bash
git add src/scenes/ui/game_over.tscn src/scripts/ui/game_over.gd src/scripts/game/game.gd
git commit -m "feat(game-over): render distance + phone% metrics, retry button

GameOver scene reads GameState.distance + get_phone_percentage()
in _ready (before SceneManager.change_to resets metrics for retry).
1.5s delay before scene transition per spec.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 15: MainMenu — Start button

**Files:**
- Modify: `src/scenes/ui/main_menu.tscn`
- Modify: `src/scripts/ui/main_menu.gd`

- [ ] **Step 1: Zapisz main_menu.tscn**

Zamień zawartość `src/scenes/ui/main_menu.tscn` na:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/main_menu.gd" id="1_menu"]

[node name="MainMenu" type="Control"]
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_menu")

[node name="Background" type="ColorRect" parent="."]
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0.05, 0.07, 0.05, 1)

[node name="VBox" type="VBoxContainer" parent="."]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -150.0
offset_top = -80.0
offset_right = 150.0
offset_bottom = 80.0

[node name="TitleLabel" type="Label" parent="VBox"]
text = "Distracted"
theme_override_font_sizes/font_size = 40
horizontal_alignment = 1

[node name="Spacer" type="Control" parent="VBox"]
custom_minimum_size = Vector2(0, 32)

[node name="StartButton" type="Button" parent="VBox"]
text = "Start"
theme_override_font_sizes/font_size = 24
```

- [ ] **Step 2: Zapisz main_menu.gd**

Zamień zawartość `src/scripts/ui/main_menu.gd` na:

```gdscript
extends Control

@onready var _start_button: Button = $VBox/StartButton

func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_start_button.grab_focus()

func _on_start_pressed() -> void:
	SceneManager.change_to("res://scenes/game/game.tscn")
```

- [ ] **Step 3: Walidacja**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

- [ ] **Step 4: Manual playtest — full game flow**

Uruchom projekt (main scene = main_menu.tscn per project.godot).

1. Widzisz "Distracted" + Start button.
2. Klik Start → Game scene.
3. Grasz, zostajesz przejechany.
4. GameOver scene z metrykami.
5. Klik Retry → znowu Game scene od zera.

Jeśli main scene w project.godot wciąż pokazuje game.tscn (z tymczasowej zmiany podczas dev) — zmień z powrotem na `res://scenes/ui/main_menu.tscn`.

- [ ] **Step 5: Commit**

```bash
git add src/scenes/ui/main_menu.tscn src/scripts/ui/main_menu.gd
git commit -m "feat(menu): main menu with Start button to game scene

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 16: End-to-end playtest validation

Final check przed M1 zamknięciem. Nie ma kodu — tylko walidacja.

- [ ] **Step 1: Headless run**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1 | grep -i error
```

Expected: brak outputu (zero linii). Jeśli coś jest — naprawić.

- [ ] **Step 2: Full playthrough — checklist**

Uruchom grę z main menu. Sprawdź każdy punkt:

- [ ] Main menu pokazuje "Distracted" + Start
- [ ] Start → Game scene; postać startuje, idzie do przodu, chunki recyklują się
- [ ] Distance label rośnie
- [ ] Po 5-8s pojawia się notification icon + willpower bar
- [ ] Willpower bar opada w ciągu 3s
- [ ] Klik na ikonkę PRZED expire → telefon zjeżdża z góry (voluntary)
- [ ] Lub: pozwól willpower expire → telefon zjeżdża (forced)
- [ ] Telefon pokazuje "Mama / zjadłeś coś?" + X w rogu
- [ ] Esc lub klik X → telefon zjeżdża z powrotem
- [ ] Następny cykl notyfikacji startuje po dismiss
- [ ] Po ~25-40m pojawia się traktor z lewa
- [ ] Traktor leci lateralnie na prawo, despawnuje za PATH
- [ ] Space PRZED kolizją w ROAD mode → świat stoi, czeka aż traktor zjedzie, auto-resume
- [ ] Space podczas PHONE mode → świat stoi 1s, auto-resume regardless of traktor
- [ ] Kolizja z traktorem (bez stop) → GAME_OVER po 1.5s
- [ ] GameOver pokazuje "Doszedłeś X m." + "Patrzyłeś na telefon Y%."
- [ ] Retry → wracasz do gry, metryki od zera

- [ ] **Step 3: Test sukcesu MVP**

Per spec: zagraj 2 min, oceń:

> *"Czy ten loop jest dla ciebie wciągający? Zagrałbyś jeszcze raz?"*

Jeśli "tak, jeszcze raz" — MVP działa, można domykać M1, planować M2 (krzywe willpower, więcej stref).
Jeśli "meh" — problem w mechanice, nie sprite'ach. Wracamy do brainstormingu z konkretnym feedbackem co nie działa.

- [ ] **Step 4: Update doc/milestones.md** (opcjonalne, jeśli M1 done)

Jeśli playtest mówi że MVP działa — zmień status M1 w `doc/milestones.md` na "DONE 2026-06-02" lub podobnie. Commit:

```bash
git add doc/milestones.md
git commit -m "docs(milestones): M1 vertical slice complete

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

- [ ] **Step 5: Zamknij issues**

Per `CLAUDE.md`, zamknij M1 issues które mapuje ten plan:

```bash
gh issue close 2 --repo dzieciol-kamil/distracted --comment "M1 done w PR core-loop"
gh issue close 3 --repo dzieciol-kamil/distracted --comment "M1 done w PR core-loop"
gh issue close 4 --repo dzieciol-kamil/distracted --comment "M1 done w PR core-loop"
gh issue close 5 --repo dzieciol-kamil/distracted --comment "M1 done w PR core-loop"
gh issue close 6 --repo dzieciol-kamil/distracted --comment "M1 done w PR core-loop (pivot: traktor zamiast kałuży, ścieżka przez pola)"
gh issue close 7 --repo dzieciol-kamil/distracted --comment "M1 done w PR core-loop"
```

Plus ustaw Status → Done dla każdej w GitHub Project per `CLAUDE.md` queries.

- [ ] **Step 6: Merge feature branch**

```bash
git checkout main
git merge feature/m1-core-loop
git push
```

---

## Spec coverage check

Kontrola po napisaniu planu — czy każdy element ze specu ma swój task:

| Spec section | Task(s) |
|---|---|
| Pętla rozgrywki | Tasks 5-7, 10, 12, 14 |
| Gracz auto-walk | Task 2 |
| Świat scroll + chunki | Task 2 + scaffold ChunkManager (no-change) |
| Tractor hazard + lateral motion | Task 9 |
| HazardSpawner spawn logic | Task 10 |
| Notification Resource model | Task 4 |
| Willpower deadline (voluntary+forced) | Task 5 |
| Phone overlay slide in/out + dismiss | Task 7 |
| HUD distance + icon + willpower bar | Task 6 |
| Stop dual-mode (ROAD/PHONE) | Task 12 |
| time_on_phone metric | Task 1 + Task 13 |
| Collision → GAME_OVER | Tasks 9 + 11 |
| GameOver scene + metrics + retry | Task 14 |
| MainMenu start | Task 15 |
| SceneManager.change_to | Task 3 |
| Input map | Task 1 |
| End-to-end validation | Task 16 |

Wszystkie sekcje speca pokryte.
