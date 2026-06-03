# M2b — Suburb Biome — Design Spec

**Data:** 2026-06-03
**Status:** Approved, ready for implementation plan
**Milestone:** M2 — Fazy + skalowanie systemów (sub-project B)

## Cel

Wprowadza drugi biom (suburb) z nową gameplay mechaniką — lane-switching między 2 pasami. Dodaje LaneObstacle jako drugi typ hazardu (statyczny, ominij przez zmianę pasa). Tym samym waliduje: czy biom + nowy mechanic = świeżość, czy data-driven zone transition (foundation z M2a) skaluje się bez nowego kodu, czy gracz odczuwa "never safe" z subtelną krzywą willpower (3.0s → 2.5s).

Sukces = playtester po 2-3 min mówi że suburb "czuje się inaczej niż wieś" i potrafi rozróżnić oba mechaniki hazardu (stop crossingi, switch lane obstacles).

## Kontekst

M2a dał wioskę z trzema crossing hazardami (traktor/pies/krowa) i Zone Resources jako foundation. Sukces playtestowy ale wszystko wciąż w jednym biomie z jednym mechanikiem (stop). M2b rozszerza:

- 2-gi biom z innym wyglądem (szary asfalt + białe linie zamiast piaskowej ścieżki)
- 2-gi mechanic gracza (lane-switching A/D + tween)
- Lane obstacles (kałuża/latarnia/skrzynka) — gracz omija switchem, nie stopem
- Suburb-themed crossing hazards (ciężarówka/samochód, plus pies reused)
- Zone transition logic — `_update_zone()` ładuje `current_zone` Resource przy distance ≥ 500m
- Subtelna willpower curve (suburb 2.5s vs village 3.0s) — pierwsze odczuwalne "mniej czasu na decyzję"

## Założenia z brainstormingu

1. **Lane mechanic = A/D + tween 0.2s ease-in-out cubic** między x=-0.9 i x=+0.9. Kolizja aktywna podczas tweenu (kara za zbyt późny switch).
2. **2 typy mechaniki hazardu w suburbie:**
   - **Crossing** (istniejący `Hazard`): ciężarówka, samochód, pies — wjeżdżają z boku, gracz stopuje
   - **LaneObstacle** (NOWY): kałuża, latarnia, skrzynka — statyczne na pasie, gracz omija switchem
3. **Suburb hazard pool zastępuje village pool** przy zone transition — pies jest re-use, reszta zmieniona narracyjnie (krowa→samochód, traktor→ciężarówka). Pool = `[ciężarówka, samochód, pies, kałuża, latarnia, skrzynka]`.
4. **Willpower 2.5s w suburb** (vs 3.0s village). Subtelne ale odczuwalne — gracz musi szybciej decydować przy bogatszym pool hazardów + 2 pasach.
5. **Visual differentiation = chunk colors zmieniają się per strefa.** Suburb = ciemny szary asfalt + białe linie podziału pasów. Read z `current_zone.path_color` i `stripe_color`. Linie suburb to podłużna biała kreska na środku (lane divider), nie poprzeczne kreski.
6. **Cały NotificationArea klikalny** (UX polish): zamiast samej ikonki `!`, cały prostokąt łapie tap. Klawisz `E` zostaje równolegle.
7. **Town/city zones nie istnieją w M2b.** Threshold 1500m i wyżej clampuje do suburb dopóki nie zbudujemy ich Resources w M2c.

## Scope

### W zakresie M2b

- `LaneObstacle` base class (Area3D z static position, cleared signal gdy gracz minie)
- 3 lane obstacle sceny: `kaluza.tscn`, `latarnia.tscn`, `skrzynka.tscn`
- 2 nowe crossing hazardy: `ciezarowka.tscn`, `samochod.tscn`
- `pies.tscn` reused (instancja `HazardEntry` w suburb pool)
- `HazardEntry` rozszerzony o pole `is_lane_obstacle: bool`
- `Zone` rozszerzony o pola wizualne: `path_color`, `stripe_color`, `stripe_orientation`
- `zone_suburb.tres` — instancja z lane_count=2, willpower 2.5, suburb hazard pool
- `zone_village.tres` zaktualizowany o pola wizualne (path_color = brąz wioski, stripe_color = piaskowy, stripe_orientation = 0)
- Lane mechanic w `Player`: input handlers (`lane_left`, `lane_right`), tween, current_lane state
- `GameState._update_zone()` rozszerzony — ładuje `current_zone` Resource z `ZONES` array indexowanej przez ZoneIndex
- `ChunkManager` rozszerzony — czyta visual params z `GameState.current_zone` przy spawn chunka
- `HazardSpawner._spawn_hazard()` rozszerzony — lane obstacle spawnuje na konkretnym pasie (random), crossing zachowuje random side
- HUD `NotificationArea` typu Button (flat, transparent) zamiast Control + inner Button
- InputMap: dodać `lane_left` (A, lewa strzałka), `lane_right` (D, prawa strzałka)

### Eksplicytnie poza zakresem M2b

- ❌ Town/city zones (M2c)
- ❌ Debug zone teleport (M2c)
- ❌ Audio (M3+)
- ❌ Multiple notification types (M3)
- ❌ Willpower curve w obrębie zony (per-zone wartości wystarczą)
- ❌ Krzywe spawn_interval (per-zone wartości)
- ❌ Animations postaci (M4)
- ❌ Final sprites (M4)
- ❌ Mobile touch dla lane-switch (tap-area na ekranie) — keyboard tylko w M2b, touch w M3
- ❌ Lane indicators (markery które pas zajmuję) — nice-to-have, defer
- ❌ Smooth biome transition (visual blend) — biom zmienia się przy spawnach nowych chunków, "stare" chunki za graczem zachowują kolor

## Model danych

### Hazard base class (bez zmian)

`src/scripts/hazards/hazard.gd` — istnieje od M2a. Crossing mechanic, bidirectional lateral motion. Bez zmian w M2b.

### LaneObstacle base class (NOWY)

`src/scripts/hazards/lane_obstacle.gd`:

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
	# Player walks in -z direction. Obstacle has fixed z (set at spawn).
	# When player.z + clear_distance_behind_player < obstacle.z,
	# obstacle is behind player by at least the buffer.
	if _player.global_position.z + clear_distance_behind_player < global_position.z:
		_emitted_cleared = true
		cleared.emit(self)
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.has_signal("collided_with_hazard"):
			body.emit_signal("collided_with_hazard")
```

Klucz: cleared signal fires gdy gracz minął obstacle (player.z więcej niż obstacle.z + buffer; przypomnijmy player idzie w -z więc "minięcie" = player.z < obstacle.z). Wtedy queue_free.

### HazardEntry rozszerzony

`src/resources/hazard_entry.gd`:

```gdscript
class_name HazardEntry
extends Resource

@export var scene: PackedScene
@export var weight: int = 1
@export var spawn_lookahead_min: float = 12.0
@export var spawn_lookahead_max: float = 15.0
@export var is_lane_obstacle: bool = false
```

Nowe pole `is_lane_obstacle`. Default false dla backward compat (istniejące traktor/pies/krowa entries pozostają crossing). Suburb entries dla kałuży/latarni/skrzynki będą miały true.

### Zone rozszerzony o wizualne pola

`src/resources/zone.gd`:

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

# Visual differentiation (M2b)
@export var path_color: Color = Color(0.4, 0.3, 0.2)
@export var stripe_color: Color = Color(0.85, 0.78, 0.55)
@export var stripe_orientation: int = 0  # 0=poprzeczne (village), 1=podłużne (suburb lane divider)
```

`zone_village.tres` zaktualizowany — dodać domyślne path_color (brąz wiejski), stripe_color (piaskowy), stripe_orientation = 0. Wartości zgodne z istniejącym wyglądem M2a.

### zone_suburb.tres

Nowy plik `src/resources/zones/zone_suburb.tres`:

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
path_color = Color(0.4, 0.4, 0.45)
stripe_color = Color(1.0, 1.0, 1.0)
stripe_orientation = 1
```

walk_speed = 9.0 (ZONE_SPEEDS[1] z istniejącej tabeli), spawn_interval 18-32m (mniejszy niż village 25-40 — denser hazards w suburbie).

## Lane mechanic w Player

### InputMap

W `project.godot` dodać dwa nowe input actions (sekcja `[input]`):

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

Keycode 65 = A, 4194319 = Left arrow. 68 = D, 4194321 = Right arrow.

### Player.gd extension

Dodać:

```gdscript
const LANE_POSITIONS_2: Array[float] = [-0.9, 0.9]
const LANE_TWEEN_DURATION: float = 0.2

var current_lane: int = 1  # default right lane in 2-lane zones
var _lane_tween: Tween = null

# Przy reset: current_lane = (lane_count > 1) ? 1 : 0; lane 0 dla 1-lane zone (center)
```

W `_input`:

```gdscript
elif event.is_action_pressed("lane_left"):
    _try_lane_switch(-1)
elif event.is_action_pressed("lane_right"):
    _try_lane_switch(1)
```

Implementacja:

```gdscript
func _try_lane_switch(delta_lane: int) -> void:
    if GameState.current_zone == null:
        return
    if GameState.current_zone.lane_count < 2:
        return
    var target_lane: int = clampi(current_lane + delta_lane, 0, GameState.current_zone.lane_count - 1)
    if target_lane == current_lane:
        return
    current_lane = target_lane
    var target_x: float = _lane_x_for(current_lane, GameState.current_zone.lane_count)
    if _lane_tween:
        _lane_tween.kill()
    _lane_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
    _lane_tween.tween_property(self, "position:x", target_x, LANE_TWEEN_DURATION)

func _lane_x_for(lane_index: int, lane_count: int) -> float:
    if lane_count == 1:
        return 0.0
    if lane_count == 2:
        return LANE_POSITIONS_2[lane_index]
    # future: 3-lane city — return centered position
    var step: float = 1.8
    var start: float = -((lane_count - 1) * step) / 2.0
    return start + lane_index * step
```

Reset przy zone transition / game start:

```gdscript
func reset_lane_for_current_zone() -> void:
    if GameState.current_zone == null:
        return
    var lane_count: int = GameState.current_zone.lane_count
    if lane_count == 1:
        current_lane = 0
    else:
        current_lane = clampi(current_lane, 0, lane_count - 1)
    position.x = _lane_x_for(current_lane, lane_count)
    if _lane_tween:
        _lane_tween.kill()
        _lane_tween = null
```

Wywołany w `Game._ready` po `GameState.reset_metrics()` i przy zone transition (Game podłączone do `GameState.zone_changed`).

### Game.gd extension

W `_ready()` po istniejącym wireringu:

```gdscript
GameState.zone_changed.connect(_on_zone_changed)
_player.reset_lane_for_current_zone()
```

Handler:

```gdscript
func _on_zone_changed(_new_zone: GameState.ZoneIndex) -> void:
    _player.reset_lane_for_current_zone()
```

Reset przy zone transition — gdy gracz wchodzi z 1-pas village w 2-pas suburb, ląduje na pasie 1 (prawy) bezpiecznie.

## Zone transition logic

`GameState` zmiany:

```gdscript
const ZONE_VILLAGE: Resource = preload("res://resources/zones/zone_village.tres")
const ZONE_SUBURB: Resource = preload("res://resources/zones/zone_suburb.tres")
const ZONES: Array[Resource] = [ZONE_VILLAGE, ZONE_SUBURB]
```

(`ZONE_VILLAGE` już istnieje od M2a; dodajemy `ZONE_SUBURB` i `ZONES` array.)

Rozszerzony `_update_zone()`:

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

`mini(new_zone, ZONES.size() - 1)` clampuje town/city (index 2/3) do suburb (index 1) dopóki nie dodamy zon w M2c.

## Visual differentiation — ChunkManager

`chunk_manager.gd` aktualnie hardkoduje `STRIPE_COLOR` (jasno-piaskowy). M2b czyta z `GameState.current_zone`:

```gdscript
const STRIPE_LENGTH_TRANSVERSE: float = 0.3   # poprzeczna kreska — village
const STRIPE_LENGTH_LONGITUDINAL: float = 2.5  # podłużna linia podziału pasów — suburb
const STRIPE_INTERVAL: float = 4.0

# (existing CHUNK_LENGTH, ACTIVE_CHUNKS, POOL_SIZE, RECYCLE_BEHIND_PLAYER)

func _make_chunk() -> Node3D:
    var root: Node3D = Node3D.new()
    var zone: Resource = GameState.current_zone
    var path_color: Color = zone.path_color if zone else Color(0.4, 0.3, 0.2)
    var stripe_color: Color = zone.stripe_color if zone else Color(0.85, 0.78, 0.55)
    var stripe_orientation: int = zone.stripe_orientation if zone else 0

    var path_mesh: MeshInstance3D = MeshInstance3D.new()
    var path_box: BoxMesh = BoxMesh.new()
    path_box.size = Vector3(3.6, 0.1, CHUNK_LENGTH)
    path_mesh.mesh = path_box
    path_mesh.position = Vector3(0, -0.05, -CHUNK_LENGTH / 2.0)
    var path_material: StandardMaterial3D = StandardMaterial3D.new()
    path_material.albedo_color = path_color
    path_mesh.material_override = path_material
    root.add_child(path_mesh)

    var stripe_material: StandardMaterial3D = StandardMaterial3D.new()
    stripe_material.albedo_color = stripe_color

    if stripe_orientation == 0:
        # village — poprzeczne kreski co STRIPE_INTERVAL
        var stripe_box: BoxMesh = BoxMesh.new()
        stripe_box.size = Vector3(3.4, 0.04, STRIPE_LENGTH_TRANSVERSE)
        var z: float = -STRIPE_INTERVAL
        while z > -CHUNK_LENGTH:
            var stripe: MeshInstance3D = MeshInstance3D.new()
            stripe.mesh = stripe_box
            stripe.material_override = stripe_material
            stripe.position = Vector3(0, 0.01, z)
            root.add_child(stripe)
            z -= STRIPE_INTERVAL
    else:
        # suburb — podłużne linie podziału pasów, segmenty białe co STRIPE_INTERVAL
        var stripe_box: BoxMesh = BoxMesh.new()
        stripe_box.size = Vector3(0.15, 0.04, STRIPE_LENGTH_LONGITUDINAL)
        var z: float = -1.0
        while z > -CHUNK_LENGTH + 0.5:
            var stripe: MeshInstance3D = MeshInstance3D.new()
            stripe.mesh = stripe_box
            stripe.material_override = stripe_material
            stripe.position = Vector3(0, 0.01, z)
            root.add_child(stripe)
            z -= STRIPE_LENGTH_LONGITUDINAL + 1.5  # gap między segmentami

    return root
```

Chunki spawnowane PO zone transition czytają nowe `current_zone` — naturalna mieszanka biomów na granicy 500m (stare chunki za graczem mają village colors, nowe ahead już suburb).

**Uwaga implementacja:** chunki istnieją w POOL_SIZE puli stworzonej raz przy `_ready` ChunkManagera. Stary kod nie tworzy nowych meshów per recycle — używa cached pool. Dla biome transition musimy:
- Albo rebuild chunk meshes przy recycle (drobny perf hit, akceptowalny w MVP)
- Albo trzymać dwa pule per zone i swap

Prostsza opcja A: w `_recycle()` regeneruj zawartość chunka (clear children + `_make_chunk_visuals`). Pula trzyma tylko root Node3D, children są recreated per use. Akceptowalne (kilka mesh allocations per recycle, paręset razy w sesji).

## HazardSpawner — lane obstacle support

`hazard_spawner.gd._spawn_hazard()` rozszerzony:

```gdscript
func _spawn_hazard() -> void:
    var entry = _pick_hazard_entry()
    if entry == null or entry.scene == null:
        return
    var hazard: Node3D = entry.scene.instantiate()
    var lookahead: float = randf_range(entry.spawn_lookahead_min, entry.spawn_lookahead_max)

    if entry.is_lane_obstacle:
        # static lane obstacle — random lane
        var lane_count: int = GameState.current_zone.lane_count
        var lane_x: float = _lane_x_for_spawn(lane_count)
        hazard.position = Vector3(lane_x, 0.5, _player.global_position.z - lookahead)
    else:
        # crossing — random spawn side (existing behavior)
        var spawn_side: float = 1.0 if randf() < 0.5 else -1.0
        hazard.position = Vector3(SPAWN_X_ABS * spawn_side, 0.75, _player.global_position.z - lookahead)

    _container.add_child(hazard)
    hazard.cleared.connect(_on_hazard_cleared)
    hazard_spawned.emit(hazard)

func _lane_x_for_spawn(lane_count: int) -> float:
    if lane_count == 1:
        return 0.0
    if lane_count == 2:
        var lane: int = 0 if randf() < 0.5 else 1
        return -0.9 if lane == 0 else 0.9
    var lane: int = randi() % lane_count
    var step: float = 1.8
    var start: float = -((lane_count - 1) * step) / 2.0
    return start + lane * step
```

`y=0.5` dla lane obstacles (poziom ścieżki + małe uniesienie). Konkretne scene mesh pozycjonują `MeshInstance3D` z odpowiednim Y transform tak by bottom był na ground level.

## HUD — NotificationArea klikalny

W `hud.tscn` zmienić root NotificationArea z `Control` na `Button`:

```ini
[node name="NotificationArea" type="Button" parent="."]
flat = true
focus_mode = 0
visible = false
offset_left = 16.0
offset_top = 64.0
offset_right = 374.0
offset_bottom = 112.0
```

`flat = true` — bez ramki i tła. `focus_mode = 0` (None) — bez highlight przy focusie. Children (NotificationIcon, WillpowerBar) zachowane jako wcześniej, ale **wewnętrzny NotificationIcon Button można usunąć** (cały NotificationArea jest button) — zamienić na Label `!` (icon visual tylko, bez interakcji):

```ini
[node name="NotificationIcon" type="Label" parent="NotificationArea"]
offset_left = 0.0
offset_top = 0.0
offset_right = 48.0
offset_bottom = 48.0
text = "!"
horizontal_alignment = 1
vertical_alignment = 1
```

`hud.gd` zmiany:

- `@onready var _notification_icon` typu `Label` (był `Button`)
- Usunięta linia `_notification_icon.pressed.connect(_on_notification_icon_pressed)`
- Dodać `_notification_area.pressed.connect(_on_notification_icon_pressed)` — handler ten sam, ale wyemitowany przez area button
- W `_ready` zmienić typ `_notification_area`: `@onready var _notification_area: Button = $NotificationArea`

Handler `_on_notification_icon_pressed` bez zmian semantycznie — wciąż wywołuje `NotificationManager.request_check_phone()`.

## Suburb hazard scenes

### Sceny crossing (extends Hazard, structurally identical to existing tractor/pies/krowa)

**`src/scenes/hazards/ciezarowka.tscn`:**
- Mesh BoxMesh size (3.0, 3.0, 5.0)
- StandardMaterial3D albedo (0.2, 0.3, 0.6) — niebieski
- CollisionShape3D BoxShape3D size (3.0, 3.0, 5.0)
- Area3D root with script hazard.gd, lateral_speed = 1.6
- collision_layer = 4, collision_mask = 2

**`src/scenes/hazards/samochod.tscn`:**
- Mesh BoxMesh size (1.8, 1.5, 4.2)
- Material albedo (0.7, 0.15, 0.15) — czerwony
- CollisionShape3D BoxShape3D size (1.8, 1.5, 4.2)
- Area3D root, script hazard.gd, lateral_speed = 2.5
- collision_layer = 4, collision_mask = 2

### Sceny lane obstacle (extends LaneObstacle)

**`src/scenes/hazards/kaluza.tscn`:**
- Mesh BoxMesh size (1.6, 0.05, 1.2) — flat
- Material albedo (0.2, 0.3, 0.4) — brudno-niebieski
- CollisionShape3D BoxShape3D size (1.6, 0.05, 1.2)
- Area3D root, script lane_obstacle.gd
- collision_layer = 4, collision_mask = 2

**`src/scenes/hazards/latarnia.tscn`:**
- Mesh BoxMesh size (0.3, 3.0, 0.3) — tall thin
- Material albedo (0.3, 0.3, 0.3) — ciemny szary
- CollisionShape3D BoxShape3D size (0.3, 3.0, 0.3)
- MeshInstance3D + CollisionShape3D transform y=1.5 (bottom at ground)
- Area3D root, script lane_obstacle.gd
- collision_layer = 4, collision_mask = 2

**`src/scenes/hazards/skrzynka.tscn`:**
- Mesh BoxMesh size (0.5, 1.2, 0.5) — chunky
- Material albedo (0.9, 0.7, 0.1) — żółta (polish post)
- CollisionShape3D BoxShape3D size (0.5, 1.2, 0.5)
- MeshInstance3D + CollisionShape3D transform y=0.6 (bottom at ground)
- Area3D root, script lane_obstacle.gd
- collision_layer = 4, collision_mask = 2

## HazardEntry .tres instances dla suburb

**`src/resources/hazards/hazard_ciezarowka.tres`:**

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

**`src/resources/hazards/hazard_samochod.tres`:** weight 3, lookahead 10-14, is_lane_obstacle false
**`src/resources/hazards/hazard_kaluza.tres`:** weight 2, lookahead 12-16, **is_lane_obstacle true**
**`src/resources/hazards/hazard_latarnia.tres`:** weight 2, lookahead 10-14, **is_lane_obstacle true**
**`src/resources/hazards/hazard_skrzynka.tres`:** weight 1, lookahead 11-15, **is_lane_obstacle true**

`hazard_pies.tres` istnieje z M2a, reused w suburb pool bez zmian.

`hazard_traktor.tres` i `hazard_krowa.tres` istnieją z M2a — pozostają w village pool bez zmian.

## Numerki M2b

| Parametr | Wartość | Lokalizacja |
|---|---|---|
| Suburb walk_speed | 9.0 u/s | `zone_suburb.tres` |
| Suburb willpower_max | 2.5 s | `zone_suburb.tres` |
| Suburb spawn_interval | 18-32m | `zone_suburb.tres` |
| Suburb lane_count | 2 | `zone_suburb.tres` |
| Lane x positions | ±0.9 | `Player.LANE_POSITIONS_2` |
| Lane tween duration | 0.2s | `Player.LANE_TWEEN_DURATION` |
| Lane tween easing | EASE_IN_OUT TRANS_CUBIC | `Player._try_lane_switch` |
| Suburb path_color | (0.4, 0.4, 0.45) | `zone_suburb.tres` |
| Suburb stripe_color | (1.0, 1.0, 1.0) — white | `zone_suburb.tres` |
| Stripe orientation suburb | 1 (longitudinal) | `zone_suburb.tres` |
| Ciężarówka mesh | 3.0×3.0×5.0 | `ciezarowka.tscn` |
| Ciężarówka lateral | 1.6 u/s | `ciezarowka.tscn` |
| Samochód mesh | 1.8×1.5×4.2 | `samochod.tscn` |
| Samochód lateral | 2.5 u/s | `samochod.tscn` |
| Kałuża mesh | 1.6×0.05×1.2 | `kaluza.tscn` |
| Latarnia mesh | 0.3×3.0×0.3 | `latarnia.tscn` |
| Skrzynka mesh | 0.5×1.2×0.5 | `skrzynka.tscn` |
| Pool weights (ciez/sam/pies/kal/lat/skrz) | 2/3/2/2/2/1 | `zone_suburb.tres` |
| Lane obstacle clear_distance_behind_player | 2.0 m | `lane_obstacle.gd` |
| Zone transition threshold suburb | 500m | `GameState.ZONE_THRESHOLDS[1]` (already) |

## Mapowanie na istniejący kod

| Plik | Status | Zmiana w M2b |
|---|---|---|
| `src/scripts/hazards/hazard.gd` | exists (M2a) | No change |
| `src/scripts/hazards/lane_obstacle.gd` | **new** | LaneObstacle base class |
| `src/scenes/hazards/tractor.tscn` | exists | No change |
| `src/scenes/hazards/pies.tscn` | exists | No change |
| `src/scenes/hazards/krowa.tscn` | exists | No change |
| `src/scenes/hazards/ciezarowka.tscn` | **new** | Big crossing hazard |
| `src/scenes/hazards/samochod.tscn` | **new** | Medium crossing hazard |
| `src/scenes/hazards/kaluza.tscn` | **new** | Flat lane obstacle |
| `src/scenes/hazards/latarnia.tscn` | **new** | Tall lane obstacle |
| `src/scenes/hazards/skrzynka.tscn` | **new** | Chunky lane obstacle |
| `src/resources/hazard_entry.gd` | exists (M2a) | Add `is_lane_obstacle: bool = false` |
| `src/resources/zone.gd` | exists (M2a) | Add `path_color`, `stripe_color`, `stripe_orientation` |
| `src/resources/hazards/hazard_traktor.tres` | exists | No change |
| `src/resources/hazards/hazard_pies.tres` | exists | No change |
| `src/resources/hazards/hazard_krowa.tres` | exists | No change |
| `src/resources/hazards/hazard_ciezarowka.tres` | **new** | HazardEntry crossing |
| `src/resources/hazards/hazard_samochod.tres` | **new** | HazardEntry crossing |
| `src/resources/hazards/hazard_kaluza.tres` | **new** | HazardEntry lane obstacle |
| `src/resources/hazards/hazard_latarnia.tres` | **new** | HazardEntry lane obstacle |
| `src/resources/hazards/hazard_skrzynka.tres` | **new** | HazardEntry lane obstacle |
| `src/resources/zones/zone_village.tres` | exists (M2a) | Add visual fields (path_color brąz, stripe_color piaskowy, stripe_orientation 0) |
| `src/resources/zones/zone_suburb.tres` | **new** | Suburb zone instance |
| `src/scripts/autoloads/game_state.gd` | exists | Add ZONE_SUBURB const, ZONES array; rewrite `_update_zone` to set `current_zone` from ZONES |
| `src/scripts/autoloads/hazard_spawner.gd` | exists | Add lane-obstacle branch in `_spawn_hazard`, `_lane_x_for_spawn` helper |
| `src/scripts/game/player.gd` | exists | Add LANE_POSITIONS_2, LANE_TWEEN_DURATION, current_lane, `_try_lane_switch`, `_lane_x_for`, `reset_lane_for_current_zone`; input handlers for lane_left/lane_right |
| `src/scripts/game/game.gd` | exists | Connect `GameState.zone_changed` → `_on_zone_changed` → call `_player.reset_lane_for_current_zone()` |
| `src/scripts/game/chunk_manager.gd` | exists | Read visual params from `GameState.current_zone` in `_make_chunk`; regenerate on `_recycle` |
| `src/scripts/ui/hud.gd` | exists | NotificationArea typed as Button, NotificationIcon → Label, click handler on area |
| `src/scenes/game/hud.tscn` | exists | NotificationArea type Control → Button (flat, focus 0); NotificationIcon Button → Label |
| `src/project.godot` | exists | Add `lane_left` (A, Left arrow) and `lane_right` (D, Right arrow) input actions |

## Definicja "done"

- [ ] `lane_obstacle.gd` base class z cleared-when-player-passes logic
- [ ] 5 nowych hazard scenes (ciezarowka, samochod, kaluza, latarnia, skrzynka)
- [ ] `HazardEntry.is_lane_obstacle` field; 5 nowych .tres instances z odpowiednim is_lane_obstacle
- [ ] `Zone` Resource z visual fields; zone_village.tres uzupełniony wizualnie; zone_suburb.tres skonfigurowany
- [ ] `GameState`: ZONE_SUBURB preload, ZONES array, `_update_zone` ustawia `current_zone`
- [ ] `HazardSpawner`: lane-obstacle branch, random lane selection, używa `current_zone.lane_count`
- [ ] `Player`: lane state, lane-switch tween, input handlers, reset on zone transition
- [ ] `Game._on_zone_changed` triggers Player.reset_lane_for_current_zone
- [ ] `ChunkManager`: visual params z current_zone, both orientation modes
- [ ] HUD: NotificationArea Button, klik gdziekolwiek na area triggers check_phone
- [ ] InputMap: lane_left + lane_right actions
- [ ] Walidacja `godot --headless --quit` przechodzi
- [ ] Manual playtest: gracz dochodzi do 500m, widzi suburb visual transition, próbuje lane switch (działa), spotyka lane obstacle (omija switchem albo umiera), spotyka ciężarówkę i samochód, willpower krótszy (2.5s) odczuwalny

## Test sukcesu

Playtest z testerką (3-5 min sesja zaczynając od village → suburb):

> *"Czy suburb czuje się inaczej niż wieś? Co cię najbardziej zaskoczyło?"*

Pozytywne sygnały:
- Visual differentiation zauważona ("inny kolor", "linie na drodze")
- Lane switching zrozumiały, używany aktywnie
- Lane obstacles vs crossings — rozróżnia mechaniki ("o to muszę objść" vs "to muszę przeczekać")
- Czuje krótszy willpower ("szybciej trzeba decydować")
- Cały notification klikalny — używany (tap większego targetu)

Negatywne:
- "Nie zauważyłam zmiany biomu" → mocniej rozjechać kolory (asfalt jeszcze ciemniejszy?)
- "Lane switching nie działa intuicyjnie" → tuning tween duration albo dodać visual lane indicators
- "Nie wiem co robić z latarnią" → dopisać onboarding albo zmienić mesh żeby wyraźniej blokowała pas

## Referencje

- `doc/specs/2026-06-02-core-loop-mvp-design.md` — M1 spec
- `doc/specs/2026-06-03-village-variety-design.md` — M2a spec
- `doc/concept.md` — sekcje "Progresja stref" i "Mechanika silnej woli"
- `doc/architecture.md` — kolizje (Layer 2/3), system pasów (LANE_POSITIONS w archived design)
- `memory/project_lane_progression.md` — 2 pasy w suburb, foundation z village 1-pas
- `memory/feedback_godot4_autoload_classname.md` — typed Resource w autoloadzie (workaround)
- `memory/project_m1_validated.md` — playtest M1
