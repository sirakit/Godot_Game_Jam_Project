extends Node

signal oxygen_changed(value, max_value)
signal tether_changed(value, max_value)
signal points_changed(value)
signal artifacts_changed(count)
signal trip_ended()

var oxygen_max: float = 100.0
var oxygen: float = 100.0
var oxygen_drain_rate: float = 4.0      # ต่อวินาที ตอนอยู่นอกยาน

var tether_time_max: float = 15.0
var tether_time: float = 15.0

var chisel_strength: float = 1.0
var drill_strength: float = 1.0

var points: int = 0
var carried_artifacts: Array = []       # [{name, value}]
var is_outside: bool = false

func reset_trip():
	oxygen = oxygen_max
	tether_time = tether_time_max
	emit_signal("oxygen_changed", oxygen, oxygen_max)
	emit_signal("tether_changed", tether_time, tether_time_max)

func start_outside():
	is_outside = true
	reset_trip()

func dock():
	is_outside = false
	for a in carried_artifacts:
		points += int(a["value"])
	carried_artifacts.clear()
	emit_signal("points_changed", points)
	emit_signal("artifacts_changed", carried_artifacts.size())
	emit_signal("trip_ended")

func add_artifact(art_data: Dictionary):
	carried_artifacts.append(art_data)
	emit_signal("artifacts_changed", carried_artifacts.size())

func tick(delta: float):
	if is_outside:
		oxygen = max(0.0, oxygen - oxygen_drain_rate * delta)
		tether_time = max(0.0, tether_time - delta)
		emit_signal("oxygen_changed", oxygen, oxygen_max)
		emit_signal("tether_changed", tether_time, tether_time_max)

func should_retract() -> bool:
	return tether_time <= 0.0 or oxygen <= 0.0

func upgrade_oxygen():
	if points >= 20:
		points -= 20
		oxygen_max += 40
		emit_signal("points_changed", points)

func upgrade_chisel():
	if points >= 15:
		points -= 15
		chisel_strength += 1
		emit_signal("points_changed", points)

func upgrade_tether():
	if points >= 10:
		points -= 10
		tether_time_max += 10.0
		emit_signal("points_changed", points)
