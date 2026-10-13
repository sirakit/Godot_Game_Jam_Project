extends PanelContainer

@onready var grid: GridContainer = $VBox/Grid
@onready var count_label: Label = $VBox/CountLabel

func _ready() -> void:
	visible = false
	Game.collection_changed.connect(_refresh)
	Game.collection_completed.connect(_on_completed)
	_build_grid()
	_refresh()

func _build_grid() -> void:
	for entry_name in Game.ALL_ARTIFACT_NAMES:
		var lbl := Label.new()
		grid.add_child(lbl)

func _refresh() -> void:
	for i in Game.ALL_ARTIFACT_NAMES.size():
		var entry_name: String = Game.ALL_ARTIFACT_NAMES[i]
		var lbl := grid.get_child(i) as Label
		if Game.discovered_artifacts.has(entry_name):
			lbl.text = "✓ " + entry_name
			lbl.modulate = Color(0.5, 1.0, 0.6)
		else:
			lbl.text = "??? "
			lbl.modulate = Color(0.5, 0.5, 0.5)
	count_label.text = "Collection: %d / %d" % [Game.discovered_artifacts.size(), Game.ALL_ARTIFACT_NAMES.size()]

func _on_completed() -> void:
	count_label.text += "   — ALL CATALOGUED! "
