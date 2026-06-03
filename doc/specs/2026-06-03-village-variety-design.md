# M2a — Village Variety — Design Spec

**Data:** 2026-06-03
**Status:** Approved, ready for implementation plan
**Milestone:** M2 — Fazy + skalowanie systemów (sub-project A)

## Cel

Trzy hazardy w wiosce zamiast jednego, każdy z wyraźnie innym rytmem (mały szybki pies / średnia powolna krowa / duży średni traktor), + foundation pod tunable Zone Resources żeby M2b/c dodawały kolejne strefy jako dane, nie kod.

Sukces = playtester (najlepiej ta sama 15-letnia testerka z M1) rozróżnia rytmy hazardów i mówi że wioska "ma więcej życia" niż w M1. Bonus: rozróżnia "pies wymaga reflexu, krowa wymaga cierpliwości, traktor stoi po drodze".

## Kontekst

M1 dostarczył grywalną pętlę z jednym typem hazardu (traktor, lateral 1.5 u/s). Playtester zagrała 8× — core fantasy działa, ale wioska jest jednostajna. M2a dodaje variety bez rozszerzania mechaniki ani biomu. Foundation pod data-driven progression (`Zone` jako `Resource`), niezbędne pod M2b (suburb).

## Założenia z brainstormingu

1. **Wszystkie 3 hazardy używają tej samej mechaniki crossing** (Area3D + lateral motion + cleared signal). Tylko `lateral_speed` + rozmiar mesh + `spawn_lookahead` różnią się. Bez nowych mechanik gracza.
2. **Hazardy spawnują się z losowej strony** (50/50 lewo/prawo). Kierunek wnioskowany ze znaku startowej `position.x`, nie ustawiany z zewnątrz.
3. **Willpower flat 3.0s przez całą wioskę.** Krzywe per-strefa dochodzą w M2b gdy są >1 strefy do różnicowania.
4. **1 pas pozostaje.** Lane-switching dochodzi w M2b (suburb). Rowerzysta i kałuża, które wymagają omijania, NIE w M2a.
5. **Zone Resource jako pierwsza migracja MVP stałych do danych.** Zachowuje istniejące mechaniki, tylko parametryzuje. `zone_village.tres` jako jedyna instancja w M2a; suburb/town/city dochodzą w M2b+.
6. **Mocniej rozjechane rozmiary mesh** (5-7× ratio pies→traktor) dla wyraźnej wizualnej różnicy z kamery (0,4,6).

## Scope

### W zakresie M2a

- Refactor `Tractor` → `Hazard` base class (klasa bazowa Area3D z `lateral_speed`, `path_half_width` jako @export)
- 3 konkretne sceny hazardów: `tractor.tscn`, `pies.tscn`, `krowa.tscn`
- Random spawn side (lewo lub prawo) w `HazardSpawner._spawn_hazard()`
- Per-hazard `spawn_lookahead_min`/`max` w `HazardEntry` Resource
- `Zone` + `HazardEntry` jako Resource model
- `zone_village.tres` instancja z aktualnymi MVP wartościami + nowy `hazard_pool` z 3 typami
- `GameState.current_zone` ładowane w `reset_metrics()`
- `HazardSpawner` czyta `hazard_pool` i robi weighted pick zamiast hardcoded `TRACTOR_SCENE`
- `NotificationManager` czyta `willpower_max` z current zone (zamiast `WILLPOWER_MAX_MVP`)

### Eksplicytnie poza zakresem M2a

- ❌ Suburb / town / city biomy
- ❌ Lane-switching (1 pas zostaje)
- ❌ Rowerzysta i kałuża (wymagają suburb)
- ❌ Willpower curves (flat 3.0s)
- ❌ Auto zone transition (`_update_zone()` zostaje, ale w praktyce zawsze village w M2a)
- ❌ Debug zone teleport (potrzebny dopiero z >1 strefą)
- ❌ Audio
- ❌ Krzywe spawn frequency / willpower w obrębie wioski
- ❌ Lane-count > 1 w `Zone` (pole istnieje jako foundation, ale unused)

## Model danych

### Hazard base class

`src/scripts/hazards/hazard.gd`:

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
	_direction = -sign(position.x)  # spawn at -3.5 → +1 (rightward); spawn at +3.5 → -1 (leftward)
	if _direction == 0.0:
		_direction = 1.0  # safety fallback

func _process(delta: float) -> void:
	position.x += lateral_speed * _direction * delta
	if not _emitted_cleared:
		var past_far_edge: bool = (
			(_direction > 0 and position.x > path_half_width)
			or (_direction < 0 and position.x < -path_half_width)
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

Klasy konkretne (`tractor.tscn`, `pies.tscn`, `krowa.tscn`) dziedziczą skrypt `hazard.gd` i tylko nadpisują `lateral_speed` + mesh + collision shape.

### Hazard scenes

**`tractor.tscn`** (existing, replaces M1 version):
- Root: `Area3D`, script `hazard.gd`, `lateral_speed = 1.8`
- Mesh: `BoxMesh size=(2.8, 2.6, 4.0)`, kolor placeholder
- CollisionShape3D: `BoxShape3D size=(2.8, 2.6, 4.0)`

**`pies.tscn`** (new):
- Root: `Area3D`, script `hazard.gd`, `lateral_speed = 4.0`
- Mesh: `BoxMesh size=(0.4, 0.4, 0.6)`
- CollisionShape3D: `BoxShape3D size=(0.4, 0.4, 0.6)`

**`krowa.tscn`** (new):
- Root: `Area3D`, script `hazard.gd`, `lateral_speed = 1.5`
- Mesh: `BoxMesh size=(1.6, 1.8, 2.5)`
- CollisionShape3D: `BoxShape3D size=(1.6, 1.8, 2.5)`

Wszystkie używają placeholder boxów (kolory różnicują wizualnie w M2a — sprite'y przychodzą w M4 zgodnie z `milestones.md`). Sugerowane kolory placeholder:
- Traktor: brunatny / ceglasty
- Krowa: biało-czarny (lub szary z białymi plamami)
- Pies: brązowy

### HazardEntry Resource

`src/resources/hazard_entry.gd`:

```gdscript
class_name HazardEntry
extends Resource

@export var scene: PackedScene
@export var weight: int = 1
@export var spawn_lookahead_min: float = 12.0
@export var spawn_lookahead_max: float = 15.0
```

### Zone Resource

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
```

### zone_village.tres

Instancja Zone z `name_id = "village"`, `walk_speed = 6.0`, `willpower_max = 3.0`, `spawn_interval = 25-40`, `lane_count = 1`. Hazard pool:

| HazardEntry | Scene | Weight | Lookahead min | Lookahead max |
|---|---|---|---|---|
| `hazard_traktor.tres` | `tractor.tscn` | 2 | 12.0 | 15.0 |
| `hazard_pies.tres` | `pies.tscn` | 2 | 5.0 | 7.0 |
| `hazard_krowa.tres` | `krowa.tscn` | 1 | 14.0 | 18.0 |

Sum weight = 5. Probabilities: traktor 40%, pies 40%, krowa 20%. Krowa rzadsza bo blokuje najdłużej — zbyt częsta byłaby męcząca.

## Spawn logic

### HazardSpawner refactor

`src/scripts/autoloads/hazard_spawner.gd` — kluczowe zmiany:

```gdscript
extends Node

signal hazard_spawned(node: Node3D)
signal hazard_cleared(node: Node3D)

const SPAWN_X_ABS: float = 3.5  # bumped from 3.0 — traktor 2.8 wide needs margin

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
	var entry: HazardEntry = _pick_hazard_entry()
	if entry == null or entry.scene == null:
		return
	var hazard: Node3D = entry.scene.instantiate()
	var lookahead: float = randf_range(entry.spawn_lookahead_min, entry.spawn_lookahead_max)
	var spawn_side: float = 1.0 if randf() < 0.5 else -1.0
	hazard.position = Vector3(SPAWN_X_ABS * spawn_side, 0.75, _player.global_position.z - lookahead)
	_container.add_child(hazard)
	hazard.cleared.connect(_on_hazard_cleared)
	hazard_spawned.emit(hazard)

func _pick_hazard_entry() -> HazardEntry:
	var pool: Array[HazardEntry] = GameState.current_zone.hazard_pool
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
	var zone: Zone = GameState.current_zone
	var interval: float = randf_range(zone.spawn_interval_min, zone.spawn_interval_max)
	_next_spawn_distance = GameState.distance + interval

func _on_phase_changed(new_phase: GameState.GamePhase) -> void:
	if new_phase == GameState.GamePhase.GAME_OVER:
		stop()
```

### GameState changes

Dodać:
```gdscript
const ZONE_VILLAGE: Zone = preload("res://resources/zones/zone_village.tres")

var current_zone: Zone = ZONE_VILLAGE

func reset_metrics() -> void:
	# existing fields...
	current_zone = ZONE_VILLAGE
	speed = current_zone.walk_speed
```

Stałe `ZONE_SPEEDS`, `ZONE_NOTIFICATION_INTERVALS`, `ZONE_THRESHOLDS` zostają (foundation pod M2b zone transition), ale `_update_zone()` w M2a praktycznie zawsze trzyma VILLAGE bo `distance` nigdy nie przekracza VILLAGE threshold w MVP (no progression past 500m playtested).

`speed` w M2a inicjalizowany z `current_zone.walk_speed`. W M2b `_update_zone` będzie ładować nowy `Zone` resource per threshold.

### NotificationManager changes

```gdscript
# Was:
# const WILLPOWER_MAX_MVP: float = 3.0

# Now:
func _on_safe_window_elapsed() -> void:
	if GameState.phase != GameState.GamePhase.ROAD:
		return
	if _all.is_empty():
		return
	current_notification = _all.pick_random()
	willpower_remaining = GameState.current_zone.willpower_max
	willpower_active = true
	notification_arrived.emit(current_notification)
```

HUD `_willpower_bar.max_value` ustawiane per notyfikację (zamiast raz w `_ready`):

```gdscript
func _on_notification_arrived(_notification) -> void:
	_willpower_bar.max_value = GameState.current_zone.willpower_max
	_willpower_bar.value = GameState.current_zone.willpower_max
	_notification_area.visible = true
```

Linia `_willpower_bar.max_value = NotificationManager.WILLPOWER_MAX_MVP` w `_ready()` usunięta.

## Numerki M2a

| Parametr | Wartość | Lokalizacja |
|---|---|---|
| Pies mesh W×H×L | 0.4 × 0.4 × 0.6 | `pies.tscn` |
| Krowa mesh W×H×L | 1.6 × 1.8 × 2.5 | `krowa.tscn` |
| Traktor mesh W×H×L | 2.8 × 2.6 × 4.0 | `tractor.tscn` |
| Pies lateral_speed | 4.0 u/s | `pies.tscn` (Hazard script @export) |
| Krowa lateral_speed | 1.5 u/s | `krowa.tscn` |
| Traktor lateral_speed | 1.8 u/s | `tractor.tscn` |
| Pies spawn_lookahead | 5-7 m | `hazard_pies.tres` |
| Krowa spawn_lookahead | 14-18 m | `hazard_krowa.tres` |
| Traktor spawn_lookahead | 12-15 m | `hazard_traktor.tres` |
| Pool weights (T/P/K) | 2 / 2 / 1 | `zone_village.tres → hazard_pool` |
| SPAWN_X_ABS | 3.5 (was 3.0) | `hazard_spawner.gd` |
| walk_speed | 6.0 u/s | `zone_village.tres` |
| willpower_max | 3.0 s | `zone_village.tres` |
| spawn_interval | 25-40 m | `zone_village.tres` |
| path_half_width | 1.8 (unchanged) | `hazard.gd` default + zone implicit |

Wartości tunable po commit `.tres` w edytorze Godot — żadnych przekompilacji.

## Mapowanie na istniejący kod

| Plik | Status | Zmiana w M2a |
|---|---|---|
| `src/scripts/hazards/tractor.gd` | exists | Usunięty (kod przeniesiony do `hazard.gd` base) |
| `src/scripts/hazards/hazard.gd` | **new** | Base class z lateral motion + cleared + collision |
| `src/scenes/hazards/tractor.tscn` | exists | Resize mesh + shape, attach `hazard.gd`, set lateral_speed = 1.8 |
| `src/scenes/hazards/pies.tscn` | **new** | placeholder mesh + collision + hazard.gd, lateral_speed = 4.0 |
| `src/scenes/hazards/krowa.tscn` | **new** | placeholder mesh + collision + hazard.gd, lateral_speed = 1.5 |
| `src/resources/hazard_entry.gd` | **new** | HazardEntry class_name + exports |
| `src/resources/zone.gd` | **new** | Zone class_name + exports |
| `src/resources/zones/zone_village.tres` | **new** | Village zone instance |
| `src/resources/hazards/hazard_traktor.tres` | **new** | HazardEntry instance |
| `src/resources/hazards/hazard_pies.tres` | **new** | HazardEntry instance |
| `src/resources/hazards/hazard_krowa.tres` | **new** | HazardEntry instance |
| `src/scripts/autoloads/hazard_spawner.gd` | exists | Refactor: weighted pick, random side, per-hazard lookahead, SPAWN_X_ABS |
| `src/scripts/autoloads/game_state.gd` | exists | Add `current_zone: Zone`, preload village, set in reset_metrics |
| `src/scripts/autoloads/notification_manager.gd` | exists | `WILLPOWER_MAX_MVP` const → `GameState.current_zone.willpower_max` |
| `src/scripts/ui/hud.gd` | exists | willpower max set per-notification z zone, nie w _ready |

## Definicja "done"

- [ ] `hazard.gd` base class z lateral motion w obu kierunkach + cleared signal + collision
- [ ] `tractor.tscn` resized do 2.8×2.6×4.0, lateral 1.8, używa `hazard.gd`
- [ ] `pies.tscn` exists, 0.4×0.4×0.6, lateral 4.0, używa `hazard.gd`
- [ ] `krowa.tscn` exists, 1.6×1.8×2.5, lateral 1.5, używa `hazard.gd`
- [ ] Spawn losuje stronę 50/50, hazard wnioskuje `_direction` z `sign(position.x)`
- [ ] Cleared signal emituje się gdy center hazardu mija odpowiedni far edge ścieżki (kierunkowo)
- [ ] Despawn gdy `abs(position.x) > path_half_width + 2.0`
- [ ] `Zone` i `HazardEntry` Resource classes istnieją
- [ ] `zone_village.tres` skonfigurowany z 3 hazardami w weighted pool (2:2:1)
- [ ] `HazardSpawner._spawn_hazard` używa weighted pick z `GameState.current_zone.hazard_pool`
- [ ] `HazardSpawner` używa per-HazardEntry lookahead, nie stałych
- [ ] `GameState.current_zone` ładowane w `reset_metrics()`
- [ ] `NotificationManager` willpower_remaining = current_zone.willpower_max
- [ ] HUD willpower_bar max_value ustawiane per notyfikację
- [ ] Walidacja `godot --headless --quit` przechodzi bez ERRORów
- [ ] Manual playtest: 2 min sesja pokazuje wszystkie 3 hazardy, każdy z innej strony przynajmniej raz

## Test sukcesu

Playtest z 15-letnią testerką (jeśli dostępna):

> *"Czy wioska teraz inaczej się czuje niż wcześniej? Co zauważyłaś?"*

Pozytywny wynik:
- "Tak, jest więcej rzeczy" → variety landed
- Bonus: rozróżnia rytmy ("krowa wolno, pies szybko, traktor średnio")
- Bonus: zauważa że hazardy wychodzą z obu stron

Negatywny:
- "Nie zauważyłam różnicy" → albo placeholder kolory za podobne, albo tuning lateral_speed nie tworzy odczuwalnej różnicy → wrócić do brainstormingu

## Referencje

- `doc/specs/2026-06-02-core-loop-mvp-design.md` — spec M1
- `doc/concept.md` — sekcje "Progresja stref" i hazardy village
- `doc/architecture.md` — kolizje, fazy
- `doc/milestones.md` — M2 jako "Fazy + skalowanie systemów"
- `memory/project_lane_progression.md` — 1 pas village zostaje
- `memory/project_m1_validated.md` — walidacja M1 (8x replay testerki)
- `memory/feedback_godot4_autoload_classname.md` — autoload class_name limitation (dotyczy jeśli `Zone`/`HazardEntry` używane w autoload-typed signal)
