extends Node3D

@export_group("Properties")
@export var target: Vehicle

@onready var camera = $Camera

enum ViewMode { FOLLOW_VEHICLE, BUILDER }
var view_mode: ViewMode = ViewMode.FOLLOW_VEHICLE
var default_basis: Basis
var builder_basis: Basis = Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))

func _ready() -> void:
	default_basis = self.transform.basis

func set_builder_mode(active: bool) -> void:
	if active:
		view_mode = ViewMode.BUILDER
	else:
		view_mode = ViewMode.FOLLOW_VEHICLE

func pan_builder(delta_offset: Vector3) -> void:
	builder_pos += delta_offset
	# Limit pan within reasonable boundary
	builder_pos.x = clampf(builder_pos.x, -50.0, 50.0)
	builder_pos.z = clampf(builder_pos.z, -50.0, 50.0)

func zoom_builder(delta_zoom: float) -> void:
	builder_zoom = clampf(builder_zoom + delta_zoom, 14.0, 55.0)

# Functions

func _physics_process(delta):
	if view_mode == ViewMode.BUILDER:
		self.position = self.position.lerp(builder_pos, delta * 6.0)
		self.transform.basis = self.transform.basis.slerp(builder_basis, delta * 6.0).orthonormalized()
		camera.position.z = lerp(camera.position.z, builder_zoom, delta * 5.0)
		return

	self.transform.basis = self.transform.basis.slerp(default_basis, delta * 4.0).orthonormalized()

	if target == null:
		return

	# Ease position towards target vehicle position

	self.position = self.position.lerp(target.get_vehicle_position(), delta * 4)

	# Zoom camera based on the speed of the vehicle

	var speed_factor = clamp(abs(target.linear_speed), 0.0, 1.0)
	var target_z = remap(speed_factor, 0.0, 1.0, 10, 20)

	camera.position.z = lerp(camera.position.z, target_z, delta * 0.5)
