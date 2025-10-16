extends Control

@onready var menu: PopupMenu = $PlantMenu
@onready var money_label: Label = $WalletPanel/MoneyLabel
@onready var buy_field_button: Button = $WalletPanel/BuyFieldButton
@onready var storage_button: Button = $WalletPanel/StorageButton
@onready var storage_popup: PopupPanel = $StoragePopup
@onready var storage_items_scroll: ScrollContainer = $StoragePopup/MarginContainer/VBoxContainer/ItemsScroll
@onready var storage_items_container: VBoxContainer = $StoragePopup/MarginContainer/VBoxContainer/ItemsScroll/ItemsContainer
@onready var storage_empty_label: Label = $StoragePopup/MarginContainer/VBoxContainer/EmptyLabel
@onready var storage_close_button: Button = $StoragePopup/MarginContainer/VBoxContainer/CloseButton
var current_tile: Node = null
var field_manager: Node = null

func _ready():
	add_to_group("ui")      # damit Tiles dich finden
	field_manager = _find_field_manager()
	if buy_field_button:
		buy_field_button.pressed.connect(_on_buy_field_pressed)
	if storage_button:
		storage_button.pressed.connect(_on_storage_button_pressed)
	if storage_close_button:
		storage_close_button.pressed.connect(_on_storage_close_pressed)
	if field_manager == null:
		call_deferred("_refresh_field_manager")
	GameState.money_changed.connect(_on_money_changed)
	GameState.inventory_changed.connect(_on_inventory_changed)
	_on_money_changed(GameState.money)
	_on_inventory_changed(GameState.get_inventory())
	menu.clear()
	menu.add_item("Weizen", 1)
	menu.add_item("Kartoffel", 2)
	menu.add_separator()
	menu.add_item("Abbrechen", 0)
	menu.id_pressed.connect(_on_menu_id)
	menu.position = Vector2(200, 200)
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
	if id == 0 or current_tile == null:
		menu.hide()
		current_tile = null
		return
	var crop_id := "wheat" if id == 1 else "potato"
	current_tile.call_deferred("start_growth", crop_id, 10.0)  # 10s Timer
	menu.hide()
	current_tile = null

func _on_money_changed(amount: int) -> void:
	if money_label:
		money_label.text = "Geld: %d" % amount
	_update_buy_button()

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
