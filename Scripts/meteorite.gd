extends Node2D

@export_group("Artifact")
@export var rock_integrity_max: float = 30.0
@export var artifact_value: int = 10
@export var artifact_name: String = "Unknown Artifact"
@export var required_drill: float = 1.0        # V2 ต้องการค่านี้สูงกว่า
@export var rock_color: Color = Color(0.05, 0.067, 0.467, 0.8)

@export_group("Drift")
@export var drift_enabled: bool = true
@export var drift_radius: float = 40.0
@export var drift_speed: float = 1.0
@export var spin_speed: float = 0.3

var rock_integrity: float
var artifact_revealed: bool = false
var artifact_collected: bool = false
var artifact_health: float = 100.0

var heat: float = 0.0
var heat_max: float = 100.0
var heat_gain_rate: float = 40.0
var heat_cool_rate: float = 25.0
var heat_damage_threshold: float = 70.0
var damage_rate: float = 30.0

var _home_position: Vector2
var _drift_time: float = 0.0
var _shake: float = 0.0

@onready var rock_sprite: Polygon2D = $RockShape
@onready var artifact_sprite: Polygon2D = $Artifact
@onready var extract_bar: ProgressBar = $ExtractBar       
@onready var heat_bar: ProgressBar = $HeatBar             
@onready var integrity_bar: ProgressBar = $IntegrityBar   

func _ready() -> void:
	rock_integrity = rock_integrity_max
	artifact_sprite.visible = false
	rock_sprite.color = rock_color
	_home_position = position

	extract_bar.min_value = 0.0
	extract_bar.max_value = 1.0
	heat_bar.min_value = 0.0
	heat_bar.max_value = heat_max
	integrity_bar.min_value = 0.0
	integrity_bar.max_value = 100.0
	integrity_bar.value = 100.0
	_set_bars_visible(false)

func _process(delta: float) -> void:
	if drift_enabled:
		_drift_time += delta * drift_speed
		position = _home_position + Vector2(
			sin(_drift_time * 1.3) * drift_radius,
			cos(_drift_time) * drift_radius
		)
		rotation += spin_speed * delta

	# สั่นตอนสกัด 
	if _shake > 0.0:
		_shake = max(0.0, _shake - delta * 8.0)
		rock_sprite.position = Vector2(randf_range(-2, 2), randf_range(-2, 2)) * _shake
	else:
		rock_sprite.position = Vector2.ZERO

func _set_bars_visible(v: bool) -> void:
	extract_bar.visible = v and not artifact_revealed
	heat_bar.visible = v
	integrity_bar.visible = v and artifact_revealed

func set_targeted(active: bool) -> void:
	if not active:
		_set_bars_visible(false)

func chisel(delta: float, strength: float) -> void:
	if artifact_collected:
		return

	_shake = 1.0
	_set_bars_visible(true)

	# ถ้าสว่านยังไม่แรงพอสำหรับหินชนิดนี้ จะขุดได้แต่ช้ามาก
	var effective := strength
	if Game.drill_strength < required_drill:
		effective *= 0.35
		extract_bar.modulate = Color(1.0, 0.4, 0.4)
	else:
		extract_bar.modulate = Color.WHITE

	if not artifact_revealed:
		rock_integrity -= effective * 10.0 * delta
		extract_bar.value = 1.0 - (rock_integrity / rock_integrity_max)
		heat = min(heat_max, heat + heat_gain_rate * delta)
		if heat > heat_damage_threshold:
			artifact_health = max(0.0, artifact_health - damage_rate * delta)
		if rock_integrity <= 0.0:
			reveal_artifact()
	else:
		heat = min(heat_max, heat + heat_gain_rate * 1.5 * delta)
		if heat > heat_damage_threshold * 0.6:
			artifact_health = max(0.0, artifact_health - damage_rate * 1.5 * delta)

	_update_bars()

func cool_down(delta: float) -> void:
	heat = max(0.0, heat - heat_cool_rate * delta)
	_update_bars()
	if heat <= 0.0 and not artifact_revealed:
		_set_bars_visible(false)

func _update_bars() -> void:
	heat_bar.value = heat
	integrity_bar.value = artifact_health
	#ปลอดภัย = ส้ม, อันตราย = แดงสด
	var danger := heat_damage_threshold if not artifact_revealed else heat_damage_threshold * 0.6
	heat_bar.modulate = Color(1.0, 0.25, 0.15) if heat > danger else Color(1.0, 0.65, 0.2)
	integrity_bar.modulate = Color(1.0, 0.3, 0.3) if artifact_health < 50.0 else Color(0.4, 0.9, 1.0)

func reveal_artifact() -> void:
	artifact_revealed = true
	rock_sprite.color = Color(0.25, 0.25, 0.25)
	artifact_sprite.visible = true
	_set_bars_visible(true)

func get_heat_ratio() -> float:
	return heat / heat_max

func collect() -> bool:
	if artifact_revealed and not artifact_collected:
		artifact_collected = true
		var quality: float = artifact_health / 100.0
		var final_value: int = int(artifact_value * max(0.1, quality))

		var is_perfect := artifact_health >= 95.0
		if is_perfect:
			final_value = int(final_value * 1.5)     # โบนัส ตอนคุณภาพ 95%+

		Game.add_artifact({"name": artifact_name, "value": final_value})
		if is_perfect:
			Game.perfect_extraction.emit()

		queue_free()
		return true
	return false
