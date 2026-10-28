extends Node2D

@export var meteorite_scene: PackedScene

@export_group("Spacing")
@export var min_spacing: float = 200.0
@export var min_distance_from_ship: float = 350.0
@export var min_distance_from_player: float = 350.0
@export var reach_margin: float = 1.1               # เกิดเลยระยะเชือกได้อีก 10%
@export var spawn_interval: Vector2 = Vector2(0.5, 1.2)

@onready var ship: Node2D = get_node("../Ship")
@onready var player: Node2D = get_node("../Player")

var _timer: float = 0.0

func _ready() -> void:
	_reset_timer()
	for i in 80:                                      # เติมโซนที่เปิดอยู่ให้เต็มตั้งแต่เริ่ม
		if not _fill_one_zone():
			break

func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_reset_timer()
	_fill_one_zone()

func _reset_timer() -> void:
	_timer = randf_range(spawn_interval.x, spawn_interval.y)

# เติมโซนที่หินน้อยกว่าเป้า 1 ก้อน คืน true ถ้าเกิดได้
func _fill_one_zone() -> bool:
	var reach := Game.tether_length_max * reach_margin
	var order := [0, 1, 2, 3, 4]
	order.shuffle()
	for z in order:
		if reach <= MeteoriteTiers.zone_inner(z):
			continue                                  # เชือกยังไปไม่ถึงโซนนี้
		if _count_in_zone(z) < _zone_target(z, reach):
			if _spawn_in_zone(z, reach):
				return true
	return false

# โซนที่เชือกครอบคลุมแค่บางส่วน ได้โควตาตามสัดส่วน
func _zone_target(z: int, reach: float) -> int:
	var inner := MeteoriteTiers.zone_inner(z)
	var outer: float = MeteoriteTiers.ZONE_OUTER[z]
	var frac := clampf((reach - inner) / (outer - inner), 0.0, 1.0)
	return ceili(MeteoriteTiers.ZONE_TARGET[z] * frac)

func _count_in_zone(z: int) -> int:
	var n := 0
	for m in get_tree().get_nodes_in_group("meteorites"):
		if MeteoriteTiers.zone_of(m.global_position.distance_to(ship.global_position)) == z:
			n += 1
	return n

func _spawn_in_zone(z: int, reach: float) -> bool:
	var r_min := maxf(MeteoriteTiers.zone_inner(z), min_distance_from_ship)
	var r_max := minf(MeteoriteTiers.ZONE_OUTER[z], reach)
	if r_max <= r_min + 50.0:
		return false
	for attempt in 12:
		var angle := randf_range(0.0, TAU)
		var dist := sqrt(randf_range(r_min * r_min, r_max * r_max))   # กระจายสม่ำเสมอตามพื้นที่
		var pos := ship.global_position + Vector2.from_angle(angle) * dist
		if Game.is_outside and pos.distance_to(player.global_position) < min_distance_from_player:
			continue
		if _too_close_to_other(pos):
			continue
		var m := meteorite_scene.instantiate()
		m.tier = MeteoriteTiers.pick_tier(z)
		m.position = to_local(pos)
		add_child(m)
		return true
	return false

func _too_close_to_other(pos: Vector2) -> bool:
	for m in get_tree().get_nodes_in_group("meteorites"):
		if m.global_position.distance_to(pos) < min_spacing:
			return true
	return false
