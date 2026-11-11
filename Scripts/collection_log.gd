extends PanelContainer

const TIERS_PER_RARITY := 2
const HIDDEN := Color(0.45, 0.50, 0.60)

var _cells: Array = []              # index = tier - 1
var _count: Label
var _new_tiers: Dictionary = {}     # tier ที่เพิ่งเจอและยังไม่ได้เปิดดู

func _ready() -> void:
	visible = false
	for c in get_children():
		c.queue_free()
	_build()
	Game.collection_changed.connect(_refresh)
	Game.collection_completed.connect(_refresh)
	Game.artifact_collected.connect(_on_collected)
	visibility_changed.connect(_on_visibility_changed)
	_refresh()

func _build() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var head := HBoxContainer.new()
	root.add_child(head)
	var title := _line(26)
	title.text = "COLLECTION"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_count = _line(20)
	head.add_child(_count)

	for r in MeteoriteTiers.RARITY_NAMES.size():
		root.add_child(_make_strip(r))

	var hint := _line(12)
	hint.text = "Farther zones hold higher tiers.   [C] or LOG to close"
	hint.add_theme_color_override("font_color", HIDDEN)
	root.add_child(hint)

func _line(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	return l

# แถวความหายาก: แถบสี + ชื่อ + 2 ช่อง tier
func _make_strip(r: int) -> Control:
	var col: Color = MeteoriteTiers.RARITY_COLORS[r]
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 10)
	var bar := ColorRect.new()
	bar.color = col
	bar.custom_minimum_size = Vector2(6, 0)
	strip.add_child(bar)
	var name_lbl := _line(16)
	name_lbl.text = MeteoriteTiers.RARITY_NAMES[r]
	name_lbl.custom_minimum_size = Vector2(120, 0)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", col)
	strip.add_child(name_lbl)
	for k in TIERS_PER_RARITY:
		strip.add_child(_make_cell(r * TIERS_PER_RARITY + k + 1, col))
	return strip

func _make_cell(tier: int, col: Color) -> Control:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(340, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.16, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	cell.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	cell.add_child(hb)

	var swatch := ColorRect.new()                       # ช่องสีของ tier (ถ้ามีภาพ artifact จะแสดงภาพทับ)
	swatch.custom_minimum_size = Vector2(44, 44)
	hb.add_child(swatch)
	var tag := _line(16)
	tag.text = "T%d" % tier
	swatch.add_child(tag)
	tag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.visible = false
	swatch.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	var title := _line(16)
	var sub := _line(12)
	var stat := _line(12)
	vb.add_child(title)
	vb.add_child(sub)
	vb.add_child(stat)

	_cells.append({"sb": sb, "col": col, "swatch": swatch, "tag": tag, "icon": icon,
		"title": title, "sub": sub, "stat": stat})
	return cell

func _refresh() -> void:
	var names := ArtifactDB.all_names()
	for i in _cells.size():
		var c: Dictionary = _cells[i]
		var tier := i + 1
		var artifact_name: String = names[i]
		var found: bool = Game.discovered_artifacts.has(artifact_name)
		var col: Color = c["col"]
		var tint: Color = MeteoriteTiers.TINTS[i]

		c["swatch"].color = tint if found else tint.darkened(0.7)
		c["sb"].border_color = col if found else col.darkened(0.55)
		var title_text := artifact_name if found else "???"
		if _new_tiers.has(tier):
			title_text += "   NEW"
		c["title"].text = title_text
		c["title"].add_theme_color_override("font_color", col if found else HIDDEN)

		var sub := "Zone %d  |  DEF %.1f" % [MeteoriteTiers.best_zone(tier) + 1, MeteoriteTiers.DEFENSE[i]]
		if found:
			sub += "  |  %d pt" % MeteoriteTiers.VALUE[i]
		c["sub"].text = sub
		if found:
			c["stat"].text = "Collected x%d    Best %d%%" % [Game.collected_counts.get(artifact_name, 0), Game.best_quality.get(artifact_name, 0)]
		else:
			c["stat"].text = "Not found yet"

		var tex: Texture2D = ArtifactDB.get_texture(artifact_name) if found else null
		c["icon"].texture = tex
		c["icon"].visible = tex != null
		c["tag"].visible = tex == null

	var n := Game.discovered_artifacts.size()
	var total := names.size()
	_count.text = "%d / %d" % [n, total] + ("   ALL CATALOGUED!" if n >= total else "")

func _on_collected(tier: int, _artifact_name: String, _quality: int, is_new: bool) -> void:
	if is_new:
		_new_tiers[tier] = true
	_refresh()

func _on_visibility_changed() -> void:
	if visible:
		_refresh()
		_new_tiers.clear()      # เปิดดูแล้ว ป้าย NEW หายในรอบถัดไป
