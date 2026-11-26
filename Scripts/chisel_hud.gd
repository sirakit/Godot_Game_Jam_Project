class_name ChiselHud
extends Control

const W := 300.0
const BAR_H := 22.0
const GAP := 10.0
const HOLD_AFTER_LOSE := 1.5

var _player: Node
var _rock: Node2D = null
var _lost_timer: float = 0.0
var _gradient: GradientTexture2D
var _grad_danger: float = -1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player = get_tree().get_first_node_in_group("player")

# ไล่สีให้ "แดง" เริ่มตรงเส้นอันตรายพอดี (เส้นอยู่ 70% ก่อนแร่โผล่ และ 42% หลังแร่โผล่ จึงสร้างใหม่เมื่อค่าเปลี่ยน)
func _make_gradient(d: float) -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, d * 0.75, d, 1.0])
	g.colors = PackedColorArray([
		Color(1.0, 0.85, 0.3),      # เหลือง: ปลอดภัย
		Color(1.0, 0.6, 0.2),       # ส้ม: ใกล้เส้น
		Color(0.95, 0.15, 0.1),     # แดง: เริ่มที่เส้นอันตราย
		Color(0.6, 0.05, 0.05),     # แดงเข้ม: ใกล้ JAM
	])
	_gradient = GradientTexture2D.new()
	_gradient.gradient = g
	_gradient.width = 256
	_gradient.height = 8
	_gradient.fill_from = Vector2(0.0, 0.0)
	_gradient.fill_to = Vector2(1.0, 0.0)

func _process(delta: float) -> void:
	var target: Node2D = null
	if is_instance_valid(_player) and not _player.docked and is_instance_valid(_player.current_meteorite):
		target = _player.current_meteorite
	if target != null:
		_rock = target
		_lost_timer = HOLD_AFTER_LOSE
	elif _lost_timer > 0.0:
		_lost_timer -= delta
	if not is_instance_valid(_rock) or _rock.artifact_collected or _lost_timer <= 0.0:
		_rock = null
	visible = _rock != null
	if visible:
		queue_redraw()

func _draw() -> void:
	if _rock == null:
		return
	var font := get_theme_default_font()
	var tier: int = _rock.tier
	var pierce: float = _rock.pierce_mult()

	var head := "TIER %d   PIERCE 100%%" % tier
	var head_col := Color(1, 1, 1, 0.9)
	if pierce < 0.02:
		head = "TIER %d   CLANG!  need Drill %.1f+" % [tier, MeteoriteTiers.drill_to_scratch(tier)]
		head_col = Color(1.0, 0.35, 0.3)
	elif pierce < 0.999:
		head = "TIER %d   PIERCE %d%%  (full at Drill %.1f)" % [tier, int(pierce * 100.0), MeteoriteTiers.drill_for_full(tier)]
		head_col = Color(1.0, 0.75, 0.3)
	draw_string(font, Vector2(0.0, 14.0), head, HORIZONTAL_ALIGNMENT_LEFT, W + 200.0, 14, head_col)

	var y := 22.0
	var ratio: float
	var label: String
	var fill: Color
	if _rock.artifact_revealed:
		ratio = _rock.artifact_health / 100.0
		label = "ARTIFACT  %d%%" % int(_rock.artifact_health)
		fill = Color(0.4, 0.9, 1.0) if _rock.artifact_health >= 50.0 else Color(1.0, 0.3, 0.3)
	else:
		ratio = _rock.extract_ratio()
		label = "EXTRACT  %d%%" % int(ratio * 100.0)
		fill = Color(0.85, 0.88, 0.95)
	_draw_bar(Rect2(0.0, y, W, BAR_H), ratio, fill, label, font)
	y += BAR_H + GAP
	_draw_heat(Rect2(0.0, y, W, BAR_H), font)

func _draw_bar(r: Rect2, ratio: float, fill: Color, text: String, font: Font) -> void:
	draw_rect(r, Color(0.12, 0.14, 0.2, 0.9))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(ratio, 0.0, 1.0), r.size.y)), fill)
	draw_rect(r, Color(1, 1, 1, 0.45), false, 2.0)
	var text_col := Color(0.05, 0.07, 0.12) if ratio > 0.45 else Color.WHITE
	draw_string(font, r.position + Vector2(8.0, r.size.y - 6.0), text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16.0, 14, text_col)

# แถบความร้อนแบบเรียบ: ไล่สีเหลือง → แดง + เส้นอันตราย + โซนแดงจางหลังเส้น ไม่มี COLD / OVERDRIVE / ช่องเขียว
func _draw_heat(r: Rect2, font: Font) -> void:
	var heat_r: float = clampf(_rock.heat / _rock.heat_max, 0.0, 1.0)
	var d: float = _rock.danger_ratio()
	if absf(d - _grad_danger) > 0.001:
		_make_gradient(d)
		_grad_danger = d

	var dark := Color(0.12, 0.14, 0.2, 0.92)
	draw_rect(r, dark)
	draw_texture_rect(_gradient, r, false)
	draw_rect(Rect2(r.position.x + r.size.x * heat_r, r.position.y, r.size.x * (1.0 - heat_r), r.size.y), dark)

	var dx := r.position.x + r.size.x * d
	draw_rect(Rect2(dx, r.position.y, r.end.x - dx, r.size.y), Color(0.9, 0.1, 0.1, 0.22))     # โซนอันตราย โชว์ตลอด
	draw_line(Vector2(dx, r.position.y - 5.0), Vector2(dx, r.end.y + 4.0), Color.WHITE, 3.0)   # เส้นอันตราย

	var hot := heat_r > d
	draw_rect(r, Color(1.0, 0.3, 0.25, 0.95) if hot else Color(1, 1, 1, 0.45), false, 2.0)

	var t := Time.get_ticks_msec() / 1000.0
	var state := ""                                     # ปกติไม่ขึ้นข้อความอะไร
	var col := Color(1.0, 0.3, 0.25)
	if _rock.is_jammed():
		state = "JAMMED"
	elif hot:
		state = "OVERHEAT   quality dropping"
		col.a = 0.6 + 0.4 * absf(sin(t * 10.0))         # กะพริบเตือน
	elif _rock.vent_flash > 0.0:
		state = "NICE RELEASE!"
		col = Color(0.4, 1.0, 0.5)

	draw_string(font, r.position + Vector2(8.0, r.size.y - 6.0), "HEAT", HORIZONTAL_ALIGNMENT_LEFT, 80.0, 14, Color.WHITE)
	if state != "":
		draw_string(font, Vector2(r.end.x + 10.0, r.end.y - 5.0), state, HORIZONTAL_ALIGNMENT_LEFT, 220.0, 14, col)
