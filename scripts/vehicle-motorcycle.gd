extends Vehicle

var motorcycle: Node3D

func _ready():
	super._ready()
	motorcycle = get_node_or_null("Container/Model/motorcycle")
	fork = get_node_or_null("Container/Model/motorcycle/body/fork")
	wheel_front = get_node_or_null("Container/Model/motorcycle/wheel-front")
	wheel_back = get_node_or_null("Container/Model/motorcycle/wheel-back")
	vehicle_body = get_node_or_null("Container/Model/motorcycle/body")

# Overwrite functions from base vehicle script

func effect_body(delta):
	
	var target_lean = -input.x / 5 * linear_speed 
	calculated_lean = lerp_angle(calculated_lean, target_lean, delta * 5)
	
	# Apply leaning when doing corners
	
	if motorcycle != null:
		motorcycle.rotation.z = lerp_angle(motorcycle.rotation.z, input.x * linear_speed , delta * 3)
		vehicle_body.rotation.x = lerp_angle(vehicle_body.rotation.x, -(linear_speed - acceleration) / 6, delta * 10)

func effect_wheels(delta):
	
	# Rotate wheels based on acceleration
	
	for wheel in [wheel_front, wheel_back]:
		if wheel != null:
			wheel.rotation.x += acceleration

	# Handle steering
	
	if wheel_front != null:
		fork.rotation.y = lerp_angle(fork.rotation.y, -input.x / 1.5, delta * 5)
		wheel_front.rotation.y = lerp_angle(wheel_front.rotation.y, -input.x / 1.5, delta * 10)
