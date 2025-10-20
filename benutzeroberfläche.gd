extends Control

const MENU_LABELS := {
	0: "Abbrechen",
	1: "Weizen",
	2: "Kartoffel",
}
const MENU_ID_TO_CROP := {
	1: "wheat",
	2: "potato",
}
const CROP_TO_SEED := {
	"wheat": "wheat_seed",
	"potato": "potato_seed",
}

@onready var menu: PopupMenu = $PlantMenu
@onready var money_label: Label = $WalletPanel/MoneyLabel
@onready var buy_field_button: Button = $WalletPanel/BuyFieldButton
@onready var storage_button: Button = $WalletPanel/StorageButton
@onready var market_button: Button = $WalletPanel/MarketButton
@onready var storage_popup: PopupPanel = $StoragePopup
@onready var storage_items_scroll: ScrollContainer = $StoragePopup/MarginContainer/VBoxContainer/ItemsScroll
@onready var storage_items_container: VBoxContainer = $StoragePopup/MarginContainer/VBoxContainer/ItemsScroll/ItemsContainer
@onready var storage_empty_label: Label = $StoragePopup/MarginContainer/VBoxContainer/EmptyLabel
@onready var storage_close_button: Button = $StoragePopup/MarginContainer/VBoxContainer/CloseButton
@onready var market_popup: PopupPanel = $MarketPopup
@onready var market_money_label: Label = $MarketPopup/MarketMargin/MarketVBox/MarketMoneyLabel
@onready var market_close_button: Button = $MarketPopup/MarketMargin/MarketVBox/MarketCloseButton
@onready var market_seeds_container: VBoxContainer = $MarketPopup/MarketMargin/MarketVBox/MarketSections/SeedsSection/SeedsContainer
@onready var market_fertilizer_container: VBoxContainer = $MarketPopup/MarketMargin/MarketVBox/MarketSections/FertilizerSection/FertilizerContainer
@onready var market_log_container: VBoxContainer = $MarketPopup/MarketMargin/MarketVBox/MarketLogScroll/MarketLogContainer
var current_tile: Node = null
var field_manager: Node = null
var _market_item_buttons: Dictionary = {}
var _market_item_stock_labels: Dictionary = {}

func _ready():
	add_to_group("ui")      # damit Tiles dich finden
	field_manager = _find_field_manager()
	if buy_field_button:
		buy_field_button.pressed.connect(_on_buy_field_pressed)
	if storage_button:
		storage_button.pressed.connect(_on_storage_button_pressed)
	if storage_close_button:
		storage_close_button.pressed.connect(_on_storage_close_pressed)
	if market_button:
		market_button.pressed.connect(_on_market_button_pressed)
	if market_close_button:
		market_close_button.pressed.connect(_on_market_close_pressed)
	if field_manager == null:
		call_deferred("_refresh_field_manager")
	GameState.money_changed.connect(_on_money_changed)
	GameState.inventory_changed.connect(_on_inventory_changed)
	GameState.supplies_changed.connect(_on_supplies_changed)
	GameState.market_log_updated.connect(_on_market_log_updated)
	_on_money_changed(GameState.money)
	_on_inventory_changed(GameState.get_inventory())
	_setup_market_ui()
	_on_supplies_changed(GameState.get_supplies())
	_on_market_log_updated(GameState.get_market_log())
	menu.clear()
	menu.add_item(MENU_LABELS.get(1, "Weizen"), 1)
	menu.add_item(MENU_LABELS.get(2, "Kartoffel"), 2)
	menu.add_separator()
	menu.add_item(MENU_LABELS.get(0, "Abbrechen"), 0)
	menu.id_pressed.connect(_on_menu_id)
	menu.position = Vector2(200, 200)
	_refresh_crop_menu()
	print("PlantMenu ready (wartet auf Feldklick)")

func _popup_at_position(screen_pos: Vector2):
	var popup_size: Vector2 = menu.size
	if popup_size == Vector2.ZERO:
		popup_size = menu.get_combined_minimum_size()
	var width: int = int(ceil(popup_size.x))
	if width < 1:
		width = 1
	var height: int = int(ceil(popup_size.y))
	if height < 1:
		height = 1
	var popup_pos := Vector2i(int(round(screen_pos.x)), int(round(screen_pos.y)))
	var popup_rect := Rect2i(popup_pos, Vector2i(width, height))
	menu.position = screen_pos
	menu.popup(popup_rect)
	print("Menu popup at:", popup_rect.position)

func open_for_tile(tile: Node, screen_pos: Vector2):
	current_tile = tile
	menu.visible = true
	_popup_at_position(screen_pos)
	print("Menu opened for tile:", tile.name)


func _on_menu_id(id: int):
	if id == 0:
		menu.hide()
		current_tile = null
		return
	if current_tile == null:
		menu.hide()
		return
	var crop_id: String = str(MENU_ID_TO_CROP.get(id, ""))
	if crop_id.is_empty():
		menu.hide()
		current_tile = null
		return
	var seed_id: String = str(CROP_TO_SEED.get(crop_id, ""))
	if not seed_id.is_empty():
		if not GameState.has_supply(seed_id):
			print("Es sind keine %s verfuegbar. Bitte kaufe Samen im Markt." % GameState.get_display_name(seed_id))
			return
		if not GameState.consume_supply(seed_id):
			print("Fehler beim Verbrauchen von %s." % GameState.get_display_name(seed_id))
			return
	current_tile.call_deferred("start_growth", crop_id, 10.0)  # 10s Timer
	menu.hide()
	current_tile = null

func _on_money_changed(amount: int) -> void:
	if money_label:
		money_label.text = "Geld: %d" % amount
	_update_buy_button()
	_update_market_money(amount)
	_update_market_buttons_state(amount)

func _on_buy_field_pressed() -> void:
	if field_manager == null:
		field_manager = _find_field_manager()
	if field_manager and field_manager.has_method("buy_field"):
		var success: bool = field_manager.buy_field()
		if not success:
			print("Feldkauf fehlgeschlagen")
	_update_buy_button()

func _update_buy_button() -> void:
	if buy_field_button == null:
		return
	if field_manager == null:
		field_manager = _find_field_manager()
	var cost: int = 10
	if field_manager and field_manager.has_method("get_field_cost"):
		cost = field_manager.get_field_cost()
	buy_field_button.text = "Feld kaufen (%d)" % cost
	if field_manager == null:
		buy_field_button.disabled = true
		return
	var disabled: bool = true
	if field_manager.has_method("can_buy_field"):
		disabled = not field_manager.can_buy_field()
	else:
		disabled = GameState.money < cost
	buy_field_button.disabled = disabled

func _refresh_crop_menu() -> void:
	if menu == null:
		return
	for index in range(menu.item_count):
		var item_id: int = menu.get_item_id(index)
		if item_id == 0:
			menu.set_item_text(index, MENU_LABELS.get(item_id, menu.get_item_text(index)))
			menu.set_item_disabled(index, false)
			menu.set_item_tooltip(index, "")
			continue
		if not MENU_ID_TO_CROP.has(item_id):
			continue
		var crop_id: String = str(MENU_ID_TO_CROP[item_id])
		var seed_id: String = str(CROP_TO_SEED.get(crop_id, ""))
		var base_text: String = str(MENU_LABELS.get(item_id, menu.get_item_text(index)))
		if seed_id.is_empty():
			menu.set_item_text(index, base_text)
			menu.set_item_disabled(index, false)
			menu.set_item_tooltip(index, "")
			continue
		var seed_count: int = GameState.get_supply_amount(seed_id)
		menu.set_item_text(index, "%s (Samen: %d)" % [base_text, seed_count])
		var has_enough := seed_count > 0
		menu.set_item_disabled(index, not has_enough)
		if has_enough:
			menu.set_item_tooltip(index, "")
		else:
			menu.set_item_tooltip(index, "Keine %s verf\u00fcgbar. Kaufe sie im Markt." % GameState.get_display_name(seed_id))

func _find_field_manager() -> Node:
	var managers: Array[Node] = get_tree().get_nodes_in_group("field_manager")
	if managers.is_empty():
		return null
	return managers[0]

func _refresh_field_manager() -> void:
	field_manager = _find_field_manager()
	_update_buy_button()

func _on_storage_button_pressed() -> void:
	if storage_popup == null:
		return
	_on_inventory_changed(GameState.get_inventory())
	storage_popup.popup_centered_ratio(0.9)

func _on_storage_close_pressed() -> void:
	if storage_popup:
		storage_popup.hide()

func _on_inventory_changed(storage: Dictionary) -> void:
	_update_storage_view(storage)

func _on_supplies_changed(supplies: Dictionary) -> void:
	_update_market_supplies(supplies)
	_refresh_crop_menu()

func _on_market_log_updated(entries: Array) -> void:
	_update_market_log(entries)

func _update_storage_view(storage: Dictionary) -> void:
	if storage_items_container == null or storage_empty_label == null or storage_items_scroll == null:
		return
	_clear_storage_items()
	if storage.is_empty():
		storage_items_scroll.visible = false
		storage_empty_label.visible = true
		return
	storage_empty_label.visible = false
	storage_items_scroll.visible = true
	var crop_ids := storage.keys()
	crop_ids.sort()
	for crop_id in crop_ids:
		var amount: float = float(storage.get(crop_id, 0.0))
		var row := _create_storage_row(crop_id, amount)
		storage_items_container.add_child(row)

func _format_tons(amount: float) -> String:
	var rounded: float = round(amount * 100.0) / 100.0
	if is_equal_approx(rounded, round(rounded)):
		return str(int(round(rounded)))
	return "%.2f" % rounded

func _clear_storage_items() -> void:
	for child in storage_items_container.get_children():
		child.queue_free()

func _create_storage_row(item_id: String, amount: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "StorageRow_%s" % item_id
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)

	var name_label := Label.new()
	name_label.text = "%s (%s t verfügbar)" % [GameState.get_display_name(item_id), _format_tons(amount)]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(name_label)

	var plus_button := Button.new()
	plus_button.text = "+"
	plus_button.focus_mode = Control.FOCUS_NONE
	row.add_child(plus_button)

	var amount_input := LineEdit.new()
	amount_input.text = "0"
	amount_input.placeholder_text = "0"
	amount_input.custom_minimum_size = Vector2(80, 0)
	amount_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(amount_input)

	var minus_button := Button.new()
	minus_button.text = "-"
	minus_button.focus_mode = Control.FOCUS_NONE
	row.add_child(minus_button)

	var sell_button := Button.new()
	sell_button.text = "Verkaufen"
	sell_button.focus_mode = Control.FOCUS_NONE
	row.add_child(sell_button)

	plus_button.pressed.connect(Callable(self, "_on_storage_adjust_pressed").bind(item_id, amount_input, 1.0))
	minus_button.pressed.connect(Callable(self, "_on_storage_adjust_pressed").bind(item_id, amount_input, -1.0))
	sell_button.pressed.connect(Callable(self, "_on_storage_sell_pressed").bind(item_id, amount_input))
	amount_input.text_submitted.connect(Callable(self, "_on_storage_sell_pressed").bind(item_id, amount_input))

	return row

func _on_storage_adjust_pressed(item_id: String, input: LineEdit, delta: float) -> void:
	var current: float = _parse_tons(input.text)
	var available: float = GameState.get_storage_amount(item_id)
	var target: float = current + delta
	if delta > 0.0:
		target = min(target, available)
	else:
		target = max(target, 0.0)
	target = clampf(target, 0.0, available)
	input.text = _format_tons(target)

func _on_storage_sell_pressed(item_id: String, input: LineEdit) -> void:
	var requested: float = _parse_tons(input.text)
	var available: float = GameState.get_storage_amount(item_id)
	var amount_to_sell: float = clampf(requested, 0.0, available)
	if amount_to_sell <= 0.0:
		input.text = "0"
		return
	if GameState.sell_from_inventory(item_id, amount_to_sell):
		input.text = "0"
	else:
		input.text = _format_tons(amount_to_sell)

func _parse_tons(raw_value: String) -> float:
	var value := raw_value.strip_edges()
	if value.is_empty():
		return 0.0
	value = value.replace(",", ".")
	return value.to_float()

func _setup_market_ui() -> void:
	_market_item_buttons.clear()
	_market_item_stock_labels.clear()
	if market_seeds_container:
		_clear_market_section(market_seeds_container)
	if market_fertilizer_container:
		_clear_market_section(market_fertilizer_container)
	var catalog := GameState.get_market_catalog()
	_populate_market_section(market_seeds_container, catalog.get("seeds", []))
	_populate_market_section(market_fertilizer_container, catalog.get("fertilizer", []))
	_update_market_buttons_state(GameState.money)

func _clear_market_section(container: VBoxContainer) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()

func _populate_market_section(container: VBoxContainer, entries: Array) -> void:
	if container == null:
		return
	for entry in entries:
		if not entry is Dictionary:
			continue
		var entry_dict: Dictionary = entry as Dictionary
		var row: HBoxContainer = _create_market_row(entry_dict)
		if row:
			container.add_child(row)

func _create_market_row(entry: Dictionary) -> HBoxContainer:
	var item_id: String = str(entry.get("id", ""))
	if item_id.is_empty():
		return null
	var price: int = int(entry.get("price", 0))
	var row := HBoxContainer.new()
	row.name = "MarketRow_%s" % item_id
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)

	var name_label := Label.new()
	name_label.text = GameState.get_display_name(item_id)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(name_label)

	var price_label := Label.new()
	price_label.text = "%d G" % price
	price_label.size_flags_horizontal = Control.SIZE_FILL
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_label.custom_minimum_size = Vector2(80, 0)
	row.add_child(price_label)

	var owned_label := Label.new()
	owned_label.text = "Bestand: 0"
	owned_label.size_flags_horizontal = Control.SIZE_FILL
	owned_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	owned_label.custom_minimum_size = Vector2(120, 0)
	row.add_child(owned_label)

	var buy_button := Button.new()
	buy_button.text = "Kaufen"
	buy_button.focus_mode = Control.FOCUS_NONE
	row.add_child(buy_button)

	_market_item_buttons[item_id] = buy_button
	_market_item_stock_labels[item_id] = owned_label
	buy_button.set_meta("price", price)
	buy_button.disabled = not GameState.can_buy_market_item(item_id)
	buy_button.pressed.connect(Callable(self, "_on_market_buy_pressed").bind(item_id))
	return row

func _on_market_button_pressed() -> void:
	if market_popup:
		_update_market_money(GameState.money)
		_update_market_buttons_state(GameState.money)
		market_popup.popup_centered_ratio(0.85)

func _on_market_close_pressed() -> void:
	if market_popup:
		market_popup.hide()

func _on_market_buy_pressed(item_id: String) -> void:
	if item_id.is_empty():
		return
	if not GameState.buy_market_item(item_id, 1):
		print("Einkauf fehlgeschlagen fuer", item_id)

func _update_market_money(amount: int) -> void:
	if market_money_label:
		market_money_label.text = "Guthaben: %d" % amount

func _update_market_buttons_state(amount: int) -> void:
	for item_id in _market_item_buttons.keys():
		var button: Button = _market_item_buttons.get(item_id, null) as Button
		if button == null:
			continue
		var price: int = int(button.get_meta("price", 0))
		var can_buy := price > 0 and amount >= price
		button.disabled = not can_buy

func _update_market_supplies(supplies: Dictionary) -> void:
	for item_id in _market_item_stock_labels.keys():
		var label: Label = _market_item_stock_labels.get(item_id, null) as Label
		if label == null:
			continue
		var owned: int = int(supplies.get(item_id, 0))
		label.text = "Bestand: %d" % owned

func _update_market_log(entries: Array) -> void:
	if market_log_container == null:
		return
	for child in market_log_container.get_children():
		child.queue_free()
	if entries.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Noch keine Verkaeufe."
		market_log_container.add_child(empty_label)
		return
	var ordered: Array = entries.duplicate()
	ordered.reverse()
	for entry in ordered:
		if not entry is Dictionary:
			continue
		var entry_dict: Dictionary = entry as Dictionary
		var label := Label.new()
		label.text = _format_market_log_entry(entry_dict)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		market_log_container.add_child(label)

func _format_market_amount(amount: float, unit: String) -> String:
	match unit:
		"t":
			return "%s t" % _format_tons(amount)
		"Stk":
			return "%d Stk" % int(round(amount))
		_:
			if unit.is_empty():
				return "%s" % _format_tons(amount)
			return "%.2f %s" % [amount, unit]

func _format_market_log_entry(entry: Dictionary) -> String:
	var actor: String = str(entry.get("actor", "Unbekannt"))
	var item_id: String = String(entry.get("item_id", ""))
	var item_name: String = GameState.get_display_name(item_id)
	var amount: float = float(entry.get("amount", 0.0))
	var unit: String = str(entry.get("unit", ""))
	var unit_price: int = int(entry.get("unit_price", 0))
	var total_price: int = int(entry.get("total_price", 0))
	var amount_text: String = _format_market_amount(amount, unit)
	var price_info: String = ""
	if unit_price > 0 and not unit.is_empty():
		price_info = " (Preis pro %s: %d G)" % [unit, unit_price]
	var action: String = String(entry.get("type", ""))
	if action == "purchase":
		return "%s kaufte %s %s fuer %d G%s" % [actor, amount_text, item_name, total_price, price_info]
	if action == "sale":
		return "%s verkaufte %s %s fuer %d G%s" % [actor, amount_text, item_name, total_price, price_info]
	return "%s handelte %s %s fuer %d G%s" % [actor, amount_text, item_name, total_price, price_info]
