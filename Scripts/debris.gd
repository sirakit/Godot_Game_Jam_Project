extends Node2D

@export var speed: float = 260.0
@export var oxygen_damage: float = 25.0       # ลดจาก 35 เพราะตอนนี้โดนบ่อยขึ้นมาก
@export var lifetime: float = 12.0
@export var homing_time: float = 0.8          # วินาทีแรกเลี้ยวเข้าหาผู้เล่นได้นิดหน่อย
@export var turn_rate_deg: float = 25.0       # องศา/วินาที ต่ำพอให้หลบได้
var direction: Vector2 = Vector2.RIGHT
var target: Node2D = null

var _age: float = 0.0

@onready var hit_area: Area2D = $Area2D

func _ready() -> void:
	z_index = 2
	hit_area.body_entered.connect(_on_body_entered)
	rotation = direction.angle()
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _process(delta: float) -> void:
	_age += delta
	if target != null and is_instance_valid(target) and _age < homing_time:
		var want := (target.global_position - global_position).angle()
		var cur := direction.angle()
		var diff := wrapf(want - cur, -PI, PI)
		var step := deg_to_rad(turn_rate_deg) * delta
		direction = Vector2.from_angle(cur + clampf(diff, -step, step))
		rotation = direction.angle()
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and Game.is_outside:
		Game.oxygen = max(0.0, Game.oxygen - oxygen_damage)
		Game.oxygen_changed.emit(Game.oxygen, Game.oxygen_max)
		Game.debris_hit.emit()
	queue_free()
