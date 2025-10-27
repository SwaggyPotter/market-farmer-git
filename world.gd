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
@export var camera_zoom_speed: float = 10.0
@export var camera_zoom_step: float = 2.5
@export var camera_zoom_limits: Vector2 = Vector2(6.0, 30.0)

const DEFAULT_FIELD_MODEL_RELATIVE := Transform3D(
	Basis(
		Vector3(0.14598325, 0.0, 0.0),
		Vector3(0.0, 0.1020821, 0.0),
		Vector3(0.0, 0.0, 0.17924231)
	),
	Vector3(0.0013673, -0.00009343, 0.01462)
)

const MIN_HALF_EXTENT := 0.25

var _field_container: Node3D = null
var _field_model_container: Node3D = null
var _model_relative: Transform3D = DEFAULT_FIELD_MODEL_RELATIVE
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
var _field_build_index: int = 0
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
	set_process_input(true)
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

func _input(event: InputEvent) -> void:
	if _camera == null:
		return
	if event is InputEventMouseButton and event.pressed:
		var mouse_event := event as InputEventMouseButton
		match mouse_event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_adjust_camera_zoom(-camera_zoom_step)
			MOUSE_BUTTON_WHEEL_DOWN:
				_adjust_camera_zoom(camera_zoom_step)

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

func _variant_to_vector3(value: Variant, default_value: Vector3 = Vector3.ONE) -> Vector3:
	if value is Vector3:
		return value as Vector3
	if value is Array and (value as Array).size() >= 3:
		var arr: Array = value
		return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
	return default_value

func _compute_half_extents(size: Vector3) -> Vector3:
	var half := Vector3(abs(size.x) * 0.5, abs(size.y) * 0.5, abs(size.z) * 0.5)
	if half.x <= 0.0:
		half.x = MIN_HALF_EXTENT
	if half.y <= 0.0:
		half.y = MIN_HALF_EXTENT
	if half.z <= 0.0:
		half.z = MIN_HALF_EXTENT
	return half

func _extract_definition_half_extents(definition: Dictionary) -> Vector3:
	var size_variant: Variant = definition.get("size", Vector3.ONE)
	var size: Vector3 = _variant_to_vector3(size_variant, Vector3.ONE)
	return _compute_half_extents(size)

func _update_model_reference() -> void:
	_model_relative = DEFAULT_FIELD_MODEL_RELATIVE
	if _field_container == null or _field_model_container == null:
		return
	var reference_field := _get_field_at(0)
	var reference_model := _get_model_at(0)
	if reference_field and reference_model:
		var relative := reference_field.global_transform.affine_inverse() * reference_model.global_transform
		_model_relative = relative

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
	var build_type := String(definition.get("build_type", ""))
	var free_first_field := build_type == "field" and get_field_count() <= 0
	var can_afford := GameState.can_afford_build(_current_build_id)
	if free_first_field:
		can_afford = true
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
	var camera_transform: Transform3D = _camera.global_transform
	var forward: Vector3 = -camera_transform.basis.z
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
	var zoom_axis: float = 0.0
	if Input.is_key_pressed(KEY_Q):
		zoom_axis -= 1.0
	if Input.is_key_pressed(KEY_E):
		zoom_axis += 1.0
	if zoom_axis != 0.0:
		_adjust_camera_zoom(zoom_axis * camera_zoom_speed * delta)

func _adjust_camera_zoom(amount: float) -> void:
	if _camera == null or amount == 0.0:
		return
	var min_distance: float = float(min(camera_zoom_limits.x, camera_zoom_limits.y))
	var max_distance: float = float(max(camera_zoom_limits.x, camera_zoom_limits.y))
	min_distance = max(min_distance, 0.1)
	if max_distance <= min_distance:
		max_distance = min_distance + 0.1
	var transform: Transform3D = _camera.global_transform
	var forward: Vector3 = -transform.basis.z
	var forward_length: float = forward.length()
	if forward_length <= 0.0001:
		return
	forward /= forward_length
	if abs(forward.y) <= 0.0001:
		return
	var origin: Vector3 = transform.origin
	var t: float = -origin.y / forward.y
	if t <= 0.0:
		return
	var focus: Vector3 = origin + forward * t
	var current_distance: float = origin.distance_to(focus)
	var target_distance: float = clamp(current_distance + amount, min_distance, max_distance)
	if is_equal_approx(target_distance, current_distance):
		return
	var new_origin: Vector3 = focus - forward * target_distance
	_camera.global_position = new_origin

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
	var size: Vector3 = _variant_to_vector3(definition.get("size", Vector3.ONE), Vector3.ONE)
	return max(size.y, 0.1)

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
	var snap_step: float = float(definition.get("snap", 1.0))
	if snap_step <= 0.0:
		snap_step = 1.0
	var base_position := _snap_to_grid(position, snap_step)
	return _apply_edge_snapping(position, base_position, definition, snap_step)

func _snap_to_grid(position: Vector3, snap_step: float) -> Vector3:
	var snapped_x: float = round(position.x / snap_step) * snap_step
	var snapped_z: float = round(position.z / snap_step) * snap_step
	return Vector3(snapped_x, 0.0, snapped_z)

func _apply_edge_snapping(raw_position: Vector3, base_position: Vector3, definition: Dictionary, snap_step: float) -> Vector3:
	var half_extents: Vector3 = _extract_definition_half_extents(definition)
	var result: Vector3 = base_position
	var x_threshold: float = max(0.35, min(half_extents.x, 1.5))
	var z_threshold: float = max(0.35, min(half_extents.z, 1.5))
	if snap_step > 0.0:
		x_threshold = max(x_threshold, snap_step * 0.5)
		z_threshold = max(z_threshold, snap_step * 0.5)
	var best_x_delta: float = x_threshold
	var best_z_delta: float = z_threshold
	for target in _gather_snap_targets():
		var target_position_variant: Variant = target.get("position", Vector3.ZERO)
		var target_half_variant: Variant = target.get("half_extents", Vector3.ONE * 0.5)
		if not (target_position_variant is Vector3) or not (target_half_variant is Vector3):
			continue
		var target_position: Vector3
		var target_half: Vector3
		target_position = target_position_variant
		target_half = target_half_variant
		var combined_half_z: float = target_half.z + half_extents.z
		var z_distance: float = abs(raw_position.z - target_position.z)
		if z_distance <= combined_half_z + z_threshold:
			var candidate_x: float = target_position.x + target_half.x + half_extents.x
			var delta_x: float = abs(raw_position.x - candidate_x)
			if delta_x <= best_x_delta:
				best_x_delta = delta_x
				result.x = candidate_x
			candidate_x = target_position.x - (target_half.x + half_extents.x)
			delta_x = abs(raw_position.x - candidate_x)
			if delta_x <= best_x_delta:
				best_x_delta = delta_x
				result.x = candidate_x
		var combined_half_x: float = target_half.x + half_extents.x
		var x_distance: float = abs(raw_position.x - target_position.x)
		if x_distance <= combined_half_x + x_threshold:
			var candidate_z: float = target_position.z + target_half.z + half_extents.z
			var delta_z: float = abs(raw_position.z - candidate_z)
			if delta_z <= best_z_delta:
				best_z_delta = delta_z
				result.z = candidate_z
			candidate_z = target_position.z - (target_half.z + half_extents.z)
			delta_z = abs(raw_position.z - candidate_z)
			if delta_z <= best_z_delta:
				best_z_delta = delta_z
				result.z = candidate_z
	return result

func _gather_snap_targets() -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	if GameState and GameState.has_method("get_built_structures"):
		var structures := GameState.get_built_structures()
		for entry_variant in structures:
			if not (entry_variant is Dictionary):
				continue
			var entry: Dictionary = entry_variant
			var metadata_variant: Variant = entry.get("metadata", {})
			if not (metadata_variant is Dictionary):
				continue
			var metadata: Dictionary = metadata_variant
			var position_variant: Variant = metadata.get("position", metadata.get("global_position", null))
			if not (position_variant is Vector3):
				continue
			var size_variant: Variant = entry.get("size", Vector3.ONE)
			var half_extents: Vector3 = _compute_half_extents(_variant_to_vector3(size_variant, Vector3.ONE))
			targets.append({
				"position": position_variant as Vector3,
				"half_extents": half_extents,
			})
	if _field_container:
		var field_half := Vector3(abs(grid_spacing.x) * 0.5, MIN_HALF_EXTENT, abs(grid_spacing.z) * 0.5)
		if field_half.x < MIN_HALF_EXTENT:
			field_half.x = MIN_HALF_EXTENT
		if field_half.z < MIN_HALF_EXTENT:
			field_half.z = MIN_HALF_EXTENT
		for child in _field_container.get_children():
			if child is Node3D:
				targets.append({
					"position": (child as Node3D).global_position,
					"half_extents": field_half,
				})
	return targets

func _is_position_blocked(position: Vector3, definition: Dictionary) -> bool:
	var containers: Array[Node3D] = []
	var build_container := _ensure_build_container()
	if build_container:
		containers.append(build_container)
	var existing_field_container := _field_container
	if existing_field_container == null:
		existing_field_container = get_node_or_null(field_container_path) as Node3D
		if existing_field_container:
			_field_container = existing_field_container
	if existing_field_container:
		containers.append(existing_field_container)
	if containers.is_empty():
		return false
	var half_extents := _extract_definition_half_extents(definition)
	var radius: float = max(max(half_extents.x, half_extents.z), 0.5)
	for container in containers:
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
	var build_type := String(definition.get("build_type", ""))
	var skip_cost := build_type == "field" and get_field_count() <= 0
	var spent_cost := false
	if not skip_cost:
		if not GameState.spend_for_build(_current_build_id):
			print("Nicht genug Geld fuer den Bau:", _current_build_id)
			GameState.cancel_build_mode()
			return
		spent_cost = true
	var metadata: Dictionary = {}
	match build_type:
		"field":
			metadata = _place_field_build(definition)
		_:
			metadata = _place_generic_build(definition)
	if metadata.is_empty():
		if spent_cost:
			var refund := int(definition.get("cost", 0))
			if refund > 0 and GameState.has_method("add_money"):
				GameState.add_money(refund)
		print("Konnte Bauobjekt nicht erstellen:", _current_build_id)
		GameState.cancel_build_mode()
		return
	GameState.register_build_instance(_current_build_id, metadata)

func _place_generic_build(definition: Dictionary) -> Dictionary:
	var container := _ensure_build_container()
	if container == null:
		return {}
	var instance := _create_build_mesh(definition, false)
	if instance == null:
		return {}
	instance.name = _generate_build_name(_current_build_id)
	var height := _get_build_height(definition)
	instance.position = Vector3(_preview_position.x, height * 0.5, _preview_position.z)
	container.add_child(instance)
	return {
		"position": instance.global_position,
		"height": height,
	}

func _place_field_build(definition: Dictionary) -> Dictionary:
	var container := _ensure_field_container()
	if container == null:
		return {}
	var scene := _extract_field_scene(definition)
	if scene == null:
		push_warning("Keine Feld-Szene fuer den Bau definiert.")
		return {}
	var instance := scene.instantiate()
	if instance == null:
		return {}
	if not (instance is Node3D):
		instance.queue_free()
		return {}
	var field := instance as Node3D
	var name_prefix := String(definition.get("field_name_prefix", "Field"))
	field.name = _generate_field_name(name_prefix)
	field.position = Vector3.ZERO
	field.rotation = Vector3.ZERO
	field.scale = Vector3.ONE
	container.add_child(field)
	field.global_position = Vector3(_preview_position.x, 0.0, _preview_position.z)
	if _ensure_field_model_container():
		_update_model_reference()
		_align_existing_models()
	if GameState.has_method("update_field_count"):
		GameState.update_field_count(get_field_count())
	var height := _get_build_height(definition)
	return {
		"position": field.global_position,
		"height": height,
		"field_name": field.name,
		"node_path": field.get_path(),
		"build_type": "field",
	}

func _extract_field_scene(definition: Dictionary) -> PackedScene:
	var scene_variant: Variant = definition.get("scene", null)
	if scene_variant is PackedScene:
		return scene_variant
	if scene_variant is String and not String(scene_variant).is_empty():
		var resource := load(String(scene_variant))
		if resource is PackedScene:
			return resource as PackedScene
	if field_scene:
		return field_scene
	return null

func _generate_field_name(prefix: String) -> String:
	var base := prefix.strip_edges()
	if base.is_empty():
		base = "Field"
	var known_fields: Array = []
	if GameState.has_method("get_known_fields"):
		known_fields = GameState.get_known_fields()
	var attempts := 0
	while attempts < 4096:
		_field_build_index += 1
		var candidate := "%s%d" % [base, _field_build_index]
		if _field_container and _field_container.get_node_or_null(NodePath(candidate)):
			attempts += 1
			continue
		if candidate in known_fields:
			attempts += 1
			continue
		return candidate
	var fallback := "%s_%d" % [base, int(Time.get_ticks_msec())]
	return fallback

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

func _ensure_field_container() -> Node3D:
	if _field_container != null and is_instance_valid(_field_container):
		return _field_container
	_field_container = get_node_or_null(field_container_path) as Node3D
	if _field_container != null:
		return _field_container
	var container := Node3D.new()
	container.name = "FieldContainer"
	add_child(container)
	_field_container = container
	return _field_container

func _ensure_field_model_container() -> Node3D:
	if _field_model_container != null and is_instance_valid(_field_model_container):
		return _field_model_container
	_field_model_container = get_node_or_null(field_model_container_path) as Node3D
	return _field_model_container

func _generate_build_name(build_id: String) -> String:
	_build_index_counter += 1
	return "%s_%d" % [build_id, _build_index_counter]
