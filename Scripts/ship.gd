extends Node2D
## ควบคุมสถานีอวกาศให้ลอยตัวในสภาวะไร้น้ำหนัก มีแรงดึงตามเชือกผู้เล่น และมีไฟสัญญาณกะพริบ

@export_group("Zero-G Drift")
@export var float_amplitude: Vector2 = Vector2(3.5, 6.0)
@export var float_speed: Vector2 = Vector2(0.7, 1.1)
@export var sway_max_deg: float = 2.2
@export var sway_speed: float = 0.55

@export_group("Tether & Docking Juice")
@export var tether_pull_offset: float = 7.0
@export var tether_tilt_deg: float = 2.8
@export var dock_bounce_power: float = 0.14

var _time: float = 0.0
var _base_sprite_pos: Vector2 = Vector2.ZERO
var _base_sprite_scale: Vector2 = Vector2.ONE
var _base_hull_pos: Vector2 = Vector2.ZERO
var _player_ref: CharacterBody2D = null
var _was_player_docked: bool = true
var _beacon_dots: Array[Line2D] = []

@onready var sprite: Sprite2D = $Sprite2D
@onready var hull: Control = $Hull
@onready var dock_area: Area2D = $DockArea


func _ready() -> void:
	dock_area.body_entered.connect(_on_enter)
	dock_area.body_exited.connect(_on_exit)
	
	_base_sprite_pos = sprite.position
	_base_sprite_scale = sprite.scale
	_base_hull_pos = hull.position
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	_setup_navigation_beacons()


func _process(delta: float) -> void:
	_time += delta
	if not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player") as CharacterBody2D
		
	_update_natural_motion(delta)
	_update_beacons()


func _update_natural_motion(delta: float) -> void:
	# 1. ลอยตัวเป็นเลขแปด (Lissajous Curve) ช้าๆ ให้เหมือนมีมวลขนาดใหญ่ในอวกาศ
	var drift_offset := Vector2(
		sin(_time * float_speed.x) * float_amplitude.x,
		cos(_time * float_speed.y) * float_amplitude.y
	)
	var target_rot_deg: float = sin(_time * sway_speed) * sway_max_deg
	var target_scale: Vector2 = _base_sprite_scale
	
	if is_instance_valid(_player_ref):
		var is_docked: bool = bool(_player_ref.get("docked"))
		
		# 2. จังหวะกระเพื่อมรับแรงกระแทก (Squash & Stretch) ตอนผู้เล่นเข้าจอดหรือดีดตัวออก
		if is_docked != _was_player_docked:
			var bounce: Vector2 = (
				Vector2(1.0 + dock_bounce_power, 1.0 - dock_bounce_power * 0.7)
				if is_docked
				else Vector2(1.0 - dock_bounce_power * 0.7, 1.0 + dock_bounce_power)
			)
			sprite.scale = _base_sprite_scale * bounce
			_was_player_docked = is_docked
			
		# 3. แรงดึงรั้งจากสายเชือก: ยานจะขยับและเอียงตามทิศที่ผู้เล่นดึงเชือกออกไป
		if not is_docked:
			var to_player: Vector2 = _player_ref.global_position - global_position
			var max_tether: float = maxf(1.0, Game.tether_length_max)
			var tension: float = clampf(to_player.length() / max_tether, 0.0, 1.0)
			var pull_dir: Vector2 = to_player.normalized()
			
			drift_offset += pull_dir * (tension * tether_pull_offset)
			target_rot_deg += pull_dir.x * tension * tether_tilt_deg
			
		# 4. ตอนผู้เล่นอยู่ใกล้ยาน (พร้อมกด E) แผงโซลาร์เซลล์จะสว่างต้อนรับเล็กน้อย
		var target_mod: Color = Color(1.12, 1.12, 1.18) if _player_ref.near_ship and not is_docked else Color.WHITE
		sprite.modulate = sprite.modulate.lerp(target_mod, 8.0 * delta)
		
	sprite.position = sprite.position.lerp(_base_sprite_pos + drift_offset, 6.0 * delta)
	hull.position = hull.position.lerp(_base_hull_pos + drift_offset, 6.0 * delta)
	sprite.rotation = lerp_angle(sprite.rotation, deg_to_rad(target_rot_deg), 5.0 * delta)
	sprite.scale = sprite.scale.lerp(target_scale, 10.0 * delta)


func _setup_navigation_beacons() -> void:
	# สร้างไฟสัญญาณเตือนภัย (Navigation Lights) บนตัวสถานีอัตโนมัติโดยไม่ต้องใช้ไฟล์ภาพ
	if not sprite.texture:
		return
	var tex_size: Vector2 = sprite.texture.get_size()
	var positions: Array[Vector2] = [
		Vector2(0.0, -tex_size.y * 0.44),
		Vector2(0.0, tex_size.y * 0.44),
		Vector2(-tex_size.x * 0.46, 0.0),
		Vector2(tex_size.x * 0.46, 0.0)
	]
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	
	for i: int in range(positions.size()):
		var dot := Line2D.new()
		dot.width = 5.0
		dot.default_color = Color(1.0, 0.25, 0.2, 0.9) if i < 2 else Color(0.2, 0.9, 1.0, 0.9)
		dot.material = mat
		dot.begin_cap_mode = Line2D.LINE_CAP_ROUND
		dot.end_cap_mode = Line2D.LINE_CAP_ROUND
		dot.position = positions[i]
		dot.add_point(Vector2.ZERO)
		dot.add_point(Vector2(0.1, 0.0))
		sprite.add_child(dot)
		_beacon_dots.append(dot)


func _update_beacons() -> void:
	# กะพริบไฟสีแดง (บน-ล่าง) สลับกับไฟสีฟ้า (ซ้าย-ขวา) ตามจังหวะสถานีอวกาศ
	for i: int in range(_beacon_dots.size()):
		var dot: Line2D = _beacon_dots[i]
		var phase: float = 0.0 if i < 2 else PI
		var pulse: float = clampf(sin(_time * 3.2 + phase), 0.0, 1.0)
		dot.modulate.a = 0.15 + (pulse * 0.85)


func _on_enter(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.near_ship = true


func _on_exit(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.near_ship = false
