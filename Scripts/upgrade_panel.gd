class_name UpgradePanel
extends Control

signal closed

var _credit: Label
var _cards: Dictionary = {}      # id -> {level, effect, bar, buy}

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	Game.upgrades_changed.connect(refresh)
	Game.points_changed.connect(_on_points_changed)
	refresh()

func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP       # แตะข้างนอกการ์ด = ปิด
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.gui_input.connect(_on_backdrop_input)

	var panel := PanelContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "UPGRADES"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_font_override("font_type", load("res://Assets/fonts/Black_Ops_One/BlackOpsOne-Regular.ttf"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_credit = Label.new()
	_credit.add_theme_font_size_override("font_size", 24)
	_credit.add_theme_font_override("font", load("res://Assets/fonts/Black_Ops_One/BlackOpsOne-Regular.ttf"))
	_credit.add_theme_color_override("font_color", Color(1.0, 0.7, 0.28))
	header.add_child(_credit)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(64, 56)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close)
	header.add_child(close_btn)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	root.add_child(grid)
	for id in Game.UPGRADE_ORDER:
		grid.add_child(_make_card(id))

func _make_card(id: String) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(320, 0)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 12)
	card.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	m.add_child(v)

	var top := HBoxContainer.new()
	v.add_child(top)
	var name_lbl := Label.new()
	name_lbl.text = Game.UPGRADE_NAME[id]
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_font_override("font", load("res://Assets/fonts/Black_Ops_One/BlackOpsOne-Regular.ttf"))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_lbl)
	var lv_lbl := Label.new()
	lv_lbl.add_theme_color_override("font_color", Color(1.0, 0.7, 0.28))
	top.add_child(lv_lbl)

	var eff := Label.new()
	eff.add_theme_color_override("font_color", Color(0.37, 0.89, 1.0))
	v.add_child(eff)

	var desc := Label.new()
	desc.text = Game.UPGRADE_DESC[id]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(296, 0)           # ต้องกำหนดความกว้าง ไม่งั้น autowrap ไม่ตัดบรรทัด
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.62, 0.69, 0.85))
	desc.add_theme_font_override("font", load("res://Assets/fonts/Black_Ops_One/BlackOpsOne-Regular.ttf"))
	v.add_child(desc)

	var bar := ProgressBar.new()
	bar.max_value = Game.UPGRADE_CAP
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	v.add_child(bar)

	var buy := Button.new()
	buy.custom_minimum_size = Vector2(0, 56)
	buy.focus_mode = Control.FOCUS_NONE
	buy.pressed.connect(_on_buy.bind(id))
	v.add_child(buy)

	_cards[id] = {"level": lv_lbl, "effect": eff, "bar": bar, "buy": buy}
	return card

func refresh() -> void:
	if _credit == null:
		return
	_credit.text = "Credit: %d" % Game.points
	for id in Game.UPGRADE_ORDER:
		var c: Dictionary = _cards[id]
		var lv: int = Game.upgrade_levels[id]
		c["level"].text = "Lv %d / %d" % [lv, Game.UPGRADE_CAP]
		c["bar"].value = lv
		if Game.is_maxed(id):
			c["effect"].text = "MAX LEVEL"
			c["buy"].text = "MAXED"
			c["buy"].disabled = true
		else:
			var cost := Game.get_upgrade_cost(id)
			c["effect"].text = Game.effect_text(id)
			c["buy"].text = "BUY   %d pt" % cost
			c["buy"].disabled = Game.points < cost

func _on_buy(id: String) -> void:
	Game.call("upgrade_" + id)           # upgrade_oxygen / _chisel / _tether / _drill / _income / _speed

func _on_points_changed(_v) -> void:
	refresh()

func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func open() -> void:
	visible = true
	refresh()

func close() -> void:
	if visible:
		visible = false
		closed.emit()
