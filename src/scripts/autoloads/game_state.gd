extends Node

const ZONE_VILLAGE: Resource = preload("res://resources/zones/zone_village.tres")
const ZONE_SUBURB: Resource = preload("res://resources/zones/zone_suburb.tres")
const ZONE_TOWN: Resource = preload("res://resources/zones/zone_town.tres")
const ZONE_CITY: Resource = preload("res://resources/zones/zone_city.tres")
const ZONES: Array[Resource] = [ZONE_VILLAGE, ZONE_SUBURB, ZONE_TOWN, ZONE_CITY]

enum GamePhase { ROAD, PHONE, GAME_OVER }
enum ZoneIndex { VILLAGE, SUBURB, TOWN, CITY }

const ZONE_THRESHOLDS: Array[float] = [0.0, 500.0, 1500.0, 3000.0]
const ZONE_SPEEDS: Array[float] = [6.0, 9.0, 13.0, 18.0]
const ZONE_NOTIFICATION_INTERVALS: Array[float] = [30.0, 20.0, 12.0, 6.0]

signal phase_changed(new_phase: GamePhase)
signal zone_changed(new_zone: ZoneIndex)
signal score_changed(new_score: int)

var phase: GamePhase = GamePhase.ROAD
var zone: ZoneIndex = ZoneIndex.VILLAGE
var distance: float = 0.0
var current_zone: Resource = ZONE_VILLAGE
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
	zone = ZoneIndex.VILLAGE
	distance = 0.0
	time_on_phone = 0.0
	total_time = 0.0
	score = 0
	current_zone = ZONE_VILLAGE
	speed = current_zone.walk_speed

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
