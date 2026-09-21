extends Node2D

@export var meteorite_scene: PackedScene        # ลาก Scenes/meteorite.tscn มาใส่
@export var spawn_radius_min: float = 400.0
@export var spawn_radius_max: float = 2600.0
@export var max_alive: int = 26
@export var spawn_interval: Vector2 = Vector2(1.5, 4.0)

@onready var ship: Node2D = get_node("../Ship")

var _alive: int = 0
var _timer: float = 0.0

func _ready() -> void:
	_alive = get_child_count()                   # นับอุกกาบาตที่วางมือไว้แล้วด้วย
	_reset_timer()

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0 and _alive < max_alive:
		_spawn_one()
		_reset_timer()

func _reset_timer() -> void:
	_timer = randf_range(spawn_interval.x, spawn_interval.y)

# ยิ่งเล่นนาน ยิ่งเจอ V2 บ่อยขึ้น (10% → สูงสุด 45%)
func _v2_chance() -> float:
	return min(0.45, 0.10 + Game.total_earned / 2000.0)

func _spawn_one() -> void:
	var m := meteorite_scene.instantiate()
	var angle := randf_range(0.0, TAU)
	var dist := randf_range(spawn_radius_min, spawn_radius_max)
	m.position = ship.global_position + Vector2(cos(angle), sin(angle)) * dist

	if randf() < _v2_chance():
		m.rock_integrity_max = 95.0              # แข็งกว่าเดิม ~3 เท่า
		m.artifact_value = 40                    # มูลค่า 4 เท่า
		m.artifact_name = "Rare Artifact"
		m.required_drill = 2.0                   # ต้องอัปเกรด Drill 1 ครั้งก่อนถึงจะขุดเต็มสปีด
		m.rock_color = Color(0.55, 0.15, 0.85, 0.85)
		m.drift_radius = 75.0                    # ขยับกว้างกว่า เล็งยากกว่า
		m.drift_speed = 1.7
		m.spin_speed = 0.6
	else:
		m.drift_radius = randf_range(25.0, 55.0)
		m.drift_speed = randf_range(0.7, 1.3)

	add_child(m)
	m.tree_exited.connect(func(): _alive -= 1)
	_alive += 1
