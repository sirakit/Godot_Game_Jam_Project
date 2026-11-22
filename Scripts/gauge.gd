@tool
class_name Gauge
extends Control

enum Style { BAR, TANK, ROPE }

@export var style: Style = Style.BAR:
	set(v):
		style = v
		queue_redraw()
@export var max_value: float = 100.0:
	set(v):
		max_value = v
		_refresh()
@export var value: float = 100.0:
	set(v):
		value = v
		_refresh()
@export var fill_color: Color = Color(0.37, 0.89, 1.0):
	set(v):
		fill_color = v
		queue_redraw()
@export var low_color: Color = Color(1.0, 0.3, 0.25)
@export_range(0.0, 1.0) var low_threshold: float = 0.25
@export_group("Images (optional)")
@export var under_texture: Texture2D
@export var fill_texture: Texture2D
@export var over_texture: Texture2D
@export_group("Skin scene: Spine / animation (optional)")
@export var skin_scene: PackedScene

var _skin: Node = null

func _ready() -> void:
	if skin_scene != null and not Engine.is_editor_hint():
		_skin = skin_scene.instantiate()
		add_child(_skin)
		if _skin is Node2D:
			(_skin as Node2D).position = size * 0.5
		_refresh()

func ratio() -> float:
	return clampf(value / maxf(max_value, 0.001), 0.0, 1.0)

func _refresh() -> void:
	queue_redraw()
	if _skin != null and _skin.has_method("set_ratio"):
		_skin.call("set_ratio", ratio())

func _draw() -> void:
	if _skin != null:
		return                                            # ซีน skin วาดเอง
	var r := Rect2(Vector2.ZERO, size)
	var t := ratio()
	var col := fill_color
	if t < low_threshold:
		col = fill_color.lerp(low_color, (low_threshold - t) / low_threshold)
	if under_texture != null or fill_texture != null:
		_draw_textured(r, t, col)
		return
	match style:
		Style.TANK:
			_draw_tank(r, t, col)
		Style.ROPE:
			_draw_rope(r, t, col)
		_:
			_draw_bar(r, t, col)

func _draw_textured(r: Rect2, t: float, col: Color) -> void:
	if under_texture != null:
		draw_texture_rect(under_texture, r, false)
	if fill_texture != null:
		var src := Rect2(Vector2.ZERO, Vector2(fill_texture.get_width() * t, fill_texture.get_height()))
		var dst := Rect2(r.position, Vector2(r.size.x * t, r.size.y))
		draw_texture_rect_region(fill_texture, dst, src, col)
	if over_texture != null:
		draw_texture_rect(over_texture, r, false)

func _draw_bar(r: Rect2, t: float, col: Color) -> void:
	draw_rect(r, Color(0.1, 0.12, 0.2, 0.9))
	draw_rect(Rect2(r.position, Vector2(r.size.x * t, r.size.y)), col)
	draw_rect(r, Color(1, 1, 1, 0.5), false, 2.0)

# ถังอากาศแนวนอน: ลำตัวแคปซูล + วาล์วซ้าย + สายรัด + แสงสะท้อน
func _draw_tank(r: Rect2, t: float, col: Color) -> void:
	var h := r.size.y
	var body := Rect2(h * 0.35, 0.0, r.size.x - h * 0.35, h)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(h * 0.5))
	sb.bg_color = Color(0.08, 0.1, 0.18, 0.95)
	sb.border_color = Color(0.75, 0.82, 0.9)
	sb.set_border_width_all(2)
	draw_style_box(sb, body)
	var inner := body.grow(-3.0)
	if inner.size.x * t > 1.0:
		var fb := StyleBoxFlat.new()
		fb.set_corner_radius_all(int(inner.size.y * 0.5))
		fb.bg_color = col
		draw_style_box(fb, Rect2(inner.position, Vector2(inner.size.x * t, inner.size.y)))
	for i in range(1, 4):
		var x := body.position.x + body.size.x * i / 4.0
		draw_line(Vector2(x, 3.0), Vector2(x, h - 3.0), Color(1, 1, 1, 0.18), 2.0)
	draw_line(Vector2(body.position.x + h * 0.5, h * 0.28), Vector2(body.end.x - h * 0.5, h * 0.28), Color(1, 1, 1, 0.3), 2.0)
	draw_rect(Rect2(0.0, h * 0.3, h * 0.35, h * 0.4), Color(0.7, 0.72, 0.78))
	draw_circle(Vector2(h * 0.17, h * 0.5), h * 0.22, Color(0.45, 0.48, 0.55))

# เชือก: ราง + เส้นเชือกถักทแยง + ตะขอที่ปลาย + จุดยึดที่ยาน
func _draw_rope(r: Rect2, t: float, col: Color) -> void:
	var h := r.size.y
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(h * 0.25))
	sb.bg_color = Color(0.08, 0.1, 0.18, 0.95)
	sb.border_color = Color(0.75, 0.82, 0.9, 0.8)
	sb.set_border_width_all(2)
	draw_style_box(sb, Rect2(0.0, h * 0.25, r.size.x, h * 0.5))
	var fw := (r.size.x - 4.0) * t
	if fw > 1.0:
		var fb := StyleBoxFlat.new()
		fb.set_corner_radius_all(int(h * 0.2))
		fb.bg_color = col
		draw_style_box(fb, Rect2(2.0, h * 0.3, fw, h * 0.4))
		var x := 6.0
		while x < fw - 4.0:
			draw_line(Vector2(x, h * 0.7), Vector2(x + h * 0.25, h * 0.3), Color(0, 0, 0, 0.3), 2.0)
			x += 9.0
		draw_arc(Vector2(2.0 + fw, h * 0.5), h * 0.28, 0.0, TAU, 20, Color.WHITE, 2.5)
	draw_circle(Vector2(h * 0.3, h * 0.5), h * 0.18, Color(0.6, 0.62, 0.7))
