extends Node

signal oxygen_changed(value, max_value)
signal tether_changed(value, max_value)
signal points_changed(value)
signal artifacts_changed(count)
signal trip_ended()
signal upgrades_changed()                      
signal collection_changed()
signal collection_completed()
signal perfect_extraction()
signal debris_hit()
signal dock_penalty_applied(penalty: float, lost: int)
signal artifact_collected(tier: int, artifact_name: String, quality: int, is_new: bool)
signal heat_danger_changed(active: bool)
signal launched()
signal docked(handed_in: int, earned: int)


var restart_progress: float = 0.0

var discovered_artifacts: Dictionary = {}   # ชื่อ -> true
var thrust_speed_bonus: float = 0.0

var oxygen_max: float = 100.0
var oxygen: float = 100.0
var oxygen_drain_rate: float = 4.0

var tether_length_max: float = 500.0           
var tether_remaining: float = 500.0

var chisel_strength: float = 1.0
var drill_strength: float = 1.0                
var income_multiplier: float = 1.0

var points: int = 0
var total_earned: int = 0                       # สถิติสะสม ใช้ไล่ระดับความยาก
var carried_artifacts: Array = []
var is_outside: bool = false

var upgrade_levels := {"oxygen": 0, "chisel": 0, "tether": 0, "drill": 0, "income": 0, "speed": 0}
const UPGRADE_BASE_COST := {"oxygen": 20.0, "chisel": 15.0, "tether": 10.0, "drill": 30.0, "income": 25.0, "speed": 20.0}
const UPGRADE_COST_GROWTH := 1.5                # ราคาโต 50% ทุกเลเวล
const UPGRADE_CAP := 10
const UPGRADE_ORDER := ["oxygen", "chisel", "tether", "drill", "income", "speed"]
const UPGRADE_NAME := {
	"oxygen": "O2 Tank", "chisel": "Chisel", "tether": "Tether",
	"drill": "Drill", "income": "Contract", "speed": "Thrusters",
}
const UPGRADE_DESC := {
	"oxygen": "More time outside the ship before you are forced back.",
	"chisel": "Breaks meteorite HP faster. Works on every tier.",
	"tether": "Fly farther (opens new zones) and move a little faster.",
	"drill": "Shreds meteorite DEF. High tiers mine at only 25% speed without it.",
	"income": "More credits for every artifact you hand in.",
	"speed": "Cross the map faster and save oxygen.",
}
const TETHER_THRUST_BONUS := 100.0
const SPEED_PER_LEVEL := 150.0           # เดิม 75 (Playtest 9: Thrusters ไม่คุ้มราคา)
const RECALL_MIN_DISTANCE := 1000.0
const RECALL_HOLD_TIME := 1.2
const RECALL_FEE := 0.10                 # เรียกยานกลับ: เสีย 10% ของมูลค่าที่ถือ
const OXYGEN_OUT_PENALTY := 0.30         # ออกซิเจนหมดถูกดึงกลับ: เสีย 30%

var touch_mode: bool = false
var ui_modal_open: bool = false
var recall_progress: float = 0.0

var collected_counts: Dictionary = {}   # ชื่อ artifact -> จำนวนที่เก็บ
var best_quality: Dictionary = {}       # ชื่อ artifact -> คุณภาพสูงสุด (%)
var _hot_rocks: Dictionary = {}         # id หินที่ร้อนเกินเส้นอันตรายตอนถูกตอก

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
	launched.emit()

func dock(penalty: float = 0.0) -> void:
	is_outside = false
	var lost := 0
	var handed := carried_artifacts.size()
	var gained := 0
	for a in carried_artifacts:
		var full := int(a["value"] * income_multiplier)
		var earned := int(full * (1.0 - penalty))
		lost += full - earned
		gained += earned
		points += earned
		total_earned += earned
	carried_artifacts.clear()
	points_changed.emit(points)
	artifacts_changed.emit(0)
	trip_ended.emit()
	if lost > 0:
		dock_penalty_applied.emit(penalty, lost)      # ป้ายค่าปรับสำคัญกว่า จึงไม่ซ้อนป้ายสรุป
	else:
		docked.emit(handed, gained)

func add_artifact(art_data: Dictionary) -> void:
	carried_artifacts.append(art_data)
	artifacts_changed.emit(carried_artifacts.size())

	var art_name: String = art_data.get("name", "")
	var tier: int = art_data.get("tier", 0)
	var quality: int = art_data.get("quality", 0)
	var is_new := false
	if ArtifactDB.is_valid(art_name):
		collected_counts[art_name] = int(collected_counts.get(art_name, 0)) + 1
		best_quality[art_name] = maxi(int(best_quality.get(art_name, 0)), quality)
		is_new = not discovered_artifacts.has(art_name)
		if is_new:
			discovered_artifacts[art_name] = true
			collection_changed.emit()
			if discovered_artifacts.size() >= ArtifactDB.all_names().size():
				collection_completed.emit()
	artifact_collected.emit(tier, art_name, quality, is_new)

# หินแต่ละก้อนแจ้งว่า "ร้อนเกินเส้นตอนถูกตอก" หรือเปล่า เตือนเมื่อมีอย่างน้อย 1 ก้อน
func set_rock_hot(id: int, hot: bool) -> void:
	var was := not _hot_rocks.is_empty()
	if hot:
		_hot_rocks[id] = true
	else:
		_hot_rocks.erase(id)
	var now := not _hot_rocks.is_empty()
	if now != was:
		heat_danger_changed.emit(now)

func tick(delta: float) -> void:
	if is_outside:
		oxygen = max(0.0, oxygen - oxygen_drain_rate * delta)
		oxygen_changed.emit(oxygen, oxygen_max)

# เรียกทุกเฟรมจาก player.gd พร้อมระยะจริงจากยาน
func update_tether(distance_from_ship: float) -> void:
	tether_remaining = max(0.0, tether_length_max - distance_from_ship)
	tether_changed.emit(tether_remaining, tether_length_max)

func should_retract() -> bool:
	return oxygen <= 0.0

func is_maxed(id: String) -> bool:
	return upgrade_levels[id] >= UPGRADE_CAP

func _buy(id: String) -> bool:
	if is_maxed(id):
		return false
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
		oxygen_changed.emit(oxygen, oxygen_max)    

func upgrade_chisel() -> void:
	if _buy("chisel"):
		chisel_strength += 1.0

func upgrade_tether() -> void:
	if _buy("tether"):
		tether_length_max += 500.0
		thrust_speed_bonus += TETHER_THRUST_BONUS
		tether_remaining = tether_length_max
		tether_changed.emit(tether_remaining, tether_length_max)

func upgrade_drill() -> void:
	if _buy("drill"):
		drill_strength += 1.0

func upgrade_income() -> void:
	if _buy("income"):
		income_multiplier += 0.25

func upgrade_speed() -> void:
	if _buy("speed"):
		thrust_speed_bonus += SPEED_PER_LEVEL

func reset_all() -> void:                        # ปุ่ม restart 
	oxygen_max = 100.0
	tether_length_max = 500.0
	thrust_speed_bonus = 0.0
	chisel_strength = 1.0
	drill_strength = 1.0
	income_multiplier = 1.0
	points = 0
	total_earned = 0
	recall_progress = 0.0
	carried_artifacts.clear()
	is_outside = false
	
	for k in upgrade_levels.keys():
		upgrade_levels[k] = 0
	
	discovered_artifacts.clear()
	collection_changed.emit()
	reset_trip()
	points_changed.emit(points)
	artifacts_changed.emit(0)
	upgrades_changed.emit()
	collected_counts.clear()
	best_quality.clear()
	_hot_rocks.clear()
	heat_danger_changed.emit(false)
	
# ความเร็วสูงสุดที่เพิ่มต่อแรงขับ 1 หน่วย: dt(1/60) x damping(0.92) / (1 - 0.92) ถ้าเปลี่ยน damping ใน player.gd ต้องแก้ตรงนี้
func speed_gain(thrust_bonus: float) -> int:
	return roundi(thrust_bonus / 60.0 * 0.92 / 0.08)

func effect_text(id: String) -> String:
	match id:
		"oxygen":
			return "Max O2   %d > %d" % [int(oxygen_max), int(oxygen_max + 40.0)]
		"chisel":
			return "Chisel power   %d > %d" % [int(chisel_strength), int(chisel_strength + 1.0)]
		"tether":
			return "Tether   %d > %d px   speed +%d px/s" % [int(tether_length_max), int(tether_length_max + 500.0), speed_gain(TETHER_THRUST_BONUS)]
		"drill":
			return "Drill power   %d > %d" % [int(drill_strength), int(drill_strength + 1.0)]
		"income":
			return "Income   x%.2f > x%.2f" % [income_multiplier, income_multiplier + 0.25]
		"speed":
			return "Top speed   +%d px/s" % speed_gain(SPEED_PER_LEVEL)
	return ""
	
