extends Node

signal money_changed(amount: int)
signal inventory_changed(storage: Dictionary)
signal supplies_changed(supplies: Dictionary)
signal market_log_updated(entries: Array)

const START_MONEY := 100
const ITEM_DISPLAY_NAMES := {
	"wheat": "Weizen",
	"potato": "Kartoffel",
	"wheat_seed": "Weizen-Samen",
	"potato_seed": "Kartoffel-Samen",
	"basic_fertilizer": "Basisduenger",
	"premium_fertilizer": "Premiumduenger",
}
const ITEM_SELL_PRICES := {
	"wheat": 15,
	"potato": 20,
}
const MARKET_CATALOG := {
	"seeds": [
		{"id": "wheat_seed", "price": 5},
		{"id": "potato_seed", "price": 7},
	],
	"fertilizer": [
		{"id": "basic_fertilizer", "price": 12},
		{"id": "premium_fertilizer", "price": 24},
	],
}
const MARKET_LOG_LIMIT := 20

var money: int:
	get:
		return _money
	set(value):
		_set_money(value)

var _money: int = START_MONEY
var _storage: Dictionary = {}
var _supplies: Dictionary = {}
var _market_log: Array = []

func _ready() -> void:
	money_changed.emit(_money)
	inventory_changed.emit(_storage.duplicate(true))
	supplies_changed.emit(_supplies.duplicate(true))
	market_log_updated.emit(_market_log.duplicate(true))

func _set_money(value: int) -> void:
	var clamped: int = value if value >= 0 else 0
	if _money == clamped:
		return
	_money = clamped
	money_changed.emit(_money)

func add_money(amount: int) -> void:
	if amount == 0:
		return
	_set_money(_money + amount)

func try_spend(amount: int) -> bool:
	if amount < 0:
		return false
	if _money < amount:
		return false
	_set_money(_money - amount)
	return true

func add_to_inventory(item_id: String, tons: float = 1.0) -> void:
	if tons <= 0.0:
		return
	var current: float = _storage.get(item_id, 0.0)
	_storage[item_id] = current + tons
	inventory_changed.emit(_storage.duplicate(true))

func get_inventory() -> Dictionary:
	return _storage.duplicate(true)

func get_supplies() -> Dictionary:
	return _supplies.duplicate(true)

func get_supply_amount(item_id: String) -> int:
	return int(_supplies.get(item_id, 0))

func get_market_catalog() -> Dictionary:
	return MARKET_CATALOG.duplicate(true)

func get_market_log() -> Array:
	return _market_log.duplicate(true)

func get_market_price(item_id: String) -> int:
	var entry := _find_market_entry(item_id)
	if entry.is_empty():
		return 0
	return int(entry.get("price", 0))

func can_buy_market_item(item_id: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	var price := get_market_price(item_id)
	if price <= 0:
		return false
	var total_cost := price * quantity
	return _money >= total_cost

func buy_market_item(item_id: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	var entry := _find_market_entry(item_id)
	if entry.is_empty():
		return false
	var price: int = int(entry.get("price", 0))
	if price <= 0:
		return false
	var total_cost: int = price * quantity
	if not try_spend(total_cost):
		return false
	var current: int = int(_supplies.get(item_id, 0))
	_supplies[item_id] = current + quantity
	supplies_changed.emit(_supplies.duplicate(true))
	_append_market_log({
		"type": "purchase",
		"actor": "Spieler",
		"item_id": item_id,
		"amount": float(quantity),
		"unit_price": price,
		"total_price": total_cost,
		"unit": "Stk",
	})
	return true

func has_supply(item_id: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	return int(_supplies.get(item_id, 0)) >= quantity

func consume_supply(item_id: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	var current: int = int(_supplies.get(item_id, 0))
	if current < quantity:
		return false
	if current == quantity:
		_supplies.erase(item_id)
	else:
		_supplies[item_id] = current - quantity
	supplies_changed.emit(_supplies.duplicate(true))
	return true

func get_display_name(item_id: String) -> String:
	return _resolve_display_name(item_id)

func get_storage_amount(item_id: String) -> float:
	return float(_storage.get(item_id, 0.0))

func get_sell_price(item_id: String) -> int:
	return ITEM_SELL_PRICES.get(item_id, 0)

func sell_from_inventory(item_id: String, tons: float) -> bool:
	if tons <= 0.0:
		return false
	if not _storage.has(item_id):
		return false
	var available: float = float(_storage[item_id])
	var amount_to_sell: float = clamp(tons, 0.0, available)
	if amount_to_sell <= 0.0:
		return false
	var remaining: float = available - amount_to_sell
	if remaining <= 0.0001:
		_storage.erase(item_id)
	else:
		_storage[item_id] = remaining
	inventory_changed.emit(_storage.duplicate(true))
	var price_per_ton: int = get_sell_price(item_id)
	if price_per_ton > 0:
		var payout: int = int(round(amount_to_sell * float(price_per_ton)))
		if payout > 0:
			add_money(payout)
			_append_market_log({
				"type": "sale",
				"actor": "Spieler",
				"item_id": item_id,
				"amount": amount_to_sell,
				"unit_price": price_per_ton,
				"total_price": payout,
				"unit": "t",
			})
	return true

func _find_market_entry(item_id: String) -> Dictionary:
	for category_entries in MARKET_CATALOG.values():
		for entry in category_entries:
			if entry.get("id", "") == item_id:
				return entry
	return {}

func _append_market_log(entry: Dictionary) -> void:
	var safe_entry := entry.duplicate(true)
	if not safe_entry.has("timestamp"):
		safe_entry["timestamp"] = Time.get_ticks_msec()
	_market_log.append(safe_entry)
	if _market_log.size() > MARKET_LOG_LIMIT:
		_market_log.pop_front()
	market_log_updated.emit(_market_log.duplicate(true))

func _resolve_display_name(item_id: String) -> String:
	if ITEM_DISPLAY_NAMES.has(item_id):
		return ITEM_DISPLAY_NAMES[item_id]
	if item_id.is_empty():
		return "Unbekannt"
	return item_id.capitalize()
