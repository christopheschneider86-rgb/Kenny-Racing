class_name RaceManager extends Node

# Race Manager for Kenny Racing:
# - Track waypoint and segment math
# - Forward-only Lap progression with halfway checkpoint anti-cheat
# - Best lap timing and lap history
# - Real-time Wrong Way detection (aligned with Kenney +Z car front)
# - Respawn / Reset handler
# - Integration bridge for learning apps (postMessage / reward signal)

signal race_state_changed(state: int)
signal countdown_tick(text: String)
signal lap_updated(current_lap: int, total_laps: int, best_lap_time: float)
signal wrong_way_toggled(is_wrong: bool)
signal race_finished(total_time: float, best_lap: float)
signal race_reward_completed(data: Dictionary)

enum GameState { MENU = 0, COUNTDOWN = 1, RACING = 2, FINISHED = 3 }

@export var vehicle: Node3D
@export var grid_map: GridMap
@export var sound_effects: Node
@export var total_laps: int = 4

var current_state: GameState = GameState.MENU
var current_lap: int = 1
var race_time: float = 0.0
var lap_start_time: float = 0.0
var best_lap_time: float = 0.0
var lap_times: Array[float] = []

var start_pos: Vector3 = Vector3(3.75, 0.0, 3.75)
var start_fwd: Vector3 = Vector3(0.0, 0.0, 1.0)
var halfway_checkpoint_pos: Vector3 = Vector3(-11.25, 0.0, -11.25)
var passed_halfway: bool = false
var prev_dist_to_finish_plane: float = 0.0

var current_segment: int = 0
var is_wrong_way: bool = false
var wrong_way_timer: float = 0.0

# 16 connected track cells that form the default circuit
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

func _find_start_tile() -> void:
	start_pos = Vector3(3.75, 0.0, 3.75)
	start_fwd = Vector3(0.0, 0.0, 1.0)

	if grid_map:
		for cell in grid_map.get_used_cells():
			if grid_map.get_cell_item(cell) == 4: # track-finish
				var loc = grid_map.map_to_local(cell)
				start_pos = grid_map.to_global(loc)
				start_pos.y = 0.0
				var orient = grid_map.get_cell_item_orientation(cell)
				start_fwd = _get_forward_from_orientation(orient)
				break

func _build_waypoints() -> void:
	track_waypoints.clear()
	_find_start_tile()

	var step := 7.4925
	for cell in TRACK_CELLS:
		if grid_map:
			var local_center = grid_map.map_to_local(Vector3i(cell.x, 0, cell.y))
			track_waypoints.append(grid_map.to_global(local_center))
		else:
			var wx = (float(cell.x) + 0.5) * step
			var wz = (float(cell.y) + 0.5) * step
			track_waypoints.append(Vector3(wx, 0.0, wz))

	# Find the halfway point farthest from start_pos
	var max_dist := 0.0
	var best_halfway = start_pos
	for wp in track_waypoints:
		var d = (wp - start_pos).length()
		if d > max_dist:
			max_dist = d
			best_halfway = wp
	halfway_checkpoint_pos = best_halfway

func _place_vehicle_at_start() -> void:
	if not vehicle:
		return
	_find_start_tile()
	vehicle.respawn_to(start_pos, start_fwd)
	prev_dist_to_finish_plane = 0.0

func _get_forward_from_orientation(orient: int) -> Vector3:
	match orient:
		0: return Vector3(0.0, 0.0, 1.0)
		16: return Vector3(-1.0, 0.0, 0.0)
		10: return Vector3(0.0, 0.0, -1.0)
		22: return Vector3(1.0, 0.0, 0.0)
		_: return Vector3(0.0, 0.0, 1.0)

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

	_build_waypoints()
	_place_vehicle_at_start()
	if vehicle:
		vehicle.input_disabled = true

	current_lap = 1
	race_time = 0.0
	lap_start_time = 0.0
	best_lap_time = 0.0
	lap_times.clear()
	passed_halfway = false
	current_segment = 0
	is_wrong_way = false
	wrong_way_timer = 0.0
	wrong_way_toggled.emit(false)
	lap_updated.emit(current_lap, total_laps, best_lap_time)

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

	# "LOS!"
	countdown_tick.emit("LOS!")
	if sound_effects:
		sound_effects.play_countdown_beep(true)

	current_state = GameState.RACING
	race_state_changed.emit(current_state)
	lap_start_time = race_time
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

	# 1. HALFWAY CHECKPOINT DETECTION
	# Vehicle must reach halfway through the track before a lap can be registered
	var dist_to_halfway = Vector2(car_pos.x - halfway_checkpoint_pos.x, car_pos.z - halfway_checkpoint_pos.z).length()
	var seg_halfway = (current_segment >= n / 3 and current_segment <= (2 * n) / 3)
	if dist_to_halfway < 10.0 or seg_halfway:
		passed_halfway = true

	# 2. FORWARD-ONLY LAP COMPLETION AT FINISH LINE
	var to_car = car_pos - start_pos
	to_car.y = 0.0
	var dist_along_fwd = to_car.dot(start_fwd)
	var lat_vec = to_car - start_fwd * dist_along_fwd
	var lat_dist = lat_vec.length()

	# Kenney vehicle model front is at local +Z
	var car_fwd = vehicle.vehicle_model.global_basis.z
	car_fwd.y = 0.0
	car_fwd = car_fwd.normalized()

	var is_facing_fwd = car_fwd.dot(start_fwd) > 0.15
	var vel_2d = Vector3(vehicle.linear_velocity.x, 0.0, vehicle.linear_velocity.z)
	var is_moving_fwd = vel_2d.dot(start_fwd) > -0.2

	# Legitimate lap completion criteria:
	# - Has reached halfway checkpoint (cannot drive back & forth across start line)
	# - Crossing within the width of the finish line road tile (lat_dist < 6.5)
	# - Facing and moving forward across the finish line plane
	if passed_halfway and lat_dist < 6.5 and is_facing_fwd and is_moving_fwd:
		if prev_dist_to_finish_plane <= 0.8 and dist_along_fwd > 0.0 and dist_along_fwd < 4.5:
			var lap_duration = race_time - lap_start_time
			if lap_duration > 4.0: # Minimum lap duration sanity filter
				lap_times.append(lap_duration)
				if best_lap_time <= 0.0 or lap_duration < best_lap_time:
					best_lap_time = lap_duration

				lap_start_time = race_time
				passed_halfway = false
				current_lap += 1

				if current_lap > total_laps:
					_finish_race()
					return
				else:
					lap_updated.emit(current_lap, total_laps, best_lap_time)
					if sound_effects:
						sound_effects.play_lap_chime()

	prev_dist_to_finish_plane = dist_along_fwd

	# 3. WRONG WAY DETECTION
	var p0 = track_waypoints[current_segment]
	var p1 = track_waypoints[(current_segment + 1) % n]
	var seg_dir = Vector3(p1.x - p0.x, 0.0, p1.z - p0.z).normalized()

	var dot = car_fwd.dot(seg_dir)

	if vel_2d.length() > 1.2:
		var move_dot = vel_2d.normalized().dot(seg_dir)
		dot = (dot + move_dot) * 0.5

	# Only alert if facing/moving opposite to track direction for > 0.65s
	if dot < -0.35:
		wrong_way_timer += delta
		if wrong_way_timer > 0.65:
			if not is_wrong_way:
				is_wrong_way = true
				wrong_way_toggled.emit(true)
				if sound_effects:
					sound_effects.play_wrong_way_alert()
	elif dot > 0.0:
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

	race_finished.emit(race_time, best_lap_time)

	var payload = {
		"laps": total_laps,
		"time": race_time,
		"time_formatted": format_time(race_time),
		"best_lap": best_lap_time,
		"best_lap_formatted": format_time(best_lap_time) if best_lap_time > 0.0 else "--:--.--",
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
					best_lap: %f,
					success: true
				}, '*');
			}
		""" % [total_laps, race_time, best_lap_time])

func format_time(seconds: float) -> String:
	var total_secs := int(seconds)
	var mins := total_secs / 60
	var secs := total_secs % 60
	var centis := int((seconds - float(total_secs)) * 100)
	return "%02d:%02d.%02d" % [mins, secs, centis]
