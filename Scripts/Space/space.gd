extends Node2D

const RESTART_HOLD_TIME := 1.2
const DEBUG_PRESSES := 5              # debug cheats (debug builds only): press the key this many times...
const DEBUG_WINDOW := 2.0             # ...within this many seconds.   L = unlock whole log,  U = max all upgrades

@onready var ship: Node2D = $Ship
@onready var player: CharacterBody2D = $Player
@onready var rope_line: Line2D = $RopeLine

var _restart_hold: float = 0.0
var _restart_armed: bool = false
var _debug_l_times: Array[float] = []
var _debug_u_times: Array[float] = []

func _ready() -> void:
	get_viewport().physics_object_picking = true
	player.set_ship_position(ship.global_position)
	rope_line.width = 3.0
	_ensure_action("restart", KEY_R)
	_ensure_action("toggle_log", KEY_C)
	_ensure_action("recall", KEY_F)

	var rings := ZoneRings.new()
	add_child(rings)
	move_child(rings, $SpaceBackground.get_index() + 1)       # ให้วาดทับพื้นหลังแต่อยู่ใต้หินและผู้เล่น
	rings.global_position = ship.global_position
	add_child(NavHud.new())
	Game.restart_progress = 0.0
	_restart_armed = not Input.is_action_pressed("restart")   # ถ้ายังกดค้างจากรอบก่อน ต้องปล่อยก่อน

# สร้าง action ให้อัตโนมัติถ้ายังไม่มีใน Input Map (ใช้ physical key เหมือน WASD)
func _ensure_action(action: String, key: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)

func _process(delta: float) -> void:
	rope_line.visible = Game.is_outside
	rope_line.clear_points()
	rope_line.add_point(ship.global_position)
	rope_line.add_point(player.global_position)
	var t: float = 1.0 - (Game.tether_remaining / max(1.0, Game.tether_length_max))
	rope_line.default_color = Color(1.0, 1.0 - t * 0.85, 1.0 - t * 0.9)

	if Input.is_action_pressed("restart"):
		if _restart_armed:
			_restart_hold += delta
			Game.restart_progress = clampf(_restart_hold / RESTART_HOLD_TIME, 0.0, 1.0)
			if _restart_hold >= RESTART_HOLD_TIME:
				Game.reset_all()
				get_tree().reload_current_scene()
	else:
		_restart_armed = true
		_restart_hold = 0.0
		Game.restart_progress = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_L and _debug_mashed(_debug_l_times):
			Game.debug_unlock_all_logs()
		elif event.physical_keycode == KEY_U and _debug_mashed(_debug_u_times):
			Game.debug_max_all_upgrades()
	if event.is_action_pressed("toggle_log"):
		var log_panel := get_node("CanvasLayer2/UI/CollectionLog")
		log_panel.visible = not log_panel.visible

# DEBUG: records a key press and returns true once it was pressed DEBUG_PRESSES times within DEBUG_WINDOW seconds
func _debug_mashed(times: Array[float]) -> bool:
	var now: float = Time.get_ticks_msec() / 1000.0
	times.append(now)
	while not times.is_empty() and now - times[0] > DEBUG_WINDOW:
		times.pop_front()
	if times.size() >= DEBUG_PRESSES:
		times.clear()
		return true
	return false
