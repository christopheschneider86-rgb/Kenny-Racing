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

# Sounds

@onready var screech_sound: AudioStreamPlayer3D = $Container/ScreechSound
@onready var engine_sound: AudioStreamPlayer3D = $Container/EngineSound
@onready var impact_sound: AudioStreamPlayer3D = $Container/ImpactSound

@export var control_mode: ControlMode = ControlMode.DIRECT_DIRECTION

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

func _init_wheel_references() -> void:
	vehicle_body = find_child("body", true, false)
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
		fwd = Vector3.FORWARD
	var up = Vector3.UP
	var right = up.cross(fwd).normalized()
	up = fwd.cross(right).normalized()
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

	vehicle_body = new_model.find_child("body", true, false)

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

func set_truck_color(color_name: String) -> void:
	set_vehicle("truck", color_name)

# Physics & Control Process

func _physics_process(delta):

	handle_input(delta)

	var direction = sign(linear_speed)
	if direction == 0: direction = sign(input.z) if abs(input.z) > 0.1 else 1

	var min_grip = 0.7 if control_mode == ControlMode.DIRECT_DIRECTION else 0.2
	var steering_grip = clamp(abs(linear_speed), min_grip, 1.0)

	var target_angular = -input.x * steering_grip * 4 * direction
	angular_speed = lerp(angular_speed, target_angular, delta * 4)

	vehicle_model.rotate_y(angular_speed * delta)

	# Ground alignment

	if raycast.is_colliding():
		if !colliding:
			if vehicle_body != null: vehicle_body.position = Vector3(0, 0.1, 0) # Bounce
			input.z = 0

		normal = raycast.get_collision_normal()

		# Orient model to colliding normal

		if normal.dot(vehicle_model.global_basis.y) > 0.5:
			var xform = align_with_y(vehicle_model.global_transform, normal)
			vehicle_model.global_transform = vehicle_model.global_transform.interpolate_with(xform, 0.2).orthonormalized()

	colliding = raycast.is_colliding()

	var target_speed = input.z

	if (target_speed < 0 and linear_speed > 0.01):
		linear_speed = lerp(linear_speed, 0.0, delta * 8)
	else:
		if (target_speed < 0):
			linear_speed = lerp(linear_speed, target_speed / 2, delta * 2)
		else:
			linear_speed = lerp(linear_speed, target_speed, delta * 6)

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

	sphere.angular_velocity += vehicle_model.get_global_transform().basis.x * (linear_speed * 100) * delta

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
		vehicle_body.position = vehicle_body.position.lerp(Vector3(0, 0.2, 0), delta * 5)

	# Motorcycle corner leaning
	if motorcycle_mesh != null:
		motorcycle_mesh.rotation.z = lerp_angle(motorcycle_mesh.rotation.z, input.x * linear_speed, delta * 3)

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
	var speed_factor = clamp(abs(linear_speed), 0.0, 1.0)
	var throttle_factor = clamp(abs(input.z), 0.0, 1.0)

	var target_volume = remap(speed_factor + (throttle_factor * 0.5), 0.0, 1.5, -15.0, -5.0)
	engine_sound.volume_db = lerp(engine_sound.volume_db, target_volume, delta * 5.0)

	var base_pitch = 0.7 if current_vehicle_type == "motorcycle" else 0.5
	var target_pitch = remap(speed_factor, 0.0, 1.0, base_pitch, 3.2)
	if throttle_factor > 0.1: target_pitch += 0.2

	engine_sound.pitch_scale = lerp(engine_sound.pitch_scale, target_pitch, delta * 2.0)

# Show trails (and play skid sound)

func effect_trails():
	var drift_intensity = abs(linear_speed - acceleration) + (abs(calculated_lean) * 2.0)
	var should_emit = drift_intensity > 0.25

	if trail_left != null: trail_left.emitting = should_emit
	if trail_right != null: trail_right.emitting = should_emit

	var target_volume = -80.0
	if should_emit: target_volume = remap(clamp(drift_intensity, 0.25, 2.0), 0.25, 2.0, -10.0, 0.0)

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
