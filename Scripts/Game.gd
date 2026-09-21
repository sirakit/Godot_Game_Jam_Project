extends Node

signal oxygen_changed(value, max_value)
signal tether_changed(value, max_value)
signal points_changed(value)
signal artifacts_changed(count)
signal trip_ended()
signal upgrades_changed()                       # ใหม่: ให้ปุ่มรีเฟรชราคา/เลเวลเอง

var oxygen_max: float = 100.0
var oxygen: float = 100.0
var oxygen_drain_rate: float = 4.0

var tether_length_max: float = 500.0           # เปลี่ยนจาก "วินาที" เป็น "พิกเซล"
var tether_remaining: float = 500.0

var chisel_strength: float = 1.0
var drill_strength: float = 1.0                 # เดิมประกาศไว้แต่ไม่เคยถูกใช้ — ตอนนี้ใช้จริงกับ V2
var income_multiplier: float = 1.0

var points: int = 0
var total_earned: int = 0                       # สถิติสะสม ใช้ไล่ระดับความยาก
var carried_artifacts: Array = []
var is_outside: bool = false

var upgrade_levels := {"oxygen": 0, "chisel": 0, "tether": 0, "drill": 0, "income": 0}
const UPGRADE_BASE_COST := {"oxygen": 20.0, "chisel": 15.0, "tether": 10.0, "drill": 30.0, "income": 25.0}
const UPGRADE_COST_GROWTH := 1.5                # ราคาโต 50% ทุกเลเวล

func get_upgrade_cost(id: String) -> int:
	return int(UPGRADE_BASE_COST[id] * pow(UPGRADE_COST_GROWTH, upgrade_levels[id]))

func reset_trip() -> void:
	oxygen = oxygen_max
	tether_remaining = tether_length_max
	oxygen_changed.emit(oxygen, oxygen_max)
	tether_changed.emit(tether_remaining, tether_length_max)

func start_outside() -> void:
	is_outside = true
	reset_trip()

func dock() -> void:
	is_outside = false
	for a in carried_artifacts:
		var earned := int(a["value"] * income_multiplier)
		points += earned
		total_earned += earned
	carried_artifacts.clear()
	points_changed.emit(points)
	artifacts_changed.emit(0)
	trip_ended.emit()

func add_artifact(art_data: Dictionary) -> void:
	carried_artifacts.append(art_data)
	artifacts_changed.emit(carried_artifacts.size())

func tick(delta: float) -> void:
	if is_outside:
		oxygen = max(0.0, oxygen - oxygen_drain_rate * delta)
		oxygen_changed.emit(oxygen, oxygen_max)

# เรียกทุกเฟรมจาก player.gd พร้อมระยะจริงจากยาน
func update_tether(distance_from_ship: float) -> void:
	tether_remaining = max(0.0, tether_length_max - distance_from_ship)
	tether_changed.emit(tether_remaining, tether_length_max)

# เชือกไม่ทำให้จบทริปแล้ว — มันเป็น "กำแพง" ส่วน oxygen เป็น "นาฬิกา"
func should_retract() -> bool:
	return oxygen <= 0.0

func _buy(id: String) -> bool:
	var cost := get_upgrade_cost(id)
	if points < cost:
		return false
	points -= cost
	upgrade_levels[id] += 1
	points_changed.emit(points)
	upgrades_changed.emit()
	return true

func upgrade_oxygen() -> void:
	if _buy("oxygen"):
		oxygen_max += 40.0
		oxygen = oxygen_max
		oxygen_changed.emit(oxygen, oxygen_max)    # <-- บั๊กเดิม: ไม่เคย emit บาร์เลยค้าง

func upgrade_chisel() -> void:
	if _buy("chisel"):
		chisel_strength += 1.0

func upgrade_tether() -> void:
	if _buy("tether"):
		tether_length_max += 300.0
		tether_remaining = tether_length_max
		tether_changed.emit(tether_remaining, tether_length_max)

func upgrade_drill() -> void:
	if _buy("drill"):
		drill_strength += 1.0

func upgrade_income() -> void:
	if _buy("income"):
		income_multiplier += 0.25

func reset_all() -> void:                        # สำหรับปุ่ม restart (playtest 1)
	oxygen_max = 100.0
	tether_length_max = 500.0
	chisel_strength = 1.0
	drill_strength = 1.0
	income_multiplier = 1.0
	points = 0
	total_earned = 0
	carried_artifacts.clear()
	is_outside = false
	for k in upgrade_levels.keys():
		upgrade_levels[k] = 0
	reset_trip()
	points_changed.emit(points)
	artifacts_changed.emit(0)
	upgrades_changed.emit()
