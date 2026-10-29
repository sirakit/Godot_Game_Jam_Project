extends PanelContainer

@onready var grid: GridContainer = $VBox/Grid
@onready var count_label: Label = $VBox/CountLabel

const COLOR_FOUND := Color(0.55, 1.0, 0.65)
const COLOR_HIDDEN := Color(0.55, 0.55, 0.55)
const COLOR_RARE_HIDDEN := Color(0.237, 0.587, 0.79, 1.0)
const COLOR_EPIC_HIDDEN := Color(0.846, 0.281, 0.754, 1.0)
const COLOR_LEGENDARY_HIDDEN := Color(0.94, 0.615, 0.16, 1.0)
const COLOR_ANCIENT_HIDDEN := Color(0.79, 0.024, 0.024, 1.0)

var _rows: Dictionary = {}   # ชื่อ artifact -> Label

func _ready() -> void:
	visible = false
	Game.collection_changed.connect(_refresh)
	Game.collection_completed.connect(_refresh)
	_build_grid()
	_refresh()

func _build_grid() -> void:
	for child in grid.get_children():
		child.queue_free()
	_rows.clear()
	for entry_name in ArtifactDB.all_names():
		var lbl := Label.new()
		grid.add_child(lbl)
		_rows[entry_name] = lbl

func _refresh() -> void:
	for entry_name in _rows.keys():
		var lbl: Label = _rows[entry_name]
		var rare: bool = ArtifactDB.is_rare(entry_name)
		var epic: bool = ArtifactDB.is_epic(entry_name)
		var legendary: bool = ArtifactDB.is_legendary(entry_name)
		var ancient: bool = ArtifactDB.is_ancient(entry_name)
		
		if Game.discovered_artifacts.has(entry_name):
			lbl.text = "[x] " + entry_name
			lbl.modulate = COLOR_FOUND
		else:
			var tier := ArtifactDB.all_names().find(entry_name) + 1
			lbl.text = "[ ] ???  (T%d, Zone %d)" % [tier, MeteoriteTiers.best_zone(tier) + 1]
			lbl.modulate = COLOR_RARE_HIDDEN if rare else COLOR_HIDDEN
			lbl.modulate = COLOR_EPIC_HIDDEN if epic else COLOR_HIDDEN
			lbl.modulate = COLOR_LEGENDARY_HIDDEN if legendary else COLOR_HIDDEN
			
	var found: int = Game.discovered_artifacts.size()
	var total: int = ArtifactDB.all_names().size()
	count_label.text = "Collection: %d / %d" % [found, total]
	if found >= total:
		count_label.text += "  -  ALL CATALOGUED!"
