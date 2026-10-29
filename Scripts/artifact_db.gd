class_name ArtifactDB
extends RefCounted

const COMMON_NAMES := ["Basalt Shard", "Iron Nodule"]
const RARE_NAMES := [ "Carbon Chondrite", "Quartz Cluster"]
const EPIC_NAMES := ["Silica, Geode", "Nickel Vein"]
const LEGENDARY_NAMES := ["Sapphire Core", "Voidglass Crystal"]
const ANCIENT_NAMES := ["Star Iron Ingot", "Ancient Alloy Relic"]
const SPRITE_DIR := ""

static func all_names() -> Array:
	return COMMON_NAMES + RARE_NAMES + EPIC_NAMES + LEGENDARY_NAMES + ANCIENT_NAMES

static func is_valid(artifact_name: String) -> bool:
	return artifact_name in COMMON_NAMES or artifact_name in RARE_NAMES or artifact_name in EPIC_NAMES or artifact_name in LEGENDARY_NAMES or artifact_name in ANCIENT_NAMES
	

static func is_rare(artifact_name: String) -> bool:
	return artifact_name in RARE_NAMES
	
static func is_epic(artifact_name: String) -> bool:
	return artifact_name in EPIC_NAMES
	
static func is_legendary(artifact_name: String) -> bool:
	return artifact_name in LEGENDARY_NAMES
	
static func is_ancient(artifact_name: String) -> bool:
	return artifact_name in ANCIENT_NAMES


# กติกาชื่อไฟล์: ชื่อ artifact แปลงเป็น snake_case + ".png"
# "Basalt Shard" -> Assets/sprites/artifacts/basalt_shard.png
# ยังไม่มีไฟล์ = คืน null (meteorite.gd จะใช้ลูกแก้วชั่วคราวแทน เกมไม่พัง)
static func get_texture(artifact_name: String) -> Texture2D:
	var path := SPRITE_DIR + artifact_name.to_snake_case() + ".png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null
