# Suburb Biome (M2b) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Drugi biom (suburb) z 2 pasami i lane-switchingiem, LaneObstacle jako drugi typ hazardu (statyczny), 5 nowych hazard scenes (ciezarowka/samochod/kaluza/latarnia/skrzynka), Zone Resource z visual fields, zone transition logic, ChunkManager per-zone visuals, HUD NotificationArea klikalny w całości.

**Architecture:** Rozszerzenie M2a foundations — `Hazard` base class zostaje (crossing), dochodzi `LaneObstacle` (static). `HazardEntry` rozszerzony o `is_lane_obstacle: bool` żeby HazardSpawner wiedział jak spawnować. `Zone` rozszerzony o `path_color`, `stripe_color`, `stripe_orientation` (ChunkManager czyta). `GameState._update_zone()` ładuje `current_zone` Resource z `ZONES` array indexowanej przez ZoneIndex. Player dostaje lane state + tween-driven lane switching, reset przy zone transition. HUD NotificationArea = Button (flat, transparent).

**Tech Stack:** Godot 4.6, GDScript typed. Brak GUT (testing w M5). Walidacja per task: `godot --headless --quit` zero ERRORs + manual playtest na końcu fazy.

---

## Spec reference

Pełny spec: `doc/specs/2026-06-03-suburb-biome-design.md`.

## Branch strategy

Per `CLAUDE.md`: jedna gałąź dla M2b — `feature/m2b-suburb-biome`. Po Tasku 1:

```bash
git checkout -b feature/m2b-suburb-biome
```

## File Structure

### Nowe pliki

| Plik | Cel |
|---|---|
| `src/scripts/hazards/lane_obstacle.gd` | LaneObstacle base class — Area3D, static, cleared when player passes |
| `src/scenes/hazards/ciezarowka.tscn` | Crossing hazard (3.0×3.0×5.0, lateral 1.6, niebieski) |
| `src/scenes/hazards/samochod.tscn` | Crossing hazard (1.8×1.5×4.2, lateral 2.5, czerwony) |
| `src/scenes/hazards/kaluza.tscn` | Lane obstacle (1.6×0.05×1.2, brudno-niebieski) |
| `src/scenes/hazards/latarnia.tscn` | Lane obstacle (0.3×3.0×0.3, ciemnoszary) |
| `src/scenes/hazards/skrzynka.tscn` | Lane obstacle (0.5×1.2×0.5, żółty) |
| `src/resources/hazards/hazard_ciezarowka.tres` | HazardEntry crossing |
| `src/resources/hazards/hazard_samochod.tres` | HazardEntry crossing |
| `src/resources/hazards/hazard_kaluza.tres` | HazardEntry lane obstacle |
| `src/resources/hazards/hazard_latarnia.tres` | HazardEntry lane obstacle |
| `src/resources/hazards/hazard_skrzynka.tres` | HazardEntry lane obstacle |
| `src/resources/zones/zone_suburb.tres` | Suburb zone instance |

### Modyfikowane pliki

| Plik | Co zmieniamy |
|---|---|
| `src/resources/hazard_entry.gd` | Dodać `@export var is_lane_obstacle: bool = false` |
| `src/resources/zone.gd` | Dodać `path_color`, `stripe_color`, `stripe_orientation` |
| `src/resources/zones/zone_village.tres` | Dodać wartości wizualne (brąz wioski, piaskowy stripe, orient 0) |
| `src/scripts/autoloads/game_state.gd` | Dodać `ZONE_SUBURB` preload + `ZONES` array; rewrite `_update_zone()` żeby ustawiał `current_zone` z `ZONES[zone]` |
| `src/scripts/autoloads/hazard_spawner.gd` | W `_spawn_hazard` rozdzielić lane-obstacle vs crossing spawn position; dodać `_lane_x_for_spawn` helper |
| `src/scripts/game/player.gd` | Dodać `LANE_POSITIONS_2`, `LANE_TWEEN_DURATION`, `current_lane`, `_lane_tween`; metody `_try_lane_switch`, `_lane_x_for`, `reset_lane_for_current_zone`; input handlers lane_left/lane_right |
| `src/scripts/game/game.gd` | Connect `GameState.zone_changed` → `_on_zone_changed` → `_player.reset_lane_for_current_zone()`; call reset w `_ready` po reset_metrics |
| `src/scripts/game/chunk_manager.gd` | `_make_chunk` czyta `GameState.current_zone` visual params; obsłużyć oba `stripe_orientation` (0=poprzeczne, 1=podłużne); rebuild chunk visuals przy recycle |
| `src/scripts/ui/hud.gd` | `_notification_area` typu `Button` (był Control); `_notification_icon` typu `Label` (był Button); click handler na area |
| `src/scenes/game/hud.tscn` | NotificationArea node type Control → Button (flat=true, focus_mode=0); NotificationIcon type Button → Label |
| `src/project.godot` | Sekcja `[input]` dodać `lane_left` (A, Left arrow) i `lane_right` (D, Right arrow) |

### Bez zmian

- `src/scripts/hazards/hazard.gd` — M2a Hazard base bez zmian
- `src/scenes/hazards/tractor.tscn`, `pies.tscn`, `krowa.tscn` — village hazardy pozostają
- `src/resources/hazards/hazard_traktor.tres`, `hazard_pies.tres`, `hazard_krowa.tres` — village entries pozostają
- `src/scripts/game/stop_controller.gd` — listen na hazard_cleared działa dla obu typów (Hazard + LaneObstacle emit same signal)
- `src/scripts/autoloads/notification_manager.gd` — willpower_max już czyta z current_zone (M2a)
- `src/scripts/autoloads/scene_manager.gd` — bez zmian

## Walidacja per task

Każdy task kończy się:
1. `cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1` — zero ERRORów
2. Manual check jeśli istnieje (większość weryfikowana E2E w Tasku 14)
3. `git commit`

---

## Task 1: Resource extensions (Zone + HazardEntry) + zone_village.tres update

**Files:**
- Modify: `src/resources/zone.gd`
- Modify: `src/resources/hazard_entry.gd`
- Modify: `src/resources/zones/zone_village.tres`

- [ ] **Step 1: Extend zone.gd with visual fields + path_width**

Replace contents of `/Users/kamil/Projects/distracted/src/resources/zone.gd` with:

```gdscript
class_name Zone
extends Resource

@export var name_id: String = ""
@export var walk_speed: float = 6.0
@export var willpower_max: float = 3.0
@export var spawn_interval_min: float = 25.0
@export var spawn_interval_max: float = 40.0
@export var hazard_pool: Array[HazardEntry] = []
@export var lane_count: int = 1

@export var path_width: float = 2.0
@export var path_color: Color = Color(0.4, 0.3, 0.2)
@export var stripe_color: Color = Color(0.85, 0.78, 0.55)
@export var stripe_orientation: int = 0
```

Defaults dla path_color (brąz wiejski) i stripe_color (piaskowy) zachowują dotychczasowy wygląd village. `stripe_orientation` 0 = poprzeczne kreski (village), 1 = podłużne linie (suburb). `path_width` default 2.0 (lane width unit). Village 2.0 (1 pas), suburb 4.0 (2 pasy × 2.0), future city 6.0 (3 pasy × 2.0). Uniform lane width 2.0 means switch distance constant across zones.

- [ ] **Step 2: Extend hazard_entry.gd with is_lane_obstacle**

Replace contents of `/Users/kamil/Projects/distracted/src/resources/hazard_entry.gd` with:

```gdscript
class_name HazardEntry
extends Resource

@export var scene: PackedScene
@export var weight: int = 1
@export var spawn_lookahead_min: float = 12.0
@export var spawn_lookahead_max: float = 15.0
@export var is_lane_obstacle: bool = false
```

Default `false` — istniejące .tres dla traktor/pies/krowa pozostają crossing bez zmian.

- [ ] **Step 3: Update zone_village.tres with explicit visual values**

Zone Resource has new fields with defaults matching village's current look. To make the values explicit (rather than relying on defaults) and document the design intent, replace `/Users/kamil/Projects/distracted/src/resources/zones/zone_village.tres` with:

```ini
[gd_resource type="Resource" script_class="Zone" load_steps=6 format=3]

[ext_resource type="Script" path="res://resources/zone.gd" id="1_zone"]
[ext_resource type="Script" path="res://resources/hazard_entry.gd" id="2_entry"]
[ext_resource type="Resource" path="res://resources/hazards/hazard_traktor.tres" id="3_traktor"]
[ext_resource type="Resource" path="res://resources/hazards/hazard_pies.tres" id="4_pies"]
[ext_resource type="Resource" path="res://resources/hazards/hazard_krowa.tres" id="5_krowa"]

[resource]
script = ExtResource("1_zone")
name_id = "village"
walk_speed = 6.0
willpower_max = 3.0
spawn_interval_min = 25.0
spawn_interval_max = 40.0
hazard_pool = Array[ExtResource("2_entry")]([ExtResource("3_traktor"), ExtResource("4_pies"), ExtResource("5_krowa")])
lane_count = 1
path_width = 2.0
path_color = Color(0.4, 0.3, 0.2, 1)
stripe_color = Color(0.85, 0.78, 0.55, 1)
stripe_orientation = 0
```

`path_width = 2.0` — wąska udeptana ścieżka (placeholder; player-width). To zmiana M2a → M2b widoczna jako "ścieżka się zwęża" (chunki 3.6 → 2.0). Traktor body 2.8 jest 40% szerszy niż ścieżka — wizualnie dominujący, blokuje całą widoczność, player musi czekać (zgodnie z mechaniką stop). Krowa 1.6 i pies 0.4 mieszczą się.

- [ ] **Step 4: Walidacja headless**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

Expected: zero ERRORs.

- [ ] **Step 5: Commit**

```bash
cd /Users/kamil/Projects/distracted
git add src/resources/zone.gd src/resources/hazard_entry.gd src/resources/zones/zone_village.tres
git commit -m "feat(resources): Zone visual fields + HazardEntry is_lane_obstacle

Zone: @export path_color (default brąz wiejski), stripe_color
(default piaskowy), stripe_orientation (0=poprzeczne village,
1=podłużne suburb). zone_village.tres: explicit values matching
M2a visuals.

HazardEntry: @export is_lane_obstacle (default false — backward
compat for existing crossing entries).

Both consumed by ChunkManager (visuals) and HazardSpawner (spawn
logic) in later tasks.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 2: LaneObstacle base class

**Files:**
- Create: `src/scripts/hazards/lane_obstacle.gd`

- [ ] **Step 1: Create lane_obstacle.gd**

Save `/Users/kamil/Projects/distracted/src/scripts/hazards/lane_obstacle.gd`:

```gdscript
class_name LaneObstacle
extends Area3D

signal cleared(node: Node3D)

@export var clear_distance_behind_player: float = 2.0

var _emitted_cleared: bool = false
var _player: Node3D = null

func _ready() -> void:
	collision_layer = 4  # Layer 3 (Hazards)
	collision_mask = 2   # Layer 2 (Player)
	body_entered.connect(_on_body_entered)

func _process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		return
	if _emitted_cleared:
		return
	if _player.global_position.z + clear_distance_behind_player < global_position.z:
		_emitted_cleared = true
		cleared.emit(self)
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.has_signal("collided_with_hazard"):
			body.emit_signal("collided_with_hazard")
```

Key semantics:
- Static obstacle — no `_process` motion
- Player walks in -z direction. Obstacle has fixed z (set at spawn). When `player.z + buffer < obstacle.z`, player is beyond the obstacle (player.z is more negative = further forward in walking direction)
- Wait — let me re-check. Player moves in -z. So as time passes, player.z DECREASES. Obstacle.z is fixed. When player.z < obstacle.z (player further in -z), player has walked past. With buffer: cleared when `player.z + 2 < obstacle.z` → equivalent to `player.z < obstacle.z - 2`. Correct.

- [ ] **Step 2: Walidacja headless**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

Expected: zero ERRORs. Class registered globally as `LaneObstacle`. Not yet used by any scene.

- [ ] **Step 3: Commit**

```bash
cd /Users/kamil/Projects/distracted
git add src/scripts/hazards/lane_obstacle.gd
git commit -m "feat(hazards): LaneObstacle base class (static, lane-occupying)

class_name LaneObstacle extends Area3D. Static — no lateral motion.
cleared signal fires when player.z + clear_distance_behind_player <
obstacle.z (player walked past), then queue_free.

Player avoids by switching lanes; stop mechanic doesn't help (static
hazard frozen with world during stop).

Used by kaluza/latarnia/skrzynka scenes in Task 6.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 3: InputMap lane_left + lane_right

**Files:**
- Modify: `src/project.godot`

- [ ] **Step 1: Add input actions to project.godot**

Open `/Users/kamil/Projects/distracted/src/project.godot`. Find the `[input]` section. Add two new actions before the closing brace of the section (or append at end of section):

```ini
lane_left={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":65,"physical_keycode":0,"key_label":0,"unicode":97,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194319,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
lane_right={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":68,"physical_keycode":0,"key_label":0,"unicode":100,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194321,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
```

Keycodes: 65 = A, 4194319 = Left arrow; 68 = D, 4194321 = Right arrow.

- [ ] **Step 2: Walidacja headless**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

Expected: zero ERRORs. Actions configured but no handlers yet (Task 4 adds Player handlers).

- [ ] **Step 3: Commit**

```bash
cd /Users/kamil/Projects/distracted
git add src/project.godot
git commit -m "feat(input): lane_left + lane_right actions for suburb 2-lane

A / Left arrow → lane_left. D / Right arrow → lane_right.
Both with deadzone 0.5. Player handlers come in Task 4. In
village (lane_count=1) handlers no-op; in suburb (lane_count=2)
trigger lane tween.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 4: Player lane mechanic

**Files:**
- Modify: `src/scripts/game/player.gd`

- [ ] **Step 1: Replace player.gd contents**

Replace `/Users/kamil/Projects/distracted/src/scripts/game/player.gd` with:

```gdscript
extends CharacterBody3D

enum WalkState { WALKING, STOPPED }

const LANE_TWEEN_DURATION: float = 0.2
const ZONE_TRANSITION_TWEEN_DURATION: float = 0.1  # half of lane switch

signal collided_with_hazard
signal stop_pressed
signal check_phone_pressed

var walk_state: WalkState = WalkState.WALKING
var current_lane: int = 0
var _lane_tween: Tween = null

func _physics_process(delta: float) -> void:
	if GameState.phase == GameState.GamePhase.GAME_OVER:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var effective_speed: float = GameState.speed if walk_state == WalkState.WALKING else 0.0
	velocity.z = -effective_speed
	if walk_state == WalkState.WALKING:
		GameState.add_distance(effective_speed * delta)

	velocity.y = 0.0
	move_and_slide()

func _input(event: InputEvent) -> void:
	if GameState.phase == GameState.GamePhase.GAME_OVER:
		return
	if event.is_action_pressed("stop"):
		stop_pressed.emit()
	elif event.is_action_pressed("check_phone"):
		check_phone_pressed.emit()
		NotificationManager.request_check_phone()
	elif event.is_action_pressed("dismiss_notification"):
		if GameState.phase == GameState.GamePhase.PHONE:
			NotificationManager.dismiss_current()
	elif event.is_action_pressed("lane_left"):
		_try_lane_switch(-1)
	elif event.is_action_pressed("lane_right"):
		_try_lane_switch(1)

func set_walking() -> void:
	walk_state = WalkState.WALKING

func set_stopped() -> void:
	walk_state = WalkState.STOPPED

func _try_lane_switch(delta_lane: int) -> void:
	if GameState.current_zone == null:
		return
	var lane_count: int = GameState.current_zone.lane_count
	if lane_count < 2:
		return
	var target_lane: int = clampi(current_lane + delta_lane, 0, lane_count - 1)
	if target_lane == current_lane:
		return
	current_lane = target_lane
	var target_x: float = _lane_x_for(current_lane, lane_count)
	if _lane_tween:
		_lane_tween.kill()
	_lane_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_lane_tween.tween_property(self, "position:x", target_x, LANE_TWEEN_DURATION)

func _lane_x_for(lane_index: int, lane_count: int) -> float:
	if lane_count == 1:
		return 0.0
	var path_width: float = GameState.current_zone.path_width if GameState.current_zone else 3.6
	var lane_width: float = path_width / float(lane_count)
	return (float(lane_index) - float(lane_count - 1) / 2.0) * lane_width

func reset_lane_for_current_zone(animate: bool = false) -> void:
	if GameState.current_zone == null:
		return
	var lane_count: int = GameState.current_zone.lane_count
	if lane_count == 1:
		current_lane = 0
	else:
		current_lane = randi() % lane_count
	var target_x: float = _lane_x_for(current_lane, lane_count)
	if _lane_tween:
		_lane_tween.kill()
		_lane_tween = null
	if animate:
		_lane_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		_lane_tween.tween_property(self, "position:x", target_x, ZONE_TRANSITION_TWEEN_DURATION)
	else:
		position.x = target_x
```

Changes vs M2a player.gd:
- Added `LANE_TWEEN_DURATION` const + `ZONE_TRANSITION_TWEEN_DURATION` const (no LANE_POSITIONS_2 const — formula-based from current_zone.path_width)
- Added `current_lane: int = 0` + `_lane_tween: Tween = null` state
- Added `lane_left` and `lane_right` action handlers in `_input` (guard: only when `current_zone.lane_count >= 2`)
- Added `_try_lane_switch(delta_lane)` — tween-driven lane change with kill-previous-tween
- Added `_lane_x_for(lane_index, lane_count)` — geometric lane position calculator reading `current_zone.path_width` (supports 1, 2, 3+ lanes; LANE_POSITIONS_2 const removed since formula handles 2-lane suburb at path 3.6 → ±0.9)
- Added `reset_lane_for_current_zone(animate)` — random lane selection; if animate=true uses 0.1s tween (half of LANE_TWEEN_DURATION), else instant set

Random lane selection (zamiast zawsze prawy): gracz wchodzący w suburb ląduje na losowym pasie — dodaje element zaskoczenia, zmusza do orientacji.

- [ ] **Step 2: Walidacja headless**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

Expected: zero ERRORs.

- [ ] **Step 3: Manual smoke test (optional during dev)**

Run game. In village (lane_count=1), pressing A/D does nothing (guard returns). Player stays at x=0. Game still works as M2a.

- [ ] **Step 4: Commit**

```bash
cd /Users/kamil/Projects/distracted
git add src/scripts/game/player.gd
git commit -m "feat(player): lane mechanic with tween (active in 2+ lane zones)

Tween 0.2s EASE_IN_OUT cubic. lane_left/lane_right inputs trigger
_try_lane_switch which kills previous tween and starts new one.
_lane_x_for computes positions from current_zone.path_width:
(lane_idx - (count-1)/2) * (path_width / count). Supports 1/2/3+
lanes geometrically. Village 1-lane: x=0. Suburb 2-lane path 3.6:
x=±0.9.

reset_lane_for_current_zone(animate=false) — sets random lane
(randi() % lane_count) based on zone's lane_count (0 for 1-lane,
random for 2-lane). If animate=true uses 0.1s tween (half of lane
switch, ZONE_TRANSITION_TWEEN_DURATION). Called by Game on zone
transition (animate=true) + initial reset (animate=false).

Guards prevent lane action in 1-lane zones (village) — Player
stays at x=0 there, unchanged behavior.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 5: Suburb crossing hazard scenes (ciezarowka + samochod)

**Files:**
- Create: `src/scenes/hazards/ciezarowka.tscn`
- Create: `src/scenes/hazards/samochod.tscn`

- [ ] **Step 1: Save ciezarowka.tscn**

Create `/Users/kamil/Projects/distracted/src/scenes/hazards/ciezarowka.tscn`:

```ini
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/hazards/hazard.gd" id="1_hazard"]

[sub_resource type="BoxMesh" id="BoxMesh_1"]
size = Vector3(3.0, 3.0, 5.0)

[sub_resource type="StandardMaterial3D" id="Material_1"]
albedo_color = Color(0.2, 0.3, 0.6, 1)

[sub_resource type="BoxShape3D" id="BoxShape3D_1"]
size = Vector3(3.0, 3.0, 5.0)

[node name="Ciezarowka" type="Area3D"]
script = ExtResource("1_hazard")
lateral_speed = 1.6
collision_layer = 4
collision_mask = 2

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
mesh = SubResource("BoxMesh_1")
surface_material_override/0 = SubResource("Material_1")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
shape = SubResource("BoxShape3D_1")
```

- [ ] **Step 2: Save samochod.tscn**

Create `/Users/kamil/Projects/distracted/src/scenes/hazards/samochod.tscn`:

```ini
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/hazards/hazard.gd" id="1_hazard"]

[sub_resource type="BoxMesh" id="BoxMesh_1"]
size = Vector3(1.8, 1.5, 4.2)

[sub_resource type="StandardMaterial3D" id="Material_1"]
albedo_color = Color(0.7, 0.15, 0.15, 1)

[sub_resource type="BoxShape3D" id="BoxShape3D_1"]
size = Vector3(1.8, 1.5, 4.2)

[node name="Samochod" type="Area3D"]
script = ExtResource("1_hazard")
lateral_speed = 2.5
collision_layer = 4
collision_mask = 2

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
mesh = SubResource("BoxMesh_1")
surface_material_override/0 = SubResource("Material_1")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
shape = SubResource("BoxShape3D_1")
```

- [ ] **Step 3: Walidacja headless**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

Expected: zero ERRORs.

- [ ] **Step 4: Commit**

```bash
cd /Users/kamil/Projects/distracted
git add src/scenes/hazards/ciezarowka.tscn src/scenes/hazards/samochod.tscn
git commit -m "feat(hazards): ciezarowka + samochod crossing scenes

Both use hazard.gd base. Ciezarowka 3.0x3.0x5.0 niebieski,
lateral 1.6 (big slow truck). Samochod 1.8x1.5x4.2 czerwony,
lateral 2.5 (medium fast car). Spawned by data config in
Task 7 — currently only built but not wired.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 6: Lane obstacle scenes (kaluza + latarnia + skrzynka)

**Files:**
- Create: `src/scenes/hazards/kaluza.tscn`
- Create: `src/scenes/hazards/latarnia.tscn`
- Create: `src/scenes/hazards/skrzynka.tscn`

- [ ] **Step 1: Save kaluza.tscn**

Create `/Users/kamil/Projects/distracted/src/scenes/hazards/kaluza.tscn`:

```ini
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/hazards/lane_obstacle.gd" id="1_obstacle"]

[sub_resource type="BoxMesh" id="BoxMesh_1"]
size = Vector3(1.6, 0.05, 1.2)

[sub_resource type="StandardMaterial3D" id="Material_1"]
albedo_color = Color(0.2, 0.3, 0.4, 1)

[sub_resource type="BoxShape3D" id="BoxShape3D_1"]
size = Vector3(1.6, 0.05, 1.2)

[node name="Kaluza" type="Area3D"]
script = ExtResource("1_obstacle")
collision_layer = 4
collision_mask = 2

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
mesh = SubResource("BoxMesh_1")
surface_material_override/0 = SubResource("Material_1")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
shape = SubResource("BoxShape3D_1")
```

Kałuża is flat (0.05 tall) — sits on ground. No y-offset on mesh/collision since the shape is so thin.

- [ ] **Step 2: Save latarnia.tscn**

Create `/Users/kamil/Projects/distracted/src/scenes/hazards/latarnia.tscn`:

```ini
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/hazards/lane_obstacle.gd" id="1_obstacle"]

[sub_resource type="BoxMesh" id="BoxMesh_1"]
size = Vector3(0.3, 3.0, 0.3)

[sub_resource type="StandardMaterial3D" id="Material_1"]
albedo_color = Color(0.3, 0.3, 0.3, 1)

[sub_resource type="BoxShape3D" id="BoxShape3D_1"]
size = Vector3(0.3, 3.0, 0.3)

[node name="Latarnia" type="Area3D"]
script = ExtResource("1_obstacle")
collision_layer = 4
collision_mask = 2

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.5, 0)
mesh = SubResource("BoxMesh_1")
surface_material_override/0 = SubResource("Material_1")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.5, 0)
shape = SubResource("BoxShape3D_1")
```

Latarnia 3.0 tall → mesh/collision transform y=1.5 (half-height) so bottom sits at scene origin y=0. Spawned at y=0.5 in HazardSpawner Task 9 (which puts bottom at -0.5, slightly buried — acceptable placeholder; precise positioning in M4).

Actually for cleaner placement, HazardSpawner spawns lane obstacles at y=0.0 — bottom at ground. Let me verify with the spec... spec says `hazard.position = Vector3(lane_x, 0.5, ...)` for lane obstacles. With y=0.5 on Area3D root and mesh transform y=1.5 inside, mesh world y is 0.5 + 1.5 = 2.0 (bottom at 0.5, top at 3.5). Mesh bottom at y=0.5 — floats 0.5 above ground.

Hmm visual will show latarnia hovering. Acceptable as placeholder per spec ("placeholder visuals OK in M2b"). Final polish in M4. Don't change Y spawn — keep consistent with spec.

- [ ] **Step 3: Save skrzynka.tscn**

Create `/Users/kamil/Projects/distracted/src/scenes/hazards/skrzynka.tscn`:

```ini
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/hazards/lane_obstacle.gd" id="1_obstacle"]

[sub_resource type="BoxMesh" id="BoxMesh_1"]
size = Vector3(0.5, 1.2, 0.5)

[sub_resource type="StandardMaterial3D" id="Material_1"]
albedo_color = Color(0.9, 0.7, 0.1, 1)

[sub_resource type="BoxShape3D" id="BoxShape3D_1"]
size = Vector3(0.5, 1.2, 0.5)

[node name="Skrzynka" type="Area3D"]
script = ExtResource("1_obstacle")
collision_layer = 4
collision_mask = 2

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.6, 0)
mesh = SubResource("BoxMesh_1")
surface_material_override/0 = SubResource("Material_1")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.6, 0)
shape = SubResource("BoxShape3D_1")
```

Skrzynka 1.2 tall, mesh transform y=0.6 (half-height) for bottom at scene origin.

- [ ] **Step 4: Walidacja headless**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

Expected: zero ERRORs.

- [ ] **Step 5: Commit**

```bash
cd /Users/kamil/Projects/distracted
git add src/scenes/hazards/kaluza.tscn src/scenes/hazards/latarnia.tscn src/scenes/hazards/skrzynka.tscn
git commit -m "feat(hazards): lane obstacle scenes (kaluza/latarnia/skrzynka)

Three new static lane obstacles using lane_obstacle.gd. Kaluza
1.6x0.05x1.2 flat brudno-niebieski. Latarnia 0.3x3.0x0.3 tall
ciemnoszary (mesh transform y=1.5 so bottom at scene origin).
Skrzynka 0.5x1.2x0.5 żółty (polish post, mesh transform y=0.6).

Spawned by HazardSpawner in Task 9, after suburb pool wiring.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 7: HazardEntry .tres instances (5 new)

**Files:**
- Create: `src/resources/hazards/hazard_ciezarowka.tres`
- Create: `src/resources/hazards/hazard_samochod.tres`
- Create: `src/resources/hazards/hazard_kaluza.tres`
- Create: `src/resources/hazards/hazard_latarnia.tres`
- Create: `src/resources/hazards/hazard_skrzynka.tres`

- [ ] **Step 1: Save hazard_ciezarowka.tres**

Create `/Users/kamil/Projects/distracted/src/resources/hazards/hazard_ciezarowka.tres`:

```ini
[gd_resource type="Resource" script_class="HazardEntry" load_steps=3 format=3]

[ext_resource type="Script" path="res://resources/hazard_entry.gd" id="1_entry"]
[ext_resource type="PackedScene" path="res://scenes/hazards/ciezarowka.tscn" id="2_scene"]

[resource]
script = ExtResource("1_entry")
scene = ExtResource("2_scene")
weight = 2
spawn_lookahead_min = 13.0
spawn_lookahead_max = 17.0
is_lane_obstacle = false
```

- [ ] **Step 2: Save hazard_samochod.tres**

Create `/Users/kamil/Projects/distracted/src/resources/hazards/hazard_samochod.tres`:

```ini
[gd_resource type="Resource" script_class="HazardEntry" load_steps=3 format=3]

[ext_resource type="Script" path="res://resources/hazard_entry.gd" id="1_entry"]
[ext_resource type="PackedScene" path="res://scenes/hazards/samochod.tscn" id="2_scene"]

[resource]
script = ExtResource("1_entry")
scene = ExtResource("2_scene")
weight = 3
spawn_lookahead_min = 10.0
spawn_lookahead_max = 14.0
is_lane_obstacle = false
```

- [ ] **Step 3: Save hazard_kaluza.tres**

Create `/Users/kamil/Projects/distracted/src/resources/hazards/hazard_kaluza.tres`:

```ini
[gd_resource type="Resource" script_class="HazardEntry" load_steps=3 format=3]

[ext_resource type="Script" path="res://resources/hazard_entry.gd" id="1_entry"]
[ext_resource type="PackedScene" path="res://scenes/hazards/kaluza.tscn" id="2_scene"]

[resource]
script = ExtResource("1_entry")
scene = ExtResource("2_scene")
weight = 2
spawn_lookahead_min = 12.0
spawn_lookahead_max = 16.0
is_lane_obstacle = true
```

- [ ] **Step 4: Save hazard_latarnia.tres**

Create `/Users/kamil/Projects/distracted/src/resources/hazards/hazard_latarnia.tres`:

```ini
[gd_resource type="Resource" script_class="HazardEntry" load_steps=3 format=3]

[ext_resource type="Script" path="res://resources/hazard_entry.gd" id="1_entry"]
[ext_resource type="PackedScene" path="res://scenes/hazards/latarnia.tscn" id="2_scene"]

[resource]
script = ExtResource("1_entry")
scene = ExtResource("2_scene")
weight = 2
spawn_lookahead_min = 10.0
spawn_lookahead_max = 14.0
is_lane_obstacle = true
```

- [ ] **Step 5: Save hazard_skrzynka.tres**

Create `/Users/kamil/Projects/distracted/src/resources/hazards/hazard_skrzynka.tres`:

```ini
[gd_resource type="Resource" script_class="HazardEntry" load_steps=3 format=3]

[ext_resource type="Script" path="res://resources/hazard_entry.gd" id="1_entry"]
[ext_resource type="PackedScene" path="res://scenes/hazards/skrzynka.tscn" id="2_scene"]

[resource]
script = ExtResource("1_entry")
scene = ExtResource("2_scene")
weight = 1
spawn_lookahead_min = 11.0
spawn_lookahead_max = 15.0
is_lane_obstacle = true
```

- [ ] **Step 6: Walidacja headless**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

Expected: zero ERRORs.

- [ ] **Step 7: Commit**

```bash
cd /Users/kamil/Projects/distracted
git add src/resources/hazards/hazard_ciezarowka.tres src/resources/hazards/hazard_samochod.tres src/resources/hazards/hazard_kaluza.tres src/resources/hazards/hazard_latarnia.tres src/resources/hazards/hazard_skrzynka.tres
git commit -m "feat(resources): 5 HazardEntry instances for suburb pool

Crossing (is_lane_obstacle=false):
- ciezarowka: weight 2, lookahead 13-17
- samochod: weight 3, lookahead 10-14

Lane obstacles (is_lane_obstacle=true):
- kaluza: weight 2, lookahead 12-16
- latarnia: weight 2, lookahead 10-14
- skrzynka: weight 1, lookahead 11-15

Consumed by zone_suburb.tres in Task 8 + HazardSpawner branch in Task 10.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 8: zone_suburb.tres

**Files:**
- Create: `src/resources/zones/zone_suburb.tres`

- [ ] **Step 1: Save zone_suburb.tres**

Create `/Users/kamil/Projects/distracted/src/resources/zones/zone_suburb.tres`:

```ini
[gd_resource type="Resource" script_class="Zone" load_steps=9 format=3]

[ext_resource type="Script" path="res://resources/zone.gd" id="1_zone"]
[ext_resource type="Script" path="res://resources/hazard_entry.gd" id="2_entry"]
[ext_resource type="Resource" path="res://resources/hazards/hazard_ciezarowka.tres" id="3_ciezarowka"]
[ext_resource type="Resource" path="res://resources/hazards/hazard_samochod.tres" id="4_samochod"]
[ext_resource type="Resource" path="res://resources/hazards/hazard_pies.tres" id="5_pies"]
[ext_resource type="Resource" path="res://resources/hazards/hazard_kaluza.tres" id="6_kaluza"]
[ext_resource type="Resource" path="res://resources/hazards/hazard_latarnia.tres" id="7_latarnia"]
[ext_resource type="Resource" path="res://resources/hazards/hazard_skrzynka.tres" id="8_skrzynka"]

[resource]
script = ExtResource("1_zone")
name_id = "suburb"
walk_speed = 9.0
willpower_max = 2.5
spawn_interval_min = 18.0
spawn_interval_max = 32.0
hazard_pool = Array[ExtResource("2_entry")]([ExtResource("3_ciezarowka"), ExtResource("4_samochod"), ExtResource("5_pies"), ExtResource("6_kaluza"), ExtResource("7_latarnia"), ExtResource("8_skrzynka")])
lane_count = 2
path_width = 4.0
path_color = Color(0.4, 0.4, 0.45, 1)
stripe_color = Color(1, 1, 1, 1)
stripe_orientation = 1
```

`path_width = 4.0` — dwa razy szerszy niż village 2.0. Lanes computed via formula `(idx - (count-1)/2) * (path_width / count)`: lane 0 = -1.0, lane 1 = +1.0 (each lane width 2.0). Future city 3 lanes → path 6.0, lanes at -2/0/+2 (same 2.0 width per lane).

Pool sums to weight 12: crossing (ciezarowka+samochod+pies) = 7, lane (kaluza+latarnia+skrzynka) = 5. Probability split ~58% crossing / ~42% lane.

- [ ] **Step 2: Walidacja headless**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

Expected: zero ERRORs.

- [ ] **Step 3: Commit**

```bash
cd /Users/kamil/Projects/distracted
git add src/resources/zones/zone_suburb.tres
git commit -m "feat(resources): zone_suburb.tres — second zone data

Suburb: walk_speed 9.0 (faster than village 6.0), willpower_max
2.5 (was 3.0), spawn_interval 18-32m (denser than 25-40m),
lane_count 2. Hazard pool: ciezarowka:2, samochod:3, pies:2
(reused from village), kaluza:2, latarnia:2, skrzynka:1. Visual:
path_color (0.4, 0.4, 0.45) dark gray asphalt, stripe_color white,
stripe_orientation 1 (longitudinal lane divider).

Loaded by GameState ZONES array in Task 9.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 9: GameState ZONES array + _update_zone refactor

**Files:**
- Modify: `src/scripts/autoloads/game_state.gd`

- [ ] **Step 1: Add ZONE_SUBURB preload + ZONES array**

In `/Users/kamil/Projects/distracted/src/scripts/autoloads/game_state.gd`, find the existing `ZONE_VILLAGE` const (line 3):

```gdscript
const ZONE_VILLAGE: Resource = preload("res://resources/zones/zone_village.tres")
```

Add immediately below it:

```gdscript
const ZONE_SUBURB: Resource = preload("res://resources/zones/zone_suburb.tres")
const ZONES: Array[Resource] = [ZONE_VILLAGE, ZONE_SUBURB]
```

- [ ] **Step 2: Update _update_zone to set current_zone**

Find the `_update_zone()` function. Replace it with:

```gdscript
func _update_zone() -> void:
	var new_zone: ZoneIndex = ZoneIndex.CITY
	for i in range(ZONE_THRESHOLDS.size() - 1, -1, -1):
		if distance >= ZONE_THRESHOLDS[i]:
			new_zone = i as ZoneIndex
			break
	if new_zone == zone:
		return
	zone = new_zone
	var safe_idx: int = mini(new_zone, ZONES.size() - 1)
	current_zone = ZONES[safe_idx]
	speed = current_zone.walk_speed
	zone_changed.emit(zone)
```

Changes:
- `current_zone = ZONES[safe_idx]` — clamp index to available zones (town/city → suburb until M2c builds those)
- `speed = current_zone.walk_speed` — sourced from Zone Resource (was `speed = ZONE_SPEEDS[zone]` which used parallel const array)

- [ ] **Step 3: Walidacja headless**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

Expected: zero ERRORs.

- [ ] **Step 4: Manual smoke test (optional during dev)**

Run game. Walk past 500m → zone transition fires, `current_zone` becomes `ZONE_SUBURB`. HazardSpawner now picks from suburb pool (mixed crossing + lane obstacles). Without Task 10 (HazardSpawner lane branch) and Task 11 (Game zone_changed handler), behavior:
- Crossing hazards spawn correctly (existing code path)
- Lane obstacles spawn at `SPAWN_X_ABS * spawn_side` (=±3.5, off-path) because old `_spawn_hazard` doesn't check is_lane_obstacle yet → harmless visual (they're off-path and don't hit player)
- Player stays at x=0 (no zone reset until Task 11)
- ChunkManager still village look (until Task 12)

Game playable, just not yet visually/mechanically suburb.

- [ ] **Step 5: Commit**

```bash
cd /Users/kamil/Projects/distracted
git add src/scripts/autoloads/game_state.gd
git commit -m "feat(state): ZONE_SUBURB preload + ZONES array, _update_zone sets current_zone

GameState.ZONES: Array[Resource] = [ZONE_VILLAGE, ZONE_SUBURB].
_update_zone() now reads zone index, clamps to ZONES.size()-1
(town/city → suburb until M2c), assigns current_zone and updates
speed from Resource walk_speed.

At distance >= 500m, current_zone switches to suburb. HazardSpawner
auto-picks from suburb pool (data-driven from M2a). Lane-obstacle
spawn position handled in Task 10. Player lane reset in Task 11.
ChunkManager visuals in Task 12.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 10: HazardSpawner lane-obstacle branch

**Files:**
- Modify: `src/scripts/autoloads/hazard_spawner.gd`

- [ ] **Step 1: Update _spawn_hazard with lane-obstacle branch**

In `/Users/kamil/Projects/distracted/src/scripts/autoloads/hazard_spawner.gd`, find `_spawn_hazard()`:

```gdscript
func _spawn_hazard() -> void:
	var entry = _pick_hazard_entry()
	if entry == null or entry.scene == null:
		return
	var hazard: Node3D = entry.scene.instantiate()
	var lookahead: float = randf_range(entry.spawn_lookahead_min, entry.spawn_lookahead_max)
	var spawn_side: float = 1.0 if randf() < 0.5 else -1.0
	hazard.position = Vector3(SPAWN_X_ABS * spawn_side, 0.75, _player.global_position.z - lookahead)
	_container.add_child(hazard)
	hazard.cleared.connect(_on_hazard_cleared)
	hazard_spawned.emit(hazard)
```

Replace with:

```gdscript
func _spawn_hazard() -> void:
	var entry = _pick_hazard_entry()
	if entry == null or entry.scene == null:
		return
	var hazard: Node3D = entry.scene.instantiate()
	var lookahead: float = randf_range(entry.spawn_lookahead_min, entry.spawn_lookahead_max)

	if entry.is_lane_obstacle:
		var lane_count: int = GameState.current_zone.lane_count
		var lane_x: float = _lane_x_for_spawn(lane_count)
		hazard.position = Vector3(lane_x, 0.5, _player.global_position.z - lookahead)
	else:
		var spawn_side: float = 1.0 if randf() < 0.5 else -1.0
		var path_half_width: float = GameState.current_zone.path_width / 2.0
		var spawn_x: float = (path_half_width + SPAWN_X_BUFFER) * spawn_side
		hazard.position = Vector3(spawn_x, 0.75, _player.global_position.z - lookahead)

	_container.add_child(hazard)
	hazard.cleared.connect(_on_hazard_cleared)
	hazard_spawned.emit(hazard)
```

- [ ] **Step 2: Add SPAWN_X_BUFFER const + _lane_x_for_spawn helper**

Near the top of the file (after `extends Node`), add the buffer constant:

```gdscript
const SPAWN_X_BUFFER: float = 2.0
```

And REMOVE the old `SPAWN_X_ABS` const (replaced by per-zone formula above).

Append at end of file:

```gdscript
func _lane_x_for_spawn(lane_count: int) -> float:
	if lane_count == 1:
		return 0.0
	var path_width: float = GameState.current_zone.path_width
	var lane_width: float = path_width / float(lane_count)
	var lane: int = randi() % lane_count
	return (float(lane) - float(lane_count - 1) / 2.0) * lane_width
```

Both crossing SPAWN_X (`path_half_width + SPAWN_X_BUFFER`) and lane positions (`(lane - (count-1)/2) * lane_width`) computed from zone path_width. Village (path 2.0): SPAWN_X 3.0. Suburb (path 4.0): SPAWN_X 4.0. Future city (path 6.0): SPAWN_X 5.0. Buffer 2.0 gives consistent ~0.6 margin past path edge for traktor body 1.4.

- [ ] **Step 3: Walidacja headless**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

Expected: zero ERRORs.

- [ ] **Step 4: Commit**

```bash
cd /Users/kamil/Projects/distracted
git add src/scripts/autoloads/hazard_spawner.gd
git commit -m "feat(hazards): HazardSpawner data-driven SPAWN_X + lane-obstacle branch

_spawn_hazard checks entry.is_lane_obstacle:
- true: spawn at lane_x (random lane from current_zone), y=0.5,
  fixed z ahead — static lane obstacle
- false: spawn at path_half_width + SPAWN_X_BUFFER (1.7), random
  side, y=0.75 — crossing hazard

Removed SPAWN_X_ABS const (was 3.5 hardcoded). Both crossing
spawn_x and lane positions computed from current_zone.path_width:
village 2.0 → SPAWN_X 3.0, lanes [0]. Suburb 4.0 → SPAWN_X 4.0,
lanes ±1.0. Future city 6.0 → SPAWN_X 5.0, lanes -2/0/+2.
Uniform lane width 2.0 across all multi-lane zones.

_lane_x_for_spawn formula: (lane - (count-1)/2) * (path_width /
count). Supports 1/2/3+ lanes.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 11: Game.gd zone_changed handler + initial lane reset

**Files:**
- Modify: `src/scripts/game/game.gd`

- [ ] **Step 1: Wire zone_changed signal**

Open `/Users/kamil/Projects/distracted/src/scripts/game/game.gd`. Current `_ready()` likely:

```gdscript
func _ready() -> void:
	GameState.reset_metrics()
	HazardSpawner.bind_scene(_hazard_container, _player)
	HazardSpawner.start()
	NotificationManager.start()
	_stop_controller.bind_player(_player)
	_player.collided_with_hazard.connect(_on_player_collided)
	_hud.stop_hold_started.connect(_on_ui_stop_hold_started)
	_hud.stop_hold_released.connect(_on_ui_stop_hold_released)
```

Add the zone_changed connection + initial lane reset AFTER `GameState.reset_metrics()` and AFTER all subscriptions. Final form:

```gdscript
func _ready() -> void:
	GameState.reset_metrics()
	GameState.zone_changed.connect(_on_zone_changed)
	HazardSpawner.bind_scene(_hazard_container, _player)
	HazardSpawner.start()
	NotificationManager.start()
	_stop_controller.bind_player(_player)
	_player.collided_with_hazard.connect(_on_player_collided)
	_hud.stop_hold_started.connect(_on_ui_stop_hold_started)
	_hud.stop_hold_released.connect(_on_ui_stop_hold_released)
	_player.reset_lane_for_current_zone()
```

Add the handler at end of file:

```gdscript
func _on_zone_changed(_new_zone: GameState.ZoneIndex) -> void:
	_player.reset_lane_for_current_zone(true)
```

Initial call w `_ready` używa `animate=false` (instant set na starcie gry).
Zone transition handler używa `animate=true` (0.1s tween — half lane-switch animation).

Gdy gracz wchodzi w suburb z village, ląduje na losowym pasie (-0.9 lub +0.9) płynnym animowanym ruchem.

- [ ] **Step 2: Walidacja headless**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

Expected: zero ERRORs.

- [ ] **Step 3: Manual smoke test**

Run game. In village walk straight. Around 500m, zone transitions to suburb — player should auto-jump to right lane (x=+0.9). Press A/D to switch lanes. Lane obstacles now matter (kaluza/latarnia/skrzynka spawn on lanes). Crossings (ciezarowka/samochod) still work.

- [ ] **Step 4: Commit**

```bash
cd /Users/kamil/Projects/distracted
git add src/scripts/game/game.gd
git commit -m "feat(game): zone_changed handler + initial Player lane reset

Game._ready: connect GameState.zone_changed → call
_player.reset_lane_for_current_zone(true) on every zone transition
(animated 0.1s half-tween). Also called once in _ready after
reset_metrics with animate=false (instant initial set for village
center).

When player crosses 500m, zone changes village→suburb, Player
tweens to random lane (-0.9 or +0.9) with 0.1s ease-out animation.
From there A/D toggle between lanes via 0.2s tween.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 12: ChunkManager per-zone visuals

**Files:**
- Modify: `src/scripts/game/chunk_manager.gd`

- [ ] **Step 1: Replace chunk_manager.gd**

Replace `/Users/kamil/Projects/distracted/src/scripts/game/chunk_manager.gd` with:

```gdscript
extends Node3D

const CHUNK_LENGTH: float = 20.0
const ACTIVE_CHUNKS: int = 6
const POOL_SIZE: int = 10
const RECYCLE_BEHIND_PLAYER: float = 25.0
const STRIPE_INTERVAL: float = 4.0
const STRIPE_LENGTH_TRANSVERSE: float = 0.3
const STRIPE_LENGTH_LONGITUDINAL: float = 2.5
const LONGITUDINAL_GAP: float = 1.5

@onready var _player: Node3D = get_parent().get_parent().get_node("Player")

var _pool: Array[Node3D] = []
var _active: Array[Node3D] = []
var _next_z: float = 0.0

func _ready() -> void:
	for i in POOL_SIZE:
		var chunk: Node3D = Node3D.new()
		chunk.visible = false
		add_child(chunk)
		_pool.append(chunk)
	for i in ACTIVE_CHUNKS:
		_spawn_chunk()

func _process(_delta: float) -> void:
	if not _player:
		return
	var player_z: float = _player.global_position.z
	for chunk in _active.duplicate():
		if chunk.position.z > player_z + RECYCLE_BEHIND_PLAYER:
			_recycle(chunk)
			_spawn_chunk()

func _spawn_chunk() -> void:
	if _pool.is_empty():
		return
	var chunk: Node3D = _pool.pop_back()
	for child in chunk.get_children():
		child.queue_free()
	_build_chunk_visuals(chunk)
	chunk.position.z = _next_z
	chunk.visible = true
	_next_z -= CHUNK_LENGTH
	_active.append(chunk)

func _recycle(chunk: Node3D) -> void:
	_active.erase(chunk)
	chunk.visible = false
	_pool.append(chunk)

func _build_chunk_visuals(chunk: Node3D) -> void:
	var zone: Resource = GameState.current_zone
	var path_width: float = zone.path_width if zone != null else 3.6
	var path_color: Color = zone.path_color if zone != null else Color(0.4, 0.3, 0.2)
	var stripe_color: Color = zone.stripe_color if zone != null else Color(0.85, 0.78, 0.55)
	var stripe_orientation: int = zone.stripe_orientation if zone != null else 0

	var path_mesh: MeshInstance3D = MeshInstance3D.new()
	var path_box: BoxMesh = BoxMesh.new()
	path_box.size = Vector3(path_width, 0.1, CHUNK_LENGTH)
	path_mesh.mesh = path_box
	path_mesh.position = Vector3(0, -0.05, -CHUNK_LENGTH / 2.0)
	var path_material: StandardMaterial3D = StandardMaterial3D.new()
	path_material.albedo_color = path_color
	path_mesh.material_override = path_material
	chunk.add_child(path_mesh)

	var stripe_material: StandardMaterial3D = StandardMaterial3D.new()
	stripe_material.albedo_color = stripe_color

	if stripe_orientation == 0:
		var stripe_box: BoxMesh = BoxMesh.new()
		stripe_box.size = Vector3(path_width - 0.2, 0.04, STRIPE_LENGTH_TRANSVERSE)
		var z: float = -STRIPE_INTERVAL
		while z > -CHUNK_LENGTH:
			var stripe: MeshInstance3D = MeshInstance3D.new()
			stripe.mesh = stripe_box
			stripe.material_override = stripe_material
			stripe.position = Vector3(0, 0.01, z)
			chunk.add_child(stripe)
			z -= STRIPE_INTERVAL
	else:
		var stripe_box: BoxMesh = BoxMesh.new()
		stripe_box.size = Vector3(0.15, 0.04, STRIPE_LENGTH_LONGITUDINAL)
		var z: float = -1.0
		while z > -CHUNK_LENGTH + 0.5:
			var stripe: MeshInstance3D = MeshInstance3D.new()
			stripe.mesh = stripe_box
			stripe.material_override = stripe_material
			stripe.position = Vector3(0, 0.01, z)
			chunk.add_child(stripe)
			z -= STRIPE_LENGTH_LONGITUDINAL + LONGITUDINAL_GAP
```

Changes vs M2a:
- Pool now contains bare `Node3D` shells (no mesh in pool — built on demand)
- `_ready()` creates Node3D shells, not full chunks
- `_spawn_chunk()` clears children + calls `_build_chunk_visuals(chunk)` — visuals built per spawn based on current zone
- `_build_chunk_visuals` reads `GameState.current_zone` and branches on `stripe_orientation` (0=transverse village, 1=longitudinal suburb lane divider)
- Both path and stripe meshes get `material_override` (single-surface mesh, simplest API)
- Removed old `_make_chunk` (replaced by `_spawn_chunk` + `_build_chunk_visuals`)

Performance: each `_spawn_chunk` allocs 1 path mesh + ~5 stripe meshes + 2 materials. With ~6 chunks active, recycle runs maybe once per second. Negligible Godot overhead.

- [ ] **Step 2: Walidacja headless**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

Expected: zero ERRORs.

- [ ] **Step 3: Manual smoke test**

Run game. Village: tan path with transverse stripes (same as M2a). Cross 500m: subsequent chunks render dark gray asphalt with longitudinal white lane divider. Old village chunks behind player retain village look — natural emergent transition.

- [ ] **Step 4: Commit**

```bash
cd /Users/kamil/Projects/distracted
git add src/scripts/game/chunk_manager.gd
git commit -m "feat(chunks): per-zone visuals + path_width (village narrow, suburb wider)

ChunkManager reads GameState.current_zone for path_width,
path_color, stripe_color, stripe_orientation. Path box scales
width per zone: village 2.8 (narrow rural path), suburb 3.6
(wider sidewalk). Pool stores bare Node3D shells; visuals built
fresh per spawn (clear children + _build_chunk_visuals).

stripe_orientation 0 (village): transverse tan stripes width
path_width - 0.2 every 4m. stripe_orientation 1 (suburb):
longitudinal white lane divider between lanes (segments + gap).

Chunks spawn ahead of player; old chunks behind retain their zone
visuals → natural biome blending at zone boundary, including
path width change.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 13: HUD NotificationArea as Button

**Files:**
- Modify: `src/scenes/game/hud.tscn`
- Modify: `src/scripts/ui/hud.gd`

- [ ] **Step 1: Replace hud.tscn**

Replace entire `/Users/kamil/Projects/distracted/src/scenes/game/hud.tscn` with:

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

[node name="NotificationArea" type="Button" parent="."]
visible = false
flat = true
focus_mode = 0
offset_left = 16.0
offset_top = 64.0
offset_right = 374.0
offset_bottom = 112.0

[node name="NotificationIcon" type="Label" parent="NotificationArea"]
offset_left = 0.0
offset_top = 0.0
offset_right = 48.0
offset_bottom = 48.0
text = "!"
horizontal_alignment = 1
vertical_alignment = 1

[node name="WillpowerBar" type="ProgressBar" parent="NotificationArea"]
offset_left = 56.0
offset_top = 8.0
offset_right = 358.0
offset_bottom = 40.0
min_value = 0.0
max_value = 3.0
value = 3.0
show_percentage = false

[node name="StopButton" type="Button" parent="."]
offset_left = 95.0
offset_top = 740.0
offset_right = 295.0
offset_bottom = 820.0
text = "STOP"
theme_override_font_sizes/font_size = 32
```

Changes vs M2a:
- `NotificationArea` type Control → Button, added `flat = true`, `focus_mode = 0`
- `NotificationIcon` type Button → Label, added alignment props

- [ ] **Step 2: Replace hud.gd**

Replace `/Users/kamil/Projects/distracted/src/scripts/ui/hud.gd` with:

```gdscript
extends CanvasLayer

signal stop_hold_started
signal stop_hold_released

@onready var _distance_label: Label = $DistanceLabel
@onready var _notification_area: Button = $NotificationArea
@onready var _notification_icon: Label = $NotificationArea/NotificationIcon
@onready var _willpower_bar: ProgressBar = $NotificationArea/WillpowerBar
@onready var _stop_button: Button = $StopButton

func _ready() -> void:
	GameState.score_changed.connect(_on_score_changed)
	NotificationManager.notification_arrived.connect(_on_notification_arrived)
	NotificationManager.phone_dismissed.connect(_on_phone_dismissed)
	NotificationManager.phone_opened.connect(_on_phone_opened)
	_notification_area.pressed.connect(_on_notification_area_pressed)
	_stop_button.button_down.connect(_on_stop_button_down)
	_stop_button.button_up.connect(_on_stop_button_up)

func _process(_delta: float) -> void:
	if NotificationManager.willpower_active:
		_willpower_bar.value = NotificationManager.willpower_remaining

func _on_score_changed(new_score: int) -> void:
	_distance_label.text = "%d m" % new_score

func _on_notification_arrived(_notification) -> void:
	var max_value: float = NotificationManager.willpower_remaining
	_willpower_bar.max_value = max_value
	_willpower_bar.value = max_value
	_notification_area.visible = true

func _on_phone_opened(_voluntary: bool) -> void:
	_notification_area.visible = false

func _on_phone_dismissed() -> void:
	_notification_area.visible = false

func _on_notification_area_pressed() -> void:
	NotificationManager.request_check_phone()

func _on_stop_button_down() -> void:
	stop_hold_started.emit()

func _on_stop_button_up() -> void:
	stop_hold_released.emit()
```

Changes vs M2a:
- `_notification_area` typed as `Button` (was `Control`)
- `_notification_icon` typed as `Label` (was `Button`); no longer has pressed signal
- Removed `_notification_icon.pressed.connect(...)` — Label can't be pressed
- Added `_notification_area.pressed.connect(_on_notification_area_pressed)` — whole area is the click target
- Renamed handler `_on_notification_icon_pressed` → `_on_notification_area_pressed` (semantic alignment)
- Handler body unchanged — still calls `NotificationManager.request_check_phone()`

- [ ] **Step 3: Walidacja headless**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

Expected: zero ERRORs.

- [ ] **Step 4: Manual smoke test**

Run game. Wait for notification (~5-8s). NotificationArea appears. Tap anywhere on the area (icon side, bar side, between them) — phone overlay should open (voluntary). Confirmed via 3 tap positions.

- [ ] **Step 5: Commit**

```bash
cd /Users/kamil/Projects/distracted
git add src/scenes/game/hud.tscn src/scripts/ui/hud.gd
git commit -m "feat(hud): NotificationArea as Button — entire area clickable

NotificationArea Control → Button (flat=true, focus_mode=0,
transparent appearance). NotificationIcon Button → Label
(non-interactive visual only). Click anywhere on area fires
request_check_phone() — bigger tap target especially for mobile.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 14: End-to-end manual playtest

Final validation. No code; full playthrough.

- [ ] **Step 1: Headless run**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1 | grep -i error
```

Expected: brak outputu (zero ERRORów).

- [ ] **Step 2: Full playthrough checklist**

Run game (`godot --path /Users/kamil/Projects/distracted/src/`). Click Start.

Village (0-500m):
- [ ] Look identical to M2a (tan path, transverse stripes)
- [ ] Hazards: traktor / pies / krowa, random side spawn
- [ ] Willpower 3.0s
- [ ] Player at x=0 center, A/D keys do nothing
- [ ] STOP, dismiss, check_phone all work as M2a

Zone transition (~500m):
- [ ] Player auto-jumps to right lane (x=+0.9)
- [ ] Next chunks spawn with dark gray asphalt + white longitudinal stripes
- [ ] Old village chunks behind player retain tan/brown look (natural blend)
- [ ] Willpower for next notification = 2.5s (slightly shorter)

Suburb (500m+):
- [ ] A / Left arrow → tween to left lane (x=-0.9)
- [ ] D / Right arrow → tween to right lane (x=+0.9)
- [ ] Tween smooth, ~0.2s
- [ ] Pressing A while in left lane = no-op (clamped)
- [ ] Crossings (ciezarowka niebieski, samochod czerwony, pies brown) wjeżdżają z boków, mechanika identyczna jak village
- [ ] Lane obstacles (kaluza brudno-niebieski, latarnia ciemnoszary, skrzynka żółty) spawnują się na jednym z 2 pasów
- [ ] Player on wrong lane → kolizja → GAME_OVER
- [ ] Player switches lanes → omija → idzie dalej, obstacle "cleared" emit gdy minięty
- [ ] STOP nie pomaga przy lane obstacle (statyczny, świat stoi, obstacle stoi) — gracz musi switch
- [ ] STOP działa dla crossings jak w village (auto-resume na cleared, lub 1s w PHONE mode)

HUD:
- [ ] NotificationArea: tap na ikonkę `!` → phone opens
- [ ] Tap na środku obszaru (między ikonką a barem) → phone opens
- [ ] Tap na willpower bar → phone opens

- [ ] **Step 3: Test sukcesu z testerką**

Per spec: 3-5 min sesja.

> *"Czy suburb czuje się inaczej niż wieś? Co cię najbardziej zaskoczyło?"*

Jeśli "tak, inaczej" + rozróżnia mechaniki crossings vs lane obstacles + zauważa visual change → M2b done, lecimy M2c (more zones, debug teleport, audio?).
Jeśli "meh" → tuning (kolory wyraźniejsze? lane indicators? willpower bardziej drastyczne?).

- [ ] **Step 4: Update doc/milestones.md (jeśli M2b done)**

Edit `doc/milestones.md` M2 section to note M2b complete:

```markdown
**M2a Village Variety DONE 2026-06-03.** [existing entry]

**M2b Suburb Biome DONE 2026-XX-XX.** Drugi biom z lane-switchingiem
i lane obstacles. 5 nowych hazardów. Visual differentiation per
zone. Merged w XXXXXXX. Spec:
`doc/specs/2026-06-03-suburb-biome-design.md`. Plan:
`doc/plans/2026-06-03-suburb-biome.md`.
```

Commit:
```bash
cd /Users/kamil/Projects/distracted
git add doc/milestones.md
git commit -m "docs(milestones): M2b Suburb Biome complete

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

- [ ] **Step 5: Merge feature branch**

Use `superpowers:finishing-a-development-branch` — option 1 merge locally or option 2 PR.

---

## Spec coverage check

| Spec section | Task(s) |
|---|---|
| Lane mechanic (input, tween, positions) | Tasks 3, 4 |
| Zone visual fields + zone_village.tres update | Task 1 |
| LaneObstacle base class | Task 2 |
| HazardEntry is_lane_obstacle | Task 1 |
| Crossing suburb scenes (ciezarowka, samochod) | Task 5 |
| Lane obstacle scenes (kaluza, latarnia, skrzynka) | Task 6 |
| HazardEntry .tres for 5 new hazards | Task 7 |
| zone_suburb.tres | Task 8 |
| GameState.current_zone update + ZONES array | Task 9 |
| HazardSpawner lane-obstacle branch | Task 10 |
| Game.gd zone_changed handler + initial Player reset | Task 11 |
| ChunkManager per-zone visuals | Task 12 |
| HUD NotificationArea Button | Task 13 |
| End-to-end validation | Task 14 |

All spec sections mapped to tasks.
