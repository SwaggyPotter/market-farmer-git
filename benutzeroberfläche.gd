extends Control

@onready var menu: PopupMenu = $PlantMenu
@onready var money_label: Label = $WalletPanel/MoneyLabel
var current_tile: Node = null

func _ready():
	add_to_group("ui")      # damit Tiles dich finden
	GameState.money_changed.connect(_on_money_changed)
	_on_money_changed(GameState.money)
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
