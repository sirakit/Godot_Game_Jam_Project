extends Area2D

@export var speed: float = 100.0
var dir: Vector2 = Vector2.LEFT

func _ready():
	body_entered.connect(_on_body_entered)
	# สุ่มทิศทางลอยผ่าน
	dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

func _process(delta):
	global_position += dir * speed * delta

func _on_body_entered(body):
	if body.name == "Player":
		# เมื่อโดนศัตรู ให้ทำลายแร่ในตัว หรือเร่งให้เชือกดึงกลับทันที
		body.inventory_ore = 0 # ดรอปแร่ทิ้งหมด
		body.start_pull_back() # ดึงกลับยานทันที
