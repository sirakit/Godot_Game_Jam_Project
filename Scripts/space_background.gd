extends Node2D
## พื้นหลังอวกาศแบบ Hardware Region Repeat แก้ปัญหาขอบจอแหว่งและลด Draw Calls บนเว็บ

@export var base_drift: Vector2 = Vector2(-12.0, 6.0)
@export var enable_shooting_stars_on_web: bool = false

var _shooting_star_timer: float = 4.0
var _player_ref: CharacterBody2D = null

@onready var layer_far: Parallax2D = $Background
@onready var layer_mid: Parallax2D = get_node_or_null("Background2") as Parallax2D
@onready var layer_near: Parallax2D = get_node_or_null("Background3") as Parallax2D


func _ready() -> void:
	z_index = -100
	_setup_seamless_layer(layer_far, 1.0)
	
	# บนเว็บให้ปิดชั้นที่ 3 เพื่อลด Overdraw เหลือแค่ 2 ชั้นก็ดูมีมิติและลื่นไหลมาก
	if is_instance_valid(layer_mid):
		_setup_seamless_layer(layer_mid, 0.65)
	if is_instance_valid(layer_near):
		if OS.has_feature("web"):
			layer_near.visible = false
		else:
			_setup_seamless_layer(layer_near, 0.5)


func _process(delta: float) -> void:
	if not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player") as CharacterBody2D
		
	_update_dynamic_drift()
	
	if not OS.has_feature("web") or enable_shooting_stars_on_web:
		_update_shooting_stars(delta)


func _setup_seamless_layer(layer: Parallax2D, alpha: float) -> void:
	if not is_instance_valid(layer):
		return
		
	# ใช้ Hardware Texture Repeat แทนการให้ Parallax2D วาดโหนดซ้ำหลายสิบรอบ
	layer.repeat_size = Vector2(320.0, 320.0)
	layer.repeat_times = 1
	layer.modulate = Color(1.0, 1.0, 1.0, alpha)
	
	for child: Node in layer.get_children():
		if child is Sprite2D:
			var sp := child as Sprite2D
			sp.centered = true
			sp.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			sp.region_enabled = true
			# กางแผ่นดาวขนาด 3840x2560 พิกเซลใน Draw Call เดียว คลุมหน้าจอทุกขนาดไม่ให้เห็นขอบสีเทา
			sp.region_rect = Rect2(0.0, 0.0, 3840.0, 2560.0)
			sp.position = Vector2.ZERO


func _update_dynamic_drift() -> void:
	var player_vel_offset := Vector2.ZERO
	if is_instance_valid(_player_ref):
		player_vel_offset = -_player_ref.velocity * 0.04
		
	var active_drift: Vector2 = base_drift + player_vel_offset
	if is_instance_valid(layer_far):
		layer_far.autoscroll = active_drift * 0.25
	if is_instance_valid(layer_mid):
		layer_mid.autoscroll = active_drift * 0.65
	if is_instance_valid(layer_near) and layer_near.visible:
		layer_near.autoscroll = active_drift * 1.2


func _update_shooting_stars(delta: float) -> void:
	_shooting_star_timer -= delta
	if _shooting_star_timer <= 0.0:
		_shooting_star_timer = randf_range(4.0, 8.0)
		_spawn_shooting_star()


func _spawn_shooting_star() -> void:
	var star_line := Line2D.new()
	star_line.z_index = 5
	star_line.width = 2.0
	star_line.default_color = Color(0.85, 0.95, 1.0, 0.8)
	
	var dir := Vector2(-0.8, 0.6).normalized()
	star_line.add_point(Vector2.ZERO)
	star_line.add_point(-dir * 65.0)
	
	var cam: Camera2D = get_viewport().get_camera_2d()
	var center: Vector2 = cam.get_screen_center_position() if is_instance_valid(cam) else Vector2.ZERO
	star_line.global_position = center + Vector2(randf_range(-400.0, 400.0), randf_range(-250.0, 250.0))
	add_child(star_line)
	
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(star_line, "global_position", star_line.global_position + dir * 500.0, 0.45)
	tw.tween_property(star_line, "modulate:a", 0.0, 0.45)
	tw.chain().tween_callback(star_line.queue_free)
