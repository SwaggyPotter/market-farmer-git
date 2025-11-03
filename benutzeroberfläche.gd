extends Control

const MENU_CANCEL_ID = 0
const MENU_ACTION_PLANT = "plant"
const MENU_ACTION_FERTILIZE = "fertilize"
const FIELD_STATE_UNKNOWN = -1
const FIELD_STATE_EMPTY = 0
const FIELD_STATE_GROWING = 1
const FIELD_STATE_READY = 2
const CROP_MENU_ORDER = [
	"wheat",
	"potato",
]
const DEFAULT_GROWTH_SECONDS = 10.0
const CROP_TO_SEED = {
	"wheat": "wheat_seed",
	"potato": "potato_seed",
}
const STORAGE_CATEGORY_ORDER = [
	GameState.ITEM_CATEGORY_FERTILIZER,
	GameState.ITEM_CATEGORY_SEEDS,
	GameState.ITEM_CATEGORY_HARVESTED,
]
const FARMER_STATUS_IDLE = "idle"
const FARMER_STATUS_ASSIGNED = "assigned"
const PERSONNEL_SELECTOR_NONE_LABEL = "Kein Feld"
const BUILD_MENU_CATEGORY_ORDER = [
	{"id": "field", "label": "Felder"},
	{"id": "decor", "label": "Dekorationen"},
	{"id": "road", "label": "Strassen"},
	{"id": "production", "label": "Produktion"},
	{"id": "power", "label": "Stromerzeugung"},
	{"id": "irrigation", "label": "Bewaesserung"},
]

const WORLD_MARKET_CHART_SCRIPT = preload("res://world_market_chart.gd")

class MenuEntryMetadata:
	var action: String = ""
	var crop_id: String = ""
	var seed_id: String = ""
	var fertilizer_id: String = ""

	func is_empty() -> bool:
		return action.is_empty()

@onready var menu: PopupMenu = $PlantMenu
@onready var money_label: Label = $WalletPanel/MoneyLabel
@onready var rent_label: Label = $WalletPanel/RentLabel
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
@onready var world_market_button: Button = $WalletPanel/WorldMarketButton
@onready var world_market_popup: PopupPanel = $WorldMarketPopup
@onready var world_market_close_button: Button = $WorldMarketPopup/WorldMarketMargin/WorldMarketVBox/WorldMarketCloseButton
@onready var world_market_search: LineEdit = $WorldMarketPopup/WorldMarketMargin/WorldMarketVBox/SearchRow/WorldMarketSearch
@onready var world_market_clear_button: Button = $WorldMarketPopup/WorldMarketMargin/WorldMarketVBox/SearchRow/WorldMarketClearButton
@onready var world_market_list: ItemList = $WorldMarketPopup/WorldMarketMargin/WorldMarketVBox/Content/ProductsSection/ProductList
@onready var world_market_selected_label: Label = $WorldMarketPopup/WorldMarketMargin/WorldMarketVBox/Content/DetailsSection/SelectedProductLabel
@onready var world_market_price_label: Label = $WorldMarketPopup/WorldMarketMargin/WorldMarketVBox/Content/DetailsSection/CurrentPriceLabel
@onready var world_market_supply_label: Label = $WorldMarketPopup/WorldMarketMargin/WorldMarketVBox/Content/DetailsSection/SupplyDemandLabel
@onready var world_market_updated_label: Label = $WorldMarketPopup/WorldMarketMargin/WorldMarketVBox/Content/DetailsSection/UpdatedLabel
@onready var world_market_history_mode: OptionButton = $WorldMarketPopup/WorldMarketMargin/WorldMarketVBox/Content/DetailsSection/HistoryHeader/HistoryModeOption
@onready var world_market_chart = $WorldMarketPopup/WorldMarketMargin/WorldMarketVBox/Content/DetailsSection/HistoryChart
@onready var research_button: Button = $WalletPanel/ResearchButton
@onready var research_popup: PopupPanel = $ResearchPopup
@onready var research_entries_scroll: ScrollContainer = $ResearchPopup/MarginContainer/VBoxContainer/EntriesScroll
@onready var research_new_products_section: VBoxContainer = $ResearchPopup/MarginContainer/VBoxContainer/EntriesScroll/EntriesContainer/NewProductsSection
@onready var research_new_products_button: Button = $ResearchPopup/MarginContainer/VBoxContainer/EntriesScroll/EntriesContainer/NewProductsSection/NewProductsButton
@onready var research_new_products_grid: GridContainer = $ResearchPopup/MarginContainer/VBoxContainer/EntriesScroll/EntriesContainer/NewProductsSection/NewProductsGrid
@onready var research_improve_section: VBoxContainer = $ResearchPopup/MarginContainer/VBoxContainer/EntriesScroll/EntriesContainer/ImprovePlantsSection
@onready var research_improve_button: Button = $ResearchPopup/MarginContainer/VBoxContainer/EntriesScroll/EntriesContainer/ImprovePlantsSection/ImprovePlantsButton
@onready var research_improve_entries_container: VBoxContainer = $ResearchPopup/MarginContainer/VBoxContainer/EntriesScroll/EntriesContainer/ImprovePlantsSection/ImproveEntries
@onready var research_empty_label: Label = $ResearchPopup/MarginContainer/VBoxContainer/EmptyLabel
@onready var research_close_button: Button = $ResearchPopup/MarginContainer/VBoxContainer/CloseButton
@onready var personnel_button: Button = $WalletPanel/PersonnelButton
@onready var personnel_popup: PopupPanel = $PersonnelPopup
@onready var personnel_hire_button: Button = $PersonnelPopup/PersonnelMargin/PersonnelVBox/Controls/HireButton
@onready var personnel_close_button: Button = $PersonnelPopup/PersonnelMargin/PersonnelVBox/PersonnelCloseButton
@onready var personnel_list_container: VBoxContainer = $PersonnelPopup/PersonnelMargin/PersonnelVBox/PersonnelScroll/PersonnelList
@onready var personnel_empty_label: Label = $PersonnelPopup/PersonnelMargin/PersonnelVBox/PersonnelEmptyLabel
@onready var build_button: Button = $BuildButton
@onready var build_popup: PopupPanel = $BuildPopup
@onready var build_category_container: VBoxContainer = $BuildPopup/MarginContainer/VBoxContainer/Content/CategorySection/CategoryButtons
@onready var build_items_container: VBoxContainer = $BuildPopup/MarginContainer/VBoxContainer/Content/ItemsScroll/ItemsContainer
@onready var build_close_button: Button = $BuildPopup/MarginContainer/VBoxContainer/Header/CloseButton
@onready var build_empty_label: Label = $BuildPopup/MarginContainer/VBoxContainer/Content/ItemsScroll/ItemsContainer/EmptyLabel
@onready var build_info_label: Label = $BuildPopup/MarginContainer/VBoxContainer/InfoLabel
var current_tile: Node = null
var field_manager: Node = null
var _latest_inventory: Dictionary = {}
var _latest_supplies: Dictionary = {}
var _market_item_buttons: Dictionary = {}
var _market_item_stock_labels: Dictionary = {}
var _world_market_entries: Array = []
var _world_market_selection: String = ""
var _world_market_overview: Dictionary = {}
var _latest_research_state: Dictionary = {}
var _research_rows: Dictionary = {}
var _research_new_products_expanded: bool = false
var _research_improve_expanded: bool = false
var _research_improve_has_entries: bool = false
var _latest_farmers: Array = []
var _known_field_names: Array = []
var _personnel_refreshing: bool = false
var _menu_entries: Dictionary[int, MenuEntryMetadata] = {} as Dictionary[int, MenuEntryMetadata]
var _menu_id_counter: int = 1
var _current_menu_field_state: int = FIELD_STATE_UNKNOWN
var _build_item_buttons: Dictionary = {}
var _build_category_buttons: Dictionary = {}
var _build_categories: Dictionary = {}
var _build_id_to_category: Dictionary = {}
var _suppress_build_button_update: bool = false
var _suppress_category_update: bool = false
var _active_build_category: String = ""
var _build_category_button_group: ButtonGroup = ButtonGroup.new()

func _ready():
	add_to_group("ui")      # damit Tiles dich finden
	field_manager = _find_field_manager()
	if storage_button:
		storage_button.pressed.connect(_on_storage_button_pressed)
	if storage_close_button:
		storage_close_button.pressed.connect(_on_storage_close_pressed)
	if market_button:
		market_button.pressed.connect(_on_market_button_pressed)
	if market_close_button:
		market_close_button.pressed.connect(_on_market_close_pressed)
	if world_market_button:
		world_market_button.pressed.connect(_on_world_market_button_pressed)
	if world_market_close_button:
		world_market_close_button.pressed.connect(_on_world_market_close_pressed)
	if world_market_search:
		world_market_search.text_changed.connect(_on_world_market_search_changed)
		world_market_search.text_submitted.connect(_on_world_market_search_submitted)
	if world_market_clear_button:
		world_market_clear_button.pressed.connect(_on_world_market_clear_pressed)
	if world_market_list:
		world_market_list.item_selected.connect(_on_world_market_item_selected)
	if world_market_history_mode:
		world_market_history_mode.clear()
		world_market_history_mode.add_item("Linie")
		world_market_history_mode.add_item("Kerzen")
		world_market_history_mode.select(0)
		world_market_history_mode.item_selected.connect(_on_world_market_history_mode_selected)
	if world_market_chart:
		world_market_chart.set_mode(WORLD_MARKET_CHART_SCRIPT.ChartMode.LINE)
	if research_button:
		research_button.pressed.connect(_on_research_button_pressed)
	if research_close_button:
		research_close_button.pressed.connect(_on_research_close_pressed)
	if research_new_products_button:
		research_new_products_button.toggled.connect(_on_research_new_products_button_toggled)
	if research_improve_button:
		research_improve_button.toggled.connect(_on_research_improve_button_toggled)
	if personnel_button:
		personnel_button.pressed.connect(_on_personnel_button_pressed)
	if personnel_hire_button:
		personnel_hire_button.pressed.connect(_on_personnel_hire_pressed)
	if personnel_close_button:
		personnel_close_button.pressed.connect(_on_personnel_close_pressed)
	if build_button:
		build_button.pressed.connect(_on_build_button_pressed)
	if build_close_button:
		build_close_button.pressed.connect(_on_build_close_pressed)
	if field_manager == null:
		call_deferred("_refresh_field_manager")
	GameState.money_changed.connect(_on_money_changed)
	GameState.inventory_changed.connect(_on_inventory_changed)
	GameState.supplies_changed.connect(_on_supplies_changed)
	GameState.market_log_updated.connect(_on_market_log_updated)
	if GameState.has_signal("world_market_updated"):
		GameState.world_market_updated.connect(_on_world_market_updated)
	GameState.rent_cost_changed.connect(_on_rent_cost_changed)
	GameState.research_state_changed.connect(_on_research_state_changed)
	GameState.farmers_changed.connect(_on_farmers_changed)
	GameState.fields_changed.connect(_on_fields_changed)
	_latest_inventory = GameState.get_inventory()
	_latest_supplies = GameState.get_supplies()
	_latest_farmers = GameState.get_farmers()
	_known_field_names = GameState.get_known_fields()
	_on_money_changed(GameState.money)
	_on_inventory_changed(_latest_inventory)
	_setup_market_ui()
	_on_world_market_updated(GameState.get_world_market_overview())
	_setup_world_market_ui()
	_setup_research_ui()
	_on_supplies_changed(_latest_supplies)
	_on_market_log_updated(GameState.get_market_log())
	_on_rent_cost_changed(GameState.get_hourly_rent_cost())
	_on_research_state_changed(GameState.get_research_state())
	_update_personnel_view()
	if GameState.has_signal("build_mode_changed"):
		GameState.build_mode_changed.connect(_on_build_mode_changed)
	if GameState.has_signal("build_catalog_changed"):
		GameState.build_catalog_changed.connect(_on_build_catalog_changed)
	if GameState.has_signal("build_constructed"):
		GameState.build_constructed.connect(_on_build_constructed)
	_refresh_build_menu()
	_refresh_build_info_label()
	if menu:
		menu.clear()
		var callback := Callable(self, "_on_menu_id")
		if not menu.id_pressed.is_connected(callback):
			menu.id_pressed.connect(callback)
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
	if menu == null:
		return
	if tile == null or not is_instance_valid(tile):
		return
	current_tile = tile
	var has_entries: bool = _build_menu_for_tile(tile)
	if not has_entries:
		current_tile = null
		return
	menu.visible = true
	_popup_at_position(screen_pos)
	print("Menu opened for tile:", tile.name)


func _on_menu_id(id: int):
	if id == MENU_CANCEL_ID:
		_close_menu()
		return
	if current_tile == null or not is_instance_valid(current_tile):
		_close_menu()
		return
	var metadata: MenuEntryMetadata = _get_menu_metadata(id)
	if metadata.is_empty():
		_close_menu()
		return
	var action: String = metadata.action
	var success: bool = false
	match action:
		MENU_ACTION_PLANT:
			success = _handle_menu_plant(metadata)
		MENU_ACTION_FERTILIZE:
			success = _handle_menu_fertilize(metadata)
		_:
			print("Unbekannte Menu-Aktion:", action)
	if success:
		_close_menu()
	else:
		if menu and menu.visible and is_instance_valid(current_tile):
			_build_menu_for_tile(current_tile)


func _get_menu_metadata(id: int) -> MenuEntryMetadata:
	if _menu_entries.has(id):
		return _menu_entries[id]
	return MenuEntryMetadata.new()

func _handle_menu_plant(metadata: MenuEntryMetadata) -> bool:
	if current_tile == null or not is_instance_valid(current_tile):
		return false
	var crop_id: String = metadata.crop_id
	if crop_id.is_empty():
		return false
	var connected_tiles := _resolve_connected_tiles(current_tile)
	var plantable_tiles: Array = []
	for tile in connected_tiles:
		if tile == null or not is_instance_valid(tile):
			continue
		var tile_state := _resolve_field_state(tile)
		if tile_state != FIELD_STATE_EMPTY:
			print("Verbundene Felder muessen frei sein fuer die Aussaat (z. B. %s)." % tile.name)
			return false
		plantable_tiles.append(tile)
	if plantable_tiles.is_empty():
		print("Keine verfuegbaren Felder fuer die Aussaat gefunden.")
		return false
	var seed_id: String = metadata.seed_id
	if seed_id.is_empty():
		seed_id = _get_seed_id_for_crop(crop_id)
	var required_seeds := plantable_tiles.size()
	if not seed_id.is_empty():
		if not GameState.has_supply(seed_id, required_seeds):
			print("Es sind nicht genug %s verfuegbar (%d benoetigt)." % [
				GameState.get_display_name(seed_id),
				required_seeds,
			])
			return false
		if not GameState.consume_supply(seed_id, required_seeds):
			print("Fehler beim Verbrauchen von %s." % GameState.get_display_name(seed_id))
			return false
	var growth_seconds: float = DEFAULT_GROWTH_SECONDS
	if GameState.has_method("get_crop_growth_duration"):
		growth_seconds = GameState.get_crop_growth_duration(crop_id)
	elif GameState.has_method("get_crop_base_growth_time"):
		growth_seconds = GameState.get_crop_base_growth_time(crop_id)
	if growth_seconds <= 0.0:
		growth_seconds = DEFAULT_GROWTH_SECONDS
	for tile in plantable_tiles:
		tile.call_deferred("start_growth", crop_id, growth_seconds)
	return true

func _handle_menu_fertilize(metadata: MenuEntryMetadata) -> bool:
	if current_tile == null or not is_instance_valid(current_tile):
		return false
	var state := _resolve_field_state(current_tile)
	if state != FIELD_STATE_GROWING:
		print("Duenger kann nur auf wachsende Felder angewendet werden.")
		return false
	var fertilizer_id: String = metadata.fertilizer_id
	if fertilizer_id.is_empty():
		return false
	if not GameState.has_supply(fertilizer_id):
		print("Kein %s verfuegbar. Kaufe ihn im Markt." % GameState.get_display_name(fertilizer_id))
		return false
	if not current_tile.has_method("apply_fertilizer"):
		print("Dieses Feld akzeptiert keinen Duenger:", current_tile.name)
		return false
	if GameState.get_fertilizer_effects(fertilizer_id).is_empty():
		print("Duenger hat keine Effekte und wird ignoriert:", fertilizer_id)
		return false
	if current_tile.has_method("can_apply_fertilizer") and not current_tile.call("can_apply_fertilizer", fertilizer_id):
		print("Aktueller Feldstatus erlaubt keinen Duenger:", current_tile.name)
		return false
	if not GameState.consume_supply(fertilizer_id):
		print("Fehler beim Verbrauchen von %s." % GameState.get_display_name(fertilizer_id))
		return false
	var application_result: Variant = current_tile.call("apply_fertilizer", fertilizer_id)
	if application_result is bool and not application_result:
		print("Duenger konnte nicht angewendet werden auf", current_tile.name)
		return false
	return true

func _resolve_connected_tiles(tile: Node) -> Array:
	if tile == null:
		return []
	var resolved: Array = []
	if tile.has_method("get_connected_fields"):
		var result_variant: Variant = tile.call("get_connected_fields")
		if result_variant is Array:
			for entry in result_variant:
				if entry == null or not is_instance_valid(entry):
					continue
				if resolved.has(entry):
					continue
				resolved.append(entry)
	if resolved.is_empty():
		resolved.append(tile)
	elif not resolved.has(tile):
		resolved.insert(0, tile)
	return resolved

func _close_menu() -> void:
	if menu:
		menu.hide()
	_menu_entries.clear()
	_menu_id_counter = 1
	current_tile = null
	_current_menu_field_state = FIELD_STATE_UNKNOWN

func _build_menu_for_tile(tile: Node) -> bool:
	if menu == null:
		return false
	_reset_menu_state()
	_current_menu_field_state = _resolve_field_state(tile)
	var total_added := 0
	if _current_menu_field_state == FIELD_STATE_EMPTY:
		total_added += _add_seed_menu_entries()
	elif _current_menu_field_state == FIELD_STATE_GROWING:
		total_added += _add_fertilizer_menu_entries()
	if total_added <= 0:
		_reset_menu_state()
		return false
	menu.add_separator()
	_add_cancel_entry()
	return true

func _reset_menu_state() -> void:
	_menu_entries.clear()
	_menu_id_counter = 1
	if menu:
		menu.clear()

func _request_menu_id() -> int:
	var id := _menu_id_counter
	_menu_id_counter += 1
	if id == MENU_CANCEL_ID:
		return _request_menu_id()
	return id

func _add_cancel_entry() -> void:
	menu.add_item("Abbrechen", MENU_CANCEL_ID)
	var index := menu.get_item_index(MENU_CANCEL_ID)
	if index == -1:
		index = menu.item_count - 1
	var metadata: MenuEntryMetadata = MenuEntryMetadata.new()
	metadata.action = "cancel"
	menu.set_item_metadata(index, metadata)
	_menu_entries[MENU_CANCEL_ID] = metadata

func _get_seed_id_for_crop(crop_id: String) -> String:
	if GameState.has_method("get_crop_seed_id"):
		var resolved := String(GameState.get_crop_seed_id(crop_id))
		if not resolved.is_empty():
			return resolved
	return String(CROP_TO_SEED.get(crop_id, ""))

func _add_seed_menu_entries() -> int:
	var added := 0
	for crop_id in CROP_MENU_ORDER:
		var crop_name := GameState.get_display_name(crop_id)
		var seed_id := _get_seed_id_for_crop(crop_id)
		var seed_count := 0
		if not seed_id.is_empty():
			seed_count = GameState.get_supply_amount(seed_id)
		var available := seed_id.is_empty() or seed_count > 0
		var label := crop_name
		if not seed_id.is_empty():
			label = "%s (Samen: %d)" % [crop_name, seed_count]
		var tooltip := ""
		if not available and not seed_id.is_empty():
			tooltip = "Keine %s verfuegbar. Kaufe sie im Markt." % GameState.get_display_name(seed_id)
		var id := _request_menu_id()
		menu.add_item(label, id)
		var index := menu.get_item_index(id)
		if index == -1:
			index = menu.item_count - 1
		menu.set_item_disabled(index, not available)
		if not tooltip.is_empty():
			menu.set_item_tooltip(index, tooltip)
		var metadata: MenuEntryMetadata = MenuEntryMetadata.new()
		metadata.action = MENU_ACTION_PLANT
		metadata.crop_id = crop_id
		metadata.seed_id = seed_id
		menu.set_item_metadata(index, metadata)
		_menu_entries[id] = metadata
		added += 1
	return added

func _add_fertilizer_menu_entries() -> int:
	var added := 0
	var catalog := GameState.get_market_catalog()
	var fertilizer_entries: Array = catalog.get("fertilizer", [])
	for entry in fertilizer_entries:
		if not entry is Dictionary:
			continue
		var entry_dict := entry as Dictionary
		var item_id := String(entry_dict.get("id", ""))
		if item_id.is_empty():
			continue
		var display_name := GameState.get_display_name(item_id)
		var owned := GameState.get_supply_amount(item_id)
		var label := "%s (Bestand: %d)" % [display_name, owned]
		var tooltip_lines := GameState.get_fertilizer_effect_lines(item_id)
		tooltip_lines.append("Wirkt auf wachsende Felder.")
		if owned <= 0:
			tooltip_lines.append("Nicht auf Lager. Kaufe im Markt.")
		var tooltip := "\n".join(tooltip_lines)
		var id := _request_menu_id()
		menu.add_item(label, id)
		var index := menu.get_item_index(id)
		if index == -1:
			index = menu.item_count - 1
		menu.set_item_disabled(index, owned <= 0)
		if not tooltip.is_empty():
			menu.set_item_tooltip(index, tooltip)
		var metadata: MenuEntryMetadata = MenuEntryMetadata.new()
		metadata.action = MENU_ACTION_FERTILIZE
		metadata.fertilizer_id = item_id
		menu.set_item_metadata(index, metadata)
		_menu_entries[id] = metadata
		added += 1
	return added

func _resolve_field_state(tile: Node) -> int:
	if tile == null or not is_instance_valid(tile):
		return FIELD_STATE_UNKNOWN
	if tile.has_method("get_field_state"):
		return int(tile.call("get_field_state"))
	var raw_state = tile.get("state")
	if typeof(raw_state) == TYPE_INT:
		return int(raw_state)
	return FIELD_STATE_UNKNOWN

func _on_money_changed(amount: int) -> void:
	if money_label:
		money_label.text = "Geld: %d" % amount
	_update_market_money(amount)
	_update_market_buttons_state(amount)
	_update_research_rows()
	_update_build_button_states()

func _on_rent_cost_changed(hourly_cost: int) -> void:
	if rent_label:
		var rented_fields := 0
		if GameState.has_method("get_rented_field_count"):
			rented_fields = GameState.get_rented_field_count()
		if rented_fields <= 0:
			rent_label.text = "Mietkosten: 0 G/Stunde"
		else:
			var feld_text := "Felder" if rented_fields != 1 else "Feld"
			rent_label.text = "Mietkosten: %d G/Stunde (%d %s)" % [hourly_cost, rented_fields, feld_text]

func _find_field_manager() -> Node:
	var managers: Array[Node] = get_tree().get_nodes_in_group("field_manager")
	if managers.is_empty():
		return null
	return managers[0]

func _get_current_field_count() -> int:
	if field_manager == null:
		field_manager = _find_field_manager()
	if field_manager and field_manager.has_method("get_field_count"):
		var field_count_variant: Variant = field_manager.call("get_field_count")
		match typeof(field_count_variant):
			TYPE_INT:
				return int(field_count_variant)
			TYPE_FLOAT:
				return int(round(float(field_count_variant)))
	if not _known_field_names.is_empty():
		return _known_field_names.size()
	return 0

func _refresh_field_manager() -> void:
	field_manager = _find_field_manager()

func _on_storage_button_pressed() -> void:
	if storage_popup == null:
		return
	_on_inventory_changed(GameState.get_inventory())
	storage_popup.popup_centered_ratio(0.9)

func _on_storage_close_pressed() -> void:
	if storage_popup:
		storage_popup.hide()

func _on_inventory_changed(storage: Dictionary) -> void:
	_latest_inventory = storage.duplicate(true)
	_update_storage_view()

func _on_supplies_changed(supplies: Dictionary) -> void:
	_latest_supplies = supplies.duplicate(true)
	_update_market_supplies(_latest_supplies)
	_update_storage_view()
	if menu and menu.visible and current_tile and is_instance_valid(current_tile):
		_build_menu_for_tile(current_tile)

func _on_market_log_updated(entries: Array) -> void:
	_update_market_log(entries)

func _update_storage_view() -> void:
	if storage_items_container == null or storage_empty_label == null or storage_items_scroll == null:
		return
	_clear_storage_items()
	var categories := _collect_storage_categories()
	var has_entries := false
	for category_entry in categories:
		var category_id := String(category_entry.get("id", ""))
		var items: Array = category_entry.get("items", [])
		if items.is_empty():
			continue
		has_entries = true
		var section := _create_storage_section(category_id, items)
		if section:
			storage_items_container.add_child(section)
	if not has_entries:
		storage_items_scroll.visible = false
		storage_empty_label.visible = true
		return
	storage_empty_label.visible = false
	storage_items_scroll.visible = true

func _format_tons(amount: float) -> String:
	var rounded: float = round(amount * 100.0) / 100.0
	if is_equal_approx(rounded, round(rounded)):
		return str(int(round(rounded)))
	return "%.2f" % rounded

func _clear_storage_items() -> void:
	for child in storage_items_container.get_children():
		child.queue_free()

func _collect_storage_categories() -> Array:
	var categories: Dictionary = {}
	for category_id in STORAGE_CATEGORY_ORDER:
		categories[category_id] = []
	for item_id in _latest_supplies.keys():
		var amount: int = int(_latest_supplies.get(item_id, 0))
		if amount <= 0:
			continue
		var category_id := GameState.get_item_category(item_id)
		if not categories.has(category_id):
			categories[category_id] = []
		var items: Array = categories[category_id]
		items.append({
			"id": item_id,
			"amount": amount,
		})
	for item_id in _latest_inventory.keys():
		var amount: float = float(_latest_inventory.get(item_id, 0.0))
		if amount <= 0.0:
			continue
		var category_id := GameState.ITEM_CATEGORY_HARVESTED
		if not categories.has(category_id):
			categories[category_id] = []
		var harvest_items: Array = categories[category_id]
		harvest_items.append({
			"id": item_id,
			"amount": amount,
		})
	var ordered: Array = []
	for category_id in STORAGE_CATEGORY_ORDER:
		var list: Array = categories.get(category_id, [])
		list.sort_custom(Callable(self, "_sort_storage_items_by_name"))
		ordered.append({
			"id": category_id,
			"items": list,
		})
	for category_id in categories.keys():
		if STORAGE_CATEGORY_ORDER.has(category_id):
			continue
		var list: Array = categories[category_id]
		list.sort_custom(Callable(self, "_sort_storage_items_by_name"))
		ordered.append({
			"id": category_id,
			"items": list,
		})
	return ordered

func _sort_storage_items_by_name(a: Dictionary, b: Dictionary) -> bool:
	var name_a: String = GameState.get_display_name(String(a.get("id", "")))
	var name_b: String = GameState.get_display_name(String(b.get("id", "")))
	return name_a.casecmp_to(name_b) < 0

func _create_storage_section(category_id: String, items: Array) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.name = "StorageSection_%s" % category_id
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 6)

	var header := Label.new()
	header.text = GameState.get_category_display_name(category_id)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	section.add_child(header)

	for item_data in items:
		if not item_data is Dictionary:
			continue
		var item_id := String(item_data.get("id", ""))
		if item_id.is_empty():
			continue
		var amount_value: Variant = item_data.get("amount", 0)
		var row := _create_storage_row(category_id, item_id, amount_value)
		if row:
			section.add_child(row)
	return section

func _create_storage_row(category_id: String, item_id: String, amount: Variant) -> Control:
	match category_id:
		GameState.ITEM_CATEGORY_HARVESTED:
			return _create_storage_harvest_row(item_id, float(amount))
		_:
			return _create_storage_supply_row(item_id, int(amount))

func _create_storage_harvest_row(item_id: String, amount: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "StorageHarvest_%s" % item_id
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)

	var name_label := Label.new()
	var unit: String = GameState.get_item_unit(item_id)
	if unit.is_empty():
		unit = "t"
	name_label.text = "%s (%s %s verfuegbar)" % [GameState.get_display_name(item_id), _format_tons(amount), unit]
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

	var seed_button := Button.new()
	seed_button.text = "Zu Samen"
	seed_button.focus_mode = Control.FOCUS_NONE
	var can_convert := false
	if GameState.has_method("can_convert_harvest_to_seeds"):
		can_convert = GameState.can_convert_harvest_to_seeds(item_id)
	var has_processing := false
	if GameState.has_method("has_seed_processing"):
		has_processing = GameState.has_seed_processing()
	seed_button.disabled = not can_convert
	var conversion_tooltip := ""
	var recipe: Dictionary = {}
	if GameState.has_method("get_seed_conversion_recipe"):
		recipe = GameState.get_seed_conversion_recipe(item_id)
	if not recipe.is_empty():
		var seed_id := String(recipe.get("seed_id", ""))
		var tons_per_seed := float(recipe.get("input_tons_per_seed", 0.0))
		var ratio_text := _format_tons(tons_per_seed)
		var seed_name := GameState.get_display_name(seed_id)
		conversion_tooltip = "Verarbeitet %s t zu 1 %s." % [ratio_text, seed_name]
	if not can_convert:
		if not has_processing:
			if conversion_tooltip.is_empty():
				conversion_tooltip = "Benoetigt eine Samenproduktion."
			else:
				conversion_tooltip += "\nBenoetigt eine Samenproduktion."
		else:
			var lacking_text := "Nicht genug Ernte fuer eine Umwandlung."
			if conversion_tooltip.is_empty():
				conversion_tooltip = lacking_text
			else:
				conversion_tooltip += "\n%s" % lacking_text
	seed_button.tooltip_text = conversion_tooltip
	row.add_child(seed_button)

	var sell_button := Button.new()
	sell_button.text = "Verkaufen"
	sell_button.focus_mode = Control.FOCUS_NONE
	row.add_child(sell_button)

	plus_button.pressed.connect(Callable(self, "_on_storage_adjust_pressed").bind(item_id, amount_input, 1.0))
	minus_button.pressed.connect(Callable(self, "_on_storage_adjust_pressed").bind(item_id, amount_input, -1.0))
	seed_button.pressed.connect(Callable(self, "_on_storage_convert_to_seeds_pressed").bind(item_id, amount_input))
	sell_button.pressed.connect(Callable(self, "_on_storage_sell_pressed").bind(item_id, amount_input))
	amount_input.text_submitted.connect(Callable(self, "_on_storage_sell_pressed").bind(item_id, amount_input))

	return row

func _create_storage_supply_row(item_id: String, amount: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "StorageSupply_%s" % item_id
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)

	var name_label := Label.new()
	name_label.text = GameState.get_display_name(item_id)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(name_label)

	var amount_label := Label.new()
	var unit: String = GameState.get_item_unit(item_id)
	if unit.is_empty():
		unit = "Stk"
	var formatted_amount: String = "%d" % int(amount)
	amount_label.text = "%s %s" % [formatted_amount, unit]
	amount_label.size_flags_horizontal = Control.SIZE_FILL
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount_label.custom_minimum_size = Vector2(120, 0)
	row.add_child(amount_label)

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

func _on_storage_convert_to_seeds_pressed(item_id: String, input: LineEdit) -> void:
	var requested: float = _parse_tons(input.text)
	if requested <= 0.0:
		input.text = "0"
		return
	if not GameState.has_method("convert_harvest_to_seeds"):
		print("Samenverarbeitung ist aktuell nicht verfuegbar.")
		return
	var result_variant: Variant = GameState.convert_harvest_to_seeds(item_id, requested)
	if not (result_variant is Dictionary):
		print("Unerwartetes Ergebnis bei der Samenverarbeitung.")
		return
	var result: Dictionary = result_variant
	if bool(result.get("success", false)):
		input.text = "0"
		var produced := int(result.get("produced", 0))
		var seed_id := String(result.get("seed_id", ""))
		if produced > 0 and not seed_id.is_empty():
			print("Samenproduktion: %d %s hergestellt." % [produced, GameState.get_display_name(seed_id)])
		return
	var reason := String(result.get("reason", ""))
	match reason:
		"no_facility":
			print("Benoetigt eine Samenproduktion, um Samen herzustellen.")
		"insufficient_input":
			print("Nicht genug Ernte vorhanden fuer die Samenproduktion.")
		"invalid_amount":
			print("Bitte gib eine Menge groesser 0 ein.")
		_:
			print("Samenproduktion fehlgeschlagen:", reason)
	var available: float = 0.0
	if GameState.has_method("get_storage_amount"):
		available = GameState.get_storage_amount(item_id)
	input.text = _format_tons(available)

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

	var tooltip := GameState.get_market_item_tooltip(item_id)
	if not tooltip.is_empty():
		row.tooltip_text = tooltip
		name_label.tooltip_text = tooltip
		price_label.tooltip_text = tooltip
		owned_label.tooltip_text = tooltip
		buy_button.tooltip_text = tooltip

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

func _setup_world_market_ui() -> void:
	_world_market_entries.clear()
	if world_market_list:
		world_market_list.clear()
	_refresh_world_market_list(false)

func _refresh_world_market_list(preserve_selection: bool = true) -> void:
	if world_market_list == null:
		return
	var previous_selection := _world_market_selection if preserve_selection else ""
	var query := ""
	if world_market_search:
		query = world_market_search.text
	if GameState.has_method("search_world_market_products"):
		_world_market_entries = GameState.search_world_market_products(query)
	else:
		_world_market_entries.clear()
	world_market_list.clear()
	if _world_market_entries.is_empty():
		world_market_list.add_item("Keine Ergebnisse")
		world_market_list.set_item_disabled(0, true)
		_world_market_selection = ""
		_reset_world_market_details()
		return
	var selected_index := -1
	for index in range(_world_market_entries.size()):
		var entry_variant: Variant = _world_market_entries[index]
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant as Dictionary
		var product_id := String(entry.get("id", ""))
		var display_name := String(entry.get("display_name", product_id))
		var price := float(entry.get("current_price", 0.0))
		var item_text := "%s  (%.2f)" % [display_name, price]
		world_market_list.add_item(item_text)
		if preserve_selection and not previous_selection.is_empty() and product_id == previous_selection:
			selected_index = index
	if selected_index < 0:
		selected_index = 0
	world_market_list.select(selected_index)
	if selected_index >= 0 and selected_index < _world_market_entries.size():
		var selected_entry_variant: Variant = _world_market_entries[selected_index]
		if selected_entry_variant is Dictionary:
			var selected_entry: Dictionary = selected_entry_variant as Dictionary
			_world_market_selection = String(selected_entry.get("id", ""))
			_update_world_market_details(_world_market_selection)
	else:
		_world_market_selection = ""
		_reset_world_market_details()

func _reset_world_market_details() -> void:
	if world_market_selected_label:
		world_market_selected_label.text = "Auswahl: -"
	if world_market_price_label:
		world_market_price_label.text = "Preis: -"
	if world_market_supply_label:
		world_market_supply_label.text = "Angebot: - | Nachfrage: -"
	if world_market_updated_label:
		world_market_updated_label.text = "Aktualisiert: -"
	_populate_world_market_history([])

func _update_world_market_details(product_id: String) -> void:
	_reset_world_market_details()
	if product_id.is_empty():
		return
	var entry: Dictionary = {}
	if GameState.has_method("get_world_market_entry"):
		entry = GameState.get_world_market_entry(product_id)
	if entry.is_empty():
		return
	var display_name := String(entry.get("display_name", product_id))
	if world_market_selected_label:
		world_market_selected_label.text = "Auswahl: %s" % display_name
	if world_market_price_label:
		world_market_price_label.text = "Preis: %.2f" % float(entry.get("current_price", 0.0))
	if world_market_supply_label:
		var supply := float(entry.get("supply_index", 0.0))
		var demand := float(entry.get("demand_index", 0.0))
		world_market_supply_label.text = "Angebot: %.1f | Nachfrage: %.1f" % [supply, demand]
	if world_market_updated_label:
		world_market_updated_label.text = "Aktualisiert: %s" % _format_world_market_timestamp(int(entry.get("last_update", 0)))
	var history: Array = []
	if GameState.has_method("get_world_market_history"):
		history = GameState.get_world_market_history(product_id)
	_populate_world_market_history(history)

func _populate_world_market_history(history: Array) -> void:
	if world_market_chart:
		world_market_chart.set_history(history)

func _on_world_market_history_mode_selected(index: int) -> void:
	if world_market_chart == null:
		return
	var new_mode: int = WORLD_MARKET_CHART_SCRIPT.ChartMode.LINE
	if index == 1:
		new_mode = WORLD_MARKET_CHART_SCRIPT.ChartMode.CANDLE
	world_market_chart.set_mode(new_mode)

func _format_world_market_timestamp(timestamp: int) -> String:
	if timestamp <= 0:
		return "unbekannt"
	var now := Time.get_ticks_msec()
	var delta_ms := int(max(now - timestamp, 0))
	var seconds := delta_ms / 1000
	if seconds <= 1:
		return "gerade eben"
	if seconds < 60:
		return "vor %d s" % seconds
	var minutes := seconds / 60
	if minutes < 60:
		return "vor %d min" % minutes
	var hours := minutes / 60
	if hours < 24:
		return "vor %d h" % hours
	var days := hours / 24
	return "vor %d d" % days

func _on_world_market_updated(state: Dictionary) -> void:
	_world_market_overview = state.duplicate(true)
	if world_market_button:
		world_market_button.tooltip_text = "Weltweiter Markt (%d Produkte)" % int(state.size())
	if world_market_popup and world_market_popup.visible:
		_refresh_world_market_list()

func _on_world_market_button_pressed() -> void:
	_refresh_world_market_list()
	if world_market_popup:
		world_market_popup.popup_centered_ratio(0.85)
		if world_market_search:
			world_market_search.grab_focus()

func _on_world_market_close_pressed() -> void:
	if world_market_popup:
		world_market_popup.hide()

func _on_world_market_search_changed(new_text: String) -> void:
	_refresh_world_market_list()

func _on_world_market_search_submitted(new_text: String) -> void:
	_refresh_world_market_list()
	if world_market_list:
		world_market_list.grab_focus()

func _on_world_market_clear_pressed() -> void:
	if world_market_search:
		world_market_search.text = ""
	_refresh_world_market_list(false)
	if world_market_search:
		world_market_search.grab_focus()

func _on_world_market_item_selected(index: int) -> void:
	if index < 0 or index >= _world_market_entries.size():
		return
	var entry_variant: Variant = _world_market_entries[index]
	if not (entry_variant is Dictionary):
		return
	var entry: Dictionary = entry_variant as Dictionary
	_world_market_selection = String(entry.get("id", ""))
	_update_world_market_details(_world_market_selection)

func _setup_research_ui() -> void:
	if research_improve_entries_container == null or research_empty_label == null:
		return
	for child in research_improve_entries_container.get_children():
		child.queue_free()
	_research_rows.clear()
	var crop_ids: Array = []
	if GameState.has_method("get_crop_ids"):
		crop_ids = GameState.get_crop_ids()
	else:
		crop_ids = CROP_MENU_ORDER.duplicate()
	var added := false
	var first_section := true
	for crop_variant in crop_ids:
		var crop_id := String(crop_variant)
		if crop_id.is_empty():
			continue
		var options_variant := []
		if GameState.has_method("get_research_options_for_crop"):
			options_variant = GameState.get_research_options_for_crop(crop_id)
		var options: Array = []
		if options_variant is Array:
			options = options_variant
		if options.is_empty():
			continue
		var ordered: Array = []
		for prefer in ["yield", "speed"]:
			if options.has(prefer):
				ordered.append(prefer)
		for option in options:
			if not ordered.has(option):
				ordered.append(option)
		var section := VBoxContainer.new()
		section.name = "ResearchSection_%s" % crop_id
		section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		section.add_theme_constant_override("separation", 4)
		var header := Label.new()
		header.text = GameState.get_display_name(crop_id)
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		header.add_theme_font_size_override("font_size", 18)
		section.add_child(header)
		var section_entries := 0
		for option_variant in ordered:
			var research_type := String(option_variant)
			var entry := _create_research_entry(crop_id, research_type)
			if entry.is_empty():
				continue
			section.add_child(entry["container"])
			var key := String(entry.get("key", ""))
			_research_rows[key] = entry
			section_entries += 1
		if section_entries <= 0:
			continue
		if not first_section:
			var separator := HSeparator.new()
			separator.name = "ResearchSeparator_%s" % crop_id
			research_improve_entries_container.add_child(separator)
		first_section = false
		research_improve_entries_container.add_child(section)
		added = true
	if research_new_products_section:
		research_new_products_section.visible = true
	if research_improve_section:
		research_improve_section.visible = true
	if research_entries_scroll:
		research_entries_scroll.visible = true
	_research_improve_has_entries = added
	if not _research_improve_has_entries:
		_research_improve_expanded = false
	_update_research_category_visibility()
	_update_research_category_buttons()
	if research_empty_label:
		research_empty_label.visible = not added
	_update_research_rows()

func _update_research_category_visibility() -> void:
	if research_new_products_grid:
		research_new_products_grid.visible = _research_new_products_expanded
	if research_improve_entries_container:
		research_improve_entries_container.visible = _research_improve_expanded and _research_improve_has_entries

func _update_research_category_buttons() -> void:
	if research_new_products_button:
		research_new_products_button.set_pressed_no_signal(_research_new_products_expanded)
		var new_products_prefix := "[-]" if _research_new_products_expanded else "[+]"
		research_new_products_button.text = "%s Neue Produkte erforschen" % new_products_prefix
	if research_improve_button:
		var effective_expanded := _research_improve_expanded and _research_improve_has_entries
		research_improve_button.set_pressed_no_signal(effective_expanded)
		var improve_prefix := "[-]" if effective_expanded else "[+]"
		research_improve_button.text = "%s Bekannte Pflanzen verbessern" % improve_prefix
		research_improve_button.disabled = not _research_improve_has_entries

func _set_research_new_products_expanded(expanded: bool) -> void:
	_research_new_products_expanded = expanded
	_update_research_category_visibility()
	_update_research_category_buttons()

func _set_research_improve_expanded(expanded: bool) -> void:
	if not _research_improve_has_entries:
		expanded = false
	_research_improve_expanded = expanded
	_update_research_category_visibility()
	_update_research_category_buttons()

func _on_research_new_products_button_toggled(pressed: bool) -> void:
	_set_research_new_products_expanded(pressed)

func _on_research_improve_button_toggled(pressed: bool) -> void:
	_set_research_improve_expanded(pressed)

func _create_research_entry(crop_id: String, research_type: String) -> Dictionary:
	if crop_id.is_empty() or research_type.is_empty():
		return {}
	if not GameState.has_method("get_research_info"):
		return {}
	var info := GameState.get_research_info(crop_id, research_type)
	if info.is_empty():
		return {}
	var container := VBoxContainer.new()
	container.name = "Research_%s_%s" % [crop_id, research_type]
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_theme_constant_override("separation", 2)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	container.add_child(row)
	var name_label := Label.new()
	name_label.text = String(info.get("label", research_type.capitalize()))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(name_label)
	var level_label := Label.new()
	level_label.size_flags_horizontal = Control.SIZE_FILL
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_label.custom_minimum_size = Vector2(130, 0)
	row.add_child(level_label)
	var effect_label := Label.new()
	effect_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	effect_label.custom_minimum_size = Vector2(220, 0)
	row.add_child(effect_label)
	var cost_label := Label.new()
	cost_label.size_flags_horizontal = Control.SIZE_FILL
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_label.custom_minimum_size = Vector2(160, 0)
	row.add_child(cost_label)
	var button := Button.new()
	button.text = "Forschen"
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(Callable(self, "_on_research_upgrade_pressed").bind(crop_id, research_type))
	row.add_child(button)
	var description_label := Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description_label.visible = false
	container.add_child(description_label)
	return {
		"key": "%s::%s" % [crop_id, research_type],
		"crop_id": crop_id,
		"research_type": research_type,
		"container": container,
		"name_label": name_label,
		"level_label": level_label,
		"effect_label": effect_label,
		"cost_label": cost_label,
		"button": button,
		"description_label": description_label,
	}

func _update_research_rows() -> void:
	if _research_rows.is_empty():
		return
	for entry in _research_rows.values():
		if not (entry is Dictionary):
			continue
		var data: Dictionary = entry
		var crop_id := String(data.get("crop_id", ""))
		var research_type := String(data.get("research_type", ""))
		if crop_id.is_empty() or research_type.is_empty():
			continue
		if not GameState.has_method("get_research_info"):
			continue
		var info := GameState.get_research_info(crop_id, research_type)
		if info.is_empty():
			continue
		var level_label: Label = data.get("level_label", null)
		var effect_label: Label = data.get("effect_label", null)
		var cost_label: Label = data.get("cost_label", null)
		var description_label: Label = data.get("description_label", null)
		var button: Button = data.get("button", null)
		var name_label: Label = data.get("name_label", null)
		var level := int(info.get("level", 0))
		var max_level := int(info.get("max_level", 0))
		var level_text := "Stufe %d" % level
		if max_level > 0:
			level_text = "Stufe %d / %d" % [level, max_level]
		if level_label:
			level_label.text = level_text
		if effect_label:
			effect_label.text = String(info.get("effect_text", ""))
		var is_maxed := bool(info.get("is_maxed", false))
		var next_cost := int(info.get("next_cost", 0))
		if cost_label:
			if is_maxed:
				cost_label.text = "Max. Stufe erreicht"
			elif next_cost > 0:
				cost_label.text = "Kosten: %d G" % next_cost
			else:
				cost_label.text = ""
		var description := String(info.get("description", ""))
		if description_label:
			description_label.text = description
			description_label.visible = not description.is_empty()
		if button:
			button.disabled = is_maxed or next_cost <= 0 or GameState.money < next_cost
			button.tooltip_text = description
		if name_label:
			name_label.tooltip_text = description

func _on_research_button_pressed() -> void:
	if research_popup:
		_update_research_rows()
		research_popup.popup_centered_ratio(0.8)
	_update_research_category_buttons()
	_update_research_category_visibility()

func _on_research_close_pressed() -> void:
	if research_popup:
		research_popup.hide()

func _on_research_upgrade_pressed(crop_id: String, research_type: String) -> void:
	if not GameState.has_method("research_crop"):
		return
	if not GameState.research_crop(crop_id, research_type):
		print("Forschung fehlgeschlagen fuer", crop_id, research_type)
	_update_research_rows()

func _on_research_state_changed(state: Dictionary) -> void:
	if state is Dictionary:
		_latest_research_state = state.duplicate(true)
	if _research_rows.is_empty():
		_setup_research_ui()
	else:
		_update_research_rows()

func _on_personnel_button_pressed() -> void:
	if personnel_popup == null:
		return
	_update_personnel_view()
	personnel_popup.popup_centered_ratio(0.75)

func _on_personnel_close_pressed() -> void:
	if personnel_popup:
		personnel_popup.hide()

func _on_personnel_hire_pressed() -> void:
	if GameState.has_method("hire_farmer"):
		GameState.hire_farmer()

func _on_farmers_changed(farmers: Array) -> void:
	_latest_farmers.clear()
	for entry in farmers:
		if entry is Dictionary:
			_latest_farmers.append((entry as Dictionary).duplicate(true))
	_update_personnel_view()

func _on_fields_changed(field_names: Array) -> void:
	_known_field_names.clear()
	for entry in field_names:
		if typeof(entry) == TYPE_STRING:
			_known_field_names.append(String(entry))
	_known_field_names.sort()
	_update_build_button_states()
	_refresh_build_info_label()
	_update_personnel_view()

func _update_personnel_view() -> void:
	if personnel_list_container == null or personnel_empty_label == null:
		return
	_personnel_refreshing = true
	_clear_personnel_list()
	if _latest_farmers.is_empty():
		personnel_empty_label.visible = true
	else:
		personnel_empty_label.visible = false
		for farmer in _latest_farmers:
			if farmer is Dictionary:
				_add_personnel_row(farmer)
	_personnel_refreshing = false

func _clear_personnel_list() -> void:
	if personnel_list_container == null:
		return
	for child in personnel_list_container.get_children():
		if child:
			child.queue_free()

func _add_personnel_row(farmer: Dictionary) -> void:
	if personnel_list_container == null:
		return
	var farmer_id := int(farmer.get("id", 0))
	if farmer_id <= 0:
		return
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	var name_label := Label.new()
	name_label.text = String(farmer.get("name", "Farmer %d" % farmer_id))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var status_label := Label.new()
	status_label.text = _format_farmer_status_text(farmer)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(status_label)
	var selector := OptionButton.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_field_selector(selector, String(farmer.get("field_name", "")))
	var select_callable := Callable(self, "_on_personnel_field_selected").bind(farmer_id, selector)
	if not selector.item_selected.is_connected(select_callable):
		selector.item_selected.connect(select_callable)
	row.add_child(selector)
	var fire_button := Button.new()
	fire_button.text = "Entlassen"
	var fire_callable := Callable(self, "_on_personnel_fire_pressed").bind(farmer_id)
	if not fire_button.pressed.is_connected(fire_callable):
		fire_button.pressed.connect(fire_callable)
	row.add_child(fire_button)
	personnel_list_container.add_child(row)

func _build_field_selector(selector: OptionButton, assigned_field: String) -> void:
	if selector == null:
		return
	selector.clear()
	selector.disabled = false
	selector.tooltip_text = ""
	selector.add_item(PERSONNEL_SELECTOR_NONE_LABEL)
	selector.set_item_metadata(0, "")
	var selected_index := 0
	var sanitized := assigned_field.strip_edges()
	for field_name in _known_field_names:
		var display := String(field_name)
		if display.is_empty():
			continue
		selector.add_item(display)
		var index := selector.get_item_count() - 1
		selector.set_item_metadata(index, display)
		if display == sanitized:
			selected_index = index
	if selector.get_item_count() <= 1:
		selector.disabled = _known_field_names.is_empty()
		if selector.disabled:
			selector.tooltip_text = "Kein Feld verfuegbar."
		else:
			selector.tooltip_text = ""
	selector.select(selected_index)

func _on_personnel_field_selected(index: int, farmer_id: int, selector: OptionButton) -> void:
	if _personnel_refreshing:
		return
	if selector == null:
		return
	var metadata: Variant = selector.get_item_metadata(index)
	var field_name := ""
	match typeof(metadata):
		TYPE_STRING:
			field_name = String(metadata)
		TYPE_NIL:
			field_name = ""
		_:
			field_name = String(metadata)
	if field_name.strip_edges().is_empty():
		if GameState.has_method("unassign_farmer"):
			GameState.unassign_farmer(farmer_id)
	else:
		if GameState.has_method("assign_farmer_to_field"):
			GameState.assign_farmer_to_field(farmer_id, field_name)

func _on_personnel_fire_pressed(farmer_id: int) -> void:
	if GameState.has_method("fire_farmer"):
		GameState.fire_farmer(farmer_id)

func _format_farmer_status_text(farmer: Dictionary) -> String:
	var status := String(farmer.get("status", FARMER_STATUS_IDLE))
	match status:
		FARMER_STATUS_ASSIGNED:
			var field_name := String(farmer.get("field_name", ""))
			if field_name.is_empty():
				return "Eingesetzt"
			return "Eingesetzt auf %s" % field_name
		_:
			return "Verfuegbar"

func _on_build_button_pressed() -> void:
	if build_popup == null:
		return
	if build_popup.visible:
		build_popup.hide()
	else:
		_refresh_build_menu()
		var viewport_rect := get_viewport_rect()
		var popup_rect := Rect2i(
			Vector2i(int(round(viewport_rect.position.x)), int(round(viewport_rect.position.y))),
			Vector2i(int(round(viewport_rect.size.x)), int(round(viewport_rect.size.y)))
		)
		build_popup.popup(popup_rect)

func _on_build_close_pressed() -> void:
	if build_popup:
		build_popup.hide()

func _refresh_build_menu() -> void:
	if build_items_container == null or build_category_container == null:
		return
	for child in build_items_container.get_children():
		if child == build_empty_label:
			continue
		if child:
			child.queue_free()
	_build_item_buttons.clear()
	if build_empty_label:
		build_empty_label.visible = true
		build_empty_label.text = "Noch keine Bauoptionen verfuegbar."
	for child in build_category_container.get_children():
		if child:
			child.queue_free()
	_build_category_buttons.clear()
	_build_categories.clear()
	_build_id_to_category.clear()
	if not GameState.has_method("get_build_catalog"):
		return
	var catalog: Dictionary = GameState.get_build_catalog()
	for cat_variant in BUILD_MENU_CATEGORY_ORDER:
		var cat_def: Dictionary = cat_variant
		var cat_id := String(cat_def.get("id", ""))
		if cat_id.is_empty():
			continue
		var cat_label := String(cat_def.get("label", cat_id))
		_build_categories[cat_id] = {
			"id": cat_id,
			"label": cat_label,
			"entries": [],
		}
	for build_id in catalog.keys():
		var def: Dictionary = catalog[build_id]
		var entry := {
			"id": String(build_id),
			"label": String(def.get("label", String(build_id))),
			"category_id": String(def.get("category", "")),
			"category_label": String(def.get("category_label", "")),
			"cost": int(def.get("cost", 0)),
			"description": String(def.get("description", "")),
		}
		var category_id := String(entry.get("category_id", ""))
		if category_id.is_empty():
			category_id = "other"
		var category_label := String(entry.get("category_label", ""))
		if category_label.is_empty():
			category_label = category_id.capitalize()
		if not _build_categories.has(category_id):
			_build_categories[category_id] = {
				"id": category_id,
				"label": category_label,
				"entries": [],
			}
		var category_dict: Dictionary = _build_categories.get(category_id, {})
		var entry_list: Array = category_dict.get("entries", [])
		entry_list.append(entry)
		category_dict["entries"] = entry_list
		var existing_label := String(category_dict.get("label", ""))
		if existing_label.is_empty() or existing_label == category_id:
			category_dict["label"] = category_label
		_build_categories[category_id] = category_dict
		_build_id_to_category[entry.get("id", "")] = category_id
	for category_id in _build_categories.keys():
		var data: Dictionary = _build_categories.get(category_id, {})
		var entry_list: Array = data.get("entries", [])
		entry_list.sort_custom(Callable(self, "_sort_build_entries"))
		data["entries"] = entry_list
		_build_categories[category_id] = data
	_refresh_category_buttons()
	var preferred_category := ""
	if GameState.has_method("get_active_build_mode"):
		var active_id := String(GameState.get_active_build_mode())
		if not active_id.is_empty():
			preferred_category = String(_build_id_to_category.get(active_id, ""))
	if preferred_category.is_empty():
		preferred_category = _active_build_category
	if preferred_category.is_empty():
		preferred_category = _find_first_category_with_entries()
	if preferred_category.is_empty():
		preferred_category = _first_category_id()
	if preferred_category.is_empty():
		return
	_set_active_build_category(preferred_category, true)
	_update_build_button_states()

func _sort_build_entries(a: Dictionary, b: Dictionary) -> bool:
	var label_a := String(a.get("label", ""))
	var label_b := String(b.get("label", ""))
	if label_a != label_b:
		return label_a < label_b
	var id_a := String(a.get("id", ""))
	var id_b := String(b.get("id", ""))
	return id_a < id_b

func _update_build_button_states() -> void:
	var active_id := ""
	if GameState.has_method("get_active_build_mode"):
		active_id = String(GameState.get_active_build_mode())
	if not active_id.is_empty():
		var target_category := String(_build_id_to_category.get(active_id, ""))
		if not target_category.is_empty() and target_category != _active_build_category:
			_set_active_build_category(target_category, true)
	if _build_item_buttons.is_empty():
		if build_popup and build_popup.visible:
			_refresh_build_info_label()
		return
	var catalog: Dictionary = {}
	if GameState.has_method("get_build_catalog"):
		catalog = GameState.get_build_catalog()
	var current_fields := _get_current_field_count()
	for build_id in _build_item_buttons.keys():
		var button: Button = _build_item_buttons.get(build_id, null)
		if button == null:
			continue
		var def_variant: Variant = catalog.get(build_id, {})
		var def: Dictionary = {}
		if def_variant is Dictionary:
			def = def_variant
		var label := String(def.get("label", build_id))
		var cost := int(def.get("cost", 0))
		var build_type := String(def.get("build_type", ""))
		var effective_cost := cost
		if build_type == "field" and current_fields <= 0:
			effective_cost = 0
		button.text = "%s (%d G)" % [label, effective_cost]
		var can_afford := true
		if GameState.has_method("can_afford_build"):
			can_afford = GameState.can_afford_build(build_id)
		if build_type == "field" and current_fields <= 0:
			can_afford = true
		button.disabled = not can_afford
		var description := String(def.get("description", ""))
		if not description.is_empty():
			button.tooltip_text = description
		if _suppress_build_button_update:
			continue
		_suppress_build_button_update = true
		button.button_pressed = (build_id == active_id)
		_suppress_build_button_update = false
	if build_popup and build_popup.visible:
		_refresh_build_info_label()

func _refresh_category_buttons() -> void:
	if build_category_container == null:
		return
	for child in build_category_container.get_children():
		if child:
			child.queue_free()
	_build_category_buttons.clear()
	_build_category_button_group = ButtonGroup.new()
	var ordered_categories: Array = []
	for cat_variant in BUILD_MENU_CATEGORY_ORDER:
		var base_def: Dictionary = cat_variant
		var cat_id := String(base_def.get("id", ""))
		if cat_id.is_empty():
			continue
		if not _build_categories.has(cat_id):
			var placeholder := {
				"id": cat_id,
				"label": String(base_def.get("label", cat_id)),
				"entries": [],
			}
			_build_categories[cat_id] = placeholder
		ordered_categories.append(_build_categories[cat_id])
	for cat_id in _build_categories.keys():
		var found := false
		for category_variant in ordered_categories:
			var category_dict: Dictionary = category_variant
			if String(category_dict.get("id", "")) == cat_id:
				found = true
				break
		if not found:
			ordered_categories.append(_build_categories[cat_id])
	for category_variant in ordered_categories:
		var category_dict: Dictionary = category_variant
		var cat_id := String(category_dict.get("id", ""))
		if cat_id.is_empty():
			continue
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = _build_category_button_group
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = String(category_dict.get("label", cat_id))
		button.toggled.connect(_on_build_category_toggled.bind(cat_id))
		build_category_container.add_child(button)
		_build_category_buttons[cat_id] = button
	_update_category_button_states()

func _set_active_build_category(category_id: String, force: bool = false) -> void:
	if category_id.is_empty():
		return
	if not _build_categories.has(category_id):
		return
	if not force and _active_build_category == category_id:
		return
	_active_build_category = category_id
	_populate_build_items_for_category(category_id)
	_update_category_button_states()

func _populate_build_items_for_category(category_id: String) -> void:
	if build_items_container == null:
		return
	if build_empty_label and build_empty_label.get_parent() == build_items_container:
		build_items_container.remove_child(build_empty_label)
	for child in build_items_container.get_children():
		if child:
			child.queue_free()
	_build_item_buttons.clear()
	var entries: Array = []
	var category_variant: Variant = _build_categories.get(category_id, {})
	var category_label := _get_category_label(category_id)
	if category_variant is Dictionary:
		var category_dict: Dictionary = category_variant
		entries = category_dict.get("entries", [])
	if build_empty_label:
		if category_label.is_empty():
			build_empty_label.text = "Noch keine Bauoptionen verfuegbar."
		else:
			build_empty_label.text = "Keine Bauoptionen in %s." % category_label
	for entry_variant in entries:
		var entry: Dictionary = entry_variant
		var label := String(entry.get("label", ""))
		var cost := int(entry.get("cost", 0))
		var button := Button.new()
		button.toggle_mode = true
		button.text = "%s (%d G)" % [label, cost]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		var description := String(entry.get("description", ""))
		if not description.is_empty():
			button.tooltip_text = description
		var entry_id := String(entry.get("id", ""))
		button.toggled.connect(_on_build_item_toggled.bind(entry_id))
		build_items_container.add_child(button)
		_build_item_buttons[entry_id] = button
	if build_empty_label:
		build_empty_label.visible = entries.is_empty()
		build_items_container.add_child(build_empty_label)

func _update_category_button_states() -> void:
	if _build_category_buttons.is_empty():
		return
	_suppress_category_update = true
	for cat_id in _build_category_buttons.keys():
		var button: Button = _build_category_buttons.get(cat_id, null)
		if button:
			button.button_pressed = (cat_id == _active_build_category)
	_suppress_category_update = false

func _get_category_label(category_id: String) -> String:
	var category_variant: Variant = _build_categories.get(category_id, {})
	if category_variant is Dictionary:
		var category_dict: Dictionary = category_variant
		return String(category_dict.get("label", category_id))
	return category_id

func _find_first_category_with_entries() -> String:
	for cat_variant in BUILD_MENU_CATEGORY_ORDER:
		var base_def: Dictionary = cat_variant
		var cat_id := String(base_def.get("id", ""))
		if cat_id.is_empty():
			continue
		var category_variant: Variant = _build_categories.get(cat_id, {})
		if category_variant is Dictionary:
			var entries: Array = category_variant.get("entries", [])
			if not entries.is_empty():
				return cat_id
	for cat_id in _build_categories.keys():
		var category_variant: Variant = _build_categories.get(cat_id, {})
		if category_variant is Dictionary:
			var entries: Array = category_variant.get("entries", [])
			if not entries.is_empty():
				return String(cat_id)
	return ""

func _first_category_id() -> String:
	for cat_variant in BUILD_MENU_CATEGORY_ORDER:
		var base_def: Dictionary = cat_variant
		var cat_id := String(base_def.get("id", ""))
		if cat_id.is_empty():
			continue
		if _build_categories.has(cat_id):
			return cat_id
	for cat_id in _build_categories.keys():
		return String(cat_id)
	return ""

func _on_build_category_toggled(pressed: bool, category_id: String) -> void:
	if _suppress_category_update:
		return
	if not pressed:
		return
	_set_active_build_category(category_id)
	_update_build_button_states()

func _on_build_item_toggled(pressed: bool, build_id: String) -> void:
	if _suppress_build_button_update:
		return
	if not GameState.has_method("get_active_build_mode"):
		return
	var active_id := String(GameState.get_active_build_mode())
	if pressed:
		if GameState.has_method("start_build_mode"):
			if GameState.start_build_mode(build_id):
				if build_popup and build_popup.visible:
					build_popup.hide()
			else:
				var button: Button = _build_item_buttons.get(build_id, null)
				if button:
					_suppress_build_button_update = true
					button.button_pressed = (build_id == active_id)
					_suppress_build_button_update = false
		return
	# toggle off
	if active_id == build_id and GameState.has_method("cancel_build_mode"):
		GameState.cancel_build_mode()

func _on_build_mode_changed(build_id: String) -> void:
	_update_build_button_states()
	_refresh_build_info_label()
	if build_popup and build_popup.visible and build_id.is_empty():
		_refresh_build_menu()

func _on_build_catalog_changed(_catalog: Dictionary) -> void:
	_refresh_build_menu()
	_update_build_button_states()
	_refresh_build_info_label()

func _on_build_constructed(_build_id: String, _data: Dictionary) -> void:
	_update_storage_view()

func _refresh_build_info_label() -> void:
	if build_info_label == null:
		return
	if not GameState.has_method("get_active_build_mode"):
		build_info_label.text = "Waehle eine Bauoption."
		return
	var active_id := String(GameState.get_active_build_mode())
	if active_id.is_empty():
		build_info_label.text = "Waehle eine Bauoption."
		return
	var def: Dictionary = {}
	if GameState.has_method("get_build_definition"):
		def = GameState.get_build_definition(active_id)
	var label := String(def.get("label", active_id))
	var cost := int(def.get("cost", 0))
	var build_type := String(def.get("build_type", ""))
	if build_type == "field" and _get_current_field_count() <= 0:
		cost = 0
	var hint := "Linksklick platziert, Rechtsklick beendet."
	if cost > 0:
		build_info_label.text = "%s (%d G). %s" % [label, cost, hint]
	else:
		build_info_label.text = "%s. %s" % [label, hint]

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
	if action == "processing":
		var source_item_id := String(entry.get("source_item_id", ""))
		var source_name := GameState.get_display_name(source_item_id)
		var source_amount := float(entry.get("source_amount", 0.0))
		var source_text := ""
		if not source_item_id.is_empty():
			source_text = " aus %s t %s" % [_format_tons(source_amount), source_name]
		return "%s stellte %s %s%s her" % [actor, amount_text, item_name, source_text]
	return "%s handelte %s %s fuer %d G%s" % [actor, amount_text, item_name, total_price, price_info]
