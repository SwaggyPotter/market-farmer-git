extends Node3D

@export var field_scene: PackedScene = preload("res://Tile.tscn")
@export var field_cost: int = 10
@export var max_fields: int = 9
@export var grid_columns: int = 3
@export var grid_spacing: Vector3 = Vector3(2.0, 0.0, 2.0)
@export var grid_origin: Vector3 = Vector3.ZERO
@export var field_container_path: NodePath = NodePath("FieldContainer")
@export var field_model_scene: PackedScene = preload("res://assets/Feld.glb")
@export var field_model_container_path: NodePath = NodePath("WorldEnvironment/FieldModelContainer")

var _field_container: Node3D = null
var _field_model_container: Node3D = null
var _model_relative: Transform3D = Transform3D.IDENTITY

func _ready() -> void:
	add_to_group("field_manager")
	_field_container = get_node_or_null(field_container_path) as Node3D
	_field_model_container = get_node_or_null(field_model_container_path) as Node3D
	if _field_container == null:
		push_warning("Field container not found at path: %s" % field_container_path)
	if _field_model_container == null:
		push_warning("Field model container not found at path: %s" % field_model_container_path)
	if _field_container == null:
		return
	if grid_origin == Vector3.ZERO and _field_container.get_child_count() > 0:
		var first_field := _field_container.get_child(0)
		if first_field is Node3D:
			grid_origin = (first_field as Node3D).position
	_align_existing_fields()
	_update_model_reference()
	_align_existing_models()

func _align_existing_fields() -> void:
	if _field_container == null:
		return
	var count: int = _field_container.get_child_count()
	for index in count:
		var field := _get_field_at(index)
		if field:
			_apply_field_slot(field, index)

func _get_field_at(index: int) -> Node3D:
	if _field_container == null:
		return null
	if index < 0 or index >= _field_container.get_child_count():
		return null
	var node := _field_container.get_child(index)
	if node is Node3D:
		return node as Node3D
	return null

func _apply_field_slot(field: Node3D, index: int) -> void:
	field.rotation = Vector3.ZERO
	field.scale = Vector3.ONE
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

func _update_model_reference() -> void:
	_model_relative = Transform3D.IDENTITY
	if _field_container == null or _field_model_container == null:
		return
	var reference_field := _get_field_at(0)
	var reference_model := _get_model_at(0)
	if reference_field and reference_model:
		_model_relative = reference_field.global_transform.affine_inverse() * reference_model.global_transform

func _align_existing_models() -> void:
	if _field_container == null or _field_model_container == null:
		return
	var count: int = get_field_count()
	for index in count:
		var field := _get_field_at(index)
		if field == null:
			continue
		var model := _get_or_create_model(index)
		if model:
			_apply_model_slot(model, field, index)

func _get_model_at(index: int) -> Node3D:
	if _field_model_container == null:
		return null
	if index < 0 or index >= _field_model_container.get_child_count():
		return null
	var node := _field_model_container.get_child(index)
	if node is Node3D:
		return node as Node3D
	return null

func _get_or_create_model(index: int) -> Node3D:
	if _field_model_container == null:
		return null
	var existing := _get_model_at(index)
	if existing:
		return existing
	var model := _create_field_model()
	if model == null:
		return null
	_field_model_container.add_child(model)
	return model

func _apply_model_slot(model: Node3D, field: Node3D, index: int) -> void:
	model.global_transform = field.global_transform * _model_relative
	model.name = "FieldModel%d" % (index + 1)

func _create_field_model() -> Node3D:
	if field_model_scene:
		var instance := field_model_scene.instantiate()
		if instance is Node3D:
			return instance as Node3D
		instance.queue_free()
	var template := _get_model_at(0)
	if template:
		var duplicate := template.duplicate()
		if duplicate is Node3D:
			return duplicate as Node3D
	return null

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
	_field_container.add_child(new_field)
	_apply_field_slot(new_field, slot_index)
	if _field_model_container == null:
		_field_model_container = get_node_or_null(field_model_container_path) as Node3D
	if _field_model_container:
		_update_model_reference()
		_align_existing_models()
	return true
