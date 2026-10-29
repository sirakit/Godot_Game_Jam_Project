extends Node2D

const HEAVY_ROCK_PATH := "res://Assets/sprites/meteorites/meteorite_2.png"
const HEAVY_ROCK_FIX := 1.5        # ตัวหินใน meteorite_2.png เล็กกว่า meteorite_1 อยู่ ~1.5 เท่า (185 px vs 277 px)

@export_group("Artifact")
@export var rock_integrity_max: float = 30.0
@export var artifact_value: int = 10
@export var artifact_name: String = "Unknown Artifact"
@export var tier: int = 0          # 0 = ให้เกมเลือกจากระยะห่างยาน (หินที่วางมือในซีน)
var defense: float = 1.0
@export var rock_color: Color = Color(0.05, 0.067, 0.467, 0.8)

@export_group("Sprites")
@export var rock_texture: Texture2D            # ว่าง = ใช้ภาพหินเดิมใน meteorite.tscn
@export var rock_scale_mult: float = 1.0       # ปรับขนาดภาพหิน (V2 ใช้ 1.7 ดูหัวข้อ B.3)
@export var artifact_display_size: float = 64.0   # แร่แสดงด้านยาวสุดกี่พิกเซล ไม่ว่าไฟล์จะใหญ่แค่ไหน
@export var artifact_tint: Color = Color(0.4, 0.9, 1.0)   # ใช้กับลูกแก้วชั่วคราวเท่านั้น

@export_group("Drift")
@export var drift_enabled: bool = true
@export var drift_radius: float = 40.0
@export var drift_speed: float = 1.0
@export var spin_speed: float = 0.3

var rock_integrity: float
var artifact_revealed: bool = false
var artifact_collected: bool = false
var artifact_health: float = 100.0

var is_mining: bool = false
var heat: float = 0.0
var heat_max: float = 100.0
var heat_gain_rate: float = 40.0
var heat_cool_rate: float = 25.0
var heat_damage_threshold: float = 70.0
var damage_rate: float = 30.0

var _home_position: Vector2
var _drift_time: float = 0.0
var _shake: float = 0.0
var _rock_base_pos: Vector2
var _artifact_final_scale: Vector2 = Vector2.ONE

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
	add_to_group("meteorites")                   # ให้ spawner นับ/เช็กระยะได้

	# หินที่วางมือในซีนไม่ได้ตั้งชื่อ -> สุ่มชื่อ common ให้ (แก้ต้นเหตุของบั๊ก Collection log)
	if tier <= 0:
		tier = _auto_tier()
	_apply_tier()

	rock_integrity = rock_integrity_max
	_home_position = position
	_rock_base_pos = rock_shape.position         # จำตำแหน่งตั้งต้น (เดิม shake รีเซ็ตเป็น 0,0 ทำให้ภาพกระตุกเลื่อน)
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

	# เกิดแบบค่อยๆ ชัด ไม่ให้หินโผล่พรวดกลางจอ
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)
	
func _auto_tier() -> int:
	var ship := get_node_or_null("../../Ship") as Node2D
	if ship == null:
		return 1
	return MeteoriteTiers.pick_tier(MeteoriteTiers.zone_of(global_position.distance_to(ship.global_position)))

func _apply_tier() -> void:
	var i := clampi(tier, 1, 10) - 1
	rock_integrity_max = MeteoriteTiers.HP[i]
	defense = MeteoriteTiers.DEFENSE[i]
	artifact_value = MeteoriteTiers.VALUE[i]
	artifact_name = MeteoriteTiers.artifact_name(tier)
	heat_gain_rate = 40.0 * MeteoriteTiers.HEAT[i]
	rock_color = MeteoriteTiers.TINTS[i]
	artifact_tint = MeteoriteTiers.TINTS[i].lightened(0.3)
	rock_scale_mult = MeteoriteTiers.SIZE[i]
	hover_area.scale = Vector2.ONE * MeteoriteTiers.SIZE[i]       # วงตรวจจับโตตามขนาดหิน
	if tier >= 7:                                                 # tier 7-10 (drill-able) ใช้ภาพหินอีกแบบ
		rock_scale_mult *= HEAVY_ROCK_FIX
		if ResourceLoader.exists(HEAVY_ROCK_PATH):
			rock_texture = load(HEAVY_ROCK_PATH) as Texture2D
	drift_radius = 30.0 + 5.0 * tier                              # tier สูง ลอยกว้างและเร็วขึ้น เล็งยากขึ้น
	drift_speed = 0.8 + 0.1 * tier
	spin_speed = 0.2 + 0.04 * tier

func _apply_visuals() -> void:
	rock_shape.color = rock_color
	if rock_texture != null:
		rock_sprite.texture = rock_texture
	rock_sprite.scale *= rock_scale_mult

	artifact_sprite.visible = false
	var tex: Texture2D = ArtifactDB.get_texture(artifact_name)
	if tex != null:
		artifact_sprite.texture = tex
		artifact_sprite.modulate = Color.WHITE       # ไม่ทับสีงานของศิลปิน
	else:
		tex = _make_placeholder_orb()
		artifact_sprite.texture = tex
		artifact_sprite.modulate = artifact_tint     # ลูกแก้วชั่วคราว (ม่วงสำหรับ V2)
	var longest := float(maxi(tex.get_width(), tex.get_height()))
	_artifact_final_scale = Vector2.ONE * (artifact_display_size / longest)
	artifact_sprite.scale = _artifact_final_scale

func _make_placeholder_orb() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t

func _process(delta: float) -> void:
	if drift_enabled:
		_drift_time += delta * drift_speed
		position = _home_position + Vector2(
			sin(_drift_time * 1.3) * drift_radius,
			cos(_drift_time) * drift_radius
		)
	visual.rotation += spin_speed * delta        # หมุนเฉพาะภาพ ป้ายกับบาร์ไม่หมุนตาม

	if not is_mining and heat > 0.0:
		heat = maxf(0.0, heat - heat_cool_rate * delta)
		_update_bars()

		if heat <= 0.0 and not artifact_revealed:
				_set_bars_visible(false)
				
	if _shake > 0.0:
		_shake = max(0.0, _shake - delta * 8.0)
		rock_shape.position = _rock_base_pos + Vector2(randf_range(-2, 2), randf_range(-2, 2)) * _shake
	else:
		rock_shape.position = _rock_base_pos

func _set_bars_visible(v: bool) -> void:
	extract_bar.visible = v and not artifact_revealed
	heat_bar.visible = v
	integrity_bar.visible = v and artifact_revealed

func set_targeted(active: bool) -> void:
	if not active:
		_set_bars_visible(false)

func chisel(delta: float, strength: float) -> void:
	if artifact_collected:
		return
	
	is_mining = true
	_shake = 1.0
	_set_bars_visible(true)

	var mult := MeteoriteTiers.defense_multiplier(tier, Game.drill_strength)
	var effective := strength * mult
	extract_bar.modulate = Color.WHITE if mult >= 0.999 else Color(1.0, 0.4, 0.4)

	if not artifact_revealed:
		rock_integrity -= effective * 10.0 * delta
		extract_bar.value = 1.0 - (rock_integrity / rock_integrity_max)
		heat = min(heat_max, heat + heat_gain_rate * delta)
		if heat > heat_damage_threshold:
			artifact_health = max(0.0, artifact_health - damage_rate * delta)
		if rock_integrity <= 0.0:
			reveal_artifact()
	else:
		heat = min(heat_max, heat + heat_gain_rate * 1.5 * delta)
		if heat > heat_damage_threshold * 0.6:
			artifact_health = max(0.0, artifact_health - damage_rate * 1.5 * delta)

	_update_bars()

func cool_down(delta: float) -> void:
	heat = max(0.0, heat - heat_cool_rate * delta)
	_update_bars()
	
	if heat <= 0.0 and not artifact_revealed:
		_set_bars_visible(false)

func _update_bars() -> void:
	heat_bar.value = heat
	integrity_bar.value = artifact_health
	var danger := heat_damage_threshold if not artifact_revealed else heat_damage_threshold * 0.6
	heat_bar.modulate = Color(1.0, 0.25, 0.15) if heat > danger else Color(1.0, 0.65, 0.2)
	integrity_bar.modulate = Color(1.0, 0.3, 0.3) if artifact_health < 50.0 else Color(0.4, 0.9, 1.0)
	if info_label.visible:
		_refresh_info_label()

func reveal_artifact() -> void:
	artifact_revealed = true
	rock_shape.color = Color(0.25, 0.25, 0.25)
	rock_sprite.modulate = Color(0.55, 0.55, 0.55)   # หินหม่นลง ให้แร่เด่นขึ้น
	artifact_sprite.visible = true
	artifact_sprite.scale = Vector2.ZERO             # แร่เด้งขึ้นมา
	var tw := create_tween()
	tw.tween_property(artifact_sprite, "scale", _artifact_final_scale, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_set_bars_visible(true)

func get_heat_ratio() -> float:
	return heat / heat_max

func collect() -> bool:
	if artifact_revealed and not artifact_collected:
		artifact_collected = true
		var quality: float = artifact_health / 100.0
		var final_value: int = int(artifact_value * max(0.1, quality))

		var is_perfect := artifact_health >= 95.0
		if is_perfect:
			final_value = int(final_value * 1.5)

		Game.add_artifact({"name": artifact_name, "value": final_value})
		if is_perfect:
			Game.perfect_extraction.emit()

		queue_free()
		return true
	return false

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
	var mult := MeteoriteTiers.defense_multiplier(tier, Game.drill_strength)
	if mult >= 0.999:
		lines.append("[OK] DEF %.1f - your Drill is enough" % defense)
	else:
		lines.append("[!] DEF %.1f - Drill %d: mining at %d%% speed" % [defense, int(Game.drill_strength), int(mult * 100.0)])
	info_label.text = "\n".join(lines)
