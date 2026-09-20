extends CharacterBody2D

@export var thrust_speed: float = 550.0
@export var damping: float = 0.92
@export var retract_speed_mult: float = 2.0

var ship_position: Vector2 = Vector2.ZERO
var docked: bool = true
var being_retracted: bool = false
var current_meteorite: Node2D = null

@onready var detect_area: Area2D = $DetectArea

func _ready():
	detect_area.area_entered.connect(_on_area_entered)
	detect_area.area_exited.connect(_on_area_exited)

func set_ship_position(pos: Vector2):
	ship_position = pos

func _physics_process(delta: float) -> void:
	Game.tick(delta)

	if docked:
		# กด interact ตอนอยู่ในยาน = ออกเดินทาง
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
			being_retracted = false
			docked = true
			Game.dock()
		return

	# เคลื่อนที่แบบลอยในอวกาศ (มี damping กันไหลไม่หยุด)
	var input_vec := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if input_vec.length() > 0.0:
		velocity += input_vec.normalized() * thrust_speed * delta
	velocity *= damping
	move_and_slide()

	# สกัดหินถ้ามีอุกกาบาตอยู่ในระยะ และกดค้าง Space
	if current_meteorite != null:
		if Input.is_action_pressed("chisel"):
			current_meteorite.chisel(delta, Game.chisel_strength)
		else:
			current_meteorite.cool_down(delta)

		if Input.is_action_just_pressed("interact"):
			current_meteorite.collect()

func undock():
	docked = false
	being_retracted = false
	Game.start_outside()

func _on_area_entered(area: Area2D):
	var meteor = area.get_parent()
	if meteor.has_method("chisel"):
		current_meteorite = meteor

func _on_area_exited(area: Area2D):
	var meteor = area.get_parent()
	if meteor == current_meteorite:
		current_meteorite = null
