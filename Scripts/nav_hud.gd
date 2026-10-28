class_name NavHud
extends CanvasLayer

const EDGE_MARGIN := 56.0

var _pad: Control
var _toast: Label
var _toast_tween: Tween
var _ship: Node2D
var _player: Node2D
var _max_zone: int = 0

func _ready() -> void:
	layer = 5
	_ship = get_node("../Ship")
	_player = get_node("../Player")

	_pad = Control.new()
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pad)
	_pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pad.draw.connect(_on_draw)

	_toast = Label.new()
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 26)
	_toast.add_theme_font_override("font", load("res://Assets/fonts/Black_Ops_One/BlackOpsOne-Regular.ttf"))
	_toast.modulate.a = 0.0
	add_child(_toast)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -300.0
	_toast.offset_right = 300.0
	_toast.offset_top = 96.0

func _process(_delta: float) -> void:
	if not Game.is_outside:
		_max_zone = 0
		_pad.queue_redraw()
		return
	var z := MeteoriteTiers.zone_of(_player.global_position.distance_to(_ship.global_position))
	if z > _max_zone:
		_max_zone = z
		_show_zone_toast(z)
	_pad.queue_redraw()

func _show_zone_toast(z: int) -> void:
	var r := MeteoriteTiers.tier_range(z)
	_toast.text = "ZONE %d   -   Tier %d to %d meteorites" % [z + 1, r.x, r.y]
	if _toast_tween != null:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.8).set_delay(1.6)

func _on_draw() -> void:
	if not Game.is_outside:
		return
	var vp := get_viewport().get_visible_rect().size
	var ship_screen: Vector2 = get_viewport().get_canvas_transform() * _ship.global_position
	if Rect2(Vector2.ZERO, vp).grow(-EDGE_MARGIN).has_point(ship_screen):
		return                                         # ยานอยู่ในจอ ไม่ต้องมีลูกศร

	var center := vp * 0.5
	var dir := (ship_screen - center).normalized()
	var tx := INF if absf(dir.x) < 0.0001 else (vp.x * 0.5 - EDGE_MARGIN) / absf(dir.x)
	var ty := INF if absf(dir.y) < 0.0001 else (vp.y * 0.5 - EDGE_MARGIN) / absf(dir.y)
	var p := center + dir * minf(tx, ty)
	var side := Vector2(-dir.y, dir.x)

	var near_limit := 1.0 - Game.tether_remaining / maxf(1.0, Game.tether_length_max)
	var col := Color(0.37, 0.89, 1.0, 0.9).lerp(Color(1.0, 0.3, 0.25, 0.95), clampf((near_limit - 0.6) / 0.4, 0.0, 1.0))
	_pad.draw_colored_polygon(PackedVector2Array([
		p + dir * 18.0, p - dir * 10.0 + side * 14.0, p - dir * 10.0 - side * 14.0]), col)

	var dist := _player.global_position.distance_to(_ship.global_position)
	_pad.draw_string(ThemeDB.fallback_font, p - dir * 34.0 + Vector2(-50.0, 6.0),
		"SHIP  %d m" % int(dist / 10.0), HORIZONTAL_ALIGNMENT_CENTER, 100.0, 14, col)
