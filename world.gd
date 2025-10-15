extends Node3D

@export var field_scene: PackedScene = preload("res://Tile.tscn")
@export var field_cost: int = 10
@export var max_fields: int = 9
@export var grid_columns: int = 3
@export var grid_spacing: Vector3 = Vector3(2.0, 0.0, 2.0)
@export var grid_origin: Vector3 = Vector3.ZERO
@export var field_container_path: NodePath = NodePath("FieldContainer")

var _field_container: Node3D = null

func _ready() -> void:
	add_to_group("field_manager")
	_field_container = get_node_or_null(field_container_path) as Node3D
	if _field_container == null:
		push_warning("Field container not found at path: %s" % field_container_path)
		return
	if grid_origin == Vector3.ZERO and _field_container.get_child_count() > 0:
		var first_field := _field_container.get_child(0)
		if first_field is Node3D:
			grid_origin = (first_field as Node3D).position
	_align_existing_fields()

func _align_existing_fields() -> void:
	if _field_container == null:
		return
	var count: int = _field_container.get_child_count()
	for index in count:
		var node := _field_container.get_child(index)
		if node is Node3D:
			var field := node as Node3D
			field.position = _compute_slot_position(index)
			field.name = "Field%d" % (index + 1)

func _compute_slot_position(index: int) -> Vector3:
	var columns: int = max(grid_columns, 1)
	var col: int = index % columns
	var row: int = index / columns
	var offset := Vector3(
		grid_spacing.x * col,
		grid_spacing.y * row,
		grid_spacing.z * row
	)
	return grid_origin + offset

func has_free_slot() -> bool:
	if _field_container == null:
		return false
	return get_field_count() < max_fields

func get_field_count() -> int:
	if _field_container == null:
		return 0
	return _field_container.get_child_count()

func get_field_limit() -> int:
	return max_fields

func get_field_cost() -> int:
	return field_cost

func can_buy_field() -> bool:
	return has_free_slot() and GameState.money >= field_cost

func buy_field() -> bool:
	if _field_container == null:
		return false
	if not has_free_slot():
		print("Keine freien Felder mehr verfuegbar.")
		return false
	if not GameState.try_spend(field_cost):
		print("Nicht genug Geld. Ein Feld kostet %d." % field_cost)
		return false
	if field_scene == null:
		push_warning("Keine Feld-Szene zugewiesen.")
		return false
	var new_field := field_scene.instantiate() as Node3D
	if new_field == null:
		push_warning("Feld-Szene liefert keinen Node3D.")
		GameState.add_money(field_cost) # Geld zurueck
		return false
	var slot_index: int = get_field_count()
	new_field.name = "Field%d" % (slot_index + 1)
	new_field.rotation = Vector3.ZERO
	new_field.scale = Vector3.ONE
	new_field.position = _compute_slot_position(slot_index)
	_field_container.add_child(new_field)
	return true
