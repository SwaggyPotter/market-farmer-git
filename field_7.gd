extends Node3D

const TILE_SIZE := 1.0
const Y_OFFSET  := 0.01
const COLOR_EMPTY := Color(0.754, 0.0, 0.254, 1.0)
const COLOR_GROWING := Color(0.868, 0.867, 0.0, 1.0)
const COLOR_READY := Color(0.223, 0.737, 0.047, 1.0)
const CROP_SCENES := {
	"wheat": preload("res://assets/WeizenBigger.glb"),
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
		add_child(m)

		var mat := StandardMaterial3D.new()
		mat.resource_local_to_scene = true   # jede Instanz hat ihr eigenes Material
		mat.roughness = 0.7
		m.material_override = mat
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
	var callable := Callable(self, "_on_growth_finished")
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
			_update_crop_growth_visual(false)
		FieldState.READY:
			mat.albedo_color = COLOR_READY
			_set_crop_visibility(crop_visual != null)
			_update_crop_growth_visual(true)

func start_growth(crop_id: String, duration: float):
	if state != FieldState.EMPTY:
		print("Feld", name, "kann nicht bepflanzt werden (Status:", state, ")")
		return
	crop_type = crop_id
	state = FieldState.GROWING
	growth_timer.wait_time = duration
	growth_timer.start()
	print("Aussaat auf", name, ":", crop_type, "(", duration, "s )")
	_spawn_crop_visual(crop_type)
	_update_visual()

func _on_growth_finished():
	state = FieldState.READY
	print("Feld", name, "ist bereit zur Ernte:", crop_type)
	_update_visual()

func _harvest():
	print("Geerntet auf", name, ":", crop_type)
	growth_timer.stop()
	crop_type = ""
	state = FieldState.EMPTY
	_clear_crop_visual()
	_update_visual()

func _spawn_crop_visual(crop_id: String):
	_clear_crop_visual()
	if not CROP_SCENES.has(crop_id):
		return
	var scene: PackedScene = CROP_SCENES[crop_id]
	var instance := scene.instantiate()
	if instance is Node3D:
		crop_visual = instance
		crop_container.add_child(crop_visual)
	else:
		var wrapper := Node3D.new()
		wrapper.name = str(crop_id, "_Wrapper")
		crop_container.add_child(wrapper)
		wrapper.add_child(instance)
		crop_visual = wrapper
	if CROP_OFFSET.has(crop_id):
		crop_visual.position = CROP_OFFSET[crop_id]
	if CROP_SCALE.has(crop_id):
		crop_visual.scale = CROP_SCALE[crop_id]

func _clear_crop_visual():
	if crop_visual and crop_visual.is_inside_tree():
		crop_visual.queue_free()
	crop_visual = null
	_set_crop_visibility(false)

func _set_crop_visibility(visible: bool):
	if crop_container:
		crop_container.visible = visible

func _update_crop_growth_visual(is_ready: bool):
	if crop_visual == null:
		return
	var scale: Vector3 = Vector3.ONE
	if CROP_SCALE.has(crop_type):
		scale = CROP_SCALE[crop_type]
	if is_ready:
		crop_visual.scale = scale
	else:
		crop_visual.scale = scale * 0.7
