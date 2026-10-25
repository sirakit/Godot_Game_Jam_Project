extends Node2D

@export var meteorite_scene: PackedScene
@export var rock2_texture: Texture2D              # ลาก Assets/sprites/meteorites/meteorite_2.png (ใช้กับ V2)

@export_group("Reach-based spawning")
@export var rocks_per_500px: float = 10.0         # เป้าจำนวนหินในระยะเชือก ต่อทุก 500px
@export var min_target: int = 13
@export var max_target: int = 45
@export var min_distance_from_ship: float = 350.0 # กันเกิดทับยาน (DockArea รัศมี 180)
@export var min_distance_from_player: float = 350.0
@export var min_spacing: float = 200.0            # กันหินเกิดซ้อน/กระจุก (drift ได้ถึง ±75)
@export var reach_margin: float = 1.1             # เกิดเลยระยะเชือกได้อีก 10%
@export var far_ring_chance: float = 0.2          # โอกาสเกิดนอกระยะเชือก (เป็นเป้าหมายให้อัปเกรดเชือก)
@export var far_extra: int = 12                   # จำนวนหินนอกระยะสูงสุด
@export var spawn_interval: Vector2 = Vector2(0.8, 2.0)

@onready var ship: Node2D = get_node("../Ship")
@onready var player: Node2D = get_node("../Player")

var _timer: float = 0.0

func _ready() -> void:
	_reset_timer()
	var reach := Game.tether_length_max
	var guard := 0
	while _count_in_reach(reach) < _target_in_reach(reach) and guard < 40:
		_spawn_one(false)
		guard += 1

func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_reset_timer()

	var reach := Game.tether_length_max
	var target := _target_in_reach(reach)
	if _count_in_reach(reach) < target:
		_spawn_one(false)
	elif randf() < far_ring_chance and get_tree().get_nodes_in_group("meteorites").size() < target + far_extra:
		_spawn_one(true)

func _reset_timer() -> void:
	_timer = randf_range(spawn_interval.x, spawn_interval.y)

func _target_in_reach(reach: float) -> int:
	return clampi(int(reach / 500.0 * rocks_per_500px), min_target, max_target)

func _count_in_reach(reach: float) -> int:
	var n := 0
	for m in get_tree().get_nodes_in_group("meteorites"):
		if m.global_position.distance_to(ship.global_position) <= reach:
			n += 1
	return n

# ยิ่งเล่นนาน ยิ่งเจอ V2 บ่อยขึ้น (10% -> สูงสุด 35% เหลือที่ให้ V1 เป็นหลักเสมอ)
func _v2_chance() -> float:
	return min(0.35, 0.10 + Game.total_earned / 2500.0)

func _pick_position(far: bool) -> Vector2:
	var reach := Game.tether_length_max
	var r_min := min_distance_from_ship
	var r_max := reach * reach_margin
	if far:
		r_min = reach * reach_margin
		r_max = reach * 2.0
	for attempt in 12:
		var angle := randf_range(0.0, TAU)
		var dist := sqrt(randf_range(r_min * r_min, r_max * r_max))   # กระจายสม่ำเสมอตามพื้นที่
		var pos := ship.global_position + Vector2(cos(angle), sin(angle)) * dist
		if Game.is_outside and pos.distance_to(player.global_position) < min_distance_from_player:
			continue
		if _too_close_to_other(pos):
			continue
		return pos
	return Vector2.INF   # หาที่ว่างไม่ได้ รอบหน้าค่อยลองใหม่

func _too_close_to_other(pos: Vector2) -> bool:
	for m in get_tree().get_nodes_in_group("meteorites"):
		if m.global_position.distance_to(pos) < min_spacing:
			return true
	return false

func _spawn_one(far: bool) -> void:
	var pos := _pick_position(far)
	if pos == Vector2.INF:
		return

	var m := meteorite_scene.instantiate()
	m.position = to_local(pos)

	if randf() < _v2_chance():
		m.rock_integrity_max = 95.0
		m.artifact_value = 40
		m.artifact_name = ArtifactDB.RARE_NAMES.pick_random()
		m.required_drill = 2.0
		m.rock_color = Color(0.55, 0.15, 0.85, 0.85)
		m.drift_radius = 75.0
		m.drift_speed = 1.7
		m.spin_speed = 0.6
		m.artifact_tint = Color(0.75, 0.4, 1.0)
		if rock2_texture != null:
			m.rock_texture = rock2_texture
			m.rock_scale_mult = 1.7
	else:
		m.artifact_name = ArtifactDB.COMMON_NAMES.pick_random()
		m.drift_radius = randf_range(25.0, 55.0)
		m.drift_speed = randf_range(0.7, 1.3)

	add_child(m)
