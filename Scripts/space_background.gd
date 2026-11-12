extends Node2D
## พื้นหลังอวกาศรุ่นปรับแต่งประสิทธิภาพสำหรับ WebGL (ลด Overdraw และ Shader Recompile)

@export_group("Drift & Twinkle")
@export var base_drift: Vector2 = Vector2(-12.0, 6.0)
@export var twinkle_speed: float = 2.0

@export_group("Shooting Stars")
@export var min_star_interval: float = 2.5
@export var max_star_interval: float = 5.5
@export var star_length: float = 80.0
@export var star_width: float = 2.5

var _time: float = 0.0
var _color_update_timer: float = 0.0
var _shooting_star_timer: float = 2.0
var _player_ref: CharacterBody2D = null

@onready var layer_far: Parallax2D = $Background
@onready var layer_mid: Parallax2D = $Background2
@onready var layer_near: Parallax2D = $Background3


func _ready() -> void:
	z_index = -100
	# ลด Repeat Times บนเว็บเพื่อไม่ให้วาด Tile เกินขอบจอมากเกินไป
	if OS.has_feature("web"):
		layer_far.repeat_times = 4
		layer_mid.repeat_times = 4
		layer_near.repeat_times = 4


func _process(delta: float) -> void:
	_time += delta
	if not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player") as CharacterBody2D
		
	# อัปเดตความโปร่งใสแค่ 15 ครั้งต่อวินาทีแทนทุกเฟรม เพื่อลดการสั่ง Batch Re-upload บน WebGL
	_color_update_timer += delta
	if _color_update_timer >= 0.066:
		_color_update_timer = 0.0
		_update_twinkle_lightweight()
		
	_update_dynamic_drift()
	_update_shooting_stars(delta)


func _update_twinkle_lightweight() -> void:
	layer_mid.modulate.a = 0.55 + (sin(_time * twinkle_speed) * 0.2)
	layer_near.modulate.a = 0.50 + (cos(_time * twinkle_speed * 1.3) * 0.25)


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
	star_line.z_index = 5
	star_line.width = star_width
	star_line.default_color = Color(0.85, 0.95, 1.0, 0.85)
	
	var dir := Vector2(randf_range(-1.0, -0.4), randf_range(0.3, 0.9)).normalized()
	star_line.add_point(Vector2.ZERO)
	star_line.add_point(-dir * star_length)
	
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
	tween.tween_property(star_line, "global_position", star_line.global_position + dir * 600.0, 0.5)
	tween.tween_property(star_line, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(star_line.queue_free)
