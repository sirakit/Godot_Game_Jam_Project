extends Node2D
## เพิ่มลูกเล่นดวงดาวกะพริบ เปลี่ยนสีเนบิวลา และสร้างดาวตกบนหน้าจอกล้องโดยไม่ถูก Parallax2D บัง

@export_group("Drift & Twinkle")
@export var base_drift: Vector2 = Vector2(-12.0, 6.0)
@export var twinkle_speed: float = 2.0
@export var color_shift_speed: float = 0.4
@export var nebula_tint_a: Color = Color(0.75, 0.85, 1.0, 0.7)
@export var nebula_tint_b: Color = Color(0.95, 0.75, 1.0, 0.7)

@export_group("Shooting Stars")
@export var min_star_interval: float = 1.5
@export var max_star_interval: float = 4.0
@export var star_length: float = 90.0
@export var star_width: float = 3.0

var _time: float = 0.0
var _shooting_star_timer: float = 1.0
var _player_ref: CharacterBody2D = null
var _star_material := CanvasItemMaterial.new()

@onready var layer_far: Parallax2D = $Background
@onready var layer_mid: Parallax2D = $Background2
@onready var layer_near: Parallax2D = $Background3


func _ready() -> void:
	z_index = -100
	# ใช้โหมดแสง Add เพื่อให้เส้นดาวตกสว่างเรืองแสงทะลุพื้นหลังมืด
	_star_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD


func _process(delta: float) -> void:
	_time += delta
	if not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player") as CharacterBody2D
		
	_update_twinkle_and_color()
	_update_dynamic_drift()
	_update_shooting_stars(delta)


func _update_twinkle_and_color() -> void:
	var alpha_mid: float = 0.55 + (sin(_time * twinkle_speed) * 0.25)
	var alpha_near: float = 0.50 + (cos(_time * twinkle_speed * 1.4) * 0.30)
	
	var color_weight: float = (sin(_time * color_shift_speed) + 1.0) * 0.5
	var current_tint: Color = nebula_tint_a.lerp(nebula_tint_b, color_weight)
	
	layer_mid.modulate = Color(current_tint.r, current_tint.g, current_tint.b, alpha_mid)
	layer_near.modulate = Color(1.0, 0.95, 0.9, alpha_near)


func _update_dynamic_drift() -> void:
	var player_vel_offset := Vector2.ZERO
	if is_instance_valid(_player_ref):
		player_vel_offset = -_player_ref.velocity * 0.05
		
	var active_drift: Vector2 = base_drift + player_vel_offset
	layer_far.autoscroll = active_drift * 0.25
	layer_mid.autoscroll = active_drift * 0.65
	layer_near.autoscroll = active_drift * 1.25


func _update_shooting_stars(delta: float) -> void:
	_shooting_star_timer -= delta
	if _shooting_star_timer <= 0.0:
		_shooting_star_timer = randf_range(min_star_interval, max_star_interval)
		_spawn_shooting_star()


func _spawn_shooting_star() -> void:
	var star_line := Line2D.new()
	# สำคัญมาก: ดัน z_index ให้อยู่เหนือ Parallax2D ทั้ง 3 ชั้น แต่ยังอยู่ใต้ยานอวกาศ
	star_line.z_index = 5
	star_line.width = star_width
	star_line.material = _star_material
	star_line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	# ทำให้หัวดาวตกหนาและหางเรียวแหลม
	var width_curve := Curve.new()
	width_curve.add_point(Vector2(0.0, 1.0))
	width_curve.add_point(Vector2(1.0, 0.0))
	star_line.width_curve = width_curve
	
	# ไล่สีหัวดาวตกสว่างจ้า หางค่อยๆ จางเป็นสีฟ้าใส
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.set_color(1, Color(0.4, 0.8, 1.0, 0.0))
	star_line.gradient = grad
	
	var dir := Vector2(randf_range(-1.0, -0.4), randf_range(0.3, 0.9)).normalized()
	star_line.add_point(Vector2.ZERO)
	star_line.add_point(-dir * star_length)
	
	# หาจุดกึ่งกลางกล้องปัจจุบัน เพื่อให้ดาวตกเกิดในจอที่ผู้เล่นมองเห็นเสมอ
	var cam_center := Vector2.ZERO
	var cam: Camera2D = get_viewport().get_camera_2d()
	if is_instance_valid(cam):
		cam_center = cam.get_screen_center_position()
	elif is_instance_valid(_player_ref):
		cam_center = _player_ref.global_position
		
	var view_size: Vector2 = get_viewport_rect().size * 0.45
	star_line.global_position = cam_center + Vector2(
		randf_range(-view_size.x, view_size.x),
		randf_range(-view_size.y, view_size.y)
	)
	add_child(star_line)
	
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(star_line, "global_position", star_line.global_position + dir * 650.0, 0.6)
	tween.tween_property(star_line, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(star_line.queue_free)
