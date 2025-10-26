extends Node

signal money_changed(amount: int)
signal inventory_changed(storage: Dictionary)
signal supplies_changed(supplies: Dictionary)
signal market_log_updated(entries: Array)
signal rent_cost_changed(hourly_cost: int)
signal research_state_changed(state: Dictionary)
signal farmers_changed(farmers: Array)
signal fields_changed(field_names: Array)
signal build_catalog_changed(catalog: Dictionary)
signal build_mode_changed(build_id: String)
signal build_constructed(build_id: String, data: Dictionary)
signal field_growth_changed(field_name: String, info: Dictionary)

const START_MONEY := 100
const ITEM_DISPLAY_NAMES := {
	"wheat": "Weizen",
	"potato": "Kartoffel",
	"wheat_seed": "Weizen-Samen",
	"potato_seed": "Kartoffel-Samen",
	"basic_fertilizer": "Basisduenger",
	"premium_fertilizer": "Premiumduenger",
	"field_rent": "Feldmiete",
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
const FERTILIZER_DEFINITIONS := {
	"basic_fertilizer": {
		"effects": [
			{"type": "yield_bonus", "value": 0.1},
		],
	},
	"premium_fertilizer": {
		"effects": [
			{"type": "yield_bonus", "value": 0.25},
		],
	},
}
const MARKET_LOG_LIMIT := 20
const FIELD_RENT_PER_HOUR := 5
const RENT_INTERVAL_SECONDS := 3600.0
const FIELD_STATE_EMPTY := 0
const FIELD_STATE_GROWING := 1
const FIELD_STATE_READY := 2
const FARMER_STATUS_IDLE := "idle"
const FARMER_STATUS_ASSIGNED := "assigned"
const FARMER_AUTO_HARVEST_DELAY := 1.5
const ITEM_CATEGORY_HARVESTED := "harvested"
const ITEM_CATEGORY_SEEDS := "seeds"
const ITEM_CATEGORY_FERTILIZER := "fertilizer"
const ITEM_CATEGORY_UNKNOWN := "other"
const ITEM_CATEGORY_DISPLAY_NAMES := {
	ITEM_CATEGORY_SEEDS: "Samen",
	ITEM_CATEGORY_FERTILIZER: "Duenger",
	ITEM_CATEGORY_HARVESTED: "Geerntet",
	ITEM_CATEGORY_UNKNOWN: "Sonstiges",
}
const ITEM_UNITS := {
	ITEM_CATEGORY_SEEDS: "Stk",
	ITEM_CATEGORY_FERTILIZER: "Stk",
	ITEM_CATEGORY_HARVESTED: "t",
}
const BUILD_CATALOG := {
	"field_basic": {
		"label": "Ackerfeld",
		"description": "Erzeugt zusaetzliche Flaeche fuer den Anbau.",
		"cost": 10,
		"category": "field",
		"category_label": "Felder",
		"shape": "box",
		"size": Vector3(1.0, 0.2, 1.0),
		"color": Color(0.42, 0.26, 0.12),
		"snap": 1.0,
		"build_type": "field",
		"scene": "res://Tile.tscn",
	},
	"road_straight": {
		"label": "Strasse",
		"description": "Gerade Strasse, perfekt um Felder zu verbinden.",
		"cost": 25,
		"category": "road",
		"category_label": "Strassen",
		"shape": "box",
		"size": Vector3(4.0, 0.15, 1.0),
		"color": Color(0.2, 0.2, 0.2),
	},
	"road_concrete": {
		"label": "Betonstrasse",
		"description": "Verstaerkte Fahrbahn fuer schwere Fahrzeuge.",
		"cost": 55,
		"category": "road",
		"category_label": "Strassen",
		"shape": "box",
		"size": Vector3(4.0, 0.2, 1.2),
		"color": Color(0.35, 0.35, 0.4),
	},
	"road_dirt": {
		"label": "Feldweg",
		"description": "Ein einfacher Weg aus festgefahrener Erde.",
		"cost": 12,
		"category": "road",
		"category_label": "Strassen",
		"shape": "box",
		"size": Vector3(4.0, 0.1, 1.0),
		"color": Color(0.4, 0.32, 0.2),
	},
	"decor_planter": {
		"label": "Blumenkuebel",
		"description": "Dekoratives Element fuer deinen Hof.",
		"cost": 35,
		"category": "decor",
		"category_label": "Dekoration",
		"shape": "cylinder",
		"size": Vector3(0.9, 1.1, 0.9),
		"color": Color(0.7, 0.5, 0.2),
	},
	"decor_tree": {
		"label": "Baum",
		"description": "Sorgt fuer Schatten und Atmosphaere.",
		"cost": 45,
		"category": "decor",
		"category_label": "Dekoration",
		"shape": "capsule",
		"size": Vector3(1.2, 3.0, 1.2),
		"color": Color(0.18, 0.45, 0.18),
	},
	"power_wind_turbine": {
		"label": "Windrad",
		"description": "Erzeugt Strom aus Windkraft.",
		"cost": 140,
		"category": "power",
		"category_label": "Stromerzeugung",
		"shape": "cylinder",
		"size": Vector3(2.5, 12.0, 2.5),
		"color": Color(0.75, 0.75, 0.8),
	},
	"power_solar_array": {
		"label": "Solarfeld",
		"description": "Paneele fuers Sammeln von Sonnenenergie.",
		"cost": 110,
		"category": "power",
		"category_label": "Stromerzeugung",
		"shape": "box",
		"size": Vector3(4.0, 0.4, 3.5),
		"color": Color(0.15, 0.2, 0.25),
	},
	"irrigation_sprinkler": {
		"label": "Beregnungsanlage",
		"description": "Rotierender Sprinkler fuer gleichmaessige Bewaesserung.",
		"cost": 65,
		"category": "irrigation",
		"category_label": "Bewaesserung",
		"shape": "cylinder",
		"size": Vector3(1.5, 1.2, 1.5),
		"color": Color(0.3, 0.5, 0.7),
	},
	"irrigation_water_tower": {
		"label": "Wasserturm",
		"description": "Speichert Wasser und erhoeht den Druck.",
		"cost": 180,
		"category": "irrigation",
		"category_label": "Bewaesserung",
		"shape": "box",
		"size": Vector3(2.5, 8.0, 2.5),
		"color": Color(0.65, 0.6, 0.5),
	},
}
const RESEARCH_TYPE_YIELD := "yield"
const RESEARCH_TYPE_SPEED := "speed"
const CROP_CONFIG := {
	"wheat": {
		"seed_id": "wheat_seed",
		"base_growth_seconds": 10.0,
		"base_yield": 1.0,
		"min_growth_seconds": 2.0,
		"research": {
			RESEARCH_TYPE_YIELD: {
				"label": "Ertrag",
				"description": "Erhoeht die Erntemenge pro Feld.",
				"base_cost": 75,
				"cost_factor": 1.6,
				"max_level": 5,
				"bonus_per_level": 0.2,
				"max_total_bonus": 1.0,
			},
			RESEARCH_TYPE_SPEED: {
				"label": "Wachstum",
				"description": "Reduziert die Wachstumsdauer bis zur Ernte.",
				"base_cost": 95,
				"cost_factor": 1.65,
				"max_level": 5,
				"bonus_per_level": 0.1,
				"max_total_bonus": 0.5,
				"min_multiplier": 0.4,
				"min_seconds": 2.0,
			},
		},
	},
	"potato": {
		"seed_id": "potato_seed",
		"base_growth_seconds": 10.0,
		"base_yield": 1.0,
		"min_growth_seconds": 2.0,
		"research": {
			RESEARCH_TYPE_YIELD: {
				"label": "Ertrag",
				"description": "Erhoeht die Erntemenge pro Feld.",
				"base_cost": 90,
				"cost_factor": 1.7,
				"max_level": 5,
				"bonus_per_level": 0.2,
				"max_total_bonus": 1.0,
			},
			RESEARCH_TYPE_SPEED: {
				"label": "Wachstum",
				"description": "Reduziert die Wachstumsdauer bis zur Ernte.",
				"base_cost": 110,
				"cost_factor": 1.75,
				"max_level": 5,
				"bonus_per_level": 0.1,
				"max_total_bonus": 0.5,
				"min_multiplier": 0.4,
				"min_seconds": 2.0,
			},
		},
	},
}

var money: int:
	get:
		return _money
	set(value):
		_set_money(value)

var _money: int = START_MONEY
var _storage: Dictionary = {}
var _supplies: Dictionary = {}
var _market_log: Array = []
var _paying_field_count: int = 0
var _rent_timer: Timer = null
var _research_state: Dictionary = {}
var _farmers: Array = []
var _farmer_id_counter: int = 1
var _field_assignments: Dictionary = {}
var _field_nodes: Dictionary = {}
var _known_field_names: Array[String] = []
var _pending_auto_harvest: Dictionary = {}
var _build_catalog: Dictionary = BUILD_CATALOG.duplicate(true)
var _field_growth_info: Dictionary = {}
var _active_build_mode: String = ""
var _built_structures: Array = []

func _ready() -> void:
	_rent_timer = _ensure_rent_timer()
	_update_rent_timer_state()
	_ensure_research_state_initialized()
	money_changed.emit(_money)
	inventory_changed.emit(_storage.duplicate(true))
	supplies_changed.emit(_supplies.duplicate(true))
	market_log_updated.emit(_market_log.duplicate(true))
	rent_cost_changed.emit(get_hourly_rent_cost())
	research_state_changed.emit(get_research_state())
	build_catalog_changed.emit(get_build_catalog())

func _set_money(value: int) -> void:
	var clamped: int = value if value >= 0 else 0
	if _money == clamped:
		return
	_money = clamped
	money_changed.emit(_money)
	if not _active_build_mode.is_empty() and not can_afford_build(_active_build_mode):
		cancel_build_mode()

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

func get_build_catalog() -> Dictionary:
	return _build_catalog.duplicate(true)

func get_build_definition(build_id: String) -> Dictionary:
	if not _build_catalog.has(build_id):
		return {}
	var definition_variant: Variant = _build_catalog[build_id]
	if not (definition_variant is Dictionary):
		return {}
	var definition: Dictionary = definition_variant
	return definition.duplicate(true)

func can_afford_build(build_id: String) -> bool:
	if not _build_catalog.has(build_id):
		return false
	var definition_variant: Variant = _build_catalog[build_id]
	if not (definition_variant is Dictionary):
		return false
	var definition: Dictionary = definition_variant
	var cost := int(definition.get("cost", 0))
	return _money >= cost

func get_active_build_mode() -> String:
	return _active_build_mode

func start_build_mode(build_id: String) -> bool:
	if build_id.is_empty():
		cancel_build_mode()
		return false
	if not _build_catalog.has(build_id):
		return false
	if not can_afford_build(build_id):
		return false
	if _active_build_mode == build_id:
		return true
	_active_build_mode = build_id
	build_mode_changed.emit(_active_build_mode)
	return true

func cancel_build_mode() -> void:
	if _active_build_mode.is_empty():
		return
	_active_build_mode = ""
	build_mode_changed.emit("")

func spend_for_build(build_id: String) -> bool:
	if build_id.is_empty():
		return false
	if not _build_catalog.has(build_id):
		return false
	var definition_variant: Variant = _build_catalog[build_id]
	if not (definition_variant is Dictionary):
		return false
	var definition: Dictionary = definition_variant
	var cost := int(definition.get("cost", 0))
	if cost <= 0:
		return true
	return try_spend(cost)

func register_build_instance(build_id: String, metadata: Dictionary = {}) -> Dictionary:
	if build_id.is_empty():
		return {}
	var entry: Dictionary = {
		"id": build_id,
		"metadata": metadata.duplicate(true),
	}
	var definition: Dictionary = get_build_definition(build_id)
	if not definition.is_empty():
		entry["label"] = definition.get("label", build_id)
		entry["cost"] = int(definition.get("cost", 0))
		entry["category"] = definition.get("category", "")
		entry["category_label"] = definition.get("category_label", "")
		entry["shape"] = definition.get("shape", "")
		entry["size"] = definition.get("size", Vector3.ONE)
		entry["color"] = definition.get("color", Color.WHITE)
	_built_structures.append(entry)
	build_constructed.emit(build_id, entry.duplicate(true))
	return entry.duplicate(true)

func get_built_structures() -> Array:
	var list: Array = []
	for entry_variant in _built_structures:
		if not (entry_variant is Dictionary):
			continue
		var entry_dict: Dictionary = entry_variant
		list.append(entry_dict.duplicate(true))
	return list

func get_fertilizer_definition(item_id: String) -> Dictionary:
	if not FERTILIZER_DEFINITIONS.has(item_id):
		return {}
	return (FERTILIZER_DEFINITIONS[item_id] as Dictionary).duplicate(true)

func get_fertilizer_effects(item_id: String) -> Array[Dictionary]:
	var definition: Dictionary = get_fertilizer_definition(item_id)
	var duplicated: Array[Dictionary] = [] as Array[Dictionary]
	if definition.is_empty():
		return duplicated
	var raw_effects: Variant = definition.get("effects", [])
	if not (raw_effects is Array):
		return duplicated
	var effect_array: Array = Array()
	effect_array.assign(raw_effects)
	for entry_variant: Variant in effect_array:
		if not (entry_variant is Dictionary):
			continue
		var effect_dict: Dictionary = entry_variant as Dictionary
		duplicated.append(effect_dict.duplicate(true) as Dictionary)
	return duplicated

func get_fertilizer_effect_lines(item_id: String) -> Array[String]:
	var lines: Array[String] = []
	for effect_dict in get_fertilizer_effects(item_id):
		var effect_type := String(effect_dict.get("type", ""))
		match effect_type:
			"yield_bonus":
				var raw_value := float(effect_dict.get("value", 0.0))
				if raw_value <= 0.0:
					continue
				var percent := int(round(raw_value * 100.0))
				lines.append("+%d%% Ertrag pro Anwendung" % percent)
				var applications := 0
				var inverse := 0.0
				if raw_value > 0.0:
					inverse = 1.0 / raw_value
				if inverse >= 1.0:
					applications = int(round(inverse))
				if applications > 0:
					lines.append("Sammelt sich: jede %d Anwendung gibt +1 Ertrag" % applications)
	return lines

func get_market_item_tooltip(item_id: String) -> String:
	if get_item_category(item_id) != ITEM_CATEGORY_FERTILIZER:
		return ""
	var lines := get_fertilizer_effect_lines(item_id)
	return "\n".join(lines)

func get_market_price(item_id: String) -> int:
	var entry: Dictionary = _find_market_entry(item_id)
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
	var entry: Dictionary = _find_market_entry(item_id)
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

func get_item_category(item_id: String) -> String:
	if item_id.is_empty():
		return ITEM_CATEGORY_UNKNOWN
	for category_name in MARKET_CATALOG.keys():
		var entries: Array = MARKET_CATALOG.get(category_name, [])
		for entry in entries:
			if entry.get("id", "") == item_id:
				return category_name
	if ITEM_SELL_PRICES.has(item_id):
		return ITEM_CATEGORY_HARVESTED
	return ITEM_CATEGORY_UNKNOWN

func get_item_unit(item_id: String) -> String:
	var category := get_item_category(item_id)
	return ITEM_UNITS.get(category, "")

func get_category_display_name(category: String) -> String:
	if ITEM_CATEGORY_DISPLAY_NAMES.has(category):
		return ITEM_CATEGORY_DISPLAY_NAMES[category]
	if category.is_empty():
		return "Kategorie"
	return category.capitalize()

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

func get_crop_ids() -> Array:
	return CROP_CONFIG.keys()

func get_crop_seed_id(crop_id: String) -> String:
	var config := _get_crop_config(crop_id)
	return String(config.get("seed_id", ""))

func get_research_options_for_crop(crop_id: String) -> Array:
	var research_map := _get_crop_research_map(crop_id)
	return research_map.keys()

func get_crop_base_growth_time(crop_id: String) -> float:
	var config := _get_crop_config(crop_id)
	return float(config.get("base_growth_seconds", 10.0))

func get_crop_base_yield(crop_id: String) -> float:
	var config := _get_crop_config(crop_id)
	return float(config.get("base_yield", 1.0))

func get_crop_growth_duration(crop_id: String) -> float:
	var config := _get_crop_config(crop_id)
	var base_duration := float(config.get("base_growth_seconds", 10.0))
	var min_duration := float(config.get("min_growth_seconds", 1.0))
	var research_config := _get_research_entry_config(crop_id, RESEARCH_TYPE_SPEED)
	if research_config.is_empty():
		return max(base_duration, min_duration)
	_ensure_research_state_initialized()
	var level := get_research_level(crop_id, RESEARCH_TYPE_SPEED)
	var per_level := float(research_config.get("bonus_per_level", 0.0))
	var max_bonus := float(research_config.get("max_total_bonus", 0.0))
	var reduction: float = clamp(level * per_level, 0.0, max_bonus)
	var duration: float = base_duration * (1.0 - reduction)
	var min_multiplier := float(research_config.get("min_multiplier", 0.0))
	if min_multiplier > 0.0:
		duration = max(duration, base_duration * min_multiplier)
	var research_min := float(research_config.get("min_seconds", 0.0))
	if research_min > 0.0:
		min_duration = max(min_duration, research_min)
	if min_duration > 0.0:
		duration = max(duration, min_duration)
	return max(duration, 0.1)

func get_crop_yield_amount(crop_id: String) -> float:
	var base_yield := get_crop_base_yield(crop_id)
	var research_config := _get_research_entry_config(crop_id, RESEARCH_TYPE_YIELD)
	if research_config.is_empty():
		return max(base_yield, 0.0)
	_ensure_research_state_initialized()
	var level := get_research_level(crop_id, RESEARCH_TYPE_YIELD)
	var per_level := float(research_config.get("bonus_per_level", 0.0))
	var max_bonus := float(research_config.get("max_total_bonus", 0.0))
	var bonus: float = clamp(level * per_level, 0.0, max_bonus)
	var amount: float = base_yield * (1.0 + bonus)
	return max(amount, 0.0)

func get_research_state() -> Dictionary:
	_ensure_research_state_initialized()
	var result: Dictionary = {}
	for crop_id in _research_state.keys():
		var crop_map_variant: Variant = _research_state.get(crop_id, {})
		if crop_map_variant is Dictionary:
			var crop_map: Dictionary = crop_map_variant
			result[crop_id] = crop_map.duplicate(true)
		else:
			result[crop_id] = {}
	return result

func get_research_level(crop_id: String, research_type: String) -> int:
	var crop_map := _ensure_research_entry_map(crop_id)
	return int(crop_map.get(research_type, 0))

func get_research_cost(crop_id: String, research_type: String) -> int:
	var config := _get_research_entry_config(crop_id, research_type)
	if config.is_empty():
		return 0
	var max_level := int(config.get("max_level", 0))
	var current_level := get_research_level(crop_id, research_type)
	if max_level > 0 and current_level >= max_level:
		return 0
	var base_cost := float(config.get("base_cost", 0.0))
	if base_cost <= 0.0:
		return 0
	var factor := float(config.get("cost_factor", 1.0))
	if factor <= 0.0:
		factor = 1.0
	var cost := base_cost * pow(factor, current_level)
	return max(int(round(cost)), 0)

func can_research_crop(crop_id: String, research_type: String) -> bool:
	var config := _get_research_entry_config(crop_id, research_type)
	if config.is_empty():
		return false
	var max_level := int(config.get("max_level", 0))
	var current_level := get_research_level(crop_id, research_type)
	if max_level > 0 and current_level >= max_level:
		return false
	var cost := get_research_cost(crop_id, research_type)
	if cost <= 0:
		return false
	return _money >= cost

func research_crop(crop_id: String, research_type: String) -> bool:
	if not can_research_crop(crop_id, research_type):
		return false
	var cost := get_research_cost(crop_id, research_type)
	if cost <= 0:
		return false
	if not try_spend(cost):
		return false
	var crop_map := _ensure_research_entry_map(crop_id)
	var current_level := int(crop_map.get(research_type, 0))
	crop_map[research_type] = current_level + 1
	_research_state[crop_id] = crop_map
	research_state_changed.emit(get_research_state())
	return true

func get_research_info(crop_id: String, research_type: String) -> Dictionary:
	var config := _get_research_entry_config(crop_id, research_type)
	if config.is_empty():
		return {}
	var info: Dictionary = {}
	var label := String(config.get("label", research_type.capitalize()))
	var description := String(config.get("description", ""))
	var level := get_research_level(crop_id, research_type)
	var max_level := int(config.get("max_level", 0))
	info["crop_id"] = crop_id
	info["type"] = research_type
	info["label"] = label
	info["description"] = description
	info["level"] = level
	info["max_level"] = max_level
	info["is_maxed"] = max_level > 0 and level >= max_level
	info["effect_text"] = _format_research_effect(crop_id, research_type)
	var next_cost := 0
	if not info["is_maxed"]:
		next_cost = get_research_cost(crop_id, research_type)
	info["next_cost"] = next_cost
	info["can_afford"] = next_cost > 0 and _money >= next_cost
	return info

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

func update_field_count(total_fields: int) -> void:
	var payable: int = max(total_fields - 1, 0)
	if payable == _paying_field_count:
		return
	_paying_field_count = payable
	_update_rent_timer_state()
	rent_cost_changed.emit(get_hourly_rent_cost())

func get_hourly_rent_cost() -> int:
	return _paying_field_count * FIELD_RENT_PER_HOUR

func get_rented_field_count() -> int:
	return _paying_field_count

func _ensure_rent_timer() -> Timer:
	var timer: Timer = get_node_or_null("RentTimer") as Timer
	if timer == null:
		timer = Timer.new()
		timer.name = "RentTimer"
		timer.wait_time = RENT_INTERVAL_SECONDS
		timer.one_shot = false
		timer.autostart = false
		add_child(timer)
	var callable := Callable(self, "_on_rent_timer_timeout")
	if not timer.timeout.is_connected(callable):
		timer.timeout.connect(callable)
	return timer

func _update_rent_timer_state() -> void:
	if _rent_timer == null:
		return
	if _paying_field_count <= 0:
		if not _rent_timer.is_stopped():
			_rent_timer.stop()
		return
	_rent_timer.wait_time = RENT_INTERVAL_SECONDS
	if _rent_timer.is_stopped():
		_rent_timer.start()

func _on_rent_timer_timeout() -> void:
	_process_rent_payment()

func _process_rent_payment() -> void:
	if _paying_field_count <= 0:
		return
	var rent_due: int = _paying_field_count * FIELD_RENT_PER_HOUR
	if rent_due <= 0:
		return
	var before: int = _money
	_set_money(_money - rent_due)
	var paid: int = before - _money
	if paid <= 0:
		return
	_append_market_log({
		"type": "rent",
		"actor": "Verwalter",
		"item_id": "field_rent",
		"amount": float(_paying_field_count),
		"unit_price": FIELD_RENT_PER_HOUR,
		"total_price": paid,
		"unit": "Stk",
	})

func _ensure_research_state_initialized() -> void:
	for crop_id in CROP_CONFIG.keys():
		if not _research_state.has(crop_id) or not (_research_state[crop_id] is Dictionary):
			_research_state[crop_id] = {}
		var crop_map: Dictionary = _research_state[crop_id]
		var research_map := _get_crop_research_map(crop_id)
		for research_type in research_map.keys():
			if not crop_map.has(research_type):
				crop_map[research_type] = 0
		_research_state[crop_id] = crop_map

func _ensure_research_entry_map(crop_id: String) -> Dictionary:
	_ensure_research_state_initialized()
	if not _research_state.has(crop_id) or not (_research_state[crop_id] is Dictionary):
		_research_state[crop_id] = {}
	var crop_map: Dictionary = _research_state[crop_id]
	var research_map := _get_crop_research_map(crop_id)
	for research_type in research_map.keys():
		if not crop_map.has(research_type):
			crop_map[research_type] = 0
	_research_state[crop_id] = crop_map
	return crop_map

func _get_crop_config(crop_id: String) -> Dictionary:
	if CROP_CONFIG.has(crop_id):
		return CROP_CONFIG[crop_id]
	return {}

func _get_crop_research_map(crop_id: String) -> Dictionary:
	var config := _get_crop_config(crop_id)
	if config.has("research") and config["research"] is Dictionary:
		return config["research"]
	return {}

func _get_research_entry_config(crop_id: String, research_type: String) -> Dictionary:
	var research_map := _get_crop_research_map(crop_id)
	if research_map.has(research_type) and research_map[research_type] is Dictionary:
		return research_map[research_type]
	return {}

func _format_research_effect(crop_id: String, research_type: String) -> String:
	match research_type:
		RESEARCH_TYPE_YIELD:
			var base_yield := get_crop_base_yield(crop_id)
			var current_yield := get_crop_yield_amount(crop_id)
			if base_yield <= 0.0:
				return "Ertrag: %.2f" % current_yield
			var bonus_percent: float = max((current_yield / base_yield - 1.0) * 100.0, 0.0)
			if bonus_percent <= 0.0:
				return "Ertrag: %.2f" % current_yield
			return "Ertrag: %.2f (+%d%%)" % [current_yield, int(round(bonus_percent))]
		RESEARCH_TYPE_SPEED:
			var base_duration := get_crop_base_growth_time(crop_id)
			var current_duration := get_crop_growth_duration(crop_id)
			if base_duration <= 0.0:
				return "Wachstum: %.1f s" % current_duration
			var reduction_percent: float = max((1.0 - current_duration / base_duration) * 100.0, 0.0)
			if reduction_percent <= 0.0:
				return "Wachstum: %.1f s" % current_duration
			return "Wachstum: %.1f s (-%d%%)" % [current_duration, int(round(reduction_percent))]
		_:
			return ""

func get_farmers() -> Array:
	return _duplicate_farmer_list()

func get_known_fields() -> Array:
	return _known_field_names.duplicate()

func get_field_growth_info() -> Dictionary:
	var snapshot: Dictionary = {}
	for key in _field_growth_info.keys():
		var info_variant: Variant = _field_growth_info[key]
		if info_variant is Dictionary:
			snapshot[key] = (info_variant as Dictionary).duplicate(true)
	return snapshot

func hire_farmer(name: String = "") -> Dictionary:
	var trimmed_name := name.strip_edges()
	var new_id := _farmer_id_counter
	_farmer_id_counter += 1
	if trimmed_name.is_empty():
		trimmed_name = "Farmer %d" % new_id
	var farmer := {
		"id": new_id,
		"name": trimmed_name,
		"status": FARMER_STATUS_IDLE,
		"field_name": "",
	}
	_farmers.append(farmer)
	_emit_farmers_changed()
	return farmer.duplicate(true)

func assign_farmer_to_field(farmer_id: int, field_name: String) -> bool:
	var normalized := field_name.strip_edges()
	if normalized.is_empty():
		return unassign_farmer(farmer_id)
	var farmer_index := _get_farmer_index(farmer_id)
	if farmer_index == -1:
		return false
	_add_known_field_name(normalized)
	_ensure_field_assignment_entry(normalized)
	var previous_field := String(_farmers[farmer_index].get("field_name", ""))
	if not previous_field.is_empty() and previous_field != normalized:
		if _field_assignments.has(previous_field) and int(_field_assignments[previous_field]) == farmer_id:
			_field_assignments[previous_field] = 0
			_clear_field_assignment_on_node(previous_field)
			_pending_auto_harvest.erase(previous_field)
	var current_holder_id := int(_field_assignments.get(normalized, 0))
	if current_holder_id == farmer_id:
		_set_farmer_assignment(farmer_index, normalized)
		_apply_assignment_to_field(normalized)
		return true
	if current_holder_id > 0 and current_holder_id != farmer_id:
		var current_holder_index := _get_farmer_index(current_holder_id)
		if current_holder_index != -1:
			_farmers[current_holder_index]["field_name"] = ""
			_farmers[current_holder_index]["status"] = FARMER_STATUS_IDLE
	_field_assignments[normalized] = farmer_id
	_set_farmer_assignment(farmer_index, normalized)
	_apply_assignment_to_field(normalized)
	_pending_auto_harvest.erase(normalized)
	_emit_farmers_changed()
	return true

func unassign_farmer(farmer_id: int) -> bool:
	var farmer_index := _get_farmer_index(farmer_id)
	if farmer_index == -1:
		return false
	var current_field := String(_farmers[farmer_index].get("field_name", ""))
	if current_field.is_empty():
		return true
	if _field_assignments.has(current_field):
		_field_assignments[current_field] = 0
	_clear_field_assignment_on_node(current_field)
	_pending_auto_harvest.erase(current_field)
	_farmers[farmer_index]["field_name"] = ""
	_farmers[farmer_index]["status"] = FARMER_STATUS_IDLE
	_emit_farmers_changed()
	return true

func fire_farmer(farmer_id: int) -> bool:
	var farmer_index := _get_farmer_index(farmer_id)
	if farmer_index == -1:
		return false
	unassign_farmer(farmer_id)
	_farmers.remove_at(farmer_index)
	_emit_farmers_changed()
	return true

func get_field_assignment(field_name: String) -> int:
	if not _field_assignments.has(field_name):
		return 0
	return int(_field_assignments[field_name])

func register_field(field_node: Node) -> void:
	if field_node == null:
		return
	var field_name := _resolve_field_name(field_node)
	if field_name.is_empty():
		return
	_field_nodes[field_name] = weakref(field_node)
	_add_known_field_name(field_name)
	_ensure_field_assignment_entry(field_name)
	_apply_assignment_to_field(field_name)

func update_field_growth_info(field_node: Node, state_value: int, progress: float, time_left: float, total_duration: float, crop_id: String = "") -> void:
	if field_node == null:
		return
	var field_name := _resolve_field_name(field_node)
	if field_name.is_empty():
		return
	if state_value == FIELD_STATE_EMPTY:
		if _field_growth_info.erase(field_name):
			field_growth_changed.emit(field_name, {})
		return
	var clamped_progress: float = clamp(progress, 0.0, 1.0)
	var safe_time_left: float = max(time_left, 0.0)
	var safe_total: float = max(total_duration, 0.0)
	var info := {
		"state": state_value,
		"progress": clamped_progress,
		"time_left": safe_time_left,
		"total": safe_total,
	}
	if not crop_id.is_empty():
		info["crop_id"] = crop_id
	_field_growth_info[field_name] = info
	field_growth_changed.emit(field_name, info.duplicate(true))

func unregister_field(field_node: Node) -> void:
	if field_node == null:
		return
	var field_name := _resolve_field_name(field_node)
	if field_name.is_empty():
		return
	_field_nodes.erase(field_name)
	var assignment_removed := false
	if _field_assignments.has(field_name):
		var assigned_id := int(_field_assignments[field_name])
		if assigned_id > 0:
			var farmer_index := _get_farmer_index(assigned_id)
			if farmer_index != -1:
				_farmers[farmer_index]["field_name"] = ""
				_farmers[farmer_index]["status"] = FARMER_STATUS_IDLE
				assignment_removed = true
		_field_assignments.erase(field_name)
	_pending_auto_harvest.erase(field_name)
	if _field_growth_info.has(field_name):
		_field_growth_info.erase(field_name)
		field_growth_changed.emit(field_name, {})
	_remove_known_field_name(field_name)
	if assignment_removed:
		_emit_farmers_changed()

func on_field_ready(field_node: Node) -> void:
	if field_node == null:
		return
	var field_name := _resolve_field_name(field_node)
	if field_name.is_empty():
		return
	var assigned_id := int(_field_assignments.get(field_name, 0))
	if assigned_id <= 0:
		return
	_schedule_auto_harvest(field_name, assigned_id)

func _schedule_auto_harvest(field_name: String, farmer_id: int) -> void:
	if field_name.is_empty():
		return
	if _pending_auto_harvest.has(field_name):
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	_pending_auto_harvest[field_name] = farmer_id
	var callable: Callable = Callable(self, "_perform_auto_harvest").bind(field_name, farmer_id)
	var timer: SceneTreeTimer = tree.create_timer(FARMER_AUTO_HARVEST_DELAY)
	if timer:
		timer.timeout.connect(callable)

func _perform_auto_harvest(field_name: String, farmer_id: int) -> void:
	_pending_auto_harvest.erase(field_name)
	var assigned_id := int(_field_assignments.get(field_name, 0))
	if assigned_id != farmer_id:
		return
	var field_node: Node = _get_field_node(field_name)
	if field_node == null:
		return
	var state_value := _get_field_state_from_node(field_node)
	if state_value != FIELD_STATE_READY:
		return
	var farmer_index := _get_farmer_index(farmer_id)
	if farmer_index == -1:
		return
	var farmer_name := String(_farmers[farmer_index].get("name", ""))
	if field_node.has_method("harvest_by_farmer"):
		var harvested := bool(field_node.call("harvest_by_farmer", farmer_name))
		if harvested:
			return
	if field_node.has_method("request_harvest"):
		field_node.call("request_harvest")
	else:
		field_node.call_deferred("_harvest")

func _resolve_field_name(field_node: Node) -> String:
	if field_node == null:
		return ""
	return String(field_node.name).strip_edges()

func _get_field_node(field_name: String) -> Node:
	if field_name.is_empty():
		return null
	if not _field_nodes.has(field_name):
		return null
	var stored: Variant = _field_nodes[field_name]
	if stored is WeakRef:
		var node_obj: Object = (stored as WeakRef).get_ref()
		if node_obj == null:
			_field_nodes.erase(field_name)
			return null
		if node_obj is Node:
			return node_obj as Node
		return null
	if stored is Node:
		return stored as Node
	return null

func _duplicate_farmer_list() -> Array:
	var duplicate: Array = []
	for entry_variant in _farmers:
		if not (entry_variant is Dictionary):
			continue
		var entry_dict: Dictionary = entry_variant
		duplicate.append(entry_dict.duplicate(true))
	return duplicate

func _emit_farmers_changed() -> void:
	farmers_changed.emit(_duplicate_farmer_list())

func _emit_fields_changed() -> void:
	fields_changed.emit(_known_field_names.duplicate())

func _ensure_field_assignment_entry(field_name: String) -> void:
	if field_name.is_empty():
		return
	if not _field_assignments.has(field_name):
		_field_assignments[field_name] = 0

func _apply_assignment_to_field(field_name: String) -> void:
	var field_node: Node = _get_field_node(field_name)
	if field_node == null:
		return
	var assigned_id := int(_field_assignments.get(field_name, 0))
	if assigned_id > 0:
		var farmer_index := _get_farmer_index(assigned_id)
		if farmer_index == -1:
			return
		var farmer_name := String(_farmers[farmer_index].get("name", ""))
		if field_node.has_method("set_assigned_farmer"):
			field_node.call("set_assigned_farmer", assigned_id, farmer_name)
	else:
		_clear_field_assignment_on_node(field_name)

func _clear_field_assignment_on_node(field_name: String) -> void:
	var field_node: Node = _get_field_node(field_name)
	if field_node == null:
		return
	if field_node.has_method("clear_assigned_farmer"):
		field_node.call("clear_assigned_farmer")

func _get_farmer_index(farmer_id: int) -> int:
	for i in _farmers.size():
		var entry: Variant = _farmers[i]
		if entry is Dictionary and int(entry.get("id", -1)) == farmer_id:
			return i
	return -1

func _set_farmer_assignment(farmer_index: int, field_name: String) -> void:
	if farmer_index < 0 or farmer_index >= _farmers.size():
		return
	_farmers[farmer_index]["field_name"] = field_name
	_farmers[farmer_index]["status"] = FARMER_STATUS_ASSIGNED if not field_name.is_empty() else FARMER_STATUS_IDLE

func _add_known_field_name(field_name: String) -> void:
	if field_name.is_empty():
		return
	if field_name in _known_field_names:
		return
	_known_field_names.append(field_name)
	_known_field_names.sort()
	_emit_fields_changed()

func _remove_known_field_name(field_name: String) -> void:
	if field_name.is_empty():
		return
	if not (field_name in _known_field_names):
		return
	_known_field_names.erase(field_name)
	_emit_fields_changed()

func _get_field_state_from_node(field_node: Node) -> int:
	if field_node == null:
		return FIELD_STATE_EMPTY
	if field_node.has_method("get_field_state"):
		var value: Variant = field_node.call("get_field_state")
		if typeof(value) == TYPE_INT:
			return int(value)
	var raw: Variant = field_node.get("state")
	if typeof(raw) == TYPE_INT:
		return int(raw)
	return FIELD_STATE_EMPTY
