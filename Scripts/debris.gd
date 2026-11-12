extends Node2D
## ขยะอวกาศที่พุ่งเป็นคลื่น ป้องกันอาการกระพริบที่จุด (0,0) และไม่ระเบิดหายเมื่อชนสถานีอวกาศ

static var _shared_scale_curve: Curve = null
static var _shared_color_ramp: Gradient = null

@export_group("Base Stats")
@export var speed: float = 260.0
@export var oxygen_damage: float = 25.0
@export var lifetime: float = 12.0
@export var homing_time: float = 0.8
@export var turn_rate_deg: float = 25.0

@export_group("Wave Motion")
@export var wave_frequency: float = 8.5
@export var wave_amplitude: float = 130.0
@export var spin_speed_deg: float = 320.0

@export_group("Impact Shatter")
@export var shatter_count: int = 16
@export var shatter_min_speed: float = 90.0
@export var shatter_max_speed: float = 260.0

var direction: Vector2 = Vector2.RIGHT
var target: Node2D = null

var _age: float = 0.0
var _wave_phase: float = 0.0
var _spin_dir: float = 1.0
var _visual_node: Node2D = null

@onready var hit_area: Area2D = $Area2D


static func _init_shared_resources() -> void:
	if _shared_scale_curve == null:
		_shared_scale_curve = Curve.new()
		_shared_scale_curve.add_point(Vector2(0.0, 1.0))
		_shared_scale_curve.add_point(Vector2(0.3, 1.2))
		_shared_scale_curve.add_point(Vector2(1.0, 0.0))
		
	if _shared_color_ramp == null:
		_shared_color_ramp = Gradient.new()
		_shared_color_ramp.set_color(0, Color(1.0, 0.95, 0.6, 1.0))
		_shared_color_ramp.add_point(0.25, Color(1.0, 0.5, 0.2, 1.0))
		_shared_color_ramp.add_point(0.65, Color(0.55, 0.55, 0.6, 0.9))
		_shared_color_ramp.set_color(1, Color(0.3, 0.3, 0.35, 0.0))


func _init() -> void:
	# ซ่อนตัวตั้งแต่วินาทีที่ถูก instantiate() เพื่อไม่ให้กระพริบที่จุด (0,0) เด็ดขาด
	visible = false


func _ready() -> void:
	_init_shared_resources()
	z_index = 2
	# ปิด Physics Interpolation ของโหนดนี้เพื่อป้องกันภาพวาร์ปข้ามหน้าจอในเฟรมแรก
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	
	hit_area.body_entered.connect(_on_body_entered)
	rotation = direction.angle()
	
	_wave_phase = randf() * TAU
	_spin_dir = -1.0 if randf() < 0.5 else 1.0
	
	for child: Node in get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			_visual_node = child as Node2D
			break
			
	get_tree().create_timer(lifetime).timeout.connect(_on_timeout)
	
	# รอให้ Spawner กำหนด global_position และ direction ให้เสร็จในเฟรมแรกก่อนค่อยแสดงผล
	await get_tree().process_frame
	if is_instance_valid(self):
		reset_physics_interpolation()
		modulate.a = 0.0
		visible = true
		create_tween().tween_property(self, "modulate:a", 1.0, 0.15)


func _process(delta: float) -> void:
	if not visible:
		return
		
	_age += delta
	if target != null and is_instance_valid(target) and _age < homing_time:
		var want: float = (target.global_position - global_position).angle()
		var cur: float = direction.angle()
		var diff: float = wrapf(want - cur, -PI, PI)
		var step: float = deg_to_rad(turn_rate_deg) * delta
		direction = Vector2.from_angle(cur + clampf(diff, -step, step))
		
	var perp_dir: Vector2 = direction.orthogonal()
	var wave_speed: float = cos(_age * wave_frequency + _wave_phase) * wave_amplitude
	var final_velocity: Vector2 = (direction * speed) + (perp_dir * wave_speed)
	
	position += final_velocity * delta
	rotation = final_velocity.angle()
	
	if is_instance_valid(_visual_node):
		_visual_node.rotation += deg_to_rad(spin_speed_deg * _spin_dir) * delta


func _spawn_shatter_effect() -> void:
	var particles := CPUParticles2D.new()
	particles.global_position = global_position
	particles.z_index = z_index + 1
	particles.emitting = false
	particles.one_shot = true
	particles.amount = shatter_count
	particles.lifetime = 0.55
	particles.explosiveness = 0.95
	
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = shatter_min_speed
	particles.initial_velocity_max = shatter_max_speed
	particles.damping_min = 220.0
	particles.damping_max = 380.0
	particles.angular_velocity_min = -540.0
	particles.angular_velocity_max = 540.0
	
	particles.scale_amount_min = 3.5
	particles.scale_amount_max = 7.5
	particles.scale_amount_curve = _shared_scale_curve
	particles.color_ramp = _shared_color_ramp
	
	var scene_root: Node = get_tree().current_scene
	if is_instance_valid(scene_root):
		scene_root.add_child(particles)
		particles.emitting = true
		particles.finished.connect(particles.queue_free)


func _on_timeout() -> void:
	if is_instance_valid(self):
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	# เช็คเฉพาะ Player เท่านั้น! ถ้าชน StaticBody2D ของสถานีอวกาศให้บินทะลุผ่านไปเลย ไม่ต้องลบตัวเอง
	if not body.is_in_group("player"):
		return
		
	if Game.is_outside:
		Game.oxygen = maxf(0.0, Game.oxygen - oxygen_damage)
		Game.oxygen_changed.emit(Game.oxygen, Game.oxygen_max)
		Game.debris_hit.emit()
		_spawn_shatter_effect()
		queue_free()
