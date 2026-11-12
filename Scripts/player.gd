extends CharacterBody2D
## ควบคุมผู้เล่นในอวกาศ ปรับขนาด Sprite อัตโนมัติให้เท่ากันทุกอนิเมชัน และแสดงท่าทางขึ้น-ลงชัดเจน

@export_group("Movement & Tether")
@export var thrust_speed: float = 600.0
@export var damping: float = 0.92
@export var retract_speed_mult: float = 2.0
@export var recall_speed: float = 3200.0

@export_group("Hammer Settings")
@export var hammer_rest_deg: float = -80.0
@export var hammer_strike_deg: float = 0.0
@export var hammer_lift_deg: float = -35.0
@export var swing_interval: float = 0.1

@export_group("Cartoon Juice (Procedural)")
@export var max_tilt_deg: float = 25.0
@export var vertical_pitch_deg: float = 20.0
@export var tilt_smoothing: float = 12.0
@export var stretch_amount: float = 0.35
@export var bob_frequency: float = 5.0
@export var bob_amplitude: float = 4.5

var ship_position: Vector2 = Vector2.ZERO
var docked: bool = true
var being_retracted: bool = false
var current_meteorite: Node2D = null
var meteorites_in_range: Array[Area2D] = []
var near_ship: bool = false

var _cam_shake: float = 0.0
var _swing_timer: float = 0.0
var _hammer_down: bool = true
var _was_chiseling: bool = false
var _retract_speed: float = 1200.0
var _dock_penalty: float = 0.0
var _recall_hold: float = 0.0
var _juice_time: float = 0.0

var _base_sprite_pos: Vector2 = Vector2.ZERO
var _base_tools_pos: Vector2 = Vector2.ZERO
var _editor_scale: Vector2 = Vector2.ONE
var _reference_height: float = 64.0

@onready var player_animation: AnimatedSprite2D = $Player_Sprite2D
@onready var sfx_hammering: AudioStreamPlayer2D = $sfx_hammering
@onready var tools: Node2D = $Tools_Node2D
@onready var hammer_pivot: Node2D = $Tools_Node2D/HammerPivot_Node2D
@onready var camera: Camera2D = $Camera2D
@onready var detect_area: Area2D = $DetectArea


func _ready() -> void:
	add_to_group("player")
	detect_area.area_entered.connect(_on_area_entered)
	detect_area.area_exited.connect(_on_area_exited)
	hammer_pivot.rotation_degrees = hammer_rest_deg
	z_index = 1
	Game.debris_hit.connect(_on_debris_hit)
	
	_editor_scale = player_animation.scale
	_base_sprite_pos = player_animation.position
	_base_tools_pos = tools.position
	player_animation.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	# วัดขนาดภาพจากอนิเมชัน Idle เป็นมาตรฐาน เพื่อไม่ให้ภาพ Floating ใหญ่ทะลุจอ
	if player_animation.sprite_frames and player_animation.sprite_frames.has_animation("Idle"):
		var idle_tex: Texture2D = player_animation.sprite_frames.get_frame_texture("Idle", 0)
		if idle_tex:
			_reference_height = idle_tex.get_height()


func _process(delta: float) -> void:
	tools.visible = not docked
	player_animation.visible = not docked

	var chiseling: bool = (
		not docked
		and not being_retracted
		and is_instance_valid(current_meteorite)
		and Input.is_action_pressed("chisel")
	)
	_update_chisel_sfx(chiseling)


func _physics_process(delta: float) -> void:
	Game.tick(delta)
	_juice_time += delta
		
	if docked:
		if Input.is_action_just_pressed("interact"):
			player_animation.play("Idle")
			undock()
		return

	if not being_retracted and Game.should_retract():
		_start_retract(thrust_speed * retract_speed_mult, Game.OXYGEN_OUT_PENALTY)

	if being_retracted:
		global_position = global_position.move_toward(ship_position, _retract_speed * delta)
		velocity = Vector2.ZERO
		player_animation.play("Idle")
		_apply_retract_juice(delta)
		if global_position.distance_to(ship_position) < 12.0:
			_finish_dock()
		return

	var input_vec: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vec.length() > 0.0:
		velocity += input_vec * (thrust_speed + Game.thrust_speed_bonus) * delta
		if input_vec.x < 0.0:
			player_animation.flip_h = false
		elif input_vec.x > 0.0:
			player_animation.flip_h = true

	velocity *= damping
	move_and_slide()

	var to_ship: Vector2 = global_position - ship_position
	var dist: float = to_ship.length()
	if dist > Game.tether_length_max:
		var n: Vector2 = to_ship.normalized()
		global_position = ship_position + n * Game.tether_length_max
		var outward: float = velocity.dot(n)
		if outward > 0.0:
			velocity -= n * outward
		dist = Game.tether_length_max
	Game.update_tether(dist)
	_update_recall(delta, dist)

	if near_ship and Input.is_action_just_pressed("interact"):
		_finish_dock()
		return
		
	_update_target()
	
	var is_chiseling: bool = false
	if is_instance_valid(current_meteorite):
		if Input.is_action_pressed("chisel"):
			is_chiseling = true
			current_meteorite.chisel(delta, Game.chisel_strength)
		else:
			current_meteorite.cool_down(delta)
		if Input.is_action_just_pressed("interact"):
			if current_meteorite.collect():
				_set_target(null)
	else:
		current_meteorite = null

	if is_chiseling:
		player_animation.play("Chisel")
	elif input_vec.length() > 0.0:
		player_animation.play("Floating")
	else:
		player_animation.play("Idle")

	_apply_cartoon_juice(input_vec, is_chiseling, delta)

	if _cam_shake > 0.0:
		_cam_shake = maxf(0.0, _cam_shake - delta * 2.5)
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 14.0 * _cam_shake
	else:
		camera.offset = Vector2.ZERO


func set_ship_position(pos: Vector2) -> void:
	ship_position = pos


func undock() -> void:
	docked = false
	being_retracted = false
	_dock_penalty = 0.0
	_cam_shake = 0.0
	Game.start_outside()


func _get_normalized_base_scale() -> Vector2:
	# คำนวณอัตราส่วนภาพปัจจุบันเทียบกับ Idle เพื่อให้ขนาดตัวละครเท่ากันเสมอแม้ไฟล์ภาพใหญ่ไม่เท่ากัน
	if player_animation.sprite_frames:
		var anim_name: StringName = player_animation.animation
		var frame_idx: int = player_animation.frame
		var tex: Texture2D = player_animation.sprite_frames.get_frame_texture(anim_name, frame_idx)
		if tex and tex.get_height() > 0:
			var ratio: float = _reference_height / float(tex.get_height())
			return _editor_scale * ratio
	return _editor_scale


func _apply_cartoon_juice(input_vec: Vector2, is_chiseling: bool, delta: float) -> void:
	var norm_scale: Vector2 = _get_normalized_base_scale()
	var max_vel: float = thrust_speed * 0.35
	var vel_x_ratio: float = clampf(velocity.x / max_vel, -1.0, 1.0)
	var vel_y_ratio: float = clampf(velocity.y / max_vel, -1.0, 1.0)
	
	# 1. การหมุนและเอียงตัว (แยกชัดเจนระหว่างพุ่งขึ้น พุ่งลง และซ้าย-ขวา)
	var facing_sign: float = 1.0 if player_animation.flip_h else -1.0
	var horizontal_tilt: float = vel_x_ratio * max_tilt_deg
	# ตอนกดขึ้น (input_vec.y < 0) ตัวจะโน้มไปข้างหน้า ตอนกดลง (input_vec.y > 0) ตัวจะเอนหงายหลังต้านแรง
	var vertical_tilt: float = -input_vec.y * vertical_pitch_deg * facing_sign
	var zero_g_sway: float = sin(_juice_time * bob_frequency * 0.6) * 4.0
	
	var target_deg: float = horizontal_tilt + vertical_tilt + zero_g_sway
	player_animation.rotation = lerp_angle(player_animation.rotation, deg_to_rad(target_deg), tilt_smoothing * delta)
	
	# 2. การยืด-หด (Squash & Stretch) ตอนขึ้น vs ตอนลง
	var scale_mult := Vector2.ONE
	var target_speed_scale: float = 1.0
	
	if is_chiseling:
		scale_mult = Vector2(1.18, 0.85) if _hammer_down else Vector2(0.9, 1.12)
	elif input_vec.length() > 0.0:
		if input_vec.y < -0.1:
			# กำลังพุ่งขึ้น (UP): ยืดตัวยาวเพรียวชัดเจน + เร่งความเร็วเฟรมไอพ่น 2 เท่า
			var up_factor: float = maxf(absf(input_vec.y), absf(vel_y_ratio))
			scale_mult = Vector2(
				1.0 - (up_factor * stretch_amount * 0.65),
				1.0 + (up_factor * stretch_amount * 1.25)
			)
			target_speed_scale = 2.0
		elif input_vec.y > 0.1:
			# กำลังพุ่งลง (DOWN): กดตัวแบนป้อมออกด้านข้าง (Squash) + ชะลอเฟรมไอพ่นลง
			var down_factor: float = maxf(absf(input_vec.y), absf(vel_y_ratio))
			scale_mult = Vector2(
				1.0 + (down_factor * stretch_amount * 0.85),
				1.0 - (down_factor * stretch_amount * 0.6)
			)
			target_speed_scale = 0.5
		else:
			# บินซ้าย-ขวา
			var side_factor: float = maxf(absf(input_vec.x), absf(vel_x_ratio))
			scale_mult = Vector2(
				1.0 + (side_factor * stretch_amount * 0.35),
				1.0 - (side_factor * stretch_amount * 0.2)
			)
			target_speed_scale = 1.3
	else:
		# ลอยนิ่งๆ ในอวกาศ
		var breathe: float = sin(_juice_time * bob_frequency) * 0.05
		scale_mult = Vector2(1.0 - breathe, 1.0 + breathe)
		
	player_animation.scale = player_animation.scale.lerp(norm_scale * scale_mult, 15.0 * delta)
	player_animation.speed_scale = target_speed_scale
	
	# 3. ขยับตัวขึ้น-ลงตามคลื่น Zero-G + ขยับนำสายตาตามทิศทางขึ้น/ลง
	var bob_y: float = sin(_juice_time * bob_frequency) * bob_amplitude
	var vertical_lead_y: float = input_vec.y * 6.0
	var final_offset := Vector2(0.0, bob_y + vertical_lead_y)
	
	player_animation.position = player_animation.position.lerp(_base_sprite_pos + final_offset, 12.0 * delta)
	tools.position = tools.position.lerp(_base_tools_pos + final_offset * 0.8, 12.0 * delta)


func _apply_retract_juice(delta: float) -> void:
	var norm_scale: Vector2 = _get_normalized_base_scale()
	var dir_to_ship: Vector2 = (ship_position - global_position).normalized()
	player_animation.rotation = lerp_angle(player_animation.rotation, dir_to_ship.angle() + PI * 0.5, 15.0 * delta)
	player_animation.scale = player_animation.scale.lerp(norm_scale * Vector2(0.75, 1.3), 12.0 * delta)


func _on_debris_hit() -> void:
	_cam_shake = 1.0
	_recall_hold = 0.0
	player_animation.scale = _get_normalized_base_scale() * Vector2(1.4, 0.6)
	if Game.touch_mode:
		Input.vibrate_handheld(80)


func _finish_dock() -> void:
	_update_chisel_sfx(false)
	being_retracted = false
	docked = true
	_cam_shake = 0.0
	_set_target(null)
	global_position = ship_position
	
	player_animation.scale = _editor_scale
	player_animation.rotation = 0.0
	player_animation.speed_scale = 1.0
	player_animation.position = _base_sprite_pos
	tools.position = _base_tools_pos
	
	var penalty: float = _dock_penalty
	_dock_penalty = 0.0
	Game.dock(penalty)


func _start_retract(speed: float, penalty: float) -> void:
	_update_chisel_sfx(false)
	being_retracted = true
	_retract_speed = speed
	_dock_penalty = penalty
	_recall_hold = 0.0
	Game.recall_progress = 0.0


func _update_recall(delta: float, dist: float) -> void:
	if dist >= Game.RECALL_MIN_DISTANCE and Input.is_action_pressed("recall"):
		_recall_hold += delta
		Game.recall_progress = clampf(_recall_hold / Game.RECALL_HOLD_TIME, 0.0, 1.0)
		if _recall_hold >= Game.RECALL_HOLD_TIME:
			_start_retract(recall_speed, Game.RECALL_FEE)
	else:
		_recall_hold = 0.0
		Game.recall_progress = 0.0


func _on_area_entered(area: Area2D) -> void:
	var meteor: Node = area.get_parent()
	if meteor.has_method("chisel") and not meteorites_in_range.has(area):
		meteorites_in_range.append(area)


func _on_area_exited(area: Area2D) -> void:
	meteorites_in_range.erase(area)


func _update_target() -> void:
	meteorites_in_range = meteorites_in_range.filter(
		func(a: Area2D) -> bool: return is_instance_valid(a)
	)

	var nearest: Node2D = null
	var nearest_dist: float = INF
	for area: Area2D in meteorites_in_range:
		var meteor := area.get_parent() as Node2D
		if not is_instance_valid(meteor):
			continue
		var d: float = global_position.distance_to(meteor.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = meteor

	if nearest == null:
		if current_meteorite != null:
			_set_target(null)
		return

	if is_instance_valid(current_meteorite) and nearest != current_meteorite:
		var current_dist: float = global_position.distance_to(current_meteorite.global_position)
		if current_dist - nearest_dist < 20.0:
			return

	if nearest != current_meteorite:
		_set_target(nearest)


func _set_target(meteor: Node2D) -> void:
	_update_chisel_sfx(false)
	if is_instance_valid(current_meteorite) and current_meteorite != meteor:
		current_meteorite.set_targeted(false)
	current_meteorite = meteor


func _update_chisel_sfx(should_play: bool) -> void:
	if should_play:
		if not sfx_hammering.playing:
			sfx_hammering.play()
	else:
		if sfx_hammering.playing:
			sfx_hammering.stop()
