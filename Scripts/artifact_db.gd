class_name ArtifactDB
extends RefCounted

const COMMON_NAMES := ["Basalt Shard", "Iron Nodule", "Quartz Cluster", "Carbon Chondrite", "Nickel Vein", "Silica Geode"]
const RARE_NAMES := ["Sapphire Core", "Voidglass Crystal", "Star Iron Ingot", "Ancient Alloy Relic"]
const SPRITE_DIR := "res://Assets/sprites/artifacts/"

static func all_names() -> Array:
	return COMMON_NAMES + RARE_NAMES

static func is_valid(artifact_name: String) -> bool:
	return artifact_name in COMMON_NAMES or artifact_name in RARE_NAMES

static func is_rare(artifact_name: String) -> bool:
	return artifact_name in RARE_NAMES

# กติกาชื่อไฟล์: ชื่อ artifact แปลงเป็น snake_case + ".png"
# "Basalt Shard" -> Assets/sprites/artifacts/basalt_shard.png
# ยังไม่มีไฟล์ = คืน null (meteorite.gd จะใช้ลูกแก้วชั่วคราวแทน เกมไม่พัง)
static func get_texture(artifact_name: String) -> Texture2D:
	var path := SPRITE_DIR + artifact_name.to_snake_case() + ".png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null
