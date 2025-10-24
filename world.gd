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
@export var build_container_path: NodePath = NodePath("BuildContainer")
@export var camera_path: NodePath = NodePath("Camera3D")
@export var camera_move_speed: float = 8.0

var _field_container: Node3D = null
var _field_model_container: Node3D = null
var _model_relative: Transform3D = Transform3D.IDENTITY
var _build_container: Node3D = null
var _current_build_id: String = ""
var _build_preview: MeshInstance3D = null
var _build_preview_height: float = 0.0
var _build_preview_material: StandardMaterial3D = null
var _preview_position: Vector3 = Vector3.ZERO
var _preview_valid: bool = false
var _preview_build_id: String = ""
var _preview_base_color: Color = Color.WHITE
var _build_index_counter: int = 0
var _camera: Camera3D = null

func _ready() -> void:
	add_to_group("field_manager")
	_field_container = get_node_or_null(field_container_path) as Node3D
	_field_model_container = get_node_or_null(field_model_container_path) as Node3D
	_build_container = get_node_or_null(build_container_path) as Node3D
	if _field_container == null:
		push_warning("Field container not found at path: %s" % field_container_path)
	if _field_model_container == null:
		push_warning("Field model container not found at path: %s" % field_model_container_path)
	if _build_container == null:
		push_warning("Build container not found at path: %s" % build_container_path)
		_build_container = Node3D.new()
		_build_container.name = "BuildContainer"
		add_child(_build_container)
	else:
		_build_index_counter = max(_build_container.get_child_count(), 0)
	_camera = get_node_or_null(camera_path) as Camera3D
	if _camera == null:
		push_warning("Camera not found at path: %s" % camera_path)
	set_process(true)
	if _field_container == null:
		return
	if grid_origin == Vector3.ZERO and _field_container.get_child_count() > 0:
		var first_field := _field_container.get_child(0)
		if first_field is Node3D:
			grid_origin = (first_field as Node3D).position
	_align_existing_fields()
	_update_model_reference()
	_align_existing_models()
	GameState.update_field_count(get_field_count())
	set_process_unhandled_input(true)
	if not GameState.build_mode_changed.is_connected(_on_build_mode_changed):
		GameState.build_mode_changed.connect(_on_build_mode_changed)
	var active_build := ""
	if GameState.has_method("get_active_build_mode"):
		active_build = String(GameState.get_active_build_mode())
	if not active_build.is_empty():
		_on_build_mode_changed(active_build)

func _process(delta: float) -> void:
	_update_camera_motion(delta)

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
	GameState.update_field_count(get_field_count())
	return true

func _physics_process(_delta: float) -> void:
	if _current_build_id.is_empty():
		return
	if not GameState.has_method("get_build_definition"):
		return
	var definition: Dictionary = GameState.get_build_definition(_current_build_id)
	if definition.is_empty():
		GameState.cancel_build_mode()
		return
	_ensure_build_preview(definition)
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	var mouse_position: Vector2 = viewport.get_mouse_position()
	var ground_point: Variant = _project_to_ground(mouse_position)
	if ground_point == null:
		_preview_valid = false
		_set_preview_visible(false)
		return
	var snapped: Vector3 = _snap_build_position(ground_point, definition)
	var blocked: bool = _is_position_blocked(snapped, definition)
	var can_afford := GameState.can_afford_build(_current_build_id)
	_preview_position = snapped
	_preview_valid = can_afford and not blocked
	_set_preview_visible(true)
	_update_preview_transform(snapped, definition, _preview_valid)

func _unhandled_input(event: InputEvent) -> void:
	if _current_build_id.is_empty():
		return
	if event is InputEventMouseButton and event.pressed:
		var mouse_event := event as InputEventMouseButton
		match mouse_event.button_index:
			MOUSE_BUTTON_LEFT:
				_try_place_current_build()
				var viewport := get_viewport()
				if viewport and viewport.has_method("set_input_as_handled"):
					viewport.set_input_as_handled()
			MOUSE_BUTTON_RIGHT:
				GameState.cancel_build_mode()
				var viewport := get_viewport()
				if viewport and viewport.has_method("set_input_as_handled"):
					viewport.set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_ESCAPE:
			GameState.cancel_build_mode()
			var viewport := get_viewport()
			if viewport and viewport.has_method("set_input_as_handled"):
				viewport.set_input_as_handled()

func _on_build_mode_changed(build_id: String) -> void:
	_current_build_id = build_id
	if _current_build_id.is_empty():
		_clear_build_preview()
	else:
		if not GameState.has_method("get_build_definition"):
			return
		var definition: Dictionary = GameState.get_build_definition(_current_build_id)
		if definition.is_empty():
			_clear_build_preview()
			return
		_ensure_build_preview(definition)

func _ensure_build_preview(definition: Dictionary) -> void:
	if _preview_build_id == _current_build_id and _build_preview:
		return
	_clear_build_preview()
	var preview: MeshInstance3D = _create_build_mesh(definition, true)
	if preview == null:
		return
	preview.name = "BuildPreview"
	var color_variant: Variant = definition.get("color", Color(0.7, 0.7, 0.7))
	_preview_base_color = color_variant if color_variant is Color else Color(0.7, 0.7, 0.7)
	_build_preview_material = preview.material_override as StandardMaterial3D
	_build_preview_height = _get_build_height(definition)
	add_child(preview)
	_build_preview = preview
	_preview_build_id = _current_build_id
	_build_preview.visible = false

func _clear_build_preview() -> void:
	if _build_preview:
		_build_preview.queue_free()
	_build_preview = null
	_build_preview_material = null
	_preview_build_id = ""
	_preview_valid = false

func _update_camera_motion(delta: float) -> void:
	if _camera == null:
		return
	var camera_transform := _camera.global_transform
	var forward := -camera_transform.basis.z
	forward.y = 0.0
	if forward.length() > 0.0:
		forward = forward.normalized()
	var right := camera_transform.basis.x
	right.y = 0.0
	if right.length() > 0.0:
		right = right.normalized()
	var direction := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		direction += forward
	if Input.is_key_pressed(KEY_S):
		direction -= forward
	if Input.is_key_pressed(KEY_D):
		direction += right
	if Input.is_key_pressed(KEY_A):
		direction -= right
	if direction.length() > 0.0:
		direction = direction.normalized()
		_camera.global_position += direction * camera_move_speed * delta

func _create_build_mesh(definition: Dictionary, is_preview: bool) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var shape := String(definition.get("shape", "box")).to_lower()
	var size_variant: Variant = definition.get("size", Vector3.ONE)
	var size := Vector3.ONE
	if size_variant is Vector3:
		size = size_variant
	elif size_variant is Array and (size_variant as Array).size() >= 3:
		var arr: Array = size_variant
		size = Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
	var material := StandardMaterial3D.new()
	var color_variant: Variant = definition.get("color", Color(0.7, 0.7, 0.7))
	var base_color: Color = color_variant if color_variant is Color else Color(0.7, 0.7, 0.7)
	if is_preview:
		var preview_color: Color = Color(base_color.r, base_color.g, base_color.b, 0.35)
		material.albedo_color = preview_color
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.roughness = 0.4
		material.metallic = 0.0
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		material.albedo_color = base_color
		material.roughness = 0.6
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var mesh: PrimitiveMesh = null
	match shape:
		"cylinder":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = max(size.x, size.z) * 0.5
			cylinder.bottom_radius = cylinder.top_radius
			cylinder.height = max(size.y, 0.1)
			mesh = cylinder
		"capsule":
			var capsule := CapsuleMesh.new()
			capsule.radius = max(size.x, size.z) * 0.5
			capsule.height = max(size.y - capsule.radius * 2.0, 0.1)
			mesh = capsule
		_:
			var box := BoxMesh.new()
			box.size = size
			mesh = box
	if mesh == null:
		return null
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = Vector3.ZERO
	return mesh_instance

func _get_build_height(definition: Dictionary) -> float:
	var size_variant: Variant = definition.get("size", Vector3.ONE)
	if size_variant is Vector3:
		return max((size_variant as Vector3).y, 0.1)
	if size_variant is Array and (size_variant as Array).size() >= 2:
		var arr: Array = size_variant
		return max(float(arr[1]), 0.1)
	return 1.0

func _project_to_ground(screen_pos: Vector2) -> Variant:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return null
	var camera: Camera3D = viewport.get_camera_3d()
	if camera == null:
		return null
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var direction: Vector3 = camera.project_ray_normal(screen_pos)
	if abs(direction.y) <= 0.0001:
		return null
	var t := -origin.y / direction.y
	if t <= 0.0:
		return null
	return origin + direction * t

func _snap_build_position(position: Vector3, definition: Dictionary) -> Vector3:
	var snap_value: float = float(definition.get("snap", 1.0))
	if snap_value <= 0.0:
		snap_value = 1.0
	var snapped_x: float = round(position.x / snap_value) * snap_value
	var snapped_z: float = round(position.z / snap_value) * snap_value
	return Vector3(snapped_x, 0.0, snapped_z)

func _is_position_blocked(position: Vector3, definition: Dictionary) -> bool:
	var container: Node3D = _ensure_build_container()
	if container == null:
		return false
	var size_variant: Variant = definition.get("size", Vector3.ONE)
	var size := Vector3.ONE
	if size_variant is Vector3:
		size = size_variant
	elif size_variant is Array and (size_variant as Array).size() >= 3:
		var arr: Array = size_variant
		size = Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
	var radius: float = max(max(size.x, size.z) * 0.5, 0.5)
	for child in container.get_children():
		if child is Node3D:
			var node: Node3D = child as Node3D
			var node_pos: Vector3 = node.global_position
			var delta: Vector2 = Vector2(node_pos.x, node_pos.z) - Vector2(position.x, position.z)
			if delta.length() < radius:
				return true
	return false

func _set_preview_visible(visible: bool) -> void:
	if _build_preview:
		_build_preview.visible = visible

func _update_preview_transform(position: Vector3, definition: Dictionary, is_valid: bool) -> void:
	if _build_preview == null:
		return
	var height := _build_preview_height
	if height <= 0.0:
		height = _get_build_height(definition)
	var target := position
	target.y = height * 0.5
	_build_preview.position = target
	_update_preview_color(is_valid)

func _update_preview_color(is_valid: bool) -> void:
	if _build_preview_material == null:
		return
	var alpha := 0.35
	var color := _preview_base_color
	if not is_valid:
		color = Color(0.8, 0.2, 0.2)
	_build_preview_material.albedo_color = Color(color.r, color.g, color.b, alpha)

func _try_place_current_build() -> void:
	if _current_build_id.is_empty():
		return
	if not _preview_valid:
		print("Position aktuell nicht baubar.")
		return
	if not GameState.has_method("get_build_definition"):
		return
	var definition := GameState.get_build_definition(_current_build_id)
	if definition.is_empty():
		GameState.cancel_build_mode()
		return
	if not GameState.spend_for_build(_current_build_id):
		print("Nicht genug Geld fuer den Bau:", _current_build_id)
		GameState.cancel_build_mode()
		return
	var container := _ensure_build_container()
	if container == null:
		GameState.cancel_build_mode()
		return
	var instance := _create_build_mesh(definition, false)
	if instance == null:
		print("Konnte Bauobjekt nicht erstellen:", _current_build_id)
		return
	instance.name = _generate_build_name(_current_build_id)
	var height := _get_build_height(definition)
	instance.position = Vector3(_preview_position.x, height * 0.5, _preview_position.z)
	container.add_child(instance)
	GameState.register_build_instance(_current_build_id, {
		"position": instance.global_position,
		"height": height,
	})

func _ensure_build_container() -> Node3D:
	if _build_container != null and is_instance_valid(_build_container):
		_build_index_counter = max(_build_index_counter, _build_container.get_child_count())
		return _build_container
	_build_container = get_node_or_null(build_container_path) as Node3D
	if _build_container != null:
		_build_index_counter = max(_build_index_counter, _build_container.get_child_count())
		return _build_container
	_build_container = Node3D.new()
	_build_container.name = "BuildContainer"
	add_child(_build_container)
	_build_index_counter = max(_build_index_counter, _build_container.get_child_count())
	return _build_container

func _generate_build_name(build_id: String) -> String:
	_build_index_counter += 1
	return "%s_%d" % [build_id, _build_index_counter]
