extends Control
## Tutorial screen shown after pressing Start on the main menu.
## Black screen, each step fades in and types its text out slowly, with a looping demo beside it.
## The whole UI is built in code, so tutorial.tscn only needs this script on a Control root.

const NEXT_SCENE := "res://Scenes/space.tscn"
const FONT_PATH := "res://Assets/fonts/Black_Ops_One/BlackOpsOne-Regular.ttf"
const ARTIFACT_TEX_PATH := "res://Assets/sprites/artifacts/quartz_cluster.png"

const FADE_IN_TIME := 0.6          # seconds for a step to fade in
const CHAR_TIME := 0.035           # seconds per typed character (bigger = slower)
const GAP_BETWEEN_STEPS := 0.9     # pause after a step finishes typing
const TEXT_WIDTH := 560.0
const DEMO_WIDTH := 340.0
const ROW_HEIGHT := 108.0

const STEPS: Array[String] = [
	"Hold SPACE to chisel. Release before it overheats to avoid a penalty. Release at the green portion to reduce heat.",
	"Don't forget to pick up the artifact [E] after you finish chiseling.",
	"Watch your O2. Running out reduces your credit. Dock at the ship to refuel.",
]

var _title: Label
var _rows: Array[Control] = []
var _labels: Array[Label] = []
var _demos: Array[DemoBase] = []
var _continue_btn: Button
var _leaving: bool = false


func _ready() -> void:
	var theme_obj := Theme.new()
	var font := load(FONT_PATH) as Font
	if font != null:
		theme_obj.default_font = font
	theme = theme_obj

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 26)
	center.add_child(box)

	_title = Label.new()
	_title.text = "HOW TO PLAY"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 44)
	_title.modulate.a = 0.0
	box.add_child(_title)

	var artifact_tex: Texture2D = null
	if ResourceLoader.exists(ARTIFACT_TEX_PATH):
		artifact_tex = load(ARTIFACT_TEX_PATH) as Texture2D

	var demos: Array[DemoBase] = [HeatDemo.new(), ArtifactDemo.new(artifact_tex), O2Demo.new()]
	for i in STEPS.size():
		var row := _make_row(STEPS[i], demos[i])
		box.add_child(row)
		_rows.append(row)
		_demos.append(demos[i])

	_continue_btn = Button.new()
	_continue_btn.text = "CONTINUE"
	_continue_btn.custom_minimum_size = Vector2(240.0, 60.0)
	_continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_continue_btn.focus_mode = Control.FOCUS_NONE     # stops Space/Enter from pressing it by accident
	_continue_btn.disabled = true
	_continue_btn.modulate.a = 0.0
	_continue_btn.pressed.connect(_go_next)
	box.add_child(_continue_btn)

	var skip_btn := Button.new()
	skip_btn.text = "SKIP >>"
	skip_btn.flat = true
	skip_btn.focus_mode = Control.FOCUS_NONE
	skip_btn.modulate = Color(1.0, 1.0, 1.0, 0.6)
	skip_btn.pressed.connect(_go_next)
	add_child(skip_btn)
	skip_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 20)

	_run_intro()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_next()


func _make_row(text: String, demo: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	row.modulate.a = 0.0

	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(DEMO_WIDTH, ROW_HEIGHT)
	holder.add_child(demo)
	row.add_child(holder)

	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(TEXT_WIDTH, 0.0)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.visible_ratio = 0.0
	row.add_child(label)
	_labels.append(label)
	return row


func _wait(seconds: float) -> void:
	# Tween-based wait: if the scene is freed mid-wait, the tween dies with it and nothing resumes.
	var tw := create_tween()
	tw.tween_interval(seconds)
	await tw.finished


func _run_intro() -> void:
	await _wait(0.7)
	create_tween().tween_property(_title, "modulate:a", 1.0, FADE_IN_TIME)
	await _wait(1.1)

	for i in _rows.size():
		create_tween().tween_property(_rows[i], "modulate:a", 1.0, FADE_IN_TIME)
		_demos[i].start()
		var type_tw := create_tween()
		type_tw.tween_property(_labels[i], "visible_ratio", 1.0, _labels[i].text.length() * CHAR_TIME)
		await type_tw.finished
		await _wait(GAP_BETWEEN_STEPS)

	_continue_btn.disabled = false
	create_tween().tween_property(_continue_btn, "modulate:a", 1.0, FADE_IN_TIME)


func _go_next() -> void:
	if _leaving:
		return
	_leaving = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		get_tree().change_scene_to_file(NEXT_SCENE)
	)


# ---------------------------------------------------------------------------
# Demo widgets. Each one starts animating when its step is revealed and loops forever.
# ---------------------------------------------------------------------------

class DemoBase extends Control:
	const COLOR_GREEN := Color(0.4, 1.0, 0.5)
	const COLOR_RED := Color(1.0, 0.3, 0.25)
	const COLOR_AMBER := Color(1.0, 0.8, 0.3)
	const COLOR_HINT := Color(1.0, 0.95, 0.55)

	var active: bool = false
	var t: float = 0.0

	func start() -> void:
		active = true
		t = 0.0

	func _process(delta: float) -> void:
		if not active:
			return
		t += delta
		_update_demo()
		queue_redraw()

	func _update_demo() -> void:
		pass


## Step 1: heat bar that builds up, reaches the green VENT window, gets released, cools, repeats.
## Numbers mirror the real HUD (danger line at 70% heat, VENT window 17% wide, vent cools 25%).
class HeatDemo extends DemoBase:
	const W := 320.0
	const BAR_Y := 40.0
	const BAR_H := 22.0
	const DANGER := 0.70
	const VENT_W := 0.17
	const PERIOD := 5.0

	var _grad: GradientTexture2D

	func _init() -> void:
		custom_minimum_size = Vector2(W, 90.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([Color(1.0, 0.85, 0.3), Color(1.0, 0.55, 0.15), Color(0.95, 0.15, 0.1)])
		_grad = GradientTexture2D.new()
		_grad.gradient = g
		_grad.width = 256
		_grad.height = 8
		_grad.fill_from = Vector2(0.0, 0.0)
		_grad.fill_to = Vector2(1.0, 0.0)

	# Returns the animation state at the current time: heat ratio, key held, just vented.
	func _sample() -> Dictionary:
		var c: float = fposmod(t, PERIOD)
		var heat: float = 0.0
		var held: bool = false
		var vented: bool = false
		if c < 0.5:
			heat = 0.0
		elif c < 2.5:                                   # holding: heat builds up
			held = true
			heat = lerpf(0.0, 0.6, (c - 0.5) / 2.0)
		elif c < 2.9:                                   # inside the green window: release now
			held = true
			heat = lerpf(0.6, 0.66, (c - 2.5) / 0.4)
		else:                                           # released: instant vent, then cooling
			var since: float = c - 2.9
			vented = since < 0.7
			heat = maxf(0.0, 0.66 - 0.25 - 0.25 * since)
		return {"heat": heat, "held": held, "vented": vented}

	func _draw() -> void:
		var font := get_theme_default_font()
		var s := _sample()
		var heat: float = s["heat"]
		var held: bool = s["held"]
		var vented: bool = s["vented"]

		# SPACE key cap
		var cap := Rect2(0.0, 0.0, 84.0, 26.0)
		draw_rect(cap, Color(0.92, 0.92, 0.97) if held else Color(0.16, 0.18, 0.26))
		draw_rect(cap, Color(1, 1, 1, 0.6), false, 2.0)
		draw_string(font, Vector2(10.0, 19.0), "SPACE", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15,
				Color(0.05, 0.07, 0.12) if held else Color.WHITE)

		# State text
		var state := "COLD"
		var state_col := Color(0.7, 0.85, 1.0)
		if vented:
			state = "VENT!"
			state_col = COLOR_GREEN
		elif held and heat >= DANGER - VENT_W:
			state = "RELEASE NOW!"
			state_col = COLOR_GREEN
		elif held and heat > DANGER * 0.45:
			state = "OVERDRIVE"
			state_col = COLOR_AMBER
		elif held:
			state = "HEATING..."
			state_col = Color(1.0, 0.9, 0.6)
		draw_string(font, Vector2(98.0, 19.0), state, HORIZONTAL_ALIGNMENT_LEFT, 220.0, 17, state_col)

		# Heat bar (same look as the in-game HUD)
		var r := Rect2(0.0, BAR_Y, W, BAR_H)
		var dark := Color(0.12, 0.14, 0.2, 0.92)
		draw_rect(r, dark)
		draw_texture_rect(_grad, r, false)
		draw_rect(Rect2(r.position.x + W * heat, r.position.y, W * (1.0 - heat), BAR_H), dark)

		# Green VENT window + danger line
		var win_x: float = W * (DANGER - VENT_W)
		var win_w: float = W * VENT_W
		draw_rect(Rect2(win_x, r.position.y, win_w, BAR_H), Color(0.4, 1.0, 0.5, 0.28))
		draw_rect(Rect2(win_x, r.position.y - 4.0, win_w, 4.0), COLOR_GREEN)
		var dx: float = W * DANGER
		draw_line(Vector2(dx, r.position.y - 5.0), Vector2(dx, r.end.y + 4.0), Color.WHITE, 3.0)
		draw_rect(r, Color(1, 1, 1, 0.45), false, 2.0)
		draw_string(font, r.position + Vector2(8.0, BAR_H - 6.0), "HEAT", HORIZONTAL_ALIGNMENT_LEFT, 80.0, 14, Color.WHITE)
		draw_string(font, Vector2(win_x - 6.0, r.end.y + 20.0), "RELEASE HERE", HORIZONTAL_ALIGNMENT_LEFT, 150.0, 13, COLOR_GREEN)


## Step 2: the artifact with the same "COLLECT" + bobbing down arrow that appears in the game.
class ArtifactDemo extends DemoBase:
	var _tex: Texture2D

	func _init(tex: Texture2D) -> void:
		_tex = tex
		custom_minimum_size = Vector2(320.0, 108.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var font := get_theme_default_font()
		var cx: float = size.x * 0.5
		var center := Vector2(cx, 78.0)
		var pulse: float = 1.0 + sin(t * 8.0) * 0.1

		# Glow ring
		draw_arc(center, 29.0, 0.0, TAU, 32, Color(0.4, 0.9, 1.0, 0.75), 2.5)

		# Artifact sprite (falls back to a glowing dot if the texture is missing)
		if _tex != null:
			var longest: float = float(maxi(_tex.get_width(), _tex.get_height()))
			var s: float = 52.0 * pulse
			var sz := Vector2(_tex.get_width(), _tex.get_height()) * (s / longest)
			draw_texture_rect(_tex, Rect2(center - sz * 0.5, sz), false)
		else:
			draw_circle(center, 16.0 * pulse, Color(0.4, 0.9, 1.0, 0.9))

		# COLLECT text + bobbing arrow
		var bob: float = (sin(t * 7.0) * 0.5 + 0.5) * 6.0
		draw_string_outline(font, Vector2(0.0, 16.0), "COLLECT", HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, 6, Color(0, 0, 0, 0.9))
		draw_string(font, Vector2(0.0, 16.0), "COLLECT", HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, COLOR_HINT)
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 9.0, 24.0 + bob),
			Vector2(cx + 9.0, 24.0 + bob),
			Vector2(cx, 38.0 + bob),
		]), COLOR_HINT)


## Step 3: the real Gauge (tank style, same as the HUD) draining, running dry, then refilling at the ship.
class O2Demo extends DemoBase:
	const PERIOD := 7.0
	var _gauge: Gauge
	var _status: Label

	func _init() -> void:
		custom_minimum_size = Vector2(320.0, 80.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

		_status = Label.new()
		_status.position = Vector2(0.0, 0.0)
		_status.add_theme_font_size_override("font_size", 17)
		add_child(_status)

		_gauge = Gauge.new()
		_gauge.style = Gauge.Style.TANK
		_gauge.fill_color = Color(0.37, 0.89, 1.0)
		_gauge.max_value = 100.0
		_gauge.value = 100.0
		_gauge.position = Vector2(0.0, 34.0)
		_gauge.size = Vector2(300.0, 30.0)
		add_child(_gauge)

	func _update_demo() -> void:
		var c: float = fposmod(t, PERIOD)
		var v: float = 100.0
		var text := "O2"
		var col := Color(0.8, 0.95, 1.0)
		if c < 0.6:
			v = 100.0
		elif c < 5.0:                                   # draining
			v = lerpf(100.0, 0.0, (c - 0.6) / 4.4)
			if v < 25.0:
				text = "LOW O2!"
				col = COLOR_RED
		elif c < 6.2:                                   # empty: forced back, credit penalty
			v = 0.0
			text = "OUT OF O2!   CREDIT -%d%%" % int(Game.OXYGEN_OUT_PENALTY * 100.0)
			col = COLOR_RED
		else:                                           # docked at the ship: refuel
			v = lerpf(0.0, 100.0, (c - 6.2) / 0.5)
			text = "DOCKED - O2 REFILLED"
			col = COLOR_GREEN
		_gauge.value = clampf(v, 0.0, 100.0)
		_status.text = text
		_status.add_theme_color_override("font_color", col)
