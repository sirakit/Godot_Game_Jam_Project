class_name MeteoriteTiers
extends RefCounted

# index 0 = Tier 1 ... index 9 = Tier 10
const HP      := [30.0, 80.0, 150.0, 220.0, 320.0, 420.0, 560.0, 700.0, 850.0, 1000.0]
const DEFENSE := [1.0, 1.0, 1.5, 2.0, 2.5, 3.0, 5.0, 7.0, 9.0, 11.0]
const VALUE   := [10, 16, 26, 42, 65, 100, 150, 225, 340, 500]
const HEAT    := [1.0, 1.0, 1.1, 1.2, 1.3, 1.4, 1.55, 1.7, 1.85, 2.0]     # ความร้อนขึ้นเร็วขึ้น = skill check สูงขึ้น
const SIZE    := [0.80, 0.85, 0.90, 0.95, 1.00, 1.05, 1.15, 1.25, 1.35, 1.50]
const TINTS := [
	Color(0.35, 0.45, 0.85, 0.85), Color(0.30, 0.60, 0.90, 0.85),
	Color(0.25, 0.70, 0.70, 0.85), Color(0.35, 0.75, 0.40, 0.85),
	Color(0.75, 0.75, 0.30, 0.85), Color(0.90, 0.55, 0.25, 0.85),
	Color(0.55, 0.15, 0.85, 0.85), Color(0.75, 0.20, 0.75, 0.85),
	Color(0.90, 0.20, 0.45, 0.85), Color(1.00, 0.85, 0.30, 0.85),
]
const DEF_FLOOR := 0.25      # Drill ไม่พอ ยังตอกได้อย่างน้อย 25% ของความเร็ว

# วงแหวน 5 โซนรอบยาน (รัศมีนอกสุดของแต่ละโซน) ตัวสุดท้ายคือขอบโลก = ระยะเชือกตัน
const ZONE_OUTER  := [1000.0, 2000.0, 3000.0, 4000.0, 5500.0]
const ZONE_TARGET := [9, 10, 11, 12, 14]
# แถว = โซน 1..5, คอลัมน์ = tier 1..10 (น้ำหนัก ไม่ต้องรวมเป็น 100 แต่ผมรวมไว้ให้อ่านง่าย)
const ZONE_WEIGHTS := [
	[55, 35, 10, 0, 0, 0, 0, 0, 0, 0],
	[15, 30, 35, 15, 5, 0, 0, 0, 0, 0],
	[0, 10, 25, 30, 25, 10, 0, 0, 0, 0],
	[0, 0, 0, 10, 20, 30, 25, 15, 0, 0],
	[0, 0, 0, 0, 0, 10, 20, 25, 25, 20],
]

const RARITY_NAMES := ["COMMON", "RARE", "EPIC", "LEGENDARY", "ANCIENT"]
const RARITY_COLORS := [
	Color(0.70, 0.78, 0.70), Color(0.24, 0.59, 0.79), Color(0.85, 0.28, 0.75),
	Color(0.94, 0.62, 0.16), Color(0.79, 0.15, 0.15),
]

# tier 1-2 = COMMON, 3-4 = RARE, 5-6 = EPIC, 7-8 = LEGENDARY, 9-10 = ANCIENT (ตรงกับลำดับใน ArtifactDB)
static func rarity(tier: int) -> int:
	return (clampi(tier, 1, 10) - 1) >> 1

static func zone_of(distance: float) -> int:
	for z in ZONE_OUTER.size():
		if distance < ZONE_OUTER[z]:
			return z
	return ZONE_OUTER.size() - 1

static func zone_inner(z: int) -> float:
	return 0.0 if z == 0 else ZONE_OUTER[z - 1]

static func pick_tier(zone: int) -> int:
	var weights: Array = ZONE_WEIGHTS[clampi(zone, 0, ZONE_WEIGHTS.size() - 1)]
	var total := 0.0
	for w in weights:
		total += w
	var roll := randf() * total
	var acc := 0.0
	for i in weights.size():
		acc += weights[i]
		if weights[i] > 0 and roll <= acc:
			return i + 1
	return 1

# โซนที่ tier นี้เกิดบ่อยที่สุด (ใช้เป็นคำใบ้ในสมุดสะสม)
static func best_zone(tier: int) -> int:
	var best := 0
	for z in ZONE_WEIGHTS.size():
		if ZONE_WEIGHTS[z][tier - 1] > ZONE_WEIGHTS[best][tier - 1]:
			best = z
	return best

static func tier_range(zone: int) -> Vector2i:
	var lo := 99
	var hi := 0
	var w: Array = ZONE_WEIGHTS[zone]
	for i in w.size():
		if w[i] > 0:
			lo = mini(lo, i + 1)
			hi = maxi(hi, i + 1)
	return Vector2i(lo, hi)

static func artifact_name(tier: int) -> String:
	return ArtifactDB.all_names()[clampi(tier, 1, 10) - 1]

static func defense_multiplier(tier: int, drill: float) -> float:
	return clampf(drill / DEFENSE[clampi(tier, 1, 10) - 1], DEF_FLOOR, 1.0)
