## res://Scripts/nav_hud.gd
class_name NavHud
extends CanvasLayer
## แสดงลูกศรชี้ตำแหน่งยานและแจ้งเตือนโซน รุ่นประหยัดพลังงาน (ไม่สั่ง queue_redraw ทุกเฟรม)

const EDGE_MARGIN := 56.0
const FONT_PATH := "res://Assets/fonts/Black_Ops_One/BlackOpsOne-Regular.ttf"

var _pad: Control
var _toast: Label
var _recall_toast: Label
var _toast_tween: Tween
var _recall_tween: Tween
var _ship: Node2D
var _player: Node2D
var _max_zone: int = 0
var _recall_notified: bool = false
var _redraw_timer: float = 0.0
var _was_drawing_indicator: bool = false


func _ready() -> void:
	layer = 5
	_ship = get_node("../Ship") as Node2D
	_player = get_node("../Player") as Node2D

	_pad = Control.new()
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pad)
	_pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pad.draw.connect(_on_draw)

	var custom_font := load(FONT_PATH) as Font

	_toast = Label.new()
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 26)
	if custom_font:
		_toast.add_theme_font_override("font", custom_font)
	_toast.modulate.a = 0.0
	add_child(_toast)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -350.0
	_toast.offset_right = 350.0
	_toast.offset_top = 150.0

	_recall_toast = Label.new()
	_recall_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_recall_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_recall_toast.add_theme_font_size_override("font_size", 20)
	if custom_font:
		_recall_toast.add_theme_font_override("font", custom_font)
	_recall_toast.modulate = Color(0.35, 1.0, 0.75, 0.0)
	add_child(_recall_toast)
	_recall_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_recall_toast.offset_left = -350.0
	_recall_toast.offset_right = 350.0
	_recall_toast.offset_top = 192.0


func _process(delta: float) -> void:
	if not Game.is_outside:
		_max_zone = 0
		_recall_notified = false
		if _was_drawing_indicator:
			_was_drawing_indicator = false
			_pad.queue_redraw()
		return

	# จำกัดการเช็คและวาดลูกศรเพียง 20 ครั้งต่อวินาที แทนการวาดใหม่ทุกเฟรม
	_redraw_timer += delta
	if _redraw_timer < 0.05:
		return
	_redraw_timer = 0.0

	var dist: float = _player.global_position.distance_to(_ship.global_position)
	var z: int = MeteoriteTiers.zone_of(dist)
	
	if z > _max_zone:
		_max_zone = z
		_show_zone_toast(z)

	if not _recall_notified and (z >= 1 or dist >= Game.RECALL_MIN_DISTANCE):
		_recall_notified = true
		_show_recall_unlocked_toast()

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var ship_screen: Vector2 = get_viewport().get_canvas_transform() * _ship.global_position
	var ship_on_screen: bool = Rect2(Vector2.ZERO, vp).grow(-EDGE_MARGIN).has_point(ship_screen)
	
	# ถ้าสถานีอวกาศอยู่ในจออยู่แล้ว ไม่ต้องสั่งวาดหน้าจอใหม่เลย
	if not ship_on_screen or _was_drawing_indicator:
		_was_drawing_indicator = not ship_on_screen
		_pad.queue_redraw()


func _show_zone_toast(z: int) -> void:
	var r: Vector2i = MeteoriteTiers.tier_range(z)
	_toast.text = "ZONE %d   -   Tier %d to %d meteorites" % [z + 1, r.x, r.y]
	if _toast_tween != null:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.8).set_delay(1.6)


func _show_recall_unlocked_toast() -> void:
	_recall_toast.text = "[ RECALL UNLOCKED ]  -  Hold Recall to return to ship"
	if _recall_tween != null:
		_recall_tween.kill()
		
	_recall_toast.pivot_offset = _recall_toast.size * 0.5
	_recall_toast.scale = Vector2(0.75, 1.25)
	_recall_toast.modulate.a = 1.0
	
	_recall_tween = create_tween().set_parallel(true)
	_recall_tween.tween_property(_recall_toast, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_recall_tween.tween_property(_recall_toast, "modulate:a", 0.0, 0.9).set_delay(2.6)


func _on_draw() -> void:
	if not Game.is_outside or not _was_drawing_indicator:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var ship_screen: Vector2 = get_viewport().get_canvas_transform() * _ship.global_position

	var center: Vector2 = vp * 0.5
	var dir: Vector2 = (ship_screen - center).normalized()
	var tx: float = INF if absf(dir.x) < 0.0001 else (vp.x * 0.5 - EDGE_MARGIN) / absf(dir.x)
	var ty: float = INF if absf(dir.y) < 0.0001 else (vp.y * 0.5 - EDGE_MARGIN) / absf(dir.y)
	var p: Vector2 = center + dir * minf(tx, ty)
	var side := Vector2(-dir.y, dir.x)

	var near_limit: float = 1.0 - Game.tether_remaining / maxf(1.0, Game.tether_length_max)
	var col: Color = Color(0.37, 0.89, 1.0, 0.9).lerp(
		Color(1.0, 0.3, 0.25, 0.95),
		clampf((near_limit - 0.6) / 0.4, 0.0, 1.0)
	)
	_pad.draw_colored_polygon(
		PackedVector2Array([
			p + dir * 18.0,
			p - dir * 10.0 + side * 14.0,
			p - dir * 10.0 - side * 14.0
		]),
		col
	)

	var dist: float = _player.global_position.distance_to(_ship.global_position)
	var status_suffix: String = " [RECALL READY]" if dist >= Game.RECALL_MIN_DISTANCE else ""
	_pad.draw_string(
		ThemeDB.fallback_font,
		p - dir * 34.0 + Vector2(-80.0, 6.0),
		"SHIP  %d m%s" % [int(dist / 10.0), status_suffix],
		HORIZONTAL_ALIGNMENT_CENTER,
		160.0,
		14,
		col
	)
