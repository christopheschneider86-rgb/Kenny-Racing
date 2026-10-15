class_name VirtualJoystick extends Control

# On-screen Virtual Touch Analog Stick for mobile/tablet & desktop
# Renders smoothly with native vector drawing and responsive multi-touch.

signal analog_moved(vector: Vector2)
signal analog_released()

@export var base_radius: float = 80.0
@export var knob_radius: float = 38.0
@export var deadzone: float = 8.0
@export var touch_activation_radius: float = 160.0

var output_vector: Vector2 = Vector2.ZERO
var knob_offset: Vector2 = Vector2.ZERO
var touch_id: int = -1
var is_active: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(base_radius * 2.5, base_radius * 2.5)
	mouse_filter = Control.MOUSE_FILTER_PASS

func get_center() -> Vector2:
	return size * 0.5

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event.index, event.pressed, event.position)
		accept_event()
	elif event is InputEventScreenDrag:
		if event.index == touch_id:
			_update_knob_position(event.position)
			accept_event()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_touch(9999, event.pressed, event.position)
			accept_event()
	elif event is InputEventMouseMotion:
		if touch_id == 9999:
			_update_knob_position(event.position)
			accept_event()

func _input(event: InputEvent) -> void:
	# Catch touches/mouse outside the control bounds if we are currently dragging
	if is_active:
		if event is InputEventScreenTouch and event.index == touch_id and not event.pressed:
			_release_joystick()
		elif event is InputEventScreenDrag and event.index == touch_id:
			var local_pos = make_canvas_position_local(event.position)
			_update_knob_position(local_pos)
		elif event is InputEventMouseButton and touch_id == 9999 and not event.pressed:
			_release_joystick()
		elif event is InputEventMouseMotion and touch_id == 9999:
			var local_pos = make_canvas_position_local(event.position)
			_update_knob_position(local_pos)

func _handle_touch(index: int, pressed: bool, pos: Vector2) -> void:
	var center = get_center()
	var dist = pos.distance_to(center)

	if pressed:
		if not is_active and dist <= touch_activation_radius:
			touch_id = index
			is_active = true
			_update_knob_position(pos)
	else:
		if index == touch_id:
			_release_joystick()

func _update_knob_position(pos: Vector2) -> void:
	var center = get_center()
	var delta = pos - center
	var length = delta.length()

	if length > base_radius:
		knob_offset = delta.normalized() * base_radius
	else:
		knob_offset = delta

	if knob_offset.length() < deadzone:
		output_vector = Vector2.ZERO
	else:
		# x: [-1, 1], y: [-1, 1] where up is positive (+1)
		output_vector = Vector2(knob_offset.x / base_radius, -knob_offset.y / base_radius)

	queue_redraw()
	analog_moved.emit(output_vector)

func _release_joystick() -> void:
	touch_id = -1
	is_active = false
	knob_offset = Vector2.ZERO
	output_vector = Vector2.ZERO
	queue_redraw()
	analog_released.emit()

func _draw() -> void:
	var center = get_center()

	# Base Background Disc
	var base_bg_color = Color(0.08, 0.12, 0.22, 0.55 if is_active else 0.4)
	draw_circle(center, base_radius, base_bg_color)

	# Outer Ring
	var ring_color = Color(0.35, 0.75, 1.0, 0.85 if is_active else 0.5)
	draw_arc(center, base_radius, 0.0, TAU, 48, ring_color, 3.5, true)

	# Inner Track Ring
	draw_arc(center, base_radius * 0.5, 0.0, TAU, 32, Color(1, 1, 1, 0.15), 1.5, true)

	# Cardinal Direction Indicators (North, South, East, West)
	var arrow_color = Color(0.6, 0.85, 1.0, 0.7 if is_active else 0.4)
	var d_offset = base_radius * 0.75
	# North
	draw_circle(center + Vector2(0, -d_offset), 3.5, arrow_color)
	# South
	draw_circle(center + Vector2(0, d_offset), 3.5, arrow_color)
	# East
	draw_circle(center + Vector2(d_offset, 0), 3.5, arrow_color)
	# West
	draw_circle(center + Vector2(-d_offset, 0), 3.5, arrow_color)

	# Stem / Connection Line when deflected
	if knob_offset.length() > deadzone:
		var stem_color = Color(0.3, 0.75, 1.0, 0.6)
		draw_line(center, center + knob_offset, stem_color, 4.0, true)

	# Knob (Handle)
	var knob_center = center + knob_offset
	var knob_color = Color(0.2, 0.62, 0.98, 0.92) if is_active else Color(0.25, 0.55, 0.85, 0.8)
	draw_circle(knob_center, knob_radius, knob_color)

	# Knob Rim Highlight
	draw_arc(knob_center, knob_radius, 0.0, TAU, 36, Color(1, 1, 1, 0.95), 2.5, true)

	# Tactile Center Jewel
	draw_circle(knob_center, knob_radius * 0.35, Color(1, 1, 1, 0.85))
