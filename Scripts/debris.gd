extends Node2D

@export var speed: float = 260.0
@export var oxygen_damage: float = 35.0
@export var lifetime: float = 12.0
var direction: Vector2 = Vector2.RIGHT

@onready var hit_area: Area2D = $Area2D

func _ready() -> void:
	hit_area.body_entered.connect(_on_body_entered)
	rotation = direction.angle()
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	# เช็ค is_outside กันไว้ ไม่งั้นเศษขยะที่ยังลอยค้างอยู่จะโดนยิงผู้เล่นได้แม้กลับเข้ายานแล้ว
	if body.is_in_group("player") and Game.is_outside:
		Game.oxygen = max(0.0, Game.oxygen - oxygen_damage)
		Game.oxygen_changed.emit(Game.oxygen, Game.oxygen_max)
	queue_free()
