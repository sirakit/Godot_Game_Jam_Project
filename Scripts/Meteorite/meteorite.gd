extends Node2D

const SKIN_PATH := "res://Scenes/meteorite_skins/tier_%02d.tscn"
const TIER_SPRITE_PATH: String = "res://Assets/sprites/meteorites/tier_%02d.png"
const BASE_ROCK_DISPLAY_SIZE: float = 112.0
const OVERDRIVE_MAX := 0.5        # โบนัสความเร็วตอกสูงสุดที่เส้นอันตราย
const SWEET_START := 0.45         # Overdrive เริ่มที่ 45% ของเส้นอันตราย
const VENT_WIDTH := 0.17          # หน้าต่าง VENT กว้าง 17% ของ heat_max ใต้เส้นอันตราย
const VENT_COOL := 25.0           # VENT สำเร็จ: ความร้อนลดทันที
const VENT_MIN_HOLD := 0.3        # ต้องค้างตอกอย่างน้อยเท่านี้ถึงนับเป็นจังหวะ
const JAM_RESUME := 0.5           # หลัง JAM ต้องเย็นลงถึง 50% ถึงตอกต่อได้
const JAM_PENALTY := 8.0          # JAM หักคุณภาพ
const GRIND_HEAT := 1.5           # เจาะไม่เข้า: ความร้อนเพิ่มสูงสุด +150%
const HINT_FONT: Font = preload("res://Assets/fonts/Black_Ops_One/BlackOpsOne-Regular.ttf")
const HINT_COLOR := Color(1.0, 0.95, 0.55)

@export_group("Artifact")
@export var rock_integrity_max: float = 30.0
@export var artifact_value: int = 10
@export var artifact_name: String = "Unknown Artifact"
@export var tier: int = 0
@export var rock_color: Color = Color(0.05, 0.067, 0.467, 0.8)

@export_group("Sprites")
@export var rock_texture: Texture2D
@export var rock_scale_mult: float = 1.0
@export var artifact_display_size: float = 64.0
@export var artifact_tint: Color = Color(0.4, 0.9, 1.0)

@export_group("Drift")
@export var drift_enabled: bool = true
@export var drift_radius: float = 40.0
@export var drift_speed: float = 1.0
@export var spin_speed: float = 0.3

var defense: float = 1.0
var rock_integrity: float = 30.0
var artifact_revealed: bool = false
var artifact_collected: bool = false
var artifact_health: float = 100.0
var heat: float = 0.0
var heat_max: float = 100.0
var heat_gain_rate: float = 40.0
var heat_cool_rate: float = 25.0
var heat_damage_threshold: float = 70.0
var damage_rate: float = 30.0

var _mining_grace: float = 0.0
var _hot: bool = false
var _home_position: Vector2 = Vector2.ZERO
var _drift_time: float = 0.0
var _shake: float = 0.0
var _rock_base_pos: Vector2 = Vector2.ZERO
var _artifact_final_scale: Vector2 = Vector2.ONE
var _ready_beacon_ring: Line2D = null
var _ready_sparkles: CPUParticles2D = null
var _collect_hint: Node2D = null

var _jammed: bool = false
var _hold_time: float = 0.0
var _was_mining: bool = false
var _clang_timer: float = 0.0
var vent_flash: float = 0.0       # > 0 = เพิ่ง VENT สำเร็จ (HUD อ่านไปกะพริบ)

var _skin: MeteoriteSkin = null
var _hit_timer: float = 0.0

@onready var visual: Node2D = $Visual
@onready var rock_shape: Polygon2D = $Visual/RockShape
@onready var rock_sprite: Sprite2D = $Visual/RockShape/Sprite2D
@onready var artifact_sprite: Sprite2D = $Visual/Artifact
@onready var extract_bar: ProgressBar = $ExtractBar
@onready var heat_bar: ProgressBar = $HeatBar
@onready var integrity_bar: ProgressBar = $IntegrityBar
@onready var hover_area: Area2D = $Area2D
@onready var info_label: Label = $InfoLabel


func _ready() -> void:
	add_to_group("meteorites")

	if tier <= 0:
		tier = _auto_tier()
	_apply_tier()

	rock_integrity = rock_integrity_max
	_home_position = position
	_rock_base_pos = rock_shape.position
	_apply_visuals()

	extract_bar.min_value = 0.0
	extract_bar.max_value = 1.0
	heat_bar.min_value = 0.0
	heat_bar.max_value = heat_max
	integrity_bar.min_value = 0.0
	integrity_bar.max_value = 100.0
	integrity_bar.value = 100.0
	_set_bars_visible(false)
	info_label.visible = false
	hover_area.mouse_entered.connect(_on_mouse_entered)
	hover_area.mouse_exited.connect(_on_mouse_exited)

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)
	
	var notifier := VisibleOnScreenNotifier2D.new()
	notifier.rect = Rect2(-180.0, -180.0, 360.0, 360.0)
	add_child(notifier)
	
	# ถ้าหินอยู่นอกจอกล้อง ให้หยุดวาดภาพและหยุดรัน _process ทันที (ลด Draw Calls ลง 90%)
	visual.visible = notifier.is_on_screen()
	set_process(notifier.is_on_screen())
	
	notifier.screen_entered.connect(func() -> void:
		visual.visible = true
		set_process(true)
	)
	notifier.screen_exited.connect(func() -> void:
		visual.visible = false
		set_process(false)
		_set_bars_visible(false)
		info_label.visible = false
	)
	
func _attach_skin() -> void:
	var path := SKIN_PATH % tier
	if not ResourceLoader.exists(path):
		return                                      # ยังไม่มี skin ของ tier นี้ = ใช้ภาพเดิม
	_skin = (load(path) as PackedScene).instantiate() as MeteoriteSkin
	if _skin == null:
		return
	visual.add_child(_skin)
	_skin.scale = Vector2.ONE * MeteoriteTiers.SIZE[clampi(tier, 1, 10) - 1]
	rock_shape.visible = false                      # ซ่อนภาพเดิม
	_skin.set_tier(tier)
	_skin.play_idle()

func _process(delta: float) -> void:
	if drift_enabled and not artifact_collected:
		_drift_time += delta * drift_speed
		position = _home_position + Vector2(
			sin(_drift_time * 1.3) * drift_radius,
			cos(_drift_time) * drift_radius
		)
	visual.rotation += spin_speed * delta

	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 8.0)
		rock_shape.position = _rock_base_pos + Vector2(randf_range(-2.5, 2.5), randf_range(-2.5, 2.5)) * _shake
	else:
		rock_shape.position = _rock_base_pos

	# เอฟเฟกต์แร่เต้นเป็นจังหวะและวงแหวนเรืองแสงตอนพร้อมให้กดเก็บ
	if artifact_revealed and not artifact_collected:
		var pulse: float = 1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.12
		artifact_sprite.scale = artifact_sprite.scale.lerp(_artifact_final_scale * pulse, 10.0 * delta)
		artifact_sprite.rotation -= spin_speed * 1.5 * delta
		if is_instance_valid(_ready_beacon_ring):
			_ready_beacon_ring.rotation += 1.8 * delta
			var ring_pulse: float = 0.85 + sin(Time.get_ticks_msec() * 0.01) * 0.2
			_ready_beacon_ring.scale = Vector2.ONE * ring_pulse


func _physics_process(delta: float) -> void:
	vent_flash = maxf(0.0, vent_flash - delta)
	if _jammed:                                    # JAM: ตอกไม่ได้ ระบายเร็ว 2 เท่า
		heat = maxf(0.0, heat - heat_cool_rate * 2.0 * delta)
		if heat <= heat_max * JAM_RESUME:
			_jammed = false
		_update_bars()
		return
	if _mining_grace > 0.0:
		_mining_grace -= delta
		_was_mining = true
		return
	if _was_mining:                                # เพิ่งปล่อยปุ่ม
		_was_mining = false
		_on_released()
	_hold_time = 0.0
	if heat > 0.0:
		heat = maxf(0.0, heat - heat_cool_rate * delta)
		_update_bars()


func _exit_tree() -> void:
	if _hot:
		Game.set_rock_hot(get_instance_id(), false)


func set_targeted(active: bool) -> void:
	if not active:
		_set_bars_visible(false)


func chisel(delta: float, strength: float) -> void:
	if artifact_collected or _jammed:
		return
	_mining_grace = 0.06
	_hold_time += delta
	_shake = 1.0

	var pierce := pierce_mult()
	if pierce < 0.02:                              # เจาะไม่เข้า: เสียงกระทบ + HUD ขึ้น CLANG
		_clang_timer -= delta
		if _clang_timer <= 0.0:
			_clang_timer = 0.25
			Game.clang.emit()
	var rate := heat_gain_rate * (1.0 + GRIND_HEAT * (1.0 - pierce))   # ยิ่งเจาะไม่เข้า ยิ่งเสียดสี ยิ่งร้อน

	var over := heat / heat_max > danger_ratio()
	if not artifact_revealed:
		rock_integrity -= strength * pierce * overdrive_mult() * 10.0 * delta
		heat = minf(heat_max, heat + rate * delta)
		if over:
			artifact_health = maxf(0.0, artifact_health - damage_rate * delta)
		if rock_integrity <= 0.0:
			reveal_artifact()
	else:
		heat = minf(heat_max, heat + rate * 1.5 * delta)
		if over:
			artifact_health = maxf(0.0, artifact_health - damage_rate * 1.5 * delta)

	if heat >= heat_max:
		_jam()
	_update_bars()

func reveal_artifact() -> void:
	artifact_revealed = true
	_shake = 2.8
	
	# 1. เปลือกหินแตกหดตัวลงและจางลงเพื่อให้แร่ข้างในเด่นเต็มตา
	var rock_tw: Tween = create_tween().set_parallel(true)
	rock_tw.tween_property(rock_shape, "color", Color(0.2, 0.2, 0.25, 0.35), 0.3)
	rock_tw.tween_property(rock_sprite, "modulate", Color(0.45, 0.45, 0.5, 0.35), 0.3)
	rock_tw.tween_property(rock_sprite, "scale", rock_sprite.scale * 0.72, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 2. แร่เด้งขยายตัวขึ้นมาพร้อมแฟลชสีขาวสว่าง
	artifact_sprite.visible = true
	artifact_sprite.scale = Vector2.ZERO
	var orig_modulate: Color = artifact_sprite.modulate
	artifact_sprite.modulate = Color(2.5, 2.5, 2.5, 1.0)
	
	var art_tw: Tween = create_tween().set_parallel(true)
	art_tw.tween_property(artifact_sprite, "scale", _artifact_final_scale * 1.25, 0.3) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	art_tw.tween_property(artifact_sprite, "modulate", orig_modulate, 0.35)
	
	# 3. สร้างเศษหินระเบิดกระจาย + ออร่าประกายดาวบอกว่ากดเก็บได้แล้ว
	_spawn_rock_break_burst()
	_create_collect_ready_aura()
	_create_collect_hint()
	_set_bars_visible(true)


func collect() -> bool:
	if artifact_revealed and not artifact_collected:
		artifact_collected = true
		_set_hot(false)
		_set_bars_visible(false)
		info_label.visible = false
		
		var quality: float = artifact_health / 100.0
		var final_value: int = int(artifact_value * maxf(0.1, quality))

		var is_perfect: bool = artifact_health >= 95.0
		if is_perfect:
			final_value = int(final_value * 1.5)

		Game.add_artifact({
			"name": artifact_name,
			"value": final_value,
			"tier": tier,
			"quality": int(artifact_health),
		})
		if is_perfect:
			Game.perfect_extraction.emit()

		_play_collect_animation(final_value, is_perfect)
		return true
	return false


func get_heat_ratio() -> float:
	return heat / heat_max



func _spawn_rock_break_burst() -> void:
	# ระเบิดเศษหินและฝุ่นควันออกรอบตัวตอนกะเทาะเปลือกหินแตก
	var burst := CPUParticles2D.new()
	burst.emitting = false
	burst.one_shot = true
	burst.amount = 24
	burst.lifetime = 0.65
	burst.explosiveness = 0.92
	burst.spread = 180.0
	burst.gravity = Vector2.ZERO
	burst.initial_velocity_min = 70.0 * rock_scale_mult
	burst.initial_velocity_max = 210.0 * rock_scale_mult
	burst.damping_min = 180.0
	burst.damping_max = 320.0
	burst.scale_amount_min = 4.0 * rock_scale_mult
	burst.scale_amount_max = 9.0 * rock_scale_mult
	
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.4, 1.1))
	curve.add_point(Vector2(1.0, 0.0))
	burst.scale_amount_curve = curve
	
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.95, 0.8, 1.0))
	grad.add_point(0.2, rock_color.lightened(0.35))
	grad.add_point(0.7, Color(0.45, 0.45, 0.5, 0.85))
	grad.set_color(1, Color(0.2, 0.2, 0.25, 0.0))
	burst.color_ramp = grad
	
	add_child(burst)
	burst.emitting = true
	burst.finished.connect(burst.queue_free)


func _create_collect_ready_aura() -> void:
	# สร้างวงแหวนเส้นประเรืองแสงและละอองดาวรอบแร่เพื่อดึงสายตาให้กดเก็บ
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	
	_ready_beacon_ring = Line2D.new()
	_ready_beacon_ring.width = 2.5
	_ready_beacon_ring.default_color = Color(artifact_tint.r, artifact_tint.g, artifact_tint.b, 0.75)
	_ready_beacon_ring.material = mat
	_ready_beacon_ring.z_index = -1
	
	var radius: float = artifact_display_size * 0.65
	var points_count: int = 24
	for i: int in range(points_count + 1):
		var angle: float = (float(i) / float(points_count)) * TAU
		_ready_beacon_ring.add_point(Vector2(cos(angle), sin(angle)) * radius)
	visual.add_child(_ready_beacon_ring)
	
	# ละอองแสงระยิบระยับลอยออกจากแร่
	_ready_sparkles = CPUParticles2D.new()
	_ready_sparkles.amount = 12
	_ready_sparkles.lifetime = 0.8
	_ready_sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_ready_sparkles.emission_sphere_radius = radius * 0.8
	_ready_sparkles.spread = 180.0
	_ready_sparkles.gravity = Vector2.ZERO
	_ready_sparkles.initial_velocity_min = 10.0
	_ready_sparkles.initial_velocity_max = 35.0
	_ready_sparkles.scale_amount_min = 2.0
	_ready_sparkles.scale_amount_max = 4.5
	_ready_sparkles.material = mat
	
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 0.9))
	grad.add_point(0.5, Color(artifact_tint.r, artifact_tint.g, artifact_tint.b, 0.8))
	grad.set_color(1, Color(artifact_tint.r, artifact_tint.g, artifact_tint.b, 0.0))
	_ready_sparkles.color_ramp = grad
	visual.add_child(_ready_sparkles)


func _create_collect_hint() -> void:
	# "COLLECT" text with a bobbing down arrow, floating right above the artifact.
	# Child of the meteorite (not of Visual) so it does not spin with the rock.
	if is_instance_valid(_collect_hint):
		return
	var base_y: float = -(artifact_display_size * 0.5 + 40.0)
	_collect_hint = Node2D.new()
	_collect_hint.z_index = 15
	_collect_hint.position = Vector2(0.0, base_y)

	var label := Label.new()
	label.text = "COLLECT"
	label.size = Vector2(160.0, 24.0)
	label.position = Vector2(-80.0, -28.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", HINT_FONT)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", HINT_COLOR)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	_collect_hint.add_child(label)

	var arrow := Polygon2D.new()
	arrow.polygon = PackedVector2Array([Vector2(-9.0, -2.0), Vector2(9.0, -2.0), Vector2(0.0, 12.0)])
	arrow.color = HINT_COLOR
	_collect_hint.add_child(arrow)

	_collect_hint.modulate.a = 0.0
	add_child(_collect_hint)

	var fade: Tween = _collect_hint.create_tween()
	fade.tween_property(_collect_hint, "modulate:a", 1.0, 0.25)

	var bob: Tween = _collect_hint.create_tween().set_loops()
	bob.tween_property(_collect_hint, "position:y", base_y + 7.0, 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(_collect_hint, "position:y", base_y, 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _play_collect_animation(final_value: int, is_perfect: bool) -> void:
	# ปิดการตรวจจับชนแล้วดูดตัวแร่วิ่งเข้าหาตัวผู้เล่นพร้อมข้อความลอย
	hover_area.set_deferred("monitoring", false)
	hover_area.set_deferred("monitorable", false)
	if is_instance_valid(_collect_hint):
		_collect_hint.queue_free()
	if is_instance_valid(_ready_beacon_ring):
		_ready_beacon_ring.queue_free()
	if is_instance_valid(_ready_sparkles):
		_ready_sparkles.emitting = false
		
	_spawn_floating_reward_text(final_value, is_perfect)
	
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var target_global_pos: Vector2 = player.global_position if is_instance_valid(player) else global_position
	
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(rock_shape, "modulate:a", 0.0, 0.15)
	tw.tween_property(self, "global_position", target_global_pos, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(artifact_sprite, "scale", Vector2.ZERO, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)


func _spawn_floating_reward_text(final_value: int, is_perfect: bool) -> void:
	# สร้างตัวเลขราคาลอยขึ้นในฉากหลักเพื่อให้แสดงผลต่อจนจบแม้หินถูกลบไปแล้ว
	var popup := Label.new()
	popup.top_level = true
	popup.z_index = 20
	popup.global_position = global_position + Vector2(-40.0, -35.0)
	popup.text = ("PERFECT! + %d pt" % final_value) if is_perfect else ("+ %d pt" % final_value)
	popup.modulate = Color(1.0, 0.9, 0.25) if is_perfect else Color(0.45, 1.0, 0.65)
	
	var scene_root: Node = get_tree().current_scene
	if is_instance_valid(scene_root):
		scene_root.add_child(popup)
		var tw: Tween = popup.create_tween().set_parallel(true)
		tw.tween_property(popup, "global_position:y", popup.global_position.y - 45.0, 0.85) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(popup, "modulate:a", 0.0, 0.85).set_delay(0.25)
		tw.chain().tween_callback(popup.queue_free)


func _auto_tier() -> int:
	var ship := get_node_or_null("../../Ship") as Node2D
	if ship == null:
		return 1
	return MeteoriteTiers.pick_tier(MeteoriteTiers.zone_of(global_position.distance_to(ship.global_position)))


func _apply_tier() -> void:
	var i: int = clampi(tier, 1, 10) - 1
	rock_integrity_max = MeteoriteTiers.HP[i]
	defense = MeteoriteTiers.DEFENSE[i]
	artifact_value = MeteoriteTiers.VALUE[i]
	artifact_name = MeteoriteTiers.artifact_name(tier)
	heat_gain_rate = 40.0 * MeteoriteTiers.HEAT[i]
	rock_color = MeteoriteTiers.TINTS[i]
	artifact_tint = MeteoriteTiers.TINTS[i].lightened(0.3)
	rock_scale_mult = MeteoriteTiers.SIZE[i]
	hover_area.scale = Vector2.ONE * MeteoriteTiers.SIZE[i]

	var sprite_path: String = TIER_SPRITE_PATH % tier
	if ResourceLoader.exists(sprite_path):
		rock_texture = load(sprite_path) as Texture2D

	drift_radius = 30.0 + 5.0 * tier
	drift_speed = 0.8 + 0.1 * tier
	spin_speed = 0.2 + 0.04 * tier


func _apply_visuals() -> void:
	rock_shape.color = rock_color
	if rock_texture != null:
		rock_sprite.texture = rock_texture

	# ปรับสเกลจากขนาดพิกเซลจริงของรูป เพื่อป้องกันปัญหาหินบางรูปเล็กหรือใหญ่เกินไป
	if rock_sprite.texture != null:
		var longest_rock: float = float(maxi(rock_sprite.texture.get_width(), rock_sprite.texture.get_height()))
		if longest_rock > 0.0:
			rock_sprite.scale = Vector2.ONE * ((BASE_ROCK_DISPLAY_SIZE / longest_rock) * rock_scale_mult)

	artifact_sprite.visible = false
	var tex: Texture2D = ArtifactDB.get_texture(artifact_name)
	if tex != null:
		artifact_sprite.texture = tex
		artifact_sprite.modulate = Color.WHITE
	else:
		tex = _make_placeholder_orb()
		artifact_sprite.texture = tex
		artifact_sprite.modulate = artifact_tint

	var longest_art: float = float(maxi(tex.get_width(), tex.get_height()))
	_artifact_final_scale = Vector2.ONE * (artifact_display_size / longest_art)
	artifact_sprite.scale = _artifact_final_scale

func _make_placeholder_orb() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])        # solid core, then a short soft edge
	g.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


func _set_bars_visible(v: bool) -> void:
	extract_bar.visible = v and not artifact_revealed
	heat_bar.visible = v
	integrity_bar.visible = v and artifact_revealed


func _update_bars() -> void:
	_set_hot(heat > danger_ratio() * heat_max and _mining_grace > 0.0)
	if not artifact_revealed:                       # รัศมีรอบหินเรืองส้มแดงตามความร้อน
		rock_shape.color = rock_color.lerp(Color(1.0, 0.35, 0.1, 0.9), clampf(heat / heat_max, 0.0, 1.0))
	queue_redraw()                                  # วงแหวนความคืบหน้า
	if info_label.visible:
		_refresh_info_label()


func _on_mouse_entered() -> void:
	_refresh_info_label()
	info_label.visible = true


func _on_mouse_exited() -> void:
	info_label.visible = false


func _refresh_info_label() -> void:
	var lines: Array[String] = []
	if not artifact_revealed:
		lines.append("Tier %d Meteorite" % tier)
		lines.append("Integrity: %d%%" % int(100.0 - (rock_integrity / rock_integrity_max) * 100.0))
	else:
		lines.append("Tier %d - %s" % [tier, artifact_name])
		lines.append("Quality so far: %d%%" % int(artifact_health))
	var mult := pierce_mult()
	if mult >= 0.999:
		lines.append("[OK] DEF %.1f - Drill pierces fully" % defense)
	elif mult < 0.02:
		lines.append("[X] DEF %.1f - CLANG! need Drill %.1f+" % [defense, MeteoriteTiers.drill_to_scratch(tier)])
	else:
		lines.append("[!] DEF %.1f - pierce %d%% (full at Drill %.1f)" % [defense, int(mult * 100.0), defense])
	info_label.text = "\n".join(lines)


func _set_hot(on: bool) -> void:
	if on != _hot:
		_hot = on
		Game.set_rock_hot(get_instance_id(), on) 

func danger_ratio() -> float:
	return heat_damage_threshold * (0.6 if artifact_revealed else 1.0) / heat_max

func overdrive_mult() -> float:
	var d := danger_ratio()
	return 1.0 + OVERDRIVE_MAX * smoothstep(d * SWEET_START, d, heat / heat_max)

func pierce_mult() -> float:
	return MeteoriteTiers.defense_multiplier(tier, Game.drill_strength)

func extract_ratio() -> float:
	return clampf(1.0 - rock_integrity / rock_integrity_max, 0.0, 1.0)

func is_jammed() -> bool:
	return _jammed

func _jam() -> void:
	_jammed = true
	_mining_grace = 0.0
	artifact_health = maxf(0.0, artifact_health - JAM_PENALTY)
	Game.rock_jammed.emit()

func _on_released() -> void:
	var ratio := heat / heat_max
	var d := danger_ratio()
	if _hold_time >= VENT_MIN_HOLD and ratio >= d - VENT_WIDTH and ratio < d:
		heat = maxf(0.0, heat - VENT_COOL)          # VENT! ปล่อยปุ่มตรงหน้าต่างพอดี
		vent_flash = 0.6
		Game.vented.emit()

func _draw() -> void:
	var progress := extract_ratio()
	if artifact_collected or artifact_revealed or progress <= 0.01:
		return
	var r : float = 62.0 * MeteoriteTiers.SIZE[clampi(tier, 1, 10) - 1]
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(1, 1, 1, 0.15), 4.0)
	draw_arc(Vector2.ZERO, r, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, Color(1, 1, 1, 0.8), 4.0)
