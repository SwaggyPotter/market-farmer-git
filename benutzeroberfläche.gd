extends Control

@onready var menu: PopupMenu = $PlantMenu
@onready var money_label: Label = $WalletPanel/MoneyLabel
@onready var buy_field_button: Button = $WalletPanel/BuyFieldButton
@onready var storage_button: Button = $WalletPanel/StorageButton
@onready var storage_popup: PopupPanel = $StoragePopup
@onready var storage_item_list: ItemList = $StoragePopup/MarginContainer/VBoxContainer/ItemList
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
	storage_popup.popup_centered()

func _on_storage_close_pressed() -> void:
	if storage_popup:
		storage_popup.hide()

func _on_inventory_changed(items: Array) -> void:
	_update_storage_view(items)

func _update_storage_view(items: Array) -> void:
	if storage_item_list == null or storage_empty_label == null:
		return
	storage_item_list.clear()
	if items.is_empty():
		storage_item_list.visible = false
		storage_empty_label.visible = true
	else:
		for entry in items:
			storage_item_list.add_item(str(entry))
		storage_item_list.visible = true
		storage_empty_label.visible = false
