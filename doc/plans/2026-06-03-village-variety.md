# Village Variety (M2a) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dodaje pies + krowa hazardy w wiosce obok przeskalowanego traktora, każdy z innym rytmem (4.0 / 1.5 / 1.8 lateral u/s) i innym spawn_lookahead. Hazardy wychodzą losowo z lewej lub prawej. Wprowadza Zone i HazardEntry Resources — pierwszy data-driven migration MVP stałych pod fundację M2b+ stref.

**Architecture:** Refactor istniejącego `tractor.gd` do `hazard.gd` base class używanej przez 3 sceny (`tractor.tscn`, `pies.tscn`, `krowa.tscn`) różniące się tylko @export values + mesh/collision. Zone i HazardEntry to dane (.tres) konsumowane przez HazardSpawner (weighted pick) i NotificationManager (willpower_max). `GameState.current_zone` jako single source of truth dla per-zone params.

**Tech Stack:** Godot 4.6, GDScript typed. Brak GUT (testing w M5). Walidacja per task: `godot --headless --quit` zero ERRORs + manual playtest na końcu fazy.

---

## Spec reference

Pełny spec: `doc/specs/2026-06-03-village-variety-design.md`.

## Branch strategy

Per `CLAUDE.md`: jedna gałąź dla M2a, `feature/m2a-village-variety`. Po Tasku 1 utwórz:

```bash
git checkout -b feature/m2a-village-variety
```

## File Structure

### Nowe pliki

| Plik | Cel |
|---|---|
| `src/scripts/hazards/hazard.gd` | Base class Area3D — lateral motion bidirectional + cleared signal + collision |
| `src/scenes/hazards/pies.tscn` | Mały hazard (mesh 0.4×0.4×0.6, lateral 4.0) |
| `src/scenes/hazards/krowa.tscn` | Średni hazard (mesh 1.6×1.8×2.5, lateral 1.5) |
| `src/resources/hazard_entry.gd` | HazardEntry Resource class — scene + weight + per-hazard lookahead |
| `src/resources/hazards/hazard_traktor.tres` | HazardEntry dla traktora |
| `src/resources/hazards/hazard_pies.tres` | HazardEntry dla pies |
| `src/resources/hazards/hazard_krowa.tres` | HazardEntry dla krowa |
| `src/resources/zone.gd` | Zone Resource class — walk_speed, willpower_max, spawn_interval, hazard_pool, lane_count |
| `src/resources/zones/zone_village.tres` | Pierwsza Zone instancja (jedyna w M2a) |

### Modyfikowane pliki

| Plik | Co zmieniamy |
|---|---|
| `src/scripts/hazards/tractor.gd` | **DELETE** (logika przeniesiona do hazard.gd) |
| `src/scenes/hazards/tractor.tscn` | Zmiana script → hazard.gd, mesh 2.8×2.6×4.0, lateral_speed 1.8, kolor placeholder |
| `src/scripts/autoloads/hazard_spawner.gd` | Pełny refactor: weighted pick z `current_zone.hazard_pool`, random spawn side, per-HazardEntry lookahead, `SPAWN_X_ABS` 3.5 |
| `src/scripts/autoloads/game_state.gd` | Dodać `current_zone: Zone`, preload village w `reset_metrics()`, ustawić `speed` z zone |
| `src/scripts/autoloads/notification_manager.gd` | `WILLPOWER_MAX_MVP` const → `GameState.current_zone.willpower_max` |
| `src/scripts/ui/hud.gd` | `_willpower_bar.max_value` ustawiane per-notification (zamiast w `_ready`) |

### Bez zmian

- `src/scripts/game/player.gd` — Player używa `GameState.speed` (zone-aware przez Task 5)
- `src/scripts/game/stop_controller.gd` — dual-mode niezmieniony, listenuje na `hazard_cleared` jak dotychczas
- `src/scripts/game/game.gd` — wiring identyczny
- `src/scenes/game/*.tscn` — żadne zmiany struktur scen
- `src/resources/notifications/mama_zjadles.tres` — bez zmian

## Walidacja per task

Każdy task kończy się:
1. `cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1` — zero ERRORów
2. Specyficzny manual check (definiowany per task) jeśli możliwy headless
3. `git commit`

End-to-end manual playtest w Tasku 9.

---

## Task 1: Hazard base class

**Files:**
- Create: `src/scripts/hazards/hazard.gd`

- [ ] **Step 1: Stwórz hazard.gd**

Zapisz `/Users/kamil/Projects/distracted/src/scripts/hazards/hazard.gd`:

```gdscript
class_name Hazard
extends Area3D

signal cleared(node: Node3D)

@export var lateral_speed: float = 1.5
@export var path_half_width: float = 1.8

var _direction: float = 1.0
var _emitted_cleared: bool = false

func _ready() -> void:
	collision_layer = 4  # Layer 3 (Hazards)
	collision_mask = 2   # Layer 2 (Player)
	body_entered.connect(_on_body_entered)
	_direction = -signf(position.x)
	if _direction == 0.0:
		_direction = 1.0

func _process(delta: float) -> void:
	position.x += lateral_speed * _direction * delta
	if not _emitted_cleared:
		var past_far_edge: bool = (
			(_direction > 0.0 and position.x > path_half_width)
			or (_direction < 0.0 and position.x < -path_half_width)
		)
		if past_far_edge:
			_emitted_cleared = true
			cleared.emit(self)
	if absf(position.x) > path_half_width + 2.0:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.has_signal("collided_with_hazard"):
			body.emit_signal("collided_with_hazard")
```

Kluczowe vs stary `tractor.gd`:
- `class_name Hazard` (była brak)
- `lateral_speed` i `path_half_width` jako `@export` (były `const`)
- `_direction` wnioskowany ze `signf(position.x)` (był stały 1.0)
- `past_far_edge` kierunkowy (był `position.x > PATH_HALF_WIDTH`)
- Despawn użycza `absf(position.x)` (był `position.x > PATH_HALF_WIDTH + 2.0`)
- `body_entered` używa `body.emit_signal` bez intermediate `var player := body as Node` (drobne uproszczenie)

- [ ] **Step 2: Walidacja headless**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

Expected: zero ERRORów. Hazard nie jest jeszcze używany w żadnej scenie — tractor.tscn nadal odwołuje się do starego tractor.gd. W Tasku 2 to naprawimy.

- [ ] **Step 3: Commit**

```bash
git add src/scripts/hazards/hazard.gd
git commit -m "feat(hazards): Hazard base class with bidirectional lateral motion

class_name Hazard extends Area3D. @export lateral_speed (was const)
+ path_half_width. _direction inferred from sign(position.x) at
_ready, supporting random spawn side. cleared signal directional
(emits when crossing far edge in direction of travel). Despawn
by absf(position.x) > path_half_width + 2.0.

Tractor refactor + new pies/krowa scenes consume this base in
following tasks.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 2: Refactor Tractor scene to use Hazard base

**Files:**
- Delete: `src/scripts/hazards/tractor.gd`
- Modify: `src/scenes/hazards/tractor.tscn`

- [ ] **Step 1: Zapisz nowy tractor.tscn**

Zamień całą zawartość `/Users/kamil/Projects/distracted/src/scenes/hazards/tractor.tscn` na:

```ini
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/hazards/hazard.gd" id="1_hazard"]

[sub_resource type="BoxMesh" id="BoxMesh_1"]
size = Vector3(2.8, 2.6, 4.0)

[sub_resource type="StandardMaterial3D" id="Material_1"]
albedo_color = Color(0.55, 0.27, 0.18, 1)

[sub_resource type="BoxShape3D" id="BoxShape3D_1"]
size = Vector3(2.8, 2.6, 4.0)

[node name="Tractor" type="Area3D"]
script = ExtResource("1_hazard")
lateral_speed = 1.8
collision_layer = 4
collision_mask = 2

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
mesh = SubResource("BoxMesh_1")
surface_material_override/0 = SubResource("Material_1")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
shape = SubResource("BoxShape3D_1")
```

Zmiany vs M1 wersja:
- Script: `tractor.gd` → `hazard.gd`
- Mesh size: 1.5×1.5×2.0 → 2.8×2.6×4.0 (big traktor)
- StandardMaterial3D z brunatnym albedo (0.55, 0.27, 0.18) jako `surface_material_override/0` na MeshInstance3D (NIE na BoxMesh — BoxMesh nie ma `material` property w Godot 4)
- `lateral_speed = 1.8` jako override @export (był const w `tractor.gd`)
- CollisionShape3D matched do nowego mesh size

- [ ] **Step 2: Usuń stary tractor.gd**

```bash
rm /Users/kamil/Projects/distracted/src/scripts/hazards/tractor.gd
rm -f /Users/kamil/Projects/distracted/src/scripts/hazards/tractor.gd.uid
```

`.uid` plik usuwamy też (Godot 4 generuje pliki .uid dla każdego skryptu).

- [ ] **Step 3: Walidacja headless**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

Expected: zero ERRORów. Jeśli ERROR mówi że `hazard_spawner.gd` używa typu z `tractor.gd` lub PackedScene reference jest broken — HazardSpawner ma `preload("res://scenes/hazards/tractor.tscn")`, scena nadal istnieje, więc preload działa. Hazardpawner Task 6 ją zastąpi data-driven loadem.

- [ ] **Step 4: Commit**

```bash
git add src/scenes/hazards/tractor.tscn
git rm src/scripts/hazards/tractor.gd
git rm -f src/scripts/hazards/tractor.gd.uid
git commit -m "refactor(hazards): Tractor scene uses Hazard base, resized to big

Tractor.tscn: script → hazard.gd, mesh 1.5x1.5x2.0 → 2.8x2.6x4.0
(big traktor per M2a spec). lateral_speed @export = 1.8 (was const
1.5 in old tractor.gd; bump matches longer body). Brunatny
placeholder color via StandardMaterial3D.

Deleted: tractor.gd (logic moved to hazard.gd in Task 1).

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 3: Pies + Krowa hazard scenes

**Files:**
- Create: `src/scenes/hazards/pies.tscn`
- Create: `src/scenes/hazards/krowa.tscn`

- [ ] **Step 1: Zapisz pies.tscn**

Stwórz `/Users/kamil/Projects/distracted/src/scenes/hazards/pies.tscn`:

```ini
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/hazards/hazard.gd" id="1_hazard"]

[sub_resource type="BoxMesh" id="BoxMesh_1"]
size = Vector3(0.4, 0.4, 0.6)

[sub_resource type="StandardMaterial3D" id="Material_1"]
albedo_color = Color(0.45, 0.25, 0.1, 1)

[sub_resource type="BoxShape3D" id="BoxShape3D_1"]
size = Vector3(0.4, 0.4, 0.6)

[node name="Pies" type="Area3D"]
script = ExtResource("1_hazard")
lateral_speed = 4.0
collision_layer = 4
collision_mask = 2

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
mesh = SubResource("BoxMesh_1")
surface_material_override/0 = SubResource("Material_1")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
shape = SubResource("BoxShape3D_1")
```

- [ ] **Step 2: Zapisz krowa.tscn**

Stwórz `/Users/kamil/Projects/distracted/src/scenes/hazards/krowa.tscn`:

```ini
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/hazards/hazard.gd" id="1_hazard"]

[sub_resource type="BoxMesh" id="BoxMesh_1"]
size = Vector3(1.6, 1.8, 2.5)

[sub_resource type="StandardMaterial3D" id="Material_1"]
albedo_color = Color(0.92, 0.92, 0.92, 1)

[sub_resource type="BoxShape3D" id="BoxShape3D_1"]
size = Vector3(1.6, 1.8, 2.5)

[node name="Krowa" type="Area3D"]
script = ExtResource("1_hazard")
lateral_speed = 1.5
collision_layer = 4
collision_mask = 2

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
mesh = SubResource("BoxMesh_1")
surface_material_override/0 = SubResource("Material_1")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
shape = SubResource("BoxShape3D_1")
```

Krowa biało-szara (0.92, 0.92, 0.92) — placeholder dla biało-czarnej krowy.

- [ ] **Step 3: Walidacja headless**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

Expected: zero ERRORów. Sceny istnieją ale nie są jeszcze spawnowane przez HazardSpawner.

- [ ] **Step 4: Commit**

```bash
git add src/scenes/hazards/pies.tscn src/scenes/hazards/krowa.tscn
git commit -m "feat(hazards): pies + krowa hazard scenes

Both use hazard.gd base. Pies: 0.4x0.4x0.6 brązowy, lateral 4.0.
Krowa: 1.6x1.8x2.5 biało-szara, lateral 1.5. Spawned by data
config in Task 6 — currently only built but not wired.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 4: HazardEntry Resource + 3 .tres instances

**Files:**
- Create: `src/resources/hazard_entry.gd`
- Create: `src/resources/hazards/hazard_traktor.tres`
- Create: `src/resources/hazards/hazard_pies.tres`
- Create: `src/resources/hazards/hazard_krowa.tres`

- [ ] **Step 1: Stwórz directories**

```bash
mkdir -p /Users/kamil/Projects/distracted/src/resources/hazards
mkdir -p /Users/kamil/Projects/distracted/src/resources/zones
```

- [ ] **Step 2: Stwórz hazard_entry.gd**

Stwórz `/Users/kamil/Projects/distracted/src/resources/hazard_entry.gd`:

```gdscript
class_name HazardEntry
extends Resource

@export var scene: PackedScene
@export var weight: int = 1
@export var spawn_lookahead_min: float = 12.0
@export var spawn_lookahead_max: float = 15.0
```

- [ ] **Step 3: Stwórz hazard_traktor.tres**

Stwórz `/Users/kamil/Projects/distracted/src/resources/hazards/hazard_traktor.tres`:

```ini
[gd_resource type="Resource" script_class="HazardEntry" load_steps=3 format=3]

[ext_resource type="Script" path="res://resources/hazard_entry.gd" id="1_entry"]
[ext_resource type="PackedScene" path="res://scenes/hazards/tractor.tscn" id="2_scene"]

[resource]
script = ExtResource("1_entry")
scene = ExtResource("2_scene")
weight = 2
spawn_lookahead_min = 12.0
spawn_lookahead_max = 15.0
```

- [ ] **Step 4: Stwórz hazard_pies.tres**

Stwórz `/Users/kamil/Projects/distracted/src/resources/hazards/hazard_pies.tres`:

```ini
[gd_resource type="Resource" script_class="HazardEntry" load_steps=3 format=3]

[ext_resource type="Script" path="res://resources/hazard_entry.gd" id="1_entry"]
[ext_resource type="PackedScene" path="res://scenes/hazards/pies.tscn" id="2_scene"]

[resource]
script = ExtResource("1_entry")
scene = ExtResource("2_scene")
weight = 2
spawn_lookahead_min = 5.0
spawn_lookahead_max = 7.0
```

- [ ] **Step 5: Stwórz hazard_krowa.tres**

Stwórz `/Users/kamil/Projects/distracted/src/resources/hazards/hazard_krowa.tres`:

```ini
[gd_resource type="Resource" script_class="HazardEntry" load_steps=3 format=3]

[ext_resource type="Script" path="res://resources/hazard_entry.gd" id="1_entry"]
[ext_resource type="PackedScene" path="res://scenes/hazards/krowa.tscn" id="2_scene"]

[resource]
script = ExtResource("1_entry")
scene = ExtResource("2_scene")
weight = 1
spawn_lookahead_min = 14.0
spawn_lookahead_max = 18.0
```

- [ ] **Step 6: Walidacja headless**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

Expected: zero ERRORów.

Note: jeśli `class_name HazardEntry` koliduje z czymś (mało prawdopodobne), przemianować na `HazardPoolEntry` we wszystkich .tres `script_class` polach + script `class_name`.

- [ ] **Step 7: Commit**

```bash
git add src/resources/hazard_entry.gd src/resources/hazards/
git commit -m "feat(resources): HazardEntry + 3 hazard pool entries (T/P/K)

HazardEntry: PackedScene + weight + spawn_lookahead range. Three
.tres instances: hazard_traktor (12-15m lookahead, weight 2),
hazard_pies (5-7m, weight 2), hazard_krowa (14-18m, weight 1).

Pool consumed by HazardSpawner in Task 6 — currently not wired.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 5: Zone Resource + zone_village.tres

**Files:**
- Create: `src/resources/zone.gd`
- Create: `src/resources/zones/zone_village.tres`

- [ ] **Step 1: Stwórz zone.gd**

Stwórz `/Users/kamil/Projects/distracted/src/resources/zone.gd`:

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
```

- [ ] **Step 2: Stwórz zone_village.tres**

Stwórz `/Users/kamil/Projects/distracted/src/resources/zones/zone_village.tres`:

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
```

Note `Array[ExtResource("2_entry")]` typuje array do `HazardEntry` (skrypt z `2_entry`). Jeśli Godot wersja-specyficznie nie parsuje typed array w .tres, fallback: zmień w `zone.gd` `Array[HazardEntry]` na `Array` (untyped), i w .tres użyj `hazard_pool = [ExtResource("3_traktor"), ExtResource("4_pies"), ExtResource("5_krowa")]`. Duck-typing przy użyciu (entry.scene/entry.weight) działa identycznie.

- [ ] **Step 3: Walidacja headless**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

Expected: zero ERRORów. Jeśli error o "could not load resource hazard_pool" — sprawdź syntax typed array. Try fallback z notą wyżej.

- [ ] **Step 4: Commit**

```bash
git add src/resources/zone.gd src/resources/zones/
git commit -m "feat(resources): Zone Resource + village instance

Zone: walk_speed, willpower_max, spawn_interval range, hazard_pool
(Array[HazardEntry]), lane_count. zone_village.tres: 6.0 u/s,
3.0s willpower, 25-40m spawn interval, hazard pool [traktor:2,
pies:2, krowa:1], lane_count 1.

Consumed by GameState in Task 7, HazardSpawner in Task 6,
NotificationManager in Task 8.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 6: HazardSpawner — weighted pick + random side + per-hazard lookahead

**Files:**
- Modify: `src/scripts/autoloads/hazard_spawner.gd`

- [ ] **Step 1: Zamień zawartość hazard_spawner.gd**

Zapisz `/Users/kamil/Projects/distracted/src/scripts/autoloads/hazard_spawner.gd`:

```gdscript
extends Node

signal hazard_spawned(node: Node3D)
signal hazard_cleared(node: Node3D)

const SPAWN_X_ABS: float = 3.5

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
	if GameState.current_zone == null:
		return
	if GameState.distance >= _next_spawn_distance:
		_spawn_hazard()
		_schedule_next_spawn()

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

func _pick_hazard_entry():
	var pool = GameState.current_zone.hazard_pool
	if pool.is_empty():
		return null
	var total: int = 0
	for entry in pool:
		total += entry.weight
	if total <= 0:
		return pool[0]
	var roll: int = randi() % total
	var acc: int = 0
	for entry in pool:
		acc += entry.weight
		if roll < acc:
			return entry
	return pool[0]

func _on_hazard_cleared(node: Node3D) -> void:
	hazard_cleared.emit(node)

func _schedule_next_spawn() -> void:
	if GameState.current_zone == null:
		return
	var zone = GameState.current_zone
	var interval: float = randf_range(zone.spawn_interval_min, zone.spawn_interval_max)
	_next_spawn_distance = GameState.distance + interval

func _on_phase_changed(new_phase: GameState.GamePhase) -> void:
	if new_phase == GameState.GamePhase.GAME_OVER:
		stop()
```

Zmiany vs M1:
- `TRACTOR_SCENE` const usunięty (był `preload("res://scenes/hazards/tractor.tscn")`)
- `SPAWN_X` (-3.0) → `SPAWN_X_ABS` (3.5)
- `SPAWN_LOOKAHEAD_MIN`/`MAX` const usunięte (per-entry teraz)
- `SPAWN_INTERVAL_MIN`/`MAX` const usunięte (per-zone teraz)
- Dodane `_pick_hazard_entry()` weighted random
- Dodane random spawn side w `_spawn_hazard()`
- `_pick_hazard_entry` i `_pick_hazard_entry` return type untyped (workaround dla `class_name` w autoloadzie wg `memory/feedback_godot4_autoload_classname.md` — autoload nie zawsze widzi `HazardEntry` typed)
- Guard `if GameState.current_zone == null` w `_process` i `_schedule_next_spawn`

- [ ] **Step 2: Walidacja headless**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

Expected: zero ERRORów. Pamiętaj że `GameState.current_zone` dodawane w Tasku 7 — w tym tasku referencja będzie nullowa i guard zapobiegnie ERRORowi. Sprawdź czy headless faktycznie nie crashuje.

- [ ] **Step 3: Commit**

```bash
git add src/scripts/autoloads/hazard_spawner.gd
git commit -m "refactor(hazards): HazardSpawner data-driven (weighted pool + random side)

Removed hardcoded TRACTOR_SCENE preload + per-spawn constants.
Now reads GameState.current_zone.hazard_pool (Array[HazardEntry])
with weighted pick. Per-HazardEntry spawn_lookahead. SPAWN_X bump
to ±3.5 (was -3.0) for big traktor margin. Random spawn side 50/50
— hazard's Hazard base infers _direction from sign(position.x).

GameState.current_zone is null until Task 7; guards prevent crash.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 7: GameState.current_zone integration

**Files:**
- Modify: `src/scripts/autoloads/game_state.gd`

- [ ] **Step 1: Dodaj current_zone do GameState**

W `/Users/kamil/Projects/distracted/src/scripts/autoloads/game_state.gd`, dodaj na początku (po `extends Node`):

```gdscript
const ZONE_VILLAGE: Resource = preload("res://resources/zones/zone_village.tres")
```

(Typowany jako `Resource` zamiast `Zone` żeby uniknąć autoload class_name issue — pamiętaj memory `feedback_godot4_autoload_classname`.)

Dodaj zmienną w bloku var (gdzieś między `var distance: float = 0.0` a `var score: int = 0`):

```gdscript
var current_zone: Resource = ZONE_VILLAGE
```

W `reset_metrics()` ustaw:

```gdscript
func reset_metrics() -> void:
	phase = GamePhase.ROAD
	zone = Zone.VILLAGE
	distance = 0.0
	time_on_phone = 0.0
	total_time = 0.0
	score = 0
	current_zone = ZONE_VILLAGE
	speed = current_zone.walk_speed
```

(`speed = ZONE_SPEEDS[0]` zamienione na `speed = current_zone.walk_speed` — równa wartość 6.0, ale teraz źródło danych to zone.)

Stałe `ZONE_THRESHOLDS`, `ZONE_SPEEDS`, `ZONE_NOTIFICATION_INTERVALS` zostawiamy (foundation pod M2b zone transition). `_update_zone()` zostaje bez zmian — w M2a praktycznie zawsze trzyma VILLAGE.

- [ ] **Step 2: Walidacja headless**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

Expected: zero ERRORów. Po tym tasku HazardSpawner powinien móc działać end-to-end (`current_zone` nie null).

- [ ] **Step 3: Manual smoke test**

Uruchom grę (`godot --path /Users/kamil/Projects/distracted/src/`). Klik Start. Po 25-40m dystansie powinien spawnować się losowy hazard (traktor / pies / krowa) z losowej strony. Bug check:
- Wszystkie 3 typy widoczne w ciągu kilku spawnów
- Hazardy wychodzą czasem z lewej, czasem z prawej
- Po spawnie idą do drugiej strony i znikają poza kadrem

Nie sprawdzamy jeszcze willpower zachowania (Task 8).

- [ ] **Step 4: Commit**

```bash
git add src/scripts/autoloads/game_state.gd
git commit -m "feat(state): current_zone preloaded from zone_village.tres

GameState.current_zone: Resource (typed as Resource, not Zone, per
Godot 4 autoload class_name limitation in memory). Initialized via
preload at script load + re-assigned on reset_metrics. speed now
sourced from current_zone.walk_speed (was ZONE_SPEEDS[0], equal
value 6.0 but data-driven origin).

HazardSpawner now functional end-to-end with data-driven pool.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 8: NotificationManager — willpower_max from zone

**Files:**
- Modify: `src/scripts/autoloads/notification_manager.gd`

- [ ] **Step 1: Zamień użycia WILLPOWER_MAX_MVP w notification_manager.gd**

Otwórz `/Users/kamil/Projects/distracted/src/scripts/autoloads/notification_manager.gd`. Znajdź:

```gdscript
const WILLPOWER_MAX_MVP: float = 3.0
```

i pozostaw — HUD jeszcze go używa do inicjalizacji `_willpower_bar.max_value` (zostanie usunięty w Tasku 9). NIE usuwać tej linii w Tasku 8.

Znajdź `_on_safe_window_elapsed`:

```gdscript
func _on_safe_window_elapsed() -> void:
	if GameState.phase != GameState.GamePhase.ROAD:
		return
	if _all.is_empty():
		return
	current_notification = _all.pick_random()
	willpower_remaining = WILLPOWER_MAX_MVP
	willpower_active = true
	notification_arrived.emit(current_notification)
```

Zamień `willpower_remaining = WILLPOWER_MAX_MVP` na `willpower_remaining = _current_willpower_max()`. Dodaj prywatny helper na końcu pliku:

```gdscript
func _current_willpower_max() -> float:
	if GameState.current_zone == null:
		return WILLPOWER_MAX_MVP
	return GameState.current_zone.willpower_max
```

Helper z fallback do `WILLPOWER_MAX_MVP` jeśli zone null (defensywne).

Pełne `_on_safe_window_elapsed`:

```gdscript
func _on_safe_window_elapsed() -> void:
	if GameState.phase != GameState.GamePhase.ROAD:
		return
	if _all.is_empty():
		return
	current_notification = _all.pick_random()
	willpower_remaining = _current_willpower_max()
	willpower_active = true
	notification_arrived.emit(current_notification)
```

- [ ] **Step 2: Walidacja headless**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

Expected: zero ERRORów.

- [ ] **Step 3: Commit**

```bash
git add src/scripts/autoloads/notification_manager.gd
git commit -m "feat(notifications): willpower_max from current_zone

_on_safe_window_elapsed pulls willpower duration from
GameState.current_zone.willpower_max via _current_willpower_max
helper (fallback to WILLPOWER_MAX_MVP const if zone null).

WILLPOWER_MAX_MVP const retained for HUD initial setup (Task 9
finishes the migration).

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 9: HUD — willpower_max per-notification + final validation

**Files:**
- Modify: `src/scripts/ui/hud.gd`

- [ ] **Step 1: Zmień hud.gd**

Otwórz `/Users/kamil/Projects/distracted/src/scripts/ui/hud.gd`. W `_ready()` USUŃ linię:

```gdscript
	_willpower_bar.max_value = NotificationManager.WILLPOWER_MAX_MVP
```

W `_on_notification_arrived(_notification)`:

```gdscript
func _on_notification_arrived(_notification) -> void:
	_willpower_bar.value = NotificationManager.WILLPOWER_MAX_MVP
	_notification_area.visible = true
```

Zamień na:

```gdscript
func _on_notification_arrived(_notification) -> void:
	var max_value: float = NotificationManager.willpower_remaining
	_willpower_bar.max_value = max_value
	_willpower_bar.value = max_value
	_notification_area.visible = true
```

`NotificationManager.willpower_remaining` ustawia się TUŻ PRZED `notification_arrived.emit()` w `_on_safe_window_elapsed`. Więc w handler'rze HUD odczytuje już zone-driven willpower_max.

- [ ] **Step 2: Walidacja headless**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1
```

Expected: zero ERRORów.

- [ ] **Step 3: Commit**

```bash
git add src/scripts/ui/hud.gd
git commit -m "feat(hud): willpower bar max from zone per notification

Removed _ready initialization (was using WILLPOWER_MAX_MVP const).
_on_notification_arrived now reads NotificationManager.willpower_
remaining (which was just set from current_zone.willpower_max in
NotificationManager._on_safe_window_elapsed) and applies to both
max_value and value.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 10: End-to-end manual playtest

Finalna walidacja — nie ma kodu, sprawdzamy że całość działa.

- [ ] **Step 1: Headless run**

```bash
cd /Users/kamil/Projects/distracted/src/ && godot --path . --headless --quit 2>&1 | grep -i error
```

Expected: brak outputu (zero ERRORów).

- [ ] **Step 2: Full playthrough checklist**

Uruchom grę (`godot --path /Users/kamil/Projects/distracted/src/`). Klik Start.

Sprawdź:
- [ ] Postać idzie do przodu, dystans rośnie, ścieżka z kreskami
- [ ] HUD willpower bar pojawia się przy notyfikacji, max_value = 3.0 (zone village willpower_max)
- [ ] Pierwszy hazard spawnuje się po 25-40m
- [ ] W ciągu pierwszych 3-4 spawnów widoczne wszystkie 3 typy (traktor brunatny, pies brązowy mały, krowa biało-szara większa)
- [ ] Hazardy wychodzą czasem z lewej, czasem z prawej (50/50 random)
- [ ] Pies (lateral 4.0) widoczny krótko, szybko przecina ścieżkę
- [ ] Krowa (lateral 1.5) widoczna długo, długo blokuje ścieżkę
- [ ] Traktor (lateral 1.8) — średnio
- [ ] Każdy hazard cleared signal poprawnie kończy STOP w ROAD mode (player auto-rusza po przejeździe)
- [ ] Kolizja z dowolnym hazardem → GAME_OVER → metryki → retry działa
- [ ] PHONE mode → STOP nadal 1s timeout (StopController behavior niezmieniony)

- [ ] **Step 3: Test sukcesu z testerką**

Per spec: 2-3 min sesja z 15-letnią testerką (lub innym).

Pytanie: *"Czy wioska teraz inaczej się czuje niż wcześniej?"*

Bonusy:
- Rozróżnia rytmy? ("krowa wolno, pies szybko")
- Zauważa losową stronę spawnów?
- "Granie jeszcze raz"?

Jeśli "tak więcej życia" → M2a done, lecimy M2b (suburb).
Jeśli "meh" → tuning lateral_speed / spawn_lookahead / weights, ewentualnie 4ty hazard.

- [ ] **Step 4: Update doc/milestones.md (jeśli M2a done)**

Jeśli playtest pozytywny — dodaj notatkę w `doc/milestones.md` przy sekcji M2:

```markdown
## M2 — Fazy + skalowanie systemów

**M2a Village Variety DONE 2026-XX-XX.** Pies, krowa, traktor (big),
random spawn side, Zone + HazardEntry Resources. Spec:
`doc/specs/2026-06-03-village-variety-design.md`.
```

Commit:
```bash
git add doc/milestones.md
git commit -m "docs(milestones): M2a Village Variety complete

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

- [ ] **Step 5: Merge feature branch**

Patrz `superpowers:finishing-a-development-branch` — opcja 1 merge locally lub opcja 2 PR.

---

## Spec coverage check

| Spec section | Task(s) |
|---|---|
| Hazard base class | Task 1 |
| Tractor scene refactor + resize | Task 2 |
| Pies + Krowa scenes | Task 3 |
| HazardEntry Resource | Task 4 |
| Zone Resource + village instance | Task 5 |
| HazardSpawner weighted pick + random side + per-entry lookahead + SPAWN_X_ABS | Task 6 |
| GameState.current_zone | Task 7 |
| NotificationManager willpower from zone | Task 8 |
| HUD willpower per-notification | Task 9 |
| End-to-end validation + playtest | Task 10 |

Wszystkie sekcje spec'a pokryte.
