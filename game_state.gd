extends Node

signal money_changed(amount: int)

const START_MONEY := 100

var money: int:
	get:
		return _money
	set(value):
		_set_money(value)

var _money: int = START_MONEY

func _ready() -> void:
	money_changed.emit(_money)

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
