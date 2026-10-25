extends CharacterBody2D

@export var thrust_speed: float = 600.0
@export var damping: float = 0.92
@export var retract_speed_mult: float = 2.0
@export var hammer_rest_deg: float = -80.0
@export var hammer_strike_deg: float = 0.0
@export var hammer_lift_deg: float = -35.0
@export var swing_interval: float = 0.1

@onready var tools: Node2D = $Tools_Node2D
@onready var hammer_pivot: Node2D = $Tools_Node2D/HammerPivot_Node2D
@onready var camera: Camera2D = $Camera2D
var _cam_shake: float = 0.0

var _swing_timer: float = 0.0
var _hammer_down: bool = true
var _was_chiseling: bool = false

var ship_position: Vector2 = Vector2.ZERO
var docked: bool = true
var being_retracted: bool = false
var current_meteorite: Node2D = null
var meteorites_in_range: Array[Area2D] = []
var near_ship: bool = false                     # ตั้งค่าโดย ship.gd

@onready var detect_area: Area2D = $DetectArea

func _ready() -> void:
	add_to_group("player")                       # ให้ ship.gd หาเจอ
	detect_area.area_entered.connect(_on_area_entered)
	detect_area.area_exited.connect(_on_area_exited)
	hammer_pivot.rotation_degrees = hammer_rest_deg #For Chiseling animation
	z_index = 1                                   # ผู้เล่นกับค้อนอยู่เหนือหิน (Playtest 9)
	Game.debris_hit.connect(_on_debris_hit)

func set_ship_position(pos: Vector2) -> void:
	ship_position = pos
	
func _on_debris_hit() -> void:
	_cam_shake = 1.0

func _physics_process(delta: float) -> void:
	Game.tick(delta)

	if docked:
		if Input.is_action_just_pressed("interact"):
			undock()
		return

	if not being_retracted and Game.should_retract():
		being_retracted = true

	if being_retracted:
		global_position = global_position.move_toward(
			ship_position, thrust_speed * retract_speed_mult * delta)
		velocity = Vector2.ZERO
		if global_position.distance_to(ship_position) < 12.0:
			_finish_dock()
		return

	var input_vec := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if input_vec.length() > 0.0:
		velocity += input_vec.normalized() * (thrust_speed + Game.thrust_speed_bonus) * delta
	velocity *= damping
	move_and_slide()

	# # เชือกเป็นกำแพงล่องหน + เกจลดตามระยะจริง
	var to_ship := global_position - ship_position
	var dist := to_ship.length()
	if dist > Game.tether_length_max:
		var n := to_ship.normalized()
		global_position = ship_position + n * Game.tether_length_max
		var outward := velocity.dot(n)
		if outward > 0.0:
			velocity -= n * outward               
		dist = Game.tether_length_max
	Game.update_tether(dist)

	# # กด E ใกล้ยาน = ส่งของ
	if near_ship and Input.is_action_just_pressed("interact"):
		_finish_dock()
		return
		
	_update_target()
	# # สกัดหิน
	if is_instance_valid(current_meteorite):
		if Input.is_action_pressed("chisel"):
			current_meteorite.chisel(delta, Game.chisel_strength)
		else:
			current_meteorite.cool_down(delta)
		if Input.is_action_just_pressed("interact"):
			current_meteorite.collect()
			_set_target(null)
	else:
		current_meteorite = null
						  # กัน error เมื่ออุกกาบาตถูก queue_free
	if _cam_shake > 0.0:
		_cam_shake = maxf(0.0, _cam_shake - delta * 2.5)
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 14.0 * _cam_shake
	else:
		camera.offset = Vector2.ZERO
				

func undock() -> void:
	docked = false
	being_retracted = false
	Game.start_outside()

func _finish_dock() -> void:
	being_retracted = false
	docked = true
	_set_target(null)
	global_position = ship_position
	Game.dock()

func _on_area_entered(area: Area2D) -> void:
	var meteor := area.get_parent()
	if meteor.has_method("chisel") and not meteorites_in_range.has(area):
		meteorites_in_range.append(area)

func _on_area_exited(area: Area2D) -> void:
	meteorites_in_range.erase(area)

func _update_target() -> void:
	meteorites_in_range = meteorites_in_range.filter(func(a): return is_instance_valid(a))

	var nearest: Node2D = null
	var nearest_dist := INF
	for area in meteorites_in_range:
		var meteor := area.get_parent()
		if not is_instance_valid(meteor):
			continue
		var d := global_position.distance_to(meteor.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = meteor

	# ไม่มีลูกไหนอยู่ในระยะเลย ต้องเคลียร์เป้าทันที ไม่ผ่าน hysteresis ด้านล่าง (แก้บั๊กขุดค้าง)
	if nearest == null:
		if current_meteorite != null:
			_set_target(null)
		return

	# กันสลับเป้าถี่ๆ ตอนสองลูกอยู่ใกล้ผู้เล่นพอๆ กัน (เทียบกันได้ก็ต่อเมื่อมีทั้งคู่จริง)
	if is_instance_valid(current_meteorite) and nearest != current_meteorite:
		var current_dist := global_position.distance_to(current_meteorite.global_position)
		if current_dist - nearest_dist < 20.0:
			return

	if nearest != current_meteorite:
		_set_target(nearest)

func _set_target(meteor: Node2D) -> void:
	if is_instance_valid(current_meteorite) and current_meteorite != meteor:
		current_meteorite.set_targeted(false)     
	current_meteorite = meteor

func _process(delta: float) -> void:
	tools.visible = not docked

	var chiseling := (
		not docked
		and not being_retracted
		and is_instance_valid(current_meteorite)
		and Input.is_action_pressed("chisel")
	)
	_update_hammer(delta, chiseling)

func _update_hammer(delta: float, chiseling: bool) -> void:
	if chiseling:
		if not _was_chiseling:
			_hammer_down = true
			_swing_timer = 0.0
			hammer_pivot.rotation_degrees = hammer_strike_deg
		else:
			_swing_timer += delta
			if _swing_timer >= swing_interval:
				_swing_timer -= swing_interval
				_hammer_down = not _hammer_down
				hammer_pivot.rotation_degrees = \
					hammer_strike_deg if _hammer_down else hammer_lift_deg
	else:
		hammer_pivot.rotation_degrees = hammer_rest_deg

	_was_chiseling = chiseling
