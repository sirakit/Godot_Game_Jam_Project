class_name ZoneRings
extends Node2D

const SEGMENTS := 72

func _ready() -> void:
	z_index = -1
	Game.upgrades_changed.connect(queue_redraw)

func _draw() -> void:
	var last := MeteoriteTiers.ZONE_OUTER.size() - 1
	for z in MeteoriteTiers.ZONE_OUTER.size():
		var r: float = MeteoriteTiers.ZONE_OUTER[z]
		var open := r <= Game.tether_length_max * 1.1
		var col := Color(0.6, 0.8, 1.0, 0.22 if open else 0.07)
		if z == last:
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 256, col, 6.0)        # ขอบโลก: เส้นทึบ
			continue
		for i in SEGMENTS:
			if i % 3 == 2:
				continue                                              # เว้นช่อง เหมือนกำแพงมีทางผ่านในภาพร่าง
			draw_arc(Vector2.ZERO, r, TAU * i / SEGMENTS, TAU * (i + 1) / SEGMENTS, 6, col, 4.0)
