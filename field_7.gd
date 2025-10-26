extends Node3D

const TILE_SIZE := 1.0
const Y_OFFSET  := 0.01
const COLOR_EMPTY := Color(0.754, 0.0, 0.254, 1.0)
const COLOR_GROWING := Color(0.868, 0.867, 0.0, 1.0)
const COLOR_READY := Color(0.223, 0.737, 0.047, 1.0)
const CROP_SCENES := {
	"wheat": preload("res://assets/WeizenBigger.glb"),
}
const DEFAULT_CROP_ID := "wheat"  # fallback visuals for crops without dedicated assets
const CROP_PHASES := {
	"wheat": [
		{"scene": preload("res://assets/SetzlingAnfang.glb"), "fraction": 0.3, "scale": Vector3(0.175, 0.175, 0.175)},
		{"scene": preload("res://assets/Setzling.glb"), "fraction": 0.4},
		{"scene": preload("res://assets/WeizenBigger.glb"), "fraction": 0.3},
	],
}
const CROP_SCALE := {
	"wheat": Vector3(1.0, 1.0, 1.0),
}
const CROP_OFFSET := {
	"wheat": Vector3(0, 0, 0),
}
const GROWTH_PROGRESS_REPORT_INTERVAL := 0.25
const PROGRESS_BAR_SIZE := Vector2(0.9, 0.12)
const PROGRESS_BAR_HEIGHT := 0.9
const PROGRESS_BAR_LABEL_OFFSET := Vector3(0.0, 0.18, 0.0)
const PROGRESS_BAR_BACK_COLOR := Color(0.05, 0.05, 0.05, 0.7)
const PROGRESS_BAR_FILL_COLOR := Color(0.2, 0.75, 0.15, 0.9)
const PROGRESS_BAR_READY_COLOR := Color(0.9, 0.8, 0.25, 0.95)

enum FieldState { EMPTY, GROWING, READY }

var state: FieldState = FieldState.EMPTY
var crop_type: String = ""

@onready var mesh: MeshInstance3D = _ensure_mesh()
@onready var body: StaticBody3D   = _ensure_body()
@onready var growth_timer: Timer  = _ensure_timer()
@onready var crop_container: Node3D = _ensure_crop_container()
@onready var progress_root: Node3D = _ensure_progress_bar()
var crop_visual: Node3D = null
var active_phases: Array = []
var phase_durations: Array[float] = []
var phase_index: int = -1
var fertilizer_yield_progress: float = 0.0
var fertilizer_applications: Dictionary = {}
var assigned_farmer_id: int = 0
var assigned_farmer_name: String = ""
var total_growth_duration: float = 0.0
var _growth_report_accumulator: float = 0.0
var _last_reported_progress: float = -1.0
var _last_reported_time_left: float = -1.0
var _progress_background: MeshInstance3D = null
var _progress_fill: MeshInstance3D = null
var _progress_label: Label3D = null

func _ready():
	body.input_event.connect(_on_input_event)
	if GameState.has_method("register_field"):
		GameState.register_field(self)
	_update_visual()
	_set_progress_visibility(false)
	set_process(false)

func _exit_tree() -> void:
	if GameState.has_method("unregister_field"):
		GameState.unregister_field(self)

func _on_input_event(_camera, event, _position, _normal, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		match state:
			FieldState.EMPTY:
				print("Klick auf freies Feld:", name)
				get_tree().call_group("ui", "open_for_tile", self, event.position)
			FieldState.GROWING:
				print("Feld", name, "wächst noch:", crop_type, "(Rest:", "%.2f" % growth_timer.time_left, "s)")
				get_tree().call_group("ui", "open_for_tile", self, event.position)
			FieldState.READY:
				_harvest()
			_:
				print("Unbekannter Feldstatus bei Klick:", state)

func get_field_state() -> int:
	return state

func can_apply_fertilizer(_fertilizer_id: String = "") -> bool:
	return state == FieldState.GROWING

func apply_fertilizer(fertilizer_id: String) -> bool:
	if not can_apply_fertilizer(fertilizer_id):
		print("Duenger kann aktuell nicht angewendet werden auf", name)
		return false
	if fertilizer_id.is_empty():
		return false
	var effects := GameState.get_fertilizer_effects(fertilizer_id)
	if effects.is_empty():
		print("Keine Effekte fuer", fertilizer_id, "definiert.")
		return false
	var recognized := false
	for effect_dict in effects:
		var effect_type := String(effect_dict.get("type", ""))
		match effect_type:
			"yield_bonus":
				var value := float(effect_dict.get("value", 0.0))
				if value <= 0.0:
					continue
				fertilizer_yield_progress += value
				recognized = true
			_:
				print("Unbekannter Duengereffekt:", effect_type)
	if not recognized:
		print("Keine anwendbaren Effekte fuer Duenger:", fertilizer_id)
		return false
	var applied_count := int(fertilizer_applications.get(fertilizer_id, 0))
	fertilizer_applications[fertilizer_id] = applied_count + 1
	print("Duenger angewendet auf %s: %s (Anwendungen: %d, Bonus-Fortschritt: %.2f)" % [
		name,
		GameState.get_display_name(fertilizer_id),
		fertilizer_applications[fertilizer_id],
		fertilizer_yield_progress,
	])
	return true

func _ensure_mesh() -> MeshInstance3D:
	var m = get_node_or_null("MeshInstance3D")
	if m == null:
		m = MeshInstance3D.new()
		m.name = "MeshInstance3D"
		var plane := PlaneMesh.new()
		plane.size = Vector2(TILE_SIZE, TILE_SIZE)
		m.mesh = plane
		m.position = Vector3(0, Y_OFFSET, 0)
		m.visible = true
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)

		var mat := StandardMaterial3D.new()
		mat.resource_local_to_scene = true   # jede Instanz hat ihr eigenes Material
		mat.roughness = 0.7
		m.material_override = mat
	m.visible = true
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m

func _ensure_body() -> StaticBody3D:
	var b = get_node_or_null("StaticBody3D")
	if b == null:
		b = StaticBody3D.new()
		b.name = "StaticBody3D"
		add_child(b)

		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var box := BoxShape3D.new()
		box.size = Vector3(TILE_SIZE, 0.1, TILE_SIZE)
		col.shape = box
		b.add_child(col)
	return b

func _ensure_timer() -> Timer:
	var t: Timer = get_node_or_null("GrowthTimer")
	if t == null:
		t = Timer.new()
		t.name = "GrowthTimer"
		t.one_shot = true
		t.autostart = false
		add_child(t)
	var callable := Callable(self, "_on_growth_timer_timeout")
	if not t.timeout.is_connected(callable):
		t.timeout.connect(callable)
	return t

func _ensure_crop_container() -> Node3D:
	var container := get_node_or_null("CropContainer")
	if container == null:
		container = Node3D.new()
		container.name = "CropContainer"
		container.position = Vector3.ZERO
		container.rotation = Vector3.ZERO
		container.visible = false
		var parent_scale := scale
		var safe_scale := Vector3(
			parent_scale.x if abs(parent_scale.x) > 0.0001 else 1.0,
			parent_scale.y if abs(parent_scale.y) > 0.0001 else 1.0,
			parent_scale.z if abs(parent_scale.z) > 0.0001 else 1.0
		)
		container.scale = Vector3(
			1.0 / safe_scale.x,
			1.0 / safe_scale.y,
			1.0 / safe_scale.z
		)
		add_child(container)
	return container

func _ensure_progress_bar() -> Node3D:
	var root := get_node_or_null("ProgressBar")
	var parent_scale := scale
	var safe_scale := Vector3(
		parent_scale.x if abs(parent_scale.x) > 0.0001 else 1.0,
		parent_scale.y if abs(parent_scale.y) > 0.0001 else 1.0,
		parent_scale.z if abs(parent_scale.z) > 0.0001 else 1.0
	)
	if root == null:
		root = Node3D.new()
		root.name = "ProgressBar"
		root.position = Vector3(0.0, PROGRESS_BAR_HEIGHT, 0.0)
		add_child(root)
	var background := root.get_node_or_null("Background") as MeshInstance3D
	if background == null:
		background = MeshInstance3D.new()
		background.name = "Background"
		var back_mesh := QuadMesh.new()
		back_mesh.size = PROGRESS_BAR_SIZE
		background.mesh = back_mesh
		root.add_child(background)
	background.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	background.position = Vector3.ZERO
	var fill := root.get_node_or_null("Fill") as MeshInstance3D
	if fill == null:
		fill = MeshInstance3D.new()
		fill.name = "Fill"
		var fill_mesh := QuadMesh.new()
		fill_mesh.size = PROGRESS_BAR_SIZE
		fill.mesh = fill_mesh
		root.add_child(fill)
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fill.position = Vector3(0.0, 0.0, -0.001)
	var time_label := root.get_node_or_null("TimeLabel") as Label3D
	if time_label == null:
		time_label = Label3D.new()
		time_label.name = "TimeLabel"
		time_label.position = PROGRESS_BAR_LABEL_OFFSET
		time_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		time_label.text = "00:00"
		time_label.pixel_size = 0.015
		root.add_child(time_label)
	if background.material_override == null:
		var back_material := StandardMaterial3D.new()
		back_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		back_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		back_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		back_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		back_material.albedo_color = PROGRESS_BAR_BACK_COLOR
		background.material_override = back_material
	if fill.material_override == null:
		var fill_material := StandardMaterial3D.new()
		fill_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fill_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fill_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		fill_material.albedo_color = PROGRESS_BAR_FILL_COLOR
		fill.material_override = fill_material
	root.scale = Vector3(
		1.0 / safe_scale.x,
		1.0 / safe_scale.y,
		1.0 / safe_scale.z
	)
	root.rotation = Vector3.ZERO
	_progress_background = background
	_progress_fill = fill
	_progress_label = time_label
	root.visible = false
	return root

func _update_visual():
	# hier gibt es garantiert ein Mesh & Material
	var mat = mesh.get_active_material(0)
	if mat == null:
		mat = mesh.get_material_override()
	if mat == null:
		mat = StandardMaterial3D.new()
		mat.resource_local_to_scene = true
		mesh.material_override = mat

	match state:
		FieldState.EMPTY:
			mat.albedo_color = COLOR_EMPTY
			_set_crop_visibility(false)
		FieldState.GROWING:
			mat.albedo_color = COLOR_GROWING
			_set_crop_visibility(crop_visual != null)
		FieldState.READY:
			mat.albedo_color = COLOR_READY
			_set_crop_visibility(crop_visual != null)

func start_growth(crop_id: String, duration: float):
	if state != FieldState.EMPTY:
		print("Feld", name, "kann nicht bepflanzt werden (Status:", state, ")")
		return
	crop_type = crop_id
	state = FieldState.GROWING
	var base_config_duration: float = max(GameState.get_crop_base_growth_time(crop_type), 0.1)
	var base_duration: float = duration if duration > 0.0 else base_config_duration
	var research_duration := GameState.get_crop_growth_duration(crop_type)
	var ratio := 1.0
	if base_config_duration > 0.0:
		ratio = research_duration / base_config_duration
	var final_duration: float = max(base_duration * ratio, 0.1)
	active_phases = _get_crop_phases(crop_type)
	phase_durations = _compute_phase_durations(final_duration, active_phases)
	phase_index = -1
	total_growth_duration = final_duration
	_growth_report_accumulator = 0.0
	_last_reported_progress = -1.0
	_last_reported_time_left = -1.0
	if final_duration > 0.0:
		set_process(true)
	else:
		set_process(false)
	print("Aussaat auf", name, ":", crop_type, "(%.2f s)" % final_duration)
	if active_phases.is_empty():
		var fallback_scene := _get_default_scene(crop_type)
		_spawn_crop_visual(fallback_scene, _get_crop_scale(crop_type), _get_crop_offset(crop_type))
		if final_duration > 0.0:
			growth_timer.wait_time = final_duration
			growth_timer.start()
		else:
			_on_growth_finished()
	else:
		phase_index = 0
		_apply_growth_phase(phase_index)
		_start_phase_timer(phase_index)
	_update_visual()
	_report_growth_progress(true)

func _on_growth_finished():
	if state == FieldState.READY:
		return
	growth_timer.stop()
	phase_durations.clear()
	if not active_phases.is_empty():
		phase_index = active_phases.size() - 1
	state = FieldState.READY
	print("Feld", name, "ist bereit zur Ernte:", crop_type)
	if GameState.has_method("on_field_ready"):
		GameState.on_field_ready(self)
	_update_visual()
	set_process(false)
	_report_growth_progress(true)

func _harvest():
	var base_amount := 0.0
	if not crop_type.is_empty():
		base_amount = GameState.get_crop_yield_amount(crop_type)
	var bonus_units := 0.0
	if fertilizer_yield_progress > 0.0:
		bonus_units = floor(fertilizer_yield_progress)
		if bonus_units > 0.0:
			fertilizer_yield_progress = max(fertilizer_yield_progress - bonus_units, 0.0)
	var total_amount := base_amount + bonus_units
	if total_amount > 0.0 and not crop_type.is_empty():
		GameState.add_to_inventory(crop_type, total_amount)
	var formatted := "%.2f" % total_amount if total_amount > 0.0 else "0"
	if bonus_units > 0.0:
		print("Bonus durch Duenger auf", name, ":+%.0f (Restbonus: %.2f)" % [bonus_units, fertilizer_yield_progress])
	print("Geerntet auf", name, ":", crop_type, "(%s)" % formatted)
	growth_timer.stop()
	active_phases.clear()
	phase_durations.clear()
	phase_index = -1
	crop_type = ""
	state = FieldState.EMPTY
	set_process(false)
	total_growth_duration = 0.0
	_growth_report_accumulator = 0.0
	_last_reported_progress = -1.0
	_last_reported_time_left = -1.0
	_clear_crop_visual()
	_update_visual()
	_report_growth_progress(true)

func request_harvest() -> bool:
	if state != FieldState.READY:
		return false
	_harvest()
	return true

func harvest_by_farmer(farmer_name: String = "") -> bool:
	if state != FieldState.READY:
		return false
	var name_to_use := farmer_name.strip_edges()
	if name_to_use.is_empty():
		name_to_use = assigned_farmer_name if not assigned_farmer_name.is_empty() else "Farmer"
	print("%s erntet automatisch %s." % [name_to_use, name])
	_harvest()
	return true

func set_assigned_farmer(farmer_id: int, farmer_name: String) -> void:
	if farmer_id <= 0:
		clear_assigned_farmer()
		return
	assigned_farmer_id = farmer_id
	assigned_farmer_name = farmer_name.strip_edges()

func clear_assigned_farmer() -> void:
	assigned_farmer_id = 0
	assigned_farmer_name = ""

func get_assigned_farmer_id() -> int:
	return assigned_farmer_id

func _spawn_crop_visual(scene: PackedScene, scale: Vector3, offset: Vector3):
	_clear_crop_visual()
	if scene == null:
		return
	var instance := scene.instantiate()
	if instance is Node3D:
		crop_visual = instance
		crop_container.add_child(crop_visual)
	else:
		var wrapper := Node3D.new()
		wrapper.name = "CropPhaseWrapper"
		crop_container.add_child(wrapper)
		wrapper.add_child(instance)
		crop_visual = wrapper
	crop_visual.position = offset
	crop_visual.scale = scale
	_set_crop_visibility(true)

func _clear_crop_visual():
	if crop_visual and crop_visual.is_inside_tree():
		crop_visual.queue_free()
	crop_visual = null
	_set_crop_visibility(false)

func _set_crop_visibility(visible: bool):
	if crop_container:
		crop_container.visible = visible

func _get_default_scene(crop_id: String) -> PackedScene:
	var resolved_id := crop_id if CROP_SCENES.has(crop_id) else DEFAULT_CROP_ID
	if CROP_SCENES.has(resolved_id):
		return CROP_SCENES[resolved_id]
	return null

func _get_crop_scale(crop_id: String) -> Vector3:
	var resolved_id := crop_id if CROP_SCALE.has(crop_id) else DEFAULT_CROP_ID
	return CROP_SCALE.get(resolved_id, Vector3.ONE)

func _get_crop_offset(crop_id: String) -> Vector3:
	var resolved_id := crop_id if CROP_OFFSET.has(crop_id) else DEFAULT_CROP_ID
	return CROP_OFFSET.get(resolved_id, Vector3.ZERO)

func _get_crop_phases(crop_id: String) -> Array:
	var resolved_id := crop_id if CROP_PHASES.has(crop_id) else DEFAULT_CROP_ID
	if CROP_PHASES.has(resolved_id):
		return CROP_PHASES[resolved_id].duplicate(true)
	return []

func _compute_phase_durations(total_duration: float, phases: Array) -> Array[float]:
	var results: Array[float] = []
	var safe_total: float = max(total_duration, 0.0)
	if phases.size() < 2:
		return results
	var transitions: int = phases.size() - 1
	var remaining: float = safe_total
	for i in range(transitions):
		var entry: Dictionary = phases[i]
		var fraction: float = 0.0
		if entry.has("fraction"):
			fraction = float(entry["fraction"])
		if fraction <= 0.0:
			fraction = 1.0 / float(transitions)
		var segment: float = safe_total * fraction
		if i == transitions - 1:
			segment = max(remaining, 0.0)
		else:
			segment = clamp(segment, 0.0, max(remaining, 0.0))
		results.append(segment)
		remaining -= segment
	return results

func _apply_growth_phase(index: int):
	if index < 0 or index >= active_phases.size():
		return
	var phase: Dictionary = active_phases[index]
	var scene: PackedScene = null
	if phase.has("scene"):
		scene = phase["scene"] as PackedScene
	if scene == null:
		scene = _get_default_scene(crop_type)
	var target_scale: Vector3 = _get_crop_scale(crop_type)
	if phase.has("scale") and phase["scale"] is Vector3:
		target_scale = phase["scale"]
	var target_offset: Vector3 = _get_crop_offset(crop_type)
	if phase.has("offset") and phase["offset"] is Vector3:
		target_offset = phase["offset"]
	_spawn_crop_visual(scene, target_scale, target_offset)

func _start_phase_timer(index: int):
	if index < 0 or index >= phase_durations.size():
		_on_growth_finished()
		return
	var wait_time := phase_durations[index]
	if wait_time <= 0.0:
		call_deferred("_advance_growth_phase")
	else:
		growth_timer.wait_time = wait_time
		growth_timer.start()

func _advance_growth_phase():
	if active_phases.is_empty():
		_on_growth_finished()
		return
	phase_index += 1
	if phase_index >= active_phases.size():
		_on_growth_finished()
		return
	_apply_growth_phase(phase_index)
	_update_visual()
	if phase_index >= active_phases.size() - 1:
		_on_growth_finished()
	else:
		_start_phase_timer(phase_index)

func _on_growth_timer_timeout():
	growth_timer.stop()
	if active_phases.is_empty() or phase_index == -1:
		_on_growth_finished()
	else:
		_advance_growth_phase()

func _process(delta: float) -> void:
	if state != FieldState.GROWING:
		set_process(false)
		return
	_growth_report_accumulator += delta
	if _growth_report_accumulator >= GROWTH_PROGRESS_REPORT_INTERVAL:
		_growth_report_accumulator = 0.0
		_report_growth_progress()

func _compute_growth_time_left() -> float:
	var remaining := 0.0
	if growth_timer:
		remaining = max(growth_timer.time_left, 0.0)
	if active_phases.is_empty():
		return remaining
	if phase_durations.is_empty():
		return remaining
	var current_index := phase_index
	if current_index < 0:
		current_index = 0
	if current_index >= phase_durations.size():
		current_index = phase_durations.size() - 1
	for i in range(current_index + 1, phase_durations.size()):
		remaining += max(phase_durations[i], 0.0)
	return max(remaining, 0.0)

func _compute_growth_progress(time_left: float) -> float:
	if total_growth_duration <= 0.0:
		return 1.0 if state == FieldState.READY else 0.0
	return clamp(1.0 - (time_left / total_growth_duration), 0.0, 1.0)

func _report_growth_progress(force: bool = false) -> void:
	var state_value: int = int(state)
	var time_left: float = 0.0
	var progress: float = 0.0
	match state_value:
		FieldState.GROWING:
			time_left = _compute_growth_time_left()
			progress = _compute_growth_progress(time_left)
		FieldState.READY:
			time_left = 0.0
			progress = 1.0
		_:
			time_left = 0.0
			progress = 0.0
	_update_progress_visual(state_value, progress, time_left)
	if not GameState.has_method("update_field_growth_info"):
		return
	if not force:
		if abs(progress - _last_reported_progress) < 0.01 and abs(time_left - _last_reported_time_left) < 0.1:
			return
	GameState.update_field_growth_info(self, state_value, progress, time_left, total_growth_duration, crop_type)
	_last_reported_progress = progress
	_last_reported_time_left = time_left

func _update_progress_visual(state_value: int, progress: float, time_left: float) -> void:
	if progress_root == null:
		return
	match state_value:
		FieldState.GROWING:
			_set_progress_visibility(true)
			_apply_progress_fill(progress, PROGRESS_BAR_FILL_COLOR)
			_update_progress_label(_format_time_remaining(time_left))
		FieldState.READY:
			_set_progress_visibility(true)
			_apply_progress_fill(1.0, PROGRESS_BAR_READY_COLOR)
			_update_progress_label("Bereit")
		_:
			_set_progress_visibility(false)

func _set_progress_visibility(visible: bool) -> void:
	if progress_root:
		progress_root.visible = visible
	if _progress_background:
		_progress_background.visible = visible
	if _progress_fill:
		_progress_fill.visible = visible
	if _progress_label:
		_progress_label.visible = visible

func _apply_progress_fill(value: float, color: Color) -> void:
	if _progress_fill == null or _progress_background == null:
		return
	var clamped: float = clamp(value, 0.0, 1.0)
	var safe: float = max(clamped, 0.001)
	var half_width := PROGRESS_BAR_SIZE.x * 0.5
	_progress_fill.scale = Vector3(safe, 1.0, 1.0)
	_progress_fill.position.x = -half_width + (half_width * clamped)
	var fill_material := _progress_fill.material_override as StandardMaterial3D
	if fill_material:
		fill_material.albedo_color = color

func _update_progress_label(text_value: String) -> void:
	if _progress_label == null:
		return
	_progress_label.text = text_value

func _format_time_remaining(seconds_left: float) -> String:
	var total_seconds := int(round(max(seconds_left, 0.0)))
	var minutes := total_seconds / 60
	var seconds := total_seconds % 60
	if minutes >= 99:
		return "%d:--" % minutes
	return "%02d:%02d" % [minutes, seconds]
