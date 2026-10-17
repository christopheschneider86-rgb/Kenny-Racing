class_name RaceManager extends Node

# Race Manager for Kenny Racing:
# - Track cell coverage and finish line crossing math ported from mrdoob/Starter-Kit-Racing (LapTimer.js)
# - Robust Lap Progression with required cell coverage anti-cheat (>= 70%)
# - Forward plane projection crossing detection with lateral road boundary checks
# - Lap timing and Personal Best record tracking (saved to user://records.cfg)
# - Respawn / Reset handler aligning vehicle with closest road tile
# - Integration bridge for learning apps (postMessage / reward signal)

signal race_state_changed(state: int)
signal countdown_tick(text: String)
signal lap_updated(current_lap: int, total_laps: int, best_lap_time: float)
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

# Finish line plane math (direct from mrdoob/Starter-Kit-Racing LapTimer.js)
var line_center: Vector3 = Vector3(3.74625, 0.0, 3.74625)
var line_forward: Vector3 = Vector3(0.0, 0.0, 1.0)
var line_right: Vector3 = Vector3(1.0, 0.0, 0.0)
var prev_forward_proj: float = 0.0
var prev_forward_proj_valid: bool = false

# Grid / Cell settings (CELL_RAW = 9.99, GRID_SCALE = 0.75 -> 7.4925m)
const CELL_RAW: float = 9.99
const GRID_SCALE: float = 0.75
var cell_size: float = CELL_RAW * GRID_SCALE # 7.4925

# Cell tracking for full circuit completion (anti-cheat + curves/corner-cutting support)
var required_cells: Dictionary = {} # Vector2i -> bool
var visited_cells: Dictionary = {}  # Vector2i -> bool

# Vehicle spawn configuration
var start_pos: Vector3 = Vector3(3.74625, 0.0, 4.95)
var start_fwd: Vector3 = Vector3(0.0, 0.0, 1.0)

# Track waypoints for fallback and segment tracking
var track_waypoints: Array[Vector3] = []
var current_segment: int = 0

# Godot GridMap orientation to degrees (matches mrdoob ORIENT_DEG)
const ORIENT_DEG: Dictionary = { 0: 0, 10: 180, 16: 90, 22: 270 }

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

const RECORDS_PATH = "user://records.cfg"

func _ready() -> void:
	best_lap_time = _load_best_lap()
	_rebuild_track_data()
	if vehicle:
		vehicle.input_disabled = true
		_place_vehicle_at_start()

func _load_best_lap() -> float:
	var cfg = ConfigFile.new()
	if cfg.load(RECORDS_PATH) == OK:
		return cfg.get_value("records", "best_lap", 0.0)
	return 0.0

func _save_best_lap(time_val: float) -> void:
	var cfg = ConfigFile.new()
	cfg.load(RECORDS_PATH)
	cfg.set_value("records", "best_lap", time_val)
	cfg.save(RECORDS_PATH)

func _rebuild_track_data() -> void:
	required_cells.clear()
	visited_cells.clear()
	track_waypoints.clear()

	var finish_found := false
	var finish_world_center := Vector3(3.74625, 0.0, 3.74625)
	var finish_orient := 0

	# Mesh Library IDs: 3 = corner, 4 = finish, 5 = ramp, 6 = straight
	const TRACK_ITEMS = [3, 4, 5, 6]

	if grid_map:
		for cell in grid_map.get_used_cells():
			var item = grid_map.get_cell_item(cell)
			if item in TRACK_ITEMS:
				var cell_2d = Vector2i(cell.x, cell.z)
				if item == 4: # track-finish
					finish_found = true
					finish_orient = grid_map.get_cell_item_orientation(cell)
					var loc = grid_map.map_to_local(cell)
					finish_world_center = grid_map.to_global(loc)
					finish_world_center.y = 0.0
				else:
					required_cells[cell_2d] = true

				var loc = grid_map.map_to_local(cell)
				var wp = grid_map.to_global(loc)
				wp.y = 0.0
				track_waypoints.append(wp)

	if not finish_found:
		# Fallback to default circuit
		for c in TRACK_CELLS:
			if c != Vector2i(0, 0):
				required_cells[c] = true
			var wx = (float(c.x) + 0.5) * cell_size
			var wz = (float(c.y) + 0.5) * cell_size
			track_waypoints.append(Vector3(wx, 0.0, wz))
		finish_world_center = Vector3(3.74625, 0.0, 3.74625)
		finish_orient = 0

	# Compute finish line vectors according to mrdoob's LapTimer.js
	var deg: float = float(ORIENT_DEG.get(finish_orient, 0))
	var rad: float = deg_to_rad(deg)

	line_center = finish_world_center
	line_forward = Vector3(sin(rad), 0.0, cos(rad)).normalized()
	line_right = Vector3(line_forward.z, 0.0, -line_forward.x).normalized()

	# Spawn slightly ahead of line center facing forward down the track
	start_pos = line_center + line_forward * 1.25
	start_fwd = line_forward

func _place_vehicle_at_start() -> void:
	if not vehicle:
		return
	vehicle.respawn_to(start_pos, start_fwd)
	prev_forward_proj_valid = false

func _get_forward_from_orientation(orient: int) -> Vector3:
	var deg: float = float(ORIENT_DEG.get(orient, 0))
	var rad: float = deg_to_rad(deg)
	return Vector3(sin(rad), 0.0, cos(rad)).normalized()

func show_main_menu() -> void:
	current_state = GameState.MENU
	race_state_changed.emit(current_state)
	if vehicle:
		vehicle.input_disabled = true
		_place_vehicle_at_start()

func start_race_countdown() -> void:
	current_state = GameState.COUNTDOWN
	race_state_changed.emit(current_state)

	_rebuild_track_data()
	_place_vehicle_at_start()
	if vehicle:
		vehicle.input_disabled = true

	current_lap = 1
	race_time = 0.0
	lap_start_time = 0.0
	lap_times.clear()
	visited_cells.clear()
	current_segment = 0
	prev_forward_proj_valid = false

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
	lap_start_time = 0.0
	race_time = 0.0
	if vehicle:
		vehicle.input_disabled = false

	# Initialize projection at spawn (positive, ahead of line)
	if vehicle:
		var offset = _get_car_position() - line_center
		prev_forward_proj = offset.dot(line_forward)
		prev_forward_proj_valid = true

	visited_cells.clear()

	await get_tree().create_timer(0.9).timeout
	countdown_tick.emit("")

func _get_car_position() -> Vector3:
	if not vehicle:
		return Vector3.ZERO
	if vehicle.has_method("get_car_position"):
		return vehicle.get_car_position()
	if vehicle.has_method("get_vehicle_position"):
		return vehicle.get_vehicle_position()
	var v_model = vehicle.get_node_or_null("Container")
	if v_model:
		return v_model.global_position
	var sp = vehicle.get_node_or_null("Sphere")
	if sp:
		return sp.global_position
	return vehicle.global_position

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("respawn"):
		respawn_vehicle()

func _physics_process(delta: float) -> void:
	# Respawn if vehicle falls off world in any state
	if vehicle and _get_car_position().y < -4.0:
		respawn_vehicle()

	if current_state != GameState.RACING:
		return

	race_time += delta
	_update_track_progress(delta)

func _update_track_progress(_delta: float) -> void:
	if not vehicle:
		return

	var car_pos: Vector3 = _get_car_position()

	# 1. Track cell coverage (anti-cheat & full circuit completion)
	var gx: int
	var gz: int
	if grid_map:
		var local_pos = grid_map.to_local(car_pos)
		var map_cell = grid_map.local_to_map(local_pos)
		gx = map_cell.x
		gz = map_cell.z
	else:
		gx = int(floorf(car_pos.x / cell_size))
		gz = int(floorf(car_pos.z / cell_size))

	var cell_key := Vector2i(gx, gz)
	if required_cells.has(cell_key):
		visited_cells[cell_key] = true

	# 2. Finish Line Plane Crossing Math (ported from mrdoob/Starter-Kit-Racing LapTimer.js)
	var offset := car_pos - line_center
	var forward_proj := offset.dot(line_forward)
	var lateral_proj := absf(offset.dot(line_right))

	if prev_forward_proj_valid:
		# Within track width (cell_size * 0.75 is ~5.6m, giving generous track boundary leeway)
		var on_line := lateral_proj <= (cell_size * 0.75)
		# No teleport or respawn jumps
		var no_teleport := absf(forward_proj - prev_forward_proj) < 6.0
		# Crossed line in forward direction (from behind line to ahead of line)
		var crossed_forward := (prev_forward_proj < 0.0 and forward_proj >= 0.0)

		if on_line and no_teleport and crossed_forward:
			var req_count := max(1, required_cells.size())
			var coverage := float(visited_cells.size()) / float(req_count)
			var lap_duration := race_time - lap_start_time

			# At least 70% of circuit cells visited (anti-cheat + allows corner-cutting / drifting)
			if coverage >= 0.70 and lap_duration > 2.0:
				_complete_lap(lap_duration)
			visited_cells.clear()

	prev_forward_proj = forward_proj
	prev_forward_proj_valid = true

func _complete_lap(lap_duration: float) -> void:
	lap_times.append(lap_duration)
	if best_lap_time <= 0.0 or lap_duration < best_lap_time:
		best_lap_time = lap_duration
		_save_best_lap(best_lap_time)

	lap_start_time = race_time
	current_lap += 1

	if current_lap > total_laps:
		_finish_race()
	else:
		lap_updated.emit(current_lap, total_laps, best_lap_time)
		if sound_effects:
			sound_effects.play_lap_chime()

func respawn_vehicle() -> void:
	if not vehicle:
		return

	prev_forward_proj_valid = false

	var car_pos := _get_car_position()
	var best_cell_center := start_pos
	var best_cell_dir := start_fwd
	var best_dist := 1e9

	# Find closest track tile
	if grid_map:
		const TRACK_ITEMS = [3, 4, 5, 6]
		for cell in grid_map.get_used_cells():
			var item = grid_map.get_cell_item(cell)
			if item in TRACK_ITEMS:
				var loc = grid_map.map_to_local(cell)
				var world_pos = grid_map.to_global(loc)
				world_pos.y = 0.0
				var d = Vector2(car_pos.x - world_pos.x, car_pos.z - world_pos.z).length()
				if d < best_dist:
					best_dist = d
					best_cell_center = world_pos
					var orient = grid_map.get_cell_item_orientation(cell)
					best_cell_dir = _get_forward_from_orientation(orient)
	elif not track_waypoints.is_empty():
		for wp in track_waypoints:
			var d = Vector2(car_pos.x - wp.x, car_pos.z - wp.z).length()
			if d < best_dist:
				best_dist = d
				best_cell_center = wp
				best_cell_dir = start_fwd

	vehicle.respawn_to(best_cell_center + Vector3(0.0, 0.35, 0.0), best_cell_dir)

func _finish_race() -> void:
	current_state = GameState.FINISHED
	race_state_changed.emit(current_state)

	if vehicle:
		vehicle.input_disabled = true

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
