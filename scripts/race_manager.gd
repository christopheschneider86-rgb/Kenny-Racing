class_name RaceManager extends Node

# Race Manager for Kenny Racing:
# - Track waypoint and segment math
# - Lap progression (strictly 4 laps with sequential checkpoint anti-cheat)
# - Real-time Wrong Way detection
# - Respawn / Reset handler
# - Integration bridge for learning apps (postMessage / reward signal)

signal race_state_changed(state: int)
signal countdown_tick(text: String)
signal lap_updated(current_lap: int, total_laps: int)
signal wrong_way_toggled(is_wrong: bool)
signal race_finished(total_time: float)
signal race_reward_completed(data: Dictionary)

enum GameState { MENU = 0, COUNTDOWN = 1, RACING = 2, FINISHED = 3 }

@export var vehicle: Vehicle
@export var grid_map: GridMap
@export var sound_effects: SoundEffects
@export var total_laps: int = 4

var current_state: GameState = GameState.MENU
var current_lap: int = 1
var race_time: float = 0.0

var current_segment: int = 0
var checkpoint_progress: int = 0
var is_wrong_way: bool = false
var wrong_way_timer: float = 0.0

# 16 connected track cells that form the circuit
const TRACK_CELLS: Array[Vector2i] = [
	Vector2i( 0,  0), # 0: Start / Finish Line
	Vector2i( 0,  1), # 1: Straight
	Vector2i( 0,  2), # 2: Corner -> turns left to -X
	Vector2i(-1,  2), # 3: Straight
	Vector2i(-2,  2), # 4: Corner -> turns to -Z
	Vector2i(-2,  1), # 5: Straight
	Vector2i(-2,  0), # 6: Straight
	Vector2i(-2, -1), # 7: Corner -> turns to -X
	Vector2i(-3, -1), # 8: Corner -> turns to -Z
	Vector2i(-3, -2), # 9: Straight
	Vector2i(-3, -3), # 10: Corner -> turns to +X
	Vector2i(-2, -3), # 11: Straight
	Vector2i(-1, -3), # 12: Straight
	Vector2i( 0, -3), # 13: Corner -> turns to +Z
	Vector2i( 0, -2), # 14: Straight
	Vector2i( 0, -1), # 15: Straight -> into Finish Line
]

var track_waypoints: Array[Vector3] = []

func _ready() -> void:
	_build_waypoints()
	if vehicle:
		vehicle.input_disabled = true
		_place_vehicle_at_start()

func _build_waypoints() -> void:
	track_waypoints.clear()
	var step := 7.4925

	for cell in TRACK_CELLS:
		if grid_map:
			var local_center = grid_map.map_to_local(Vector3i(cell.x, 0, cell.y))
			track_waypoints.append(grid_map.to_global(local_center))
		else:
			var wx = (float(cell.x) + 0.5) * step
			var wz = (float(cell.y) + 0.5) * step
			track_waypoints.append(Vector3(wx, 0.0, wz))

func _place_vehicle_at_start() -> void:
	if not vehicle:
		return
	var start_pos = Vector3(3.5, 0.0, 4.0)
	var forward = Vector3(0.0, 0.0, 1.0)
	vehicle.respawn_to(start_pos, forward)

func show_main_menu() -> void:
	current_state = GameState.MENU
	race_state_changed.emit(current_state)
	if vehicle:
		vehicle.input_disabled = true
		_place_vehicle_at_start()
	is_wrong_way = false
	wrong_way_toggled.emit(false)

func start_race_countdown() -> void:
	current_state = GameState.COUNTDOWN
	race_state_changed.emit(current_state)

	_place_vehicle_at_start()
	if vehicle:
		vehicle.input_disabled = true

	current_lap = 1
	race_time = 0.0
	current_segment = 0
	checkpoint_progress = 0
	is_wrong_way = false
	wrong_way_timer = 0.0
	wrong_way_toggled.emit(false)
	lap_updated.emit(current_lap, total_laps)

	_run_countdown_sequence()

func _run_countdown_sequence() -> void:
	# "3"
	countdown_tick.emit("3")
	if sound_effects:
		sound_effects.play_countdown_beep(false)
	await get_tree().create_timer(0.85).timeout

	# "2"
	countdown_tick.emit("2")
	if sound_effects:
		sound_effects.play_countdown_beep(false)
	await get_tree().create_timer(0.85).timeout

	# "1"
	countdown_tick.emit("1")
	if sound_effects:
		sound_effects.play_countdown_beep(false)
	await get_tree().create_timer(0.85).timeout

	# "LOS! 🏁"
	countdown_tick.emit("LOS! 🏁")
	if sound_effects:
		sound_effects.play_countdown_beep(true)

	current_state = GameState.RACING
	race_state_changed.emit(current_state)
	if vehicle:
		vehicle.input_disabled = false

	await get_tree().create_timer(0.9).timeout
	countdown_tick.emit("")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("respawn"):
		respawn_vehicle()

func _physics_process(delta: float) -> void:
	# Respawn if vehicle falls off world in any state
	if vehicle and vehicle.global_position.y < -4.0:
		respawn_vehicle()

	if current_state != GameState.RACING:
		return

	race_time += delta
	_update_track_progress(delta)

func _update_track_progress(delta: float) -> void:
	if not vehicle or track_waypoints.is_empty():
		return

	var car_pos = vehicle.global_position
	var n = track_waypoints.size()

	# Find closest track segment
	var best_dist := 1e9
	var best_seg := 0

	for i in range(n):
		var p0 = track_waypoints[i]
		var p1 = track_waypoints[(i + 1) % n]
		var seg_v = p1 - p0
		var seg_len_sq = seg_v.x * seg_v.x + seg_v.z * seg_v.z
		if seg_len_sq < 0.001:
			continue

		var to_car = car_pos - p0
		var t = clampf((to_car.x * seg_v.x + to_car.z * seg_v.z) / seg_len_sq, 0.0, 1.0)
		var proj = p0 + seg_v * t
		var d = Vector2(car_pos.x - proj.x, car_pos.z - proj.z).length()

		if d < best_dist:
			best_dist = d
			best_seg = i

	current_segment = best_seg

	# Sequential Checkpoint Progress to prevent cutting or reversing
	if current_segment >= 1 and current_segment <= 4:
		if checkpoint_progress == 0:
			checkpoint_progress = 1
	elif current_segment >= 5 and current_segment <= 8:
		if checkpoint_progress == 1:
			checkpoint_progress = 2
	elif current_segment >= 9 and current_segment <= 12:
		if checkpoint_progress == 2:
			checkpoint_progress = 3
	elif current_segment >= 13 and current_segment <= 15:
		if checkpoint_progress == 3:
			checkpoint_progress = 4
	elif current_segment == 0:
		if checkpoint_progress == 4:
			# Completed full circuit!
			current_lap += 1
			checkpoint_progress = 0

			if current_lap > total_laps:
				_finish_race()
				return
			else:
				lap_updated.emit(current_lap, total_laps)
				if sound_effects:
					sound_effects.play_lap_chime()

	# Wrong Way Detection
	var p0 = track_waypoints[current_segment]
	var p1 = track_waypoints[(current_segment + 1) % n]
	var seg_dir = Vector3(p1.x - p0.x, 0.0, p1.z - p0.z).normalized()

	var car_fwd = vehicle.vehicle_model.global_basis.z
	car_fwd.y = 0.0
	car_fwd = car_fwd.normalized()

	var dot = car_fwd.dot(seg_dir)

	# If moving fast backward, consider velocity direction
	var vel = vehicle.linear_velocity
	var vel_2d = Vector3(vel.x, 0.0, vel.z)
	if vel_2d.length() > 1.2:
		var move_dot = vel_2d.normalized().dot(seg_dir)
		if move_dot < -0.3:
			dot = minf(dot, move_dot)

	if dot < -0.2:
		wrong_way_timer += delta
		if wrong_way_timer > 0.25:
			if not is_wrong_way:
				is_wrong_way = true
				wrong_way_toggled.emit(true)
				if sound_effects:
					sound_effects.play_wrong_way_alert()
	elif dot > 0.1:
		wrong_way_timer = 0.0
		if is_wrong_way:
			is_wrong_way = false
			wrong_way_toggled.emit(false)

func respawn_vehicle() -> void:
	if not vehicle or track_waypoints.is_empty():
		return

	var n = track_waypoints.size()
	var p0 = track_waypoints[current_segment]
	var p1 = track_waypoints[(current_segment + 1) % n]
	var seg_dir = (p1 - p0).normalized()
	var center_pos = (p0 + p1) * 0.5 + Vector3(0.0, 0.35, 0.0)

	vehicle.respawn_to(center_pos, seg_dir)

	is_wrong_way = false
	wrong_way_timer = 0.0
	wrong_way_toggled.emit(false)

func _finish_race() -> void:
	current_state = GameState.FINISHED
	race_state_changed.emit(current_state)

	if vehicle:
		vehicle.input_disabled = true

	is_wrong_way = false
	wrong_way_toggled.emit(false)

	race_finished.emit(race_time)

	var payload = {
		"laps": total_laps,
		"time": race_time,
		"time_formatted": format_time(race_time),
		"success": true
	}
	race_reward_completed.emit(payload)

	if sound_effects:
		sound_effects.play_victory()

	# Web iframe / Lernapp message bridge
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
			if (window.parent && window.parent.postMessage) {
				window.parent.postMessage({
					type: 'KENNY_RACING_COMPLETED',
					laps: %d,
					time: %f,
					success: true
				}, '*');
			}
		""" % [total_laps, race_time])

func format_time(seconds: float) -> String:
	var total_secs := int(seconds)
	var mins := total_secs / 60
	var secs := total_secs % 60
	var centis := int((seconds - float(total_secs)) * 100)
	return "%02d:%02d.%02d" % [mins, secs, centis]
