extends Node

signal money_changed(new_money: int)
signal stock_updated()
signal day_changed(new_day: int)

var money: int = 50000 # Modal awal Rp 50.000
var day: int = 1
var reputation: int = 100
var stove_upgrade_level: int = 1 # Kecepatan masak
var toppings: Array = []

func _ready() -> void:
	load_toppings_data()

func load_toppings_data() -> void:
	var file = FileAccess.open("res://data/toppings.json", FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		var parsed = JSON.parse_string(json_text)
		if parsed and parsed.has("toppings"):
			toppings = parsed["toppings"]
		file.close()

func add_money(amount: int) -> void:
	money += amount
	emit_signal("money_changed", money)

func spend_money(amount: int) -> bool:
	if money >= amount:
		money -= amount
		emit_signal("money_changed", money)
		return true
	return false

func get_available_toppings() -> Array:
	var available = []
	for t in toppings:
		if t["stock"] > 0:
			available.append(t)
	return available

func consume_topping(topping_id: String) -> void:
	for t in toppings:
		if t["id"] == topping_id and t["stock"] > 0:
			t["stock"] -= 1
			emit_signal("stock_updated")
			return

func restock_topping(index: int) -> bool:
	if index < 0 or index >= toppings.size():
		return false
	var item = toppings[index]
	var pack_cost = item["buy_price"] * 5 # Beli 5 porsi sekaligus
	if spend_money(pack_cost):
		item["stock"] += 5
		emit_signal("stock_updated")
		return true
	return false

func upgrade_stove() -> bool:
	var cost = stove_upgrade_level * 35000
	if spend_money(cost):
		stove_upgrade_level += 1
		return true
	return false
