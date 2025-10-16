extends Node

signal money_changed(amount: int)
signal inventory_changed(storage: Dictionary)

const START_MONEY := 100
const ITEM_DISPLAY_NAMES := {
	"wheat": "Weizen",
	"potato": "Kartoffel",
}
const ITEM_SELL_PRICES := {
	"wheat": 15,
	"potato": 20,
}

var money: int:
	get:
		return _money
	set(value):
		_set_money(value)

var _money: int = START_MONEY
var _storage: Dictionary = {}

func _ready() -> void:
	money_changed.emit(_money)
	inventory_changed.emit(_storage.duplicate(true))

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
	return true

func _resolve_display_name(item_id: String) -> String:
	if ITEM_DISPLAY_NAMES.has(item_id):
		return ITEM_DISPLAY_NAMES[item_id]
	if item_id.is_empty():
		return "Unbekannt"
	return item_id.capitalize()
