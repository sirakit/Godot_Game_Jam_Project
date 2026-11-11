extends Control

const AUTO_OPEN_SHOP_AFTER_DOCK := false        # true = เปิด popup อัปเกรดเองตอนกลับยานถ้ามีของซื้อได้

@onready var oxygen_bar: ProgressBar = $OxygenBar
@onready var tether_bar: ProgressBar = $TetherBar
@onready var points_label: Label = $PointsLabel
@onready var artifacts_label: Label = $ArtifactsLabel
@onready var hint_label: Label = $HintLabel
@onready var hit_flash: ColorRect = $HitFlash

var _upgrade_panel: UpgradePanel
var _btn_upgrades: Button
var _menu_root: Control
var _restart_btn: Button
var _restart_armed: bool = false
var _toast: Label
var _toast_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS          # ให้ปุ่มเมนูกดได้ตอนเกมหยุด (pause)
	Game.oxygen_changed.connect(_on_oxygen_changed)
	Game.tether_changed.connect(_on_tether_changed)
	Game.points_changed.connect(_on_points_changed)
	Game.artifacts_changed.connect(_on_artifacts_changed)
	Game.upgrades_changed.connect(_refresh_top)
	Game.perfect_extraction.connect(_on_perfect)
	Game.debris_hit.connect(_on_debris_hit)
	Game.dock_penalty_applied.connect(_on_dock_penalty)
	Game.trip_ended.connect(_on_trip_ended)

	hit_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE   # ไม่งั้นบล็อกเมาส์ ทำให้ hover/แตะหินไม่ติด
	hit_flash.color.a = 0.0

	var old_buttons := get_node_or_null("UpgradeButtons")  # แถวปุ่ม 6 ปุ่มเดิม ใช้ popup แทนแล้ว
	if old_buttons != null:
		old_buttons.visible = false

	_build_top_row()
	_build_upgrade_panel()
	_build_menu()
	_build_toast()

	if has_node("PerfectLabel"):
		$PerfectLabel.visible = false
		$PerfectLabel.modulate.a = 0.0
	if has_node("CollectionLog"):
		$CollectionLog.visible = false

	_on_oxygen_changed(Game.oxygen, Game.oxygen_max)
	_on_tether_changed(Game.tether_remaining, Game.tether_length_max)
	_on_points_changed(Game.points)
	_on_artifacts_changed(Game.carried_artifacts.size())

# ---------- สร้าง UI ด้วยโค้ด ----------
func _make_button(text: String, callback: Callable, min_size := Vector2(128, 64)) -> Button:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_override("font", load("res://Assets/fonts/Black_Ops_One/BlackOpsOne-Regular.ttf"))
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE                 # กัน Space ไปกดปุ่มแทนการตอก
	b.pressed.connect(callback)
	return b

func _build_top_row() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_override("font", load("res://Assets/fonts/Black_Ops_One/BlackOpsOne-Regular.ttf"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	row.offset_left = -200.0
	row.offset_right = -16.0
	row.offset_top = 12.0
	_btn_upgrades = _make_button("UPGRADES", _open_upgrades, Vector2(150, 64))
	_btn_upgrades.add_theme_font_override("font", load("res://Assets/fonts/Black_Ops_One/BlackOpsOne-Regular.ttf"))
	row.add_child(_btn_upgrades)
	var _btn_log = _make_button("LOG", _toggle_log, Vector2(150, 64))
	_btn_log.add_theme_font_override("font", load("res://Assets/fonts/Black_Ops_One/BlackOpsOne-Regular.ttf"))
	row.add_child(_btn_log)
	var _btn_menu = _make_button("MENU", _open_menu, Vector2(104, 64))
	_btn_menu.add_theme_font_override("font", load("res://Assets/fonts/Black_Ops_One/BlackOpsOne-Regular.ttf"))
	row.add_child(_btn_menu)
	

func _build_upgrade_panel() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_override("font", load("res://Assets/fonts/Black_Ops_One/BlackOpsOne-Regular.ttf"))
	_upgrade_panel = UpgradePanel.new()
	add_child(_upgrade_panel)

func _build_menu() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_override("font", load("res://Assets/fonts/Black_Ops_One/BlackOpsOne-Regular.ttf"))
	_menu_root = Control.new()
	_menu_root.visible = false
	add_child(_menu_root)
	_menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	_menu_root.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	_menu_root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_font_override("font", load("res://Assets/fonts/Black_Ops_One/BlackOpsOne-Regular.ttf"))
	box.add_child(title)
	box.add_theme_font_override("font", load("res://Assets/fonts/Black_Ops_One/BlackOpsOne-Regular.ttf"))
	var _resume_btn = _make_button("Resume", _close_menu, Vector2(300, 64))
	_resume_btn.add_theme_font_override("font", load("res://Assets/fonts/Black_Ops_One/BlackOpsOne-Regular.ttf"))
	box.add_child(_resume_btn)
	_restart_btn = _make_button("Restart run", _on_restart_pressed, Vector2(300, 64))
	_restart_btn.add_theme_font_override("font", load("res://Assets/fonts/Black_Ops_One/BlackOpsOne-Regular.ttf"))
	box.add_child(_restart_btn)
	var _main_menu_btn =_make_button("Main menu", _on_main_menu_pressed, Vector2(300, 64))
	_main_menu_btn.add_theme_font_override("font", load("res://Assets/fonts/Black_Ops_One/BlackOpsOne-Regular.ttf"))
	box.add_child(_main_menu_btn)

func _build_toast() -> void:
	_toast = Label.new()
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 24)
	_toast.add_theme_font_override("font", load("res://Assets/fonts/Black_Ops_One/BlackOpsOne-Regular.ttf"))
	_toast.modulate.a = 0.0
	add_child(_toast)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -360.0
	_toast.offset_right = 360.0
	_toast.offset_top = 150.0

func _show_toast(text: String, color: Color) -> void:
	_toast.text = text
	add_theme_font_override("font", load("res://Assets/fonts/Black_Ops_One/BlackOpsOne-Regular.ttf"))
	_toast.add_theme_color_override("font_color", color)
	if _toast_tween != null:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.8).set_delay(2.0)

# ---------- ปุ่ม ----------
func _open_upgrades() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upgrade_panel.open()

func _toggle_log() -> void:
	add_theme_font_override("font", load("res://Assets/fonts/Black_Ops_One/BlackOpsOne-Regular.ttf"))
	var log_panel := get_node_or_null("CollectionLog")
	if log_panel != null:
		log_panel.visible = not log_panel.visible

func _open_menu() -> void:
	_restart_btn.add_theme_font_override("font", load("res://Assets/fonts/Black_Ops_One/BlackOpsOne-Regular.ttf"))
	_restart_armed = false
	_restart_btn.text = "Restart run"
	_menu_root.visible = true
	get_tree().paused = true

func _close_menu() -> void:
	add_theme_font_override("font", load("res://Assets/fonts/Black_Ops_One/BlackOpsOne-Regular.ttf"))
	_menu_root.visible = false
	get_tree().paused = false

func _on_restart_pressed() -> void:
	add_theme_font_override("font", load("res://Assets/fonts/Black_Ops_One/BlackOpsOne-Regular.ttf"))
	if not _restart_armed:                            # กดครั้งแรก = ขอยืนยัน กันกดพลาดบนจอสัมผัส
		_restart_armed = true
		_restart_btn.text = "Tap again to confirm"
		return
	get_tree().paused = false
	Game.reset_all()
	get_tree().reload_current_scene()

func _on_main_menu_pressed() -> void:
	add_theme_font_override("font", load("res://Assets/fonts/Black_Ops_One/BlackOpsOne-Regular.ttf"))
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")

# ---------- ทุกเฟรม ----------
func _process(_delta: float) -> void:
	_btn_upgrades.visible = not Game.is_outside
	if Game.is_outside and _upgrade_panel.visible:
		_upgrade_panel.close()

	var log_panel := get_node_or_null("CollectionLog")
	log_panel.add_theme_font_override("font", load("res://Assets/fonts/Black_Ops_One/BlackOpsOne-Regular.ttf"))
	var log_open: bool = log_panel != null and log_panel.visible
	Game.ui_modal_open = _upgrade_panel.visible or _menu_root.visible or log_open

	if Game.recall_progress > 0.0:
		hint_label.text = "Recalling... %d%%   (release F to cancel)" % int(Game.recall_progress * 100.0)
		return
	hint_label.text = _hint_text()

func _hint_text() -> String:
	var dist := Game.tether_length_max - Game.tether_remaining
	var far := dist >= Game.RECALL_MIN_DISTANCE
	var fee := roundi(Game.RECALL_FEE * 100.0)
		# ตั้งค่าให้กางเต็มแนวนอนด้านล่าง และข้อความชิดขวา
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		# เว้นระยะห่างจากขอบจอเล็กน้อย (Offset) ไม่ให้ตัวหนังสือแนบติดขอบเกินไป
	hint_label.offset_right = -24.0
	hint_label.offset_bottom = -16.0
	if Game.touch_mode:
		if Game.is_outside:
			var t := "Left thumb: fly   |   hold CHISEL (watch the HEAT)   |   action button: collect / dock"
			if far:
				t += "   |   hold RECALL (-%d%% of carried value)" % fee
			return t
		return "Tap LAUNCH to go out   |   UPGRADES to power up   |   LOG for your collection"
	if Game.is_outside:
		var t2 := "[SPACE] hold to chisel (watch the HEAT)   |   [E] collect / dock"
		if far:
			t2 += "   |   [F] hold: recall "
		return t2
	return "[E] launch into space   |   click UPGRADES to power up   " 

# ---------- สัญญาณ ----------
func _on_oxygen_changed(value, max_value) -> void:
	oxygen_bar.max_value = max_value
	oxygen_bar.value = value
	oxygen_bar.modulate = Color(1, 0.3, 0.3) if value / max(1.0, max_value) < 0.25 else Color.WHITE

func _on_tether_changed(value, max_value) -> void:
	tether_bar.max_value = max_value
	tether_bar.value = value
	tether_bar.modulate = Color(1, 0.3, 0.3) if value / max(1.0, max_value) < 0.2 else Color.WHITE

func _on_points_changed(value) -> void:
	points_label.text = "Credit: %d" % value
	_refresh_top()

func _on_artifacts_changed(count) -> void:
	artifacts_label.text = "Artifacts carried: %d" % count

func _refresh_top() -> void:
	var n := 0
	for id in Game.UPGRADE_ORDER:
		if not Game.is_maxed(id) and Game.points >= Game.get_upgrade_cost(id):
			n += 1
	_btn_upgrades.text = ("UPGRADES (%d)" % n) if n > 0 else "UPGRADES"

func _on_trip_ended() -> void:
	if AUTO_OPEN_SHOP_AFTER_DOCK and _btn_upgrades.text != "UPGRADES":
		_upgrade_panel.open()

func _on_perfect() -> void:
	if Game.touch_mode:
		Input.vibrate_handheld(40)
	if not has_node("PerfectLabel"):
		return
	var lbl: Label = $PerfectLabel
	lbl.visible = true
	lbl.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.0)
	tw.tween_callback(lbl.hide)

func _on_debris_hit() -> void:
	hit_flash.color.a = 0.45
	var tw := create_tween()
	tw.tween_property(hit_flash, "color:a", 0.0, 0.45)

func _on_dock_penalty(penalty: float, lost: int) -> void:
	var pct := roundi(penalty * 100.0)
	if penalty >= Game.OXYGEN_OUT_PENALTY - 0.001:
		_show_toast("OUT OF OXYGEN   -%d%%   (-%d pt)" % [pct, lost], Color(1.0, 0.35, 0.3))
	else:
		_show_toast("RECALL FEE   -%d%%   (-%d pt)" % [pct, lost], Color(1.0, 0.75, 0.3))
