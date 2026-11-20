extends Node

signal money_changed(new_money: int)
signal stock_updated()
signal day_changed(new_day: int)
signal stats_updated()

const SAVE_PATH = "user://savegame.json"

var money: int = 50000
var day: int = 1
var reputation: int = 100
var stove_upgrade_level: int = 1
var qris_unlocked: bool = false
var fan_upgrade_level: int = 1
var second_wok_unlocked: bool = false

var daily_revenue: int = 0
var daily_expense: int = 0
var daily_customers_served: int = 0
var customers_per_day: int = 6

var toppings: Array = []

func _ready() -> void:
	load_default_toppings()
	load_game()

func load_default_toppings() -> void:
	var file = FileAccess.open("res://data/toppings.json", FileAccess.READ)
	if file:
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed and parsed.has("toppings"):
			toppings = parsed["toppings"]
		file.close()

func save_game() -> void:
	var stock_map = {}
	for t in toppings:
		stock_map[t["id"]] = t["stock"]
	
	var save_data = {
		"money": money,
		"day": day,
		"reputation": reputation,
		"stove_upgrade_level": stove_upgrade_level,
		"qris_unlocked": qris_unlocked,
		"fan_upgrade_level": fan_upgrade_level,
		"second_wok_unlocked": second_wok_unlocked,
		"stock_map": stock_map
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed:
			money = int(parsed.get("money", 50000))
			day = int(parsed.get("day", 1))
			reputation = int(parsed.get("reputation", 100))
			stove_upgrade_level = int(parsed.get("stove_upgrade_level", 1))
			qris_unlocked = bool(parsed.get("qris_unlocked", false))
			fan_upgrade_level = int(parsed.get("fan_upgrade_level", 1))
			second_wok_unlocked = bool(parsed.get("second_wok_unlocked", false))
			var stock_map = parsed.get("stock_map", {})
			for t in toppings:
				if stock_map.has(t["id"]):
					t["stock"] = int(stock_map[t["id"]])
		file.close()

func add_money(amount: int, is_revenue: bool = true) -> void:
	money += amount
	if is_revenue:
		daily_revenue += amount
	emit_signal("money_changed", money)
	save_game()

func spend_money(amount: int, is_expense: bool = true) -> bool:
	if money >= amount:
		money -= amount
		if is_expense:
			daily_expense += amount
		emit_signal("money_changed", money)
		save_game()
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
			save_game()
			return

func restock_topping(index: int) -> bool:
	if index < 0 or index >= toppings.size():
		return false
	var item = toppings[index]
	var pack_cost = int(item["buy_price"]) * 5
	if spend_money(pack_cost, true):
		item["stock"] += 5
		emit_signal("stock_updated")
		return true
	return false

func upgrade_stove() -> bool:
	var cost = stove_upgrade_level * 35000
	if spend_money(cost, true):
		stove_upgrade_level += 1
		emit_signal("stats_updated")
		return true
	return false

func unlock_qris() -> bool:
	if qris_unlocked:
		return false
	if spend_money(40000, true):
		qris_unlocked = true
		emit_signal("stats_updated")
		return true
	return false

func upgrade_fan() -> bool:
	var cost = fan_upgrade_level * 25000
	if spend_money(cost, true):
		fan_upgrade_level += 1
		emit_signal("stats_updated")
		return true
	return false

func unlock_second_wok() -> bool:
	if second_wok_unlocked:
		return false
	if spend_money(60000, true):
		second_wok_unlocked = true
		emit_signal("stats_updated")
		return true
	return false

func start_next_day() -> void:
	var daily_rent = 15000
	money = max(0, money - daily_rent)
	day += 1
	customers_per_day = min(12, 5 + day)
	daily_revenue = 0
	daily_expense = 0
	daily_customers_served = 0
	emit_signal("day_changed", day)
	emit_signal("money_changed", money)
	save_game()
