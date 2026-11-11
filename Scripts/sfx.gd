extends Node

const DIR := "res://Assets/audio/sfx/"
const EXTS := [".wav", ".ogg", ".mp3"]
const VOICES := 8                    # เล่นซ้อนกันได้พร้อมกัน 8 เสียง

var _voices: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}          # id -> AudioStream (หรือ null ถ้าไม่มีไฟล์ จะได้ไม่หาซ้ำ)
var _loop: AudioStreamPlayer
var _loop_id: String = ""
var _levels: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS        # เมนู pause ยังมีเสียงปุ่ม
	var bus := "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		add_child(p)
		_voices.append(p)
	_loop = AudioStreamPlayer.new()
	_loop.bus = bus
	_loop.finished.connect(_on_loop_finished)
	add_child(_loop)

	# ฟังสัญญาณที่มีอยู่แล้ว ไม่ต้องแก้ไฟล์อื่น
	Game.perfect_extraction.connect(play.bind("perfect"))
	Game.debris_hit.connect(play.bind("debris_hit"))
	Game.trip_ended.connect(play.bind("dock"))
	Game.launched.connect(play.bind("launch"))
	Game.artifact_collected.connect(_on_collected)
	Game.heat_danger_changed.connect(_on_heat_danger)
	Game.upgrades_changed.connect(_on_upgrades)

# หาไฟล์ครั้งแรกแล้วจำไว้ ไม่มีไฟล์ = เงียบ ไม่ error เพิ่มเสียงทีละไฟล์ได้เลย
func _stream(id: String) -> AudioStream:
	if _cache.has(id):
		return _cache[id]
	var s: AudioStream = null
	for e in EXTS:
		var path: String = DIR + id + e
		if ResourceLoader.exists(path):
			s = load(path) as AudioStream
			break
	_cache[id] = s
	return s

func play(id: String, pitch_variance: float = 0.0) -> void:
	var s := _stream(id)
	if s == null:
		return
	for p in _voices:
		if not p.playing:
			p.stream = s
			p.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
			p.play()
			return

func loop_start(id: String) -> void:
	var s := _stream(id)
	if s == null or _loop_id == id:
		return
	_loop_id = id
	_loop.stream = s
	_loop.play()

func loop_stop() -> void:
	_loop_id = ""
	_loop.stop()

func _on_loop_finished() -> void:      # วนซ้ำด้วยโค้ด ไม่ต้องตั้ง Loop ในแผง Import
	if _loop_id != "":
		_loop.play()

func _on_collected(_tier: int, _artifact_name: String, _quality: int, is_new: bool) -> void:
	if is_new and _stream("discovery") != null:
		play("discovery")
	else:
		play("collect", 0.05)

func _on_heat_danger(active: bool) -> void:
	if active:
		loop_start("heat_warning")
	else:
		loop_stop()

func _on_upgrades() -> void:           # upgrades_changed ยิงตอน restart ด้วย จึงเทียบผลรวมเลเวล
	var total := 0
	for v in Game.upgrade_levels.values():
		total += v
	if total > _levels:
		play("upgrade")
	_levels = total
