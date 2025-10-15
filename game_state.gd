extends Node

signal money_changed(amount: int)
signal inventory_changed(items: Array)

const START_MONEY := 100
const ITEM_DISPLAY_NAMES := {
	"wheat": "Weizen",
	"potato": "Kartoffel",
}

var money: int:
	get:
		return _money
	set(value):
		_set_money(value)

var _money: int = START_MONEY
var _inventory: Array[String] = []

func _ready() -> void:
	money_changed.emit(_money)
	inventory_changed.emit(_inventory.duplicate())

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

func add_to_inventory(item_id: String) -> void:
	var entry: String = _resolve_display_name(item_id)
	_inventory.append(entry)
	inventory_changed.emit(_inventory.duplicate())

func get_inventory() -> Array[String]:
	return _inventory.duplicate()

func _resolve_display_name(item_id: String) -> String:
	if ITEM_DISPLAY_NAMES.has(item_id):
		return ITEM_DISPLAY_NAMES[item_id]
	if item_id.is_empty():
		return "Unbekannt"
	return item_id.capitalize()
