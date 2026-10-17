class_name SkidRibbon extends Node3D

# Manages continuous tire skidmark ribbons for vehicles
# Eliminates gaps and connects wheel tracks smoothly

@export var half_width: float = 0.13
@export var max_points_per_strip: int = 120

var skid_material: StandardMaterial3D

var current_mesh_instance: MeshInstance3D
var current_immediate_mesh: ImmediateMesh
var current_points: Array[Vector3] = []
var prev_point: Vector3 = Vector3.ZERO
var is_skidding: bool = false

var active_strips: Array = []

func _ready() -> void:
	top_level = true
	global_position = Vector3.ZERO
	global_rotation = Vector3.ZERO

	skid_material = StandardMaterial3D.new()
	skid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	skid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	skid_material.albedo_color = Color(0.12, 0.12, 0.14, 0.75)
	skid_material.render_priority = 3
	skid_material.cull_mode = BaseMaterial3D.CULL_DISABLED

func set_skidding(skidding: bool, wheel_pos: Vector3, _normal_dir: Vector3 = Vector3.UP) -> void:
	if skidding:
		var ground_pos = Vector3(wheel_pos.x, 0.045, wheel_pos.z)
		if not is_skidding:
			_start_new_strip(ground_pos)
		else:
			if (ground_pos - prev_point).length() > 0.10:
				_add_strip_point(ground_pos)
	else:
		if is_skidding:
			_end_strip()

	is_skidding = skidding

func _start_new_strip(pos: Vector3) -> void:
	current_points.clear()
	current_points.append(pos)
	prev_point = pos

	current_immediate_mesh = ImmediateMesh.new()
	current_mesh_instance = MeshInstance3D.new()
	current_mesh_instance.mesh = current_immediate_mesh
	current_mesh_instance.material_override = skid_material.duplicate()
	add_child(current_mesh_instance)

	active_strips.append({
		"instance": current_mesh_instance,
		"mat": current_mesh_instance.material_override,
		"age": 0.0
	})

func _add_strip_point(pos: Vector3) -> void:
	current_points.append(pos)
	prev_point = pos

	if current_points.size() >= max_points_per_strip:
		_end_strip()
		_start_new_strip(pos)
		return

	_rebuild_current_mesh()

func _rebuild_current_mesh() -> void:
	if not current_immediate_mesh or current_points.size() < 2:
		return

	current_immediate_mesh.clear_surfaces()
	current_immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)

	for i in range(current_points.size()):
		var p = current_points[i]
		var fwd: Vector3
		if i < current_points.size() - 1:
			fwd = (current_points[i + 1] - p).normalized()
		else:
			fwd = (p - current_points[i - 1]).normalized()

		if fwd.is_zero_approx():
			fwd = Vector3(0, 0, 1)

		var right = fwd.cross(Vector3.UP).normalized() * half_width
		current_immediate_mesh.surface_add_vertex(p - right)
		current_immediate_mesh.surface_add_vertex(p + right)

	current_immediate_mesh.surface_end()

func _end_strip() -> void:
	current_immediate_mesh = null
	current_mesh_instance = null
	current_points.clear()

@export var strip_lifetime: float = 18.0

func _process(delta: float) -> void:
	var to_remove: Array = []
	for s in active_strips:
		s["age"] += delta
		var progress = s["age"] / strip_lifetime
		var alpha = 1.0
		if progress > 0.6:
			alpha = clampf((1.0 - progress) / 0.4, 0.0, 1.0)
		if s["mat"] is StandardMaterial3D:
			s["mat"].albedo_color.a = alpha * 0.8
		if s["age"] >= strip_lifetime:
			to_remove.append(s)

	for r in to_remove:
		active_strips.erase(r)
		if is_instance_valid(r["instance"]):
			r["instance"].queue_free()
