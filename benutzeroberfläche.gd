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
	var popup_size: Vector2 = menu.size
	if popup_size == Vector2.ZERO:
		popup_size = menu.get_combined_minimum_size()
	var popup_rect := Rect2(menu.position, popup_size.ceil())
	menu.popup(Rect2i(popup_rect))
	print("Menu forced visible:", menu.visible)


func open_for_tile(tile: Node, _screen_pos: Vector2):
	current_tile = tile
	menu.visible = true
	menu.position = Vector2(200, 200)
	menu.popup()
	print("Menu opened manually at 200,200")


func _on_menu_id(id: int):
	if id == 0 or current_tile == null:
		menu.hide()
		return
	var crop_id := "wheat" if id == 1 else "potato"
	current_tile.call_deferred("start_growth", crop_id, 10.0)  # 10s Timer
	menu.hide()
