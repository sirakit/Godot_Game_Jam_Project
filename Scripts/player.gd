extends CharacterBody2D

@export var thrust_speed: float = 600.0
@export var damping: float = 0.92
@export var retract_speed_mult: float = 2.0

var ship_position: Vector2 = Vector2.ZERO
var docked: bool = true
var being_retracted: bool = false
var current_meteorite: Node2D = null
var near_ship: bool = false                     # ตั้งค่าโดย ship.gd

@onready var detect_area: Area2D = $DetectArea

func _ready() -> void:
	add_to_group("player")                       # ให้ ship.gd หาเจอ
	detect_area.area_entered.connect(_on_area_entered)
	detect_area.area_exited.connect(_on_area_exited)

func set_ship_position(pos: Vector2) -> void:
	ship_position = pos

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
		velocity += input_vec.normalized() * thrust_speed * delta
	velocity *= damping
	move_and_slide()

	# --- Feature 4: เชือกเป็นกำแพงล่องหน + เกจลดตามระยะจริง ---
	var to_ship := global_position - ship_position
	var dist := to_ship.length()
	if dist > Game.tether_length_max:
		var n := to_ship.normalized()
		global_position = ship_position + n * Game.tether_length_max
		var outward := velocity.dot(n)
		if outward > 0.0:
			velocity -= n * outward               # ตัดแรงที่พุ่งออก เหลือให้ไถลรอบวงได้
		dist = Game.tether_length_max
	Game.update_tether(dist)

	# --- Feature 5: กด E ใกล้ยาน = ส่งของ (playtest 5 ขอมาตรงๆ) ---
	if near_ship and Input.is_action_just_pressed("interact"):
		_finish_dock()
		return

	# --- สกัดหิน ---
	if is_instance_valid(current_meteorite):
		if Input.is_action_pressed("chisel"):
			current_meteorite.chisel(delta, Game.chisel_strength)
		else:
			current_meteorite.cool_down(delta)
		if Input.is_action_just_pressed("interact"):
			current_meteorite.collect()
			current_meteorite = null
	else:
		current_meteorite = null                  # กัน error เมื่ออุกกาบาตถูก queue_free

func undock() -> void:
	docked = false
	being_retracted = false
	Game.start_outside()

func _finish_dock() -> void:
	being_retracted = false
	docked = true
	current_meteorite = null
	global_position = ship_position
	Game.dock()

func _on_area_entered(area: Area2D) -> void:
	var meteor := area.get_parent()
	if meteor.has_method("chisel"):
		current_meteorite = meteor

func _on_area_exited(area: Area2D) -> void:
	var meteor := area.get_parent()
	if meteor == current_meteorite:
		current_meteorite = null
