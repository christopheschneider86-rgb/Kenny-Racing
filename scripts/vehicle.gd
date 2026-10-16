class_name Vehicle extends Node3D

enum ControlMode { DIRECT_DIRECTION = 0, CLASSIC = 1 }

# Nodes

@onready var sphere: RigidBody3D = $Sphere
@onready var raycast: RayCast3D = $Ground

# Vehicle elements

@onready var vehicle_model = $Container
@onready var vehicle_body = get_node_or_null("Container/Model/body")

# 4-wheel vehicles (Trucks & RaceCars)
var wheel_fl: Node3D
var wheel_fr: Node3D
var wheel_bl: Node3D
var wheel_br: Node3D

# 2-wheel vehicle (Motorcycle)
var wheel_front: Node3D
var wheel_back: Node3D
var fork: Node3D
var motorcycle_mesh: Node3D

# Effects

@onready var trail_left = get_node_or_null("Container/TrailLeft")
@onready var trail_right = get_node_or_null("Container/TrailRight")

# Continuous ribbon skidmarks
var skid_ribbon_left: SkidRibbon
var skid_ribbon_right: SkidRibbon
var skid_ribbon_center: SkidRibbon

var vehicle_body_default_pos: Vector3 = Vector3(0, 0.4, 0)

# Sounds

@onready var screech_sound: AudioStreamPlayer3D = $Container/ScreechSound
@onready var engine_sound: AudioStreamPlayer3D = $Container/EngineSound
@onready var impact_sound: AudioStreamPlayer3D = $Container/ImpactSound

@export var control_mode: ControlMode = ControlMode.DIRECT_DIRECTION

const VEHICLE_SPECS: Dictionary = {
	"truck": {
		"name": "Racing Truck",
		"max_speed": 1.0,
		"accel_rate": 5.5,
		"brake_rate": 8.5,
		"steer_speed": 3.8,
		"min_grip": 0.55,
		"drift_mult": 1.0,
		"sphere_force": 95.0,
		"mass": 1300.0,
		"engine_pitch_base": 0.45,
	},
	"racecar": {
		"name": "Rennauto",
		"max_speed": 1.30,
		"accel_rate": 7.5,
		"brake_rate": 10.5,
		"steer_speed": 5.0,
		"min_grip": 0.45,
		"drift_mult": 1.3,
		"sphere_force": 125.0,
		"mass": 750.0,
		"engine_pitch_base": 0.60,
	},
	"motorcycle": {
		"name": "Motorrad",
		"max_speed": 1.20,
		"accel_rate": 9.0,
		"brake_rate": 9.5,
		"steer_speed": 5.5,
		"min_grip": 0.50,
		"drift_mult": 1.1,
		"sphere_force": 115.0,
		"mass": 450.0,
		"engine_pitch_base": 0.75,
	}
}

func get_spec() -> Dictionary:
	return VEHICLE_SPECS.get(current_vehicle_type, VEHICLE_SPECS["truck"])

var current_vehicle_type: String = "truck"
var current_vehicle_color: String = "yellow"

var joystick_vector: Vector2 = Vector2.ZERO
var joystick_active: bool = false
var input_disabled: bool = false

var input: Vector3
var normal: Vector3

var acceleration: float
var angular_speed: float
var linear_speed: float

var colliding: bool

var linear_velocity: Vector3
var prev_position: Vector3

var calculated_lean: float

func _ready() -> void:
	_init_wheel_references()
	if sphere:
		sphere.mass = get_spec()["mass"]

	skid_ribbon_left = SkidRibbon.new()
	skid_ribbon_left.name = "SkidRibbonLeft"
	skid_ribbon_left.half_width = 0.12
	add_child(skid_ribbon_left)

	skid_ribbon_right = SkidRibbon.new()
	skid_ribbon_right.name = "SkidRibbonRight"
	skid_ribbon_right.half_width = 0.12
	add_child(skid_ribbon_right)

	skid_ribbon_center = SkidRibbon.new()
	skid_ribbon_center.name = "SkidRibbonCenter"
	skid_ribbon_center.half_width = 0.16
	add_child(skid_ribbon_center)

func _init_wheel_references() -> void:
	vehicle_body = find_child("body", true, false)
	if vehicle_body:
		vehicle_body_default_pos = vehicle_body.position
	wheel_fl = find_child("wheel-front-left", true, false)
	if not wheel_fl: wheel_fl = find_child("wheelFrontLeft", true, false)
	wheel_fr = find_child("wheel-front-right", true, false)
	if not wheel_fr: wheel_fr = find_child("wheelFrontRight", true, false)
	wheel_bl = find_child("wheel-back-left", true, false)
	if not wheel_bl: wheel_bl = find_child("wheelBackLeft", true, false)
	wheel_br = find_child("wheel-back-right", true, false)
	if not wheel_br: wheel_br = find_child("wheelBackRight", true, false)

	wheel_front = find_child("wheel-front", true, false)
	wheel_back = find_child("wheel-back", true, false)
	fork = find_child("fork", true, false)
	motorcycle_mesh = find_child("motorcycle", true, false)

# Public Functions

func rotate_showroom(delta: float) -> void:
	vehicle_model.rotate_y(delta * 0.75)

func get_vehicle_position() -> Vector3:
	return vehicle_model.global_position

func set_joystick_input(vec: Vector2, active: bool) -> void:
	joystick_vector = vec
	joystick_active = active

func toggle_control_mode() -> ControlMode:
	if control_mode == ControlMode.DIRECT_DIRECTION:
		control_mode = ControlMode.CLASSIC
	else:
		control_mode = ControlMode.DIRECT_DIRECTION
	return control_mode

func respawn_to(target_pos: Vector3, forward_dir: Vector3) -> void:
	sphere.linear_velocity = Vector3.ZERO
	sphere.angular_velocity = Vector3.ZERO
	sphere.global_position = target_pos + Vector3(0, 0.65, 0)

	var fwd = Vector3(forward_dir.x, 0.0, forward_dir.z).normalized()
	if fwd.is_zero_approx():
		fwd = Vector3(0, 0, 1)

	# Kenney vehicles have front at local +Z. Align basis.z with forward direction:
	var right = Vector3.UP.cross(fwd).normalized()
	var up = fwd.cross(right).normalized()
	var new_basis = Basis(right, up, fwd)
	vehicle_model.global_transform = Transform3D(new_basis, target_pos)
	raycast.global_position = sphere.global_position

	linear_speed = 0.0
	acceleration = 0.0
	angular_speed = 0.0
	input = Vector3.ZERO
	prev_position = target_pos

func set_vehicle(type_name: String, color_name: String) -> void:
	current_vehicle_type = type_name.to_lower()
	current_vehicle_color = color_name.to_lower()

	var glb_path := ""
	if current_vehicle_type == "truck":
		glb_path = "res://models/vehicle-truck-%s.glb" % current_vehicle_color
	elif current_vehicle_type == "racecar":
		glb_path = "res://models/vehicle-racecar-%s.glb" % current_vehicle_color
	elif current_vehicle_type == "motorcycle":
		glb_path = "res://models/vehicle-motorcycle.glb"

	if not ResourceLoader.exists(glb_path):
		return
	var scene = load(glb_path)
	if not scene:
		return

	var old_model = $Container.get_node_or_null("Model")
	if old_model:
		old_model.name = "OldModel"
		old_model.queue_free()

	var new_model = scene.instantiate()
	new_model.name = "Model"
	$Container.add_child(new_model)
	new_model.position = Vector3.ZERO
	new_model.rotation = Vector3.ZERO

	if current_vehicle_type == "racecar":
		new_model.scale = Vector3(1.4, 1.4, 1.4)
		_apply_racecar_paint(new_model, current_vehicle_color)
	elif current_vehicle_type == "motorcycle":
		new_model.scale = Vector3(1.2, 1.2, 1.2)
	else:
		new_model.scale = Vector3(1.0, 1.0, 1.0)

	vehicle_body = new_model.find_child("body", true, false)
	if vehicle_body:
		vehicle_body_default_pos = vehicle_body.position

	wheel_fl = new_model.find_child("wheel-front-left", true, false)
	if not wheel_fl: wheel_fl = new_model.find_child("wheelFrontLeft", true, false)

	wheel_fr = new_model.find_child("wheel-front-right", true, false)
	if not wheel_fr: wheel_fr = new_model.find_child("wheelFrontRight", true, false)

	wheel_bl = new_model.find_child("wheel-back-left", true, false)
	if not wheel_bl: wheel_bl = new_model.find_child("wheelBackLeft", true, false)

	wheel_br = new_model.find_child("wheel-back-right", true, false)
	if not wheel_br: wheel_br = new_model.find_child("wheelBackRight", true, false)

	wheel_front = new_model.find_child("wheel-front", true, false)
	wheel_back = new_model.find_child("wheel-back", true, false)
	fork = new_model.find_child("fork", true, false)
	motorcycle_mesh = new_model.find_child("motorcycle", true, false)

	var spec = get_spec()
	if sphere:
		sphere.mass = spec["mass"]

func _apply_racecar_paint(model_node: Node, color_key: String) -> void:
	var color_map = {
		"red": Color(0.92, 0.15, 0.15),
		"green": Color(0.18, 0.8, 0.32),
		"orange": Color(0.98, 0.52, 0.12),
		"white": Color(0.96, 0.96, 0.98),
		"yellow": Color(0.96, 0.85, 0.15),
		"purple": Color(0.72, 0.28, 0.88),
	}
	var paint_color: Color = color_map.get(color_key, Color(0.92, 0.15, 0.15))

	var meshes = model_node.find_children("*", "MeshInstance3D", true, false)
	for mi in meshes:
		if mi is MeshInstance3D and mi.mesh:
			for s in range(mi.mesh.get_surface_count()):
				var mat = mi.get_surface_override_material(s)
				if mat == null:
					mat = mi.mesh.surface_get_material(s)
				if mat is StandardMaterial3D:
					var m_name = mat.resource_name.to_lower()
					if not ("tire" in m_name or "glass" in m_name or "black" in m_name):
						var dup_mat: StandardMaterial3D = mat.duplicate()
						dup_mat.albedo_color = paint_color
						dup_mat.roughness = 0.35
						dup_mat.metallic = 0.25
						mi.set_surface_override_material(s, dup_mat)

func set_truck_color(color_name: String) -> void:
	set_vehicle("truck", color_name)

# Physics & Control Process

func _physics_process(delta):
	var spec = get_spec()

	handle_input(delta)

	var direction = sign(linear_speed)
	if direction == 0: direction = sign(input.z) if abs(input.z) > 0.1 else 1

	var min_grip = spec["min_grip"] if control_mode == ControlMode.DIRECT_DIRECTION else 0.2
	var steering_grip = clamp(abs(linear_speed), min_grip, 1.0)

	var target_angular = -input.x * steering_grip * spec["steer_speed"] * direction
	angular_speed = lerp(angular_speed, target_angular, delta * 4)

	vehicle_model.rotate_y(angular_speed * delta)

	# Ground alignment

	if raycast.is_colliding():
		if !colliding:
			if vehicle_body != null: vehicle_body.position = vehicle_body_default_pos + Vector3(0, 0.08, 0) # Bounce
			input.z = 0

		normal = raycast.get_collision_normal()

		# Orient model to colliding normal

		if normal.dot(vehicle_model.global_basis.y) > 0.5:
			var xform = align_with_y(vehicle_model.global_transform, normal)
			vehicle_model.global_transform = vehicle_model.global_transform.interpolate_with(xform, 0.2).orthonormalized()

	colliding = raycast.is_colliding()

	var target_speed = input.z * spec["max_speed"]

	if (target_speed < 0 and linear_speed > 0.01):
		linear_speed = lerp(linear_speed, 0.0, delta * spec["brake_rate"])
	else:
		if (target_speed < 0):
			linear_speed = lerp(linear_speed, target_speed * 0.5, delta * 3.0)
		else:
			linear_speed = lerp(linear_speed, target_speed, delta * spec["accel_rate"])

	acceleration = lerpf(acceleration, linear_speed + (abs(sphere.angular_velocity.length() * linear_speed) / 100), delta * 1)

	# Match vehicle model to physics sphere

	vehicle_model.position = sphere.position - Vector3(0, 0.65, 0)
	raycast.position = sphere.position

	# Calculate vehicle model linear velocity

	linear_velocity = (vehicle_model.position - prev_position) / delta
	prev_position = vehicle_model.position

	# Visual and audio effects

	effect_engine(delta)
	effect_body(delta)
	effect_wheels(delta)
	effect_trails()

# Handle input when vehicle is colliding with ground

func handle_input(delta):

	if input_disabled:
		input = Vector3.ZERO
		return

	if raycast.is_colliding():
		var kb_x = Input.get_axis("left", "right")
		var kb_z = Input.get_axis("back", "forward")

		if absf(kb_x) > 0.05 or absf(kb_z) > 0.05:
			input.x = kb_x
			input.z = kb_z
		elif joystick_active and joystick_vector.length() > 0.05:
			if control_mode == ControlMode.DIRECT_DIRECTION:
				apply_directional_steering(joystick_vector, delta)
			else:
				input.x = joystick_vector.x
				input.z = joystick_vector.y
		else:
			input.x = 0.0
			input.z = 0.0

	var spec = get_spec()
	sphere.angular_velocity += vehicle_model.get_global_transform().basis.x * (linear_speed * spec["sphere_force"]) * delta

func apply_directional_steering(j_vec: Vector2, _delta: float) -> void:
	var cam = get_viewport().get_camera_3d()
	if not cam:
		input.x = j_vec.x
		input.z = j_vec.y
		return

	var cam_basis = cam.global_basis
	var cam_fwd = -cam_basis.z
	cam_fwd.y = 0.0
	cam_fwd = cam_fwd.normalized()

	var cam_right = cam_basis.x
	cam_right.y = 0.0
	cam_right = cam_right.normalized()

	var target_dir = (cam_right * j_vec.x + cam_fwd * j_vec.y).normalized()

	var car_fwd = vehicle_model.global_basis.z
	car_fwd.y = 0.0
	car_fwd = car_fwd.normalized()

	var angle_diff = car_fwd.signed_angle_to(target_dir, Vector3.UP)
	input.x = clampf(-angle_diff * 1.8, -1.0, 1.0)

	var stick_mag = clampf(j_vec.length(), 0.0, 1.0)
	var alignment = car_fwd.dot(target_dir)

	if alignment > 0.15:
		input.z = clampf(stick_mag * (0.35 + 0.65 * alignment), 0.25, 1.0)
	elif alignment > -0.4:
		input.z = stick_mag * 0.35
	else:
		input.z = stick_mag * 0.2

func effect_body(delta):
	calculated_lean = lerp_angle(calculated_lean, -input.x / 5 * linear_speed, delta * 5)

	if vehicle_body != null:
		vehicle_body.rotation.x = lerp_angle(vehicle_body.rotation.x, -(linear_speed - acceleration) / 6, delta * 10)
		vehicle_body.rotation.z = calculated_lean
		vehicle_body.position = vehicle_body.position.lerp(vehicle_body_default_pos, delta * 5)

	# Motorcycle corner leaning (leans dynamically inward into curves)
	if motorcycle_mesh != null:
		var target_lean = input.x * clampf(abs(linear_speed), 0.2, 1.0) * 0.65
		motorcycle_mesh.rotation.z = lerp_angle(motorcycle_mesh.rotation.z, target_lean, delta * 7.0)

func effect_wheels(delta):
	# Rotate 4 wheels (Truck & RaceCar)
	for wheel in [wheel_fl, wheel_fr, wheel_bl, wheel_br]:
		if wheel != null:
			wheel.rotation.x += acceleration

	if wheel_fl != null: wheel_fl.rotation.y = lerp_angle(wheel_fl.rotation.y, -input.x / 1.5, delta * 10)
	if wheel_fr != null: wheel_fr.rotation.y = lerp_angle(wheel_fr.rotation.y, -input.x / 1.5, delta * 10)

	# Rotate 2 wheels & fork (Motorcycle)
	if wheel_front != null:
		wheel_front.rotation.x += acceleration
		wheel_front.rotation.y = lerp_angle(wheel_front.rotation.y, -input.x / 1.5, delta * 10)
	if wheel_back != null:
		wheel_back.rotation.x += acceleration
	if fork != null:
		fork.rotation.y = lerp_angle(fork.rotation.y, -input.x / 1.5, delta * 5)

# Engine sounds

func effect_engine(delta):
	var spec = get_spec()
	var speed_factor = clamp(abs(linear_speed), 0.0, 1.0)
	var throttle_factor = clamp(abs(input.z), 0.0, 1.0)

	var target_volume = remap(speed_factor + (throttle_factor * 0.5), 0.0, 1.5, -15.0, -5.0)
	engine_sound.volume_db = lerp(engine_sound.volume_db, target_volume, delta * 5.0)

	var base_pitch: float = spec["engine_pitch_base"]
	var target_pitch = remap(speed_factor, 0.0, 1.0, base_pitch, 3.2)
	if throttle_factor > 0.1: target_pitch += 0.2

	engine_sound.pitch_scale = lerp(engine_sound.pitch_scale, target_pitch, delta * 2.0)

# Show trails (and play skid sound)

func effect_trails():
	var spec = get_spec()
	var drift_intensity = abs(linear_speed - acceleration) * spec.get("drift_mult", 1.0) + (abs(calculated_lean) * 2.0)
	var is_burnout = (input.z > 0.35 and abs(linear_speed) < 0.55)
	var is_braking = (input.z < -0.1 and abs(linear_speed) > 0.05)
	var is_drifting = (abs(input.x) > 0.25 and abs(linear_speed) > 0.2) or (drift_intensity > 0.18)
	var should_emit = (is_burnout or is_braking or is_drifting) and colliding

	# Smoke particles
	if trail_left != null: trail_left.emitting = should_emit
	if trail_right != null: trail_right.emitting = should_emit

	# Continuous connected ribbon skidmarks (no gaps!)
	if should_emit:
		if current_vehicle_type == "motorcycle":
			# Motorcycle: exactly ONE single rear wheel track!
			var center_pos = vehicle_model.to_global(Vector3(0.0, 0.0, -0.65))
			if skid_ribbon_center: skid_ribbon_center.set_skidding(true, center_pos)
			if skid_ribbon_left: skid_ribbon_left.set_skidding(false, Vector3.ZERO)
			if skid_ribbon_right: skid_ribbon_right.set_skidding(false, Vector3.ZERO)
		else:
			# 4-wheel vehicles: two parallel continuous tracks
			var left_pos = vehicle_model.to_global(Vector3(0.38, 0.0, -0.55))
			var right_pos = vehicle_model.to_global(Vector3(-0.38, 0.0, -0.55))
			if skid_ribbon_left: skid_ribbon_left.set_skidding(true, left_pos)
			if skid_ribbon_right: skid_ribbon_right.set_skidding(true, right_pos)
			if skid_ribbon_center: skid_ribbon_center.set_skidding(false, Vector3.ZERO)
	else:
		if skid_ribbon_left: skid_ribbon_left.set_skidding(false, Vector3.ZERO)
		if skid_ribbon_right: skid_ribbon_right.set_skidding(false, Vector3.ZERO)
		if skid_ribbon_center: skid_ribbon_center.set_skidding(false, Vector3.ZERO)

	var target_volume = -80.0
	if should_emit: target_volume = remap(clamp(drift_intensity, 0.18, 2.0), 0.18, 2.0, -10.0, 0.0)

	screech_sound.pitch_scale = lerp(screech_sound.pitch_scale, clamp(abs(linear_speed), 1.0, 3.0), 0.1)
	screech_sound.volume_db = lerp(screech_sound.volume_db, target_volume, 10.0 * get_physics_process_delta_time())

# Align vehicle with normal

func align_with_y(xform, new_y):
	xform.basis.y = new_y
	xform.basis.x = -xform.basis.z.cross(new_y)
	xform.basis = xform.basis.orthonormalized()
	return xform

# Detect collisions and play impact sound

func _on_sphere_body_entered(_body: Node) -> void:
	if vehicle_body == null: return

	if not impact_sound.playing:
		var impact_velocity := absf(linear_velocity.dot(vehicle_body.global_basis.z))
		impact_sound.volume_db = clampf(remap(impact_velocity, 0.0, 6.0, -20.0, 0.0), -20.0, 0.0)
		impact_sound.play()
