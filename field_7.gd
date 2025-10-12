extends Node3D

const TILE_SIZE := 1.0
const Y_OFFSET  := 0.01

var planted := false

@onready var mesh: MeshInstance3D = _ensure_mesh()
@onready var body: StaticBody3D   = _ensure_body()

func _ready():
	body.input_event.connect(_on_input_event)
	_update_visual()

func _on_input_event(_camera, event, _position, _normal, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Klick auf: ", name)
		get_tree().call_group("ui", "open_for_tile", self, event.position)
		planted = !planted
		_update_visual()

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

func _update_visual():
	# hier gibt es garantiert ein Mesh & Material
	var mat = mesh.get_active_material(0)
	if mat == null:
		mat = mesh.get_material_override()
	if mat == null:
		mat = StandardMaterial3D.new()
		mat.resource_local_to_scene = true
		mesh.material_override = mat

	mat.albedo_color = (Color(0.868, 0.867, 0.0, 1.0) if planted else Color(0.754, 0.0, 0.254, 1.0))
