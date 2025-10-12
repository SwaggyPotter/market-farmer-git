extends Node3D

const TILE_SIZE := 1.0
const Y_OFFSET  := 0.01
const COLOR_EMPTY := Color(0.754, 0.0, 0.254, 1.0)
const COLOR_GROWING := Color(0.868, 0.867, 0.0, 1.0)
const COLOR_READY := Color(0.223, 0.737, 0.047, 1.0)

enum FieldState { EMPTY, GROWING, READY }

var state: FieldState = FieldState.EMPTY
var crop_type: String = ""

@onready var mesh: MeshInstance3D = _ensure_mesh()
@onready var body: StaticBody3D   = _ensure_body()
@onready var growth_timer: Timer  = _ensure_timer()

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
		FieldState.GROWING:
			mat.albedo_color = COLOR_GROWING
		FieldState.READY:
			mat.albedo_color = COLOR_READY

func start_growth(crop_id: String, duration: float):
	if state != FieldState.EMPTY:
		print("Feld", name, "kann nicht bepflanzt werden (Status:", state, ")")
		return
	crop_type = crop_id
	state = FieldState.GROWING
	growth_timer.wait_time = duration
	growth_timer.start()
	print("Aussaat auf", name, ":", crop_type, "(", duration, "s )")
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
	_update_visual()
