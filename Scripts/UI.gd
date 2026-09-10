extends Control

@onready var upgrade_button: Button = $BtnSpeed
@onready var oxygen_bar: ProgressBar = $OxygenBar
@onready var tether_bar: ProgressBar = $TetherBar
@onready var points_label: Label = $PointsLabel
@onready var artifacts_label: Label = $ArtifactsLabel

@export var player: CharacterBody2D

func _ready():
	Game.oxygen_changed.connect(_on_oxygen_changed)
	Game.tether_changed.connect(_on_tether_changed)
	Game.points_changed.connect(_on_points_changed)
	Game.artifacts_changed.connect(_on_artifacts_changed)

	$UpgradeButtons/BtnOxygen.pressed.connect(Game.upgrade_oxygen)
	$UpgradeButtons/BtnChisel.pressed.connect(Game.upgrade_chisel)
	$UpgradeButtons/BtnTether.pressed.connect(Game.upgrade_tether)

	_on_oxygen_changed(Game.oxygen, Game.oxygen_max)
	_on_tether_changed(Game.tether_time, Game.tether_time_max)
	_on_points_changed(Game.points)
	_on_artifacts_changed(0)

func _on_oxygen_changed(value, max_value):
	oxygen_bar.max_value = max_value
	oxygen_bar.value = value

func _on_tether_changed(value, max_value):
	tether_bar.max_value = max_value
	tether_bar.value = value

func _on_points_changed(value):
	points_label.text = "Credit: %d" % value

func _on_artifacts_changed(count):
	artifacts_label.text = "Numbers of Artifact: %d " % count
