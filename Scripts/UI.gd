extends Control

@onready var oxygen_bar: ProgressBar = $OxygenBar
@onready var tether_bar: ProgressBar = $TetherBar
@onready var points_label: Label = $PointsLabel
@onready var artifacts_label: Label = $ArtifactsLabel
@onready var hint_label: Label = $HintLabel
@onready var upgrade_buttons: HBoxContainer = $UpgradeButtons

const UPGRADE_UI := {
	"oxygen": {"node": "BtnOxygen", "label": "O2 Tank"},
	"chisel": {"node": "BtnChisel", "label": "Chisel"},
	"tether": {"node": "BtnTether", "label": "Tether"},
	"drill":  {"node": "BtnDrill",  "label": "Drill"},
	"income": {"node": "BtnIncome", "label": "Contract"},
}

func _ready() -> void:
	Game.oxygen_changed.connect(_on_oxygen_changed)
	Game.tether_changed.connect(_on_tether_changed)
	Game.points_changed.connect(_on_points_changed)
	Game.artifacts_changed.connect(_on_artifacts_changed)
	Game.upgrades_changed.connect(_refresh_buttons)

	upgrade_buttons.get_node("BtnOxygen").pressed.connect(Game.upgrade_oxygen)
	upgrade_buttons.get_node("BtnChisel").pressed.connect(Game.upgrade_chisel)
	upgrade_buttons.get_node("BtnTether").pressed.connect(Game.upgrade_tether)
	if upgrade_buttons.has_node("BtnDrill"):
		upgrade_buttons.get_node("BtnDrill").pressed.connect(Game.upgrade_drill)
	if upgrade_buttons.has_node("BtnIncome"):
		upgrade_buttons.get_node("BtnIncome").pressed.connect(Game.upgrade_income)

	# แก้บั๊ก playtest 5: ปุ่มจับ focus หลังคลิก แล้ว Space ไปกดปุ่มแทนการสกัด
	for btn in upgrade_buttons.get_children():
		if btn is Button:
			btn.focus_mode = Control.FOCUS_NONE

	_on_oxygen_changed(Game.oxygen, Game.oxygen_max)
	_on_tether_changed(Game.tether_remaining, Game.tether_length_max)
	_on_points_changed(Game.points)
	_on_artifacts_changed(Game.carried_artifacts.size())
	_refresh_buttons()

func _process(_delta: float) -> void:
	upgrade_buttons.visible = not Game.is_outside          # ซื้อของได้เฉพาะตอนอยู่ในยาน
	if Game.is_outside:
		hint_label.text = "[SPACE] hold to chisel (watch the HEAT)   [E] collect artifact   fly back to ship + [E] to hand in"
	else:
		hint_label.text = "[E] launch into space   |   buy upgrades bottom-right   |   [R] restart"

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
		btn.text = "%s Lv.%d — %d pt" % [UPGRADE_UI[id]["label"], Game.upgrade_levels[id], cost]
		btn.disabled = Game.points < cost
