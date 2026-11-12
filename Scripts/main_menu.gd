extends Control
## ควบคุมหน้าเมนูหลักให้ทั้งป้ายชื่อ ปุ่ม Start และปุ่ม Quit ลอยเคว้งในอวกาศพร้อมเอฟเฟกต์โต้ตอบเมาส์

@export_group("Title Zero-G Float")
@export var title_amplitude: Vector2 = Vector2(8.0, 14.0)
@export var title_speed: Vector2 = Vector2(1.1, 1.8)
@export var title_tilt_deg: float = 2.8
@export var title_pulse_amount: float = 0.04

@export_group("Buttons Zero-G Float")
@export var btn_amplitude: Vector2 = Vector2(5.0, 8.0)
@export var btn_speed: Vector2 = Vector2(1.3, 2.0)
@export var btn_tilt_deg: float = 2.0
@export var hover_scale_mult: float = 1.12

var _time: float = 0.0
var _title_base_pos: Vector2 = Vector2.ZERO
var _title_base_scale: Vector2 = Vector2.ONE

var _start_base_pos: Vector2 = Vector2.ZERO
var _quit_base_pos: Vector2 = Vector2.ZERO
var _start_hover_scale: Vector2 = Vector2.ONE
var _quit_hover_scale: Vector2 = Vector2.ONE

@onready var title_label: Label = $Title
@onready var btn_start: Button = $BtnStart
@onready var btn_quit: Button = $BtnQuit


func _ready() -> void:
	btn_start.pressed.connect(_on_start_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	
	_title_base_pos = title_label.position
	_title_base_scale = title_label.scale
	_start_base_pos = btn_start.position
	_quit_base_pos = btn_quit.position
	
	# รอ 1 เฟรมให้ Control คำนวณขนาดเสร็จก่อนตั้งจุดหมุนไว้ตรงกลาง
	await get_tree().process_frame
	title_label.pivot_offset = title_label.size * 0.5
	btn_start.pivot_offset = btn_start.size * 0.5
	btn_quit.pivot_offset = btn_quit.size * 0.5
	
	_bind_button_hover(btn_start, true)
	_bind_button_hover(btn_quit, false)


func _process(delta: float) -> void:
	_time += delta
	_update_title_float()
	# ให้ปุ่ม Start และ Quit มีค่า phase ต่างกัน (1.5 และ 3.2) เพื่อจะได้ลอยเหลื่อมจังหวะกันเป็นธรรมชาติ
	_update_button_float(btn_start, _start_base_pos, _start_hover_scale, 1.5, delta)
	_update_button_float(btn_quit, _quit_base_pos, _quit_hover_scale, 3.2, delta)


func _update_title_float() -> void:
	var offset := Vector2(
		sin(_time * title_speed.x) * title_amplitude.x,
		cos(_time * title_speed.y) * title_amplitude.y
	)
	title_label.position = _title_base_pos + offset
	title_label.rotation = deg_to_rad(sin(_time * 1.3) * title_tilt_deg)
	
	var pulse: float = sin(_time * 2.2) * title_pulse_amount
	title_label.scale = _title_base_scale * Vector2(1.0 + pulse, 1.0 - pulse * 0.5)


func _update_button_float(
		btn: Button,
		base_pos: Vector2,
		target_hover_scale: Vector2,
		phase: float,
		delta: float
) -> void:
	var offset := Vector2(
		sin(_time * btn_speed.x + phase) * btn_amplitude.x,
		cos(_time * btn_speed.y + phase) * btn_amplitude.y
	)
	btn.position = base_pos + offset
	btn.rotation = deg_to_rad(sin(_time * 1.6 + phase) * btn_tilt_deg)
	
	var breathe: float = sin(_time * 2.5 + phase) * 0.025
	var wave_scale := Vector2(1.0 + breathe, 1.0 - breathe * 0.5)
	btn.scale = btn.scale.lerp(target_hover_scale * wave_scale, 14.0 * delta)


func _bind_button_hover(btn: Button, is_start_btn: bool) -> void:
	btn.mouse_entered.connect(func() -> void:
		# เด้ง Squash & Stretch ตอนเมาส์ชี้ปุ่ม
		btn.scale = Vector2(hover_scale_mult * 1.1, hover_scale_mult * 0.88)
		if is_start_btn:
			_start_hover_scale = Vector2.ONE * hover_scale_mult
			btn.modulate = Color(1.0, 0.97, 0.97, 1.0)
		else:
			_quit_hover_scale = Vector2.ONE * hover_scale_mult
			btn.modulate = Color(1.0, 0.97, 0.97, 1.0)
	)
	btn.mouse_exited.connect(func() -> void:
		if is_start_btn:
			_start_hover_scale = Vector2.ONE
		else:
			_quit_hover_scale = Vector2.ONE
		btn.modulate = Color.WHITE
	)


func _on_start_pressed() -> void:
	# ยุบปุ่มลงแบบการ์ตูนก่อนเข้าสู่ฉากอวกาศ
	btn_start.disabled = true
	var tw: Tween = create_tween()
	tw.tween_property(btn_start, "scale", Vector2(1.25, 0.75), 0.08)
	tw.tween_property(btn_start, "scale", Vector2.ZERO, 0.12)
	tw.tween_callback(func() -> void:
		Game.reset_all()
		get_tree().change_scene_to_file("res://Scenes/space.tscn")
	)


func _on_quit_pressed() -> void:
	btn_quit.disabled = true
	var tw: Tween = create_tween()
	tw.tween_property(btn_quit, "scale", Vector2(1.25, 0.75), 0.08)
	tw.tween_property(btn_quit, "scale", Vector2.ZERO, 0.1)
	tw.tween_callback(get_tree().quit)
