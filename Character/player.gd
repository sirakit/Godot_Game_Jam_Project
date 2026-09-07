extends CharacterBody2D


@export var max_speed: float = 400.0
# แรงเร่งความเร็ว (ยิ่งเยอะยิ่งออกตัวไว)
@export var acceleration: float = 800.0
# แรงต้านในอวกาศ (ยิ่งน้อยยิ่งลอยไปไกลหลุดมือ/ยิ่งเยอะยิ่งหยุดง่าย)
@export var friction: float = 200.0


func _physics_process(delta: float) -> void:
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_direction != Vector2.ZERO:
		velocity = velocity.move_toward(input_direction * max_speed, acceleration * delta)
		rotation = input_direction.angle()
	else:
		# 4. หากปล่อยปุ่ม ให้ค่อยๆ ลดความเร็วลงตามแรงต้านต่ำๆ ในอวกาศ (จะไม่หยุดทันที)
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()
