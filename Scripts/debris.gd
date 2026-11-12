extends Node2D
## ขยะอวกาศที่พุ่งเป็นคลื่น Sine พร้อมหางเส้นแสงและเอฟเฟกต์เศษกระจายเมื่อชนผู้เล่น

@export_group("Base Stats")
@export var speed: float = 260.0
@export var oxygen_damage: float = 25.0
@export var lifetime: float = 12.0
@export var homing_time: float = 0.8
@export var turn_rate_deg: float = 25.0

@export_group("Wave & Cartoon Juice")
@export var wave_frequency: float = 9.0
@export var wave_amplitude: float = 140.0
@export var spin_speed_deg: float = 360.0
@export var pulse_amount: float = 0.18
@export var max_trail_points: int = 16

@export_group("Impact Shatter")
@export var shatter_count: int = 18
@export var shatter_min_speed: float = 90.0
@export var shatter_max_speed: float = 280.0

var direction: Vector2 = Vector2.RIGHT
var target: Node2D = null

var _age: float = 0.0
var _wave_phase: float = 0.0
var _spin_dir: float = 1.0
var _base_scale: Vector2 = Vector2.ONE
var _visual_node: Node2D = null
var _trail: Line2D = null
var _lifetime_timer: SceneTreeTimer = null

@onready var hit_area: Area2D = $Area2D


func _ready() -> void:
	z_index = 2
	hit_area.body_entered.connect(_on_body_entered)
	rotation = direction.angle()
	
	_wave_phase = randf() * TAU
	_spin_dir = -1.0 if randf() < 0.5 else 1.0
	
	_setup_visual_ref()
	_setup_wave_trail()
	
	_lifetime_timer = get_tree().create_timer(lifetime)
	_lifetime_timer.timeout.connect(_on_lifetime_timeout)


func _process(delta: float) -> void:
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
	
	_update_cartoon_juice(delta)
	_update_trail()


func _setup_visual_ref() -> void:
	for child: Node in get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			_visual_node = child as Node2D
			_base_scale = _visual_node.scale
			break


func _setup_wave_trail() -> void:
	_trail = Line2D.new()
	_trail.top_level = true
	_trail.z_index = z_index - 1
	_trail.width = 7.0
	
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(1.0, 1.0))
	_trail.width_curve = curve
	
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.35, 0.2, 0.0))
	grad.set_color(1, Color(1.0, 0.85, 0.3, 0.75))
	_trail.gradient = grad
	
	add_child(_trail)


func _update_cartoon_juice(delta: float) -> void:
	if not is_instance_valid(_visual_node):
		return
	_visual_node.rotation += deg_to_rad(spin_speed_deg * _spin_dir) * delta
	var pulse: float = sin(_age * wave_frequency * 2.0 + _wave_phase) * pulse_amount
	_visual_node.scale = _base_scale * Vector2(1.0 + pulse, 1.0 - pulse * 0.7)


func _update_trail() -> void:
	if not is_instance_valid(_trail):
		return
	_trail.add_point(global_position)
	if _trail.get_point_count() > max_trail_points:
		_trail.remove_point(0)


func _spawn_shatter_effect() -> void:
	# สร้าง CPUParticles2D แยกไปวางในฉากหลักเพื่อให้เล่นเอฟเฟกต์ต่อได้แม้ตัวขยะถูก queue_free()
	var particles := CPUParticles2D.new()
	particles.global_position = global_position
	particles.z_index = z_index + 1
	particles.emitting = false
	particles.one_shot = true
	particles.amount = shatter_count
	particles.lifetime = 0.55
	particles.explosiveness = 0.95
	
	# กระจายรอบทิศทาง 360 องศาในสภาวะไร้น้ำหนัก
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = shatter_min_speed
	particles.initial_velocity_max = shatter_max_speed
	particles.damping_min = 220.0
	particles.damping_max = 380.0
	particles.angular_velocity_min = -540.0
	particles.angular_velocity_max = 540.0
	
	# ปรับขนาดเศษขยะให้เป็นก้อนเหลี่ยมแบบ Pixel Art ที่ค่อยๆ หดเล็กลง
	particles.scale_amount_min = 3.5
	particles.scale_amount_max = 7.5
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(0.3, 1.2))
	scale_curve.add_point(Vector2(1.0, 0.0))
	particles.scale_amount_curve = scale_curve
	
	# ไล่สีจากประกายไฟสว่างจ้าตอนกระแทก -> สีส้ม -> สีเทาเศษหินอวกาศก่อนจางหาย
	var color_ramp := Gradient.new()
	color_ramp.set_color(0, Color(1.0, 0.95, 0.6, 1.0))
	color_ramp.add_point(0.25, Color(1.0, 0.5, 0.2, 1.0))
	color_ramp.add_point(0.65, Color(0.55, 0.55, 0.6, 0.9))
	color_ramp.set_color(1, Color(0.3, 0.3, 0.35, 0.0))
	particles.color_ramp = color_ramp
	
	var scene_root: Node = get_tree().current_scene
	if is_instance_valid(scene_root):
		scene_root.add_child(particles)
		particles.emitting = true
		particles.finished.connect(particles.queue_free)


func _on_lifetime_timeout() -> void:
	if is_instance_valid(self):
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and Game.is_outside:
		Game.oxygen = maxf(0.0, Game.oxygen - oxygen_damage)
		Game.oxygen_changed.emit(Game.oxygen, Game.oxygen_max)
		Game.debris_hit.emit()
		_spawn_shatter_effect()
	queue_free()
