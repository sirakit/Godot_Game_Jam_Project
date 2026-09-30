extends Control

@onready var oxygen_bar: ProgressBar = $OxygenBar
@onready var tether_bar: ProgressBar = $TetherBar
@onready var points_label: Label = $PointsLabel
@onready var artifacts_label: Label = $ArtifactsLabel
@onready var hint_label: Label = $HintLabel
@onready var upgrade_buttons: HBoxContainer = $UpgradeButtons

const UPGRADE_UI := {
	"oxygen": {"node": "BtnOxygen", "label": "O2 Tank",
		"desc": "Max oxygen +40. Lets you stay outside the ship longer before you're forced back."},
	"chisel": {"node": "BtnChisel", "label": "Chisel",
		"desc": "Chisel strength +1. Breaks rock integrity faster on EVERY meteorite (common and rare)."},
	"tether": {"node": "BtnTether", "label": "Tether",
		"desc": "Max tether length +500px. Lets you fly farther from the ship before you hit the rope's limit."},
	"drill":  {"node": "BtnDrill",  "label": "Drill",
		"desc": "Drill strength +1. Rare (purple) meteorites need enough Drill or they mine 3x slower — upgrading Chisel does NOT help with this."},
	"income": {"node": "BtnIncome", "label": "Contract",
		"desc": "Income multiplier +25%. Applies to every artifact's value when you dock and hand it in."},
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Game.oxygen_changed.connect(_on_oxygen_changed)
	Game.tether_changed.connect(_on_tether_changed)
	Game.points_changed.connect(_on_points_changed)
	Game.artifacts_changed.connect(_on_artifacts_changed)
	Game.upgrades_changed.connect(_refresh_buttons)
	Game.perfect_extraction.connect(_on_perfect)

	upgrade_buttons.get_node("BtnOxygen").pressed.connect(Game.upgrade_oxygen)
	upgrade_buttons.get_node("BtnChisel").pressed.connect(Game.upgrade_chisel)
	upgrade_buttons.get_node("BtnTether").pressed.connect(Game.upgrade_tether)
	upgrade_buttons.get_node("BtnDrill").pressed.connect(Game.upgrade_drill)
	upgrade_buttons.get_node("BtnIncome").pressed.connect(Game.upgrade_income)

	for btn in upgrade_buttons.get_children():
		if btn is Button:
			btn.focus_mode = Control.FOCUS_NONE

	_on_oxygen_changed(Game.oxygen, Game.oxygen_max)
	_on_tether_changed(Game.tether_remaining, Game.tether_length_max)
	_on_points_changed(Game.points)
	_on_artifacts_changed(Game.carried_artifacts.size())
	_refresh_buttons()

	if has_node("PerfectLabel"):
		$PerfectLabel.visible = false
		$PerfectLabel.modulate.a = 0.0
	if has_node("CollectionLog"):
		$CollectionLog.visible = false

func _process(_delta: float) -> void:
	upgrade_buttons.visible = not Game.is_outside
	if Game.is_outside:
		hint_label.text = "[SPACE] hold to chisel (watch the HEAT)   [E] collect artifact   fly back to ship + [E] to hand in   [C] collection log"
	else:
		hint_label.text = "[E] launch into space   |   hover a button to see what it does   |   [R] restart   [C] collection log"

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
	_refresh_buttons()

func _on_artifacts_changed(count) -> void:
	artifacts_label.text = "Artifacts carried: %d" % count

func _refresh_buttons() -> void:
	for id in UPGRADE_UI.keys():
		var btn := upgrade_buttons.get_node_or_null(UPGRADE_UI[id]["node"]) as Button
		if btn == null:
			continue
		var cost := Game.get_upgrade_cost(id)
		# "→ Lv.N" คือเลเวลที่ "กำลังจะซื้อ" เลยไม่มีทางโชว์ Lv.0 อีกต่อไป (แก้บั๊กข้อ 2)
		btn.text = "%s → Lv.%d (%d pt)" % [UPGRADE_UI[id]["label"], Game.upgrade_levels[id] + 1, cost]
		btn.tooltip_text = UPGRADE_UI[id]["desc"]
		btn.disabled = Game.points < cost

func _on_perfect() -> void:
	if not has_node("PerfectLabel"):
		return
	var lbl: Label = $PerfectLabel
	lbl.visible = true
	lbl.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.0)
	tw.tween_callback(lbl.hide)
