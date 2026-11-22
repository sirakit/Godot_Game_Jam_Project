class_name MeteoriteSkin
extends Node2D

# ซีนของแต่ละ tier ใช้สคริปต์ลูกของคลาสนี้ ทำเฉพาะเมธอดที่ใช้ ที่เหลือปล่อยว่างได้
@export var rotates: bool = true      # false = ไม่หมุนตามค่า spin ของหิน (เมื่อแอนิเมชันหมุนเอง)

func set_tier(_tier: int) -> void:
	pass

func set_progress(_ratio: float) -> void:     # 0..1 ความคืบหน้าการตอกเปลือก เลื่อนแอนิเมชัน "break"
	pass

func set_heat(_ratio: float) -> void:         # 0..1 ความร้อน (เรืองแสง/สั่น)
	pass

func play_idle() -> void:
	pass

func play_hit() -> void:                      # ทุกครั้งที่ค้อนกระทบ
	pass

func play_reveal() -> void:                   # เปลือกแตก แร่โผล่
	pass

func play_jam() -> void:
	pass

func play_collected() -> void:
	pass
