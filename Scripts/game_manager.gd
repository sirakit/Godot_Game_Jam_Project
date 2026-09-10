extends Node2D

var credits: int = 0
var fuel: float = 100.0
var target_fuel_to_win: float = 300.0
@export var fuel_drain_rate: float = 2.0 # เชื้อเพลิงลดลงเรื่อยๆ ตามเวลา
@export var fuel_price: int = 10 # ราคาต่อการเติมเชื้อเพลิง 10 หน่วย

@onready var player = $Player
@onready var ship = $Ship

func _ready():
	player.ship_position = ship.global_position
	player.returned_to_ship.connect(_on_player_returned)

func _process(delta):
	# เชื้อเพลิงลดลงตามเวลาเป็นการกดดัน
	fuel -= fuel_drain_rate * delta
	if fuel <= 0:
		print("GAME OVER: Fuel Depleted!")
		set_process(false)

func _on_player_returned():
	# เมื่อกลับถึงยาน ให้ขายแร่ทั้งหมด
	if player.inventory_ore > 0:
		var earned = player.inventory_ore * 20
		credits += earned
		print("Sold Ores! Earned: $", earned, " Total Credits: $", credits)
		player.inventory_ore = 0

# ฟังก์ชั่นกดซื้อเชื้อเพลิง (เรียกใช้ผ่าน UI/กดปุ่ม)
func buy_fuel():
	if credits >= fuel_price:
		credits -= fuel_price
		fuel += 20.0
		print("Bought Fuel! Current Fuel: ", fuel)
		if fuel >= target_fuel_to_win:
			print("YOU WIN! Reached Home!")
