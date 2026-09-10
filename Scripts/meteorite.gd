extends Node2D

@export var rock_integrity_max: float = 30.0
@export var artifact_value: int = 10
@export var artifact_name: String = "Unknown Artifact"

var rock_integrity: float
var artifact_revealed: bool = false
var artifact_collected: bool = false
var artifact_health: float = 100.0   # คุณภาพ/ความสมบูรณ์ของอาร์ติแฟกต์

var heat: float = 0.0
var heat_max: float = 100.0
var heat_gain_rate: float = 40.0
var heat_cool_rate: float = 25.0
var heat_damage_threshold: float = 70.0
var damage_rate: float = 30.0

@onready var rock_sprite: Polygon2D = $RockShape
@onready var artifact_sprite: Polygon2D = $Artifact

func _ready():
	rock_integrity = rock_integrity_max
	artifact_sprite.visible = false

func chisel(delta: float, strength: float):
	if artifact_collected:
		return
	if not artifact_revealed:
		rock_integrity -= strength * 10.0 * delta
		heat = min(heat_max, heat + heat_gain_rate * delta)
		if heat > heat_damage_threshold:
			# สกัดหินแรงเกินไป โดยไม่พักเลย ความร้อนทะลุไปสั่นสะเทือนของข้างในด้วย
			artifact_health = max(0.0, artifact_health - damage_rate * delta)
		if rock_integrity <= 0.0:
			reveal_artifact()
	else:
		# ขั้นสกัดละเอียดตรงตัวอาร์ติแฟกต์ บอบบางกว่าเดิม
		heat = min(heat_max, heat + heat_gain_rate * 1.5 * delta)
		if heat > heat_damage_threshold * 0.6:
			artifact_health = max(0.0, artifact_health - damage_rate * 1.5 * delta)

func cool_down(delta: float):
	heat = max(0.0, heat - heat_cool_rate * delta)

func reveal_artifact():
	artifact_revealed = true
	rock_sprite.color = Color(0.3, 0.015, 0.221, 1.0)
	artifact_sprite.visible = true

func get_heat_ratio() -> float:
	return heat / heat_max

func collect() -> bool:
	if artifact_revealed and not artifact_collected:
		artifact_collected = true
		artifact_sprite.visible = false
		var quality: float = artifact_health / 100.0
		var final_value: int = int(artifact_value * max(0.1, quality))
		Game.add_artifact({"name": artifact_name, "value": final_value})
		return true
	return false
