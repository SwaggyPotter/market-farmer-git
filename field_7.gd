extends Node3D

const TILE_SIZE := 1.0
const Y_OFFSET  := 0.01
const COLOR_EMPTY := Color(0.754, 0.0, 0.254, 1.0)
const COLOR_GROWING := Color(0.868, 0.867, 0.0, 1.0)
const COLOR_READY := Color(0.223, 0.737, 0.047, 1.0)
const CROP_SCENES := {
	"wheat": preload("res://assets/WeizenBigger.glb"),
}
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

enum FieldState { EMPTY, GROWING, READY }

var state: FieldState = FieldState.EMPTY
var crop_type: String = ""

@onready var mesh: MeshInstance3D = _ensure_mesh()
@onready var body: StaticBody3D   = _ensure_body()
@onready var growth_timer: Timer  = _ensure_timer()
@onready var crop_container: Node3D = _ensure_crop_container()
var crop_visual: Node3D = null
var active_phases: Array = []
var phase_durations: Array[float] = []
var phase_index: int = -1

func _ready():
	body.input_event.connect(_on_input_event)
	_update_visual()

func _on_input_event(_camera, event, _position, _normal, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		match state:
			FieldState.READY:
				_harvest()
			FieldState.GROWING:
				print("Feld", name, "wächst noch:", crop_type, "(Rest:", "%.2f" % growth_timer.time_left, "s)")
			_:
				print("Klick auf freies Feld:", name)
				get_tree().call_group("ui", "open_for_tile", self, event.position)

func _ensure_mesh() -> MeshInstance3D:
	var m = get_node_or_null("MeshInstance3D")
	if m == null:
		m = MeshInstance3D.new()
		m.name = "MeshInstance3D"
		var plane := PlaneMesh.new()
		plane.size = Vector2(TILE_SIZE, TILE_SIZE)
		m.mesh = plane
		m.position = Vector3(0, Y_OFFSET, 0)
		m.visible = false
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)

		var mat := StandardMaterial3D.new()
		mat.resource_local_to_scene = true   # jede Instanz hat ihr eigenes Material
		mat.roughness = 0.7
		m.material_override = mat
	m.visible = false
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
	active_phases = _get_crop_phases(crop_type)
	phase_durations = _compute_phase_durations(duration, active_phases)
	phase_index = -1
	print("Aussaat auf", name, ":", crop_type, "(", duration, "s )")
	if active_phases.is_empty():
		var fallback_scene := _get_default_scene(crop_type)
		_spawn_crop_visual(fallback_scene, _get_crop_scale(crop_type), _get_crop_offset(crop_type))
		if duration > 0.0:
			growth_timer.wait_time = duration
			growth_timer.start()
		else:
			_on_growth_finished()
	else:
		phase_index = 0
		_apply_growth_phase(phase_index)
		_start_phase_timer(phase_index)
	_update_visual()

func _on_growth_finished():
	if state == FieldState.READY:
		return
	growth_timer.stop()
	phase_durations.clear()
	if not active_phases.is_empty():
		phase_index = active_phases.size() - 1
	state = FieldState.READY
	print("Feld", name, "ist bereit zur Ernte:", crop_type)
	_update_visual()

func _harvest():
	print("Geerntet auf", name, ":", crop_type)
	growth_timer.stop()
	active_phases.clear()
	phase_durations.clear()
	phase_index = -1
	crop_type = ""
	state = FieldState.EMPTY
	_clear_crop_visual()
	_update_visual()

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
	if CROP_SCENES.has(crop_id):
		return CROP_SCENES[crop_id]
	return null

func _get_crop_scale(crop_id: String) -> Vector3:
	return CROP_SCALE.get(crop_id, Vector3.ONE)

func _get_crop_offset(crop_id: String) -> Vector3:
	return CROP_OFFSET.get(crop_id, Vector3.ZERO)

func _get_crop_phases(crop_id: String) -> Array:
	if CROP_PHASES.has(crop_id):
		return CROP_PHASES[crop_id].duplicate(true)
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
