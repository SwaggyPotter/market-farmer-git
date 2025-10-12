extends Control

@onready var menu: PopupMenu = $PlantMenu
var current_tile: Node = null

func _ready():
	add_to_group("ui")      # damit Tiles dich finden
	menu.clear()
	menu.add_item("Weizen", 1)
	menu.add_item("Kartoffel", 2)
	menu.add_separator()
	menu.add_item("Abbrechen", 0)
	menu.id_pressed.connect(_on_menu_id)
	menu.position = Vector2(200, 200)
	call_deferred("_open_initial_menu")
	print("Menu popup scheduled at:", menu.position)
	print("PlantMenu ready")

func _open_initial_menu():
	_popup_at_position(menu.position)
	print("Menu forced visible:", menu.visible)

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
	var popup_rect := Rect2i(Vector2i(screen_pos), Vector2i(width, height))
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
		return
	var crop_id := "wheat" if id == 1 else "potato"
	current_tile.call_deferred("start_growth", crop_id, 10.0)  # 10s Timer
	menu.hide()
