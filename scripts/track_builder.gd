class_name TrackBuilder extends Node

# Track Builder for Kenny Racing (Ported from mrdoob/Starter-Kit-Racing editor.html)
# - Interactive Auto-Tiling: placing road connects seamlessly with corners and straights
# - Finish Line Protection: (0, 0) cannot be erased; clicking it flips direction by 180°
# - Erase tool with neighbor auto-updating
# - Thematic Props placement matching the chosen World
# - Integration with TrackManager slots (Slot 1..3 persistence)
# - 1-Click Test Drive

signal tool_changed(tool_type: String, item_id: int, prop_name: String)
signal orientation_changed(angle_deg: int)
signal world_theme_changed(world_id: String)
signal builder_mode_toggled(is_active: bool)

enum ToolType { ROAD, PROP, ERASE }

@export var grid_map: GridMap
@export var view_node: Node3D
@export var race_manager: RaceManager
@export var track_manager: TrackManager
@export var vehicle: Vehicle
@export var sound_effects: Node

var is_active: bool = false

# Current selection
var current_tool_type: ToolType = ToolType.ROAD
var current_road_item: int = 6 # Default: Straight (item 6)
var current_prop_path: String = ""
var current_prop_name: String = ""

# Orientations for GridMap (orthogonal basis indexes for 0, 90, 180, 270 deg)
const ORIENTATIONS: Array[int] = [0, 16, 10, 22]
const ORIENT_ANGLES: Array[float] = [0.0, PI / 2.0, PI, 3.0 * PI / 2.0]
const ORIENT_DEGREES: Array[int] = [0, 90, 180, 270]
const ORIENT_FLIP: Dictionary = { 0: 10, 10: 0, 16: 22, 22: 16 }
var current_rot_idx: int = 0

# Auto-tile mapping: Bitmask N=8, S=4, E=2, W=1 (exact table from mrdoob editor.html)
# Items in mesh-library: 3 = corner, 4 = finish, 6 = straight
const AUTOTILE_TABLE: Array[Dictionary] = [
	{"item": 6, "orient": 0},   #  0: isolated
	{"item": 6, "orient": 16},  #  1: W
	{"item": 6, "orient": 16},  #  2: E
	{"item": 6, "orient": 16},  #  3: E+W
	{"item": 6, "orient": 0},   #  4: S
	{"item": 3, "orient": 0},   #  5: S+W
	{"item": 3, "orient": 16},  #  6: S+E
	{"item": 6, "orient": 16},  #  7: S+E+W
	{"item": 6, "orient": 0},   #  8: N
	{"item": 3, "orient": 22},  #  9: N+W
	{"item": 3, "orient": 10},  # 10: N+E
	{"item": 6, "orient": 16},  # 11: N+E+W
	{"item": 6, "orient": 0},   # 12: N+S
	{"item": 6, "orient": 0},   # 13: N+S+W
	{"item": 6, "orient": 0},   # 14: N+S+E
	{"item": 6, "orient": 0},   # 15: N+S+E+W
]

# Cache of initial default track cells for 1-click restore
var initial_cells: Dictionary = {}

# Node container for custom placed props
var custom_props_root: Node3D
# Map of Vector2i(x, z) -> Node3D for placed custom props
var placed_props_map: Dictionary = {}

# Visual 3D Cursor & Ghost Preview
var cursor_root: Node3D
var cursor_box_mesh: MeshInstance3D
var ghost_preview: Node3D

# Interaction state
var hovered_grid_cell: Vector2i = Vector2i(9999, 9999)
var is_pointer_down: bool = false
var pointer_down_pos: Vector2 = Vector2.ZERO
var is_dragging_view: bool = false
var is_mouse_over_ui: bool = false

func _ready() -> void:
	_resolve_dependencies()
	_create_custom_props_root()
	_create_3d_cursor()
	_cache_initial_track()

func _resolve_dependencies() -> void:
	if not grid_map:
		grid_map = get_node_or_null("../GridMap")
	if not view_node:
		view_node = get_node_or_null("../View")
	if not race_manager:
		race_manager = get_node_or_null("../RaceManager")
	if not track_manager:
		track_manager = get_node_or_null("../TrackManager")
	if not vehicle:
		vehicle = get_node_or_null("../Vehicle")
	if not sound_effects:
		sound_effects = get_node_or_null("../SoundEffects")

func _create_custom_props_root() -> void:
	custom_props_root = Node3D.new()
	custom_props_root.name = "CustomPlacedProps"
	add_child(custom_props_root)

func _cache_initial_track() -> void:
	if not grid_map:
		return
	initial_cells.clear()
	for cell in grid_map.get_used_cells():
		initial_cells[cell] = {
			"item": grid_map.get_cell_item(cell),
			"orientation": grid_map.get_cell_item_orientation(cell)
		}

func _create_3d_cursor() -> void:
	cursor_root = Node3D.new()
	cursor_root.name = "Builder3DCursor"
	cursor_root.visible = false
	add_child(cursor_root)

	# Subtle glowing frame on ground
	cursor_box_mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(7.4925, 0.12, 7.4925)
	cursor_box_mesh.mesh = box

	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 0.7, 1.0, 0.35)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cursor_box_mesh.material_override = mat
	cursor_root.add_child(cursor_box_mesh)

	# Ghost model container
	ghost_preview = Node3D.new()
	ghost_preview.name = "GhostPreview"
	cursor_root.add_child(ghost_preview)

func open_builder() -> void:
	is_active = true
	cursor_root.visible = true
	if view_node and view_node.has_method("set_builder_mode"):
		view_node.set_builder_mode(true)
	if vehicle:
		vehicle.input_disabled = true
	_update_ghost_preview()
	builder_mode_toggled.emit(true)

func close_builder() -> void:
	_save_to_active_slot()
	is_active = false
	cursor_root.visible = false
	if view_node and view_node.has_method("set_builder_mode"):
		view_node.set_builder_mode(false)
	builder_mode_toggled.emit(false)

func _save_to_active_slot() -> void:
	if track_manager and track_manager.active_slot_idx > 0:
		track_manager.save_current_grid_to_slot(track_manager.active_slot_idx)

# ==============================================================================
# TOOL ACTIONS
# ==============================================================================

func select_road_item(item_id: int) -> void:
	current_tool_type = ToolType.ROAD
	current_road_item = item_id
	current_prop_path = ""
	current_prop_name = ""
	_update_cursor_color(Color(0.2, 0.7, 1.0, 0.35))
	_update_ghost_preview()
	var road_name := "Straße (Auto-Tile)" if item_id == 6 else ("Spezial-Straße #%d" % item_id)
	tool_changed.emit("road", item_id, road_name)

func select_prop_item(prop_path: String, prop_title: String) -> void:
	current_tool_type = ToolType.PROP
	current_prop_path = prop_path
	current_prop_name = prop_title
	_update_cursor_color(Color(0.3, 1.0, 0.4, 0.35))
	_update_ghost_preview()
	tool_changed.emit("prop", 0, prop_title)

func select_erase_tool() -> void:
	current_tool_type = ToolType.ERASE
	current_prop_path = ""
	current_prop_name = ""
	_update_cursor_color(Color(1.0, 0.2, 0.2, 0.45))
	_update_ghost_preview()
	tool_changed.emit("erase", -1, "Radiergummi (Löschen)")

func rotate_piece() -> void:
	current_rot_idx = (current_rot_idx + 1) % 4
	orientation_changed.emit(ORIENT_DEGREES[current_rot_idx])
	_update_ghost_preview()
	if sound_effects and sound_effects.has_method("play_button_click"):
		sound_effects.play_button_click()

func restore_default_track() -> void:
	if track_manager:
		track_manager.apply_slot(0)
	if sound_effects and sound_effects.has_method("play_checkpoint_beep"):
		sound_effects.play_checkpoint_beep()

func clear_all() -> void:
	if track_manager and track_manager.active_slot_idx > 0:
		track_manager.clear_slot(track_manager.active_slot_idx)
	elif grid_map:
		const ROAD_ITEMS = [3, 4, 5, 6]
		for c in grid_map.get_used_cells():
			if grid_map.get_cell_item(c) in ROAD_ITEMS:
				grid_map.set_cell_item(c, -1)
		# Preserve finish line at (0, 0)
		grid_map.set_cell_item(Vector3i(0, 0, 0), 4, 0)

	for k in placed_props_map:
		var node = placed_props_map[k]
		if is_instance_valid(node):
			node.queue_free()
	placed_props_map.clear()

	if sound_effects and sound_effects.has_method("play_button_click"):
		sound_effects.play_button_click()

func start_test_drive() -> void:
	_save_to_active_slot()
	close_builder()

	if race_manager:
		race_manager.start_race_countdown()

# ==============================================================================
# INPUT & POINTER PROCESSING
# ==============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return

	# Shortcut 'R' for manual rotation
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			rotate_piece()
			return

	# Mouse / Touch movement -> update hover
	if event is InputEventMouseMotion:
		_process_hover(event.position)
		if is_pointer_down and (event.position - pointer_down_pos).length() > 14.0:
			is_dragging_view = true
			if view_node and view_node.has_method("pan_builder"):
				var pan_dir = Vector3(-event.relative.x, 0.0, -event.relative.y) * 0.04
				view_node.pan_builder(pan_dir)

	# Mouse Button Click
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_pointer_down = true
				pointer_down_pos = event.position
				is_dragging_view = false
			else:
				if not is_dragging_view and not is_mouse_over_ui:
					_apply_placement(hovered_grid_cell)
				is_pointer_down = false
				is_dragging_view = false

		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if view_node and view_node.has_method("zoom_builder"):
				view_node.zoom_builder(-2.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if view_node and view_node.has_method("zoom_builder"):
				view_node.zoom_builder(2.5)

	# Touch screen gestures
	elif event is InputEventScreenTouch:
		if event.pressed:
			is_pointer_down = true
			pointer_down_pos = event.position
			is_dragging_view = false
			_process_hover(event.position)
		else:
			if not is_dragging_view and not is_mouse_over_ui:
				_apply_placement(hovered_grid_cell)
			is_pointer_down = false
			is_dragging_view = false

	elif event is InputEventScreenDrag:
		_process_hover(event.position)
		if (event.position - pointer_down_pos).length() > 12.0:
			is_dragging_view = true
			if view_node and view_node.has_method("pan_builder"):
				var pan_dir = Vector3(-event.relative.x, 0.0, -event.relative.y) * 0.04
				view_node.pan_builder(pan_dir)

func _process_hover(screen_pos: Vector2) -> void:
	if not grid_map:
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if not cam:
		return

	var ray_origin = cam.project_ray_origin(screen_pos)
	var ray_normal = cam.project_ray_normal(screen_pos)
	var plane = Plane(Vector3.UP, 0.0)
	var hit = plane.intersects_ray(ray_origin, ray_normal)
	if hit == null:
		return

	var local_hit = grid_map.to_local(hit)
	var map_cell = grid_map.local_to_map(local_hit)
	hovered_grid_cell = Vector2i(map_cell.x, map_cell.z)

	var cell_center_local = grid_map.map_to_local(map_cell)
	var cell_center_global = grid_map.to_global(cell_center_local)
	cursor_root.global_position = Vector3(cell_center_global.x, 0.06, cell_center_global.z)

# ==============================================================================
# MRDOOB AUTO-TILING PLACEMENT LOGIC
# ==============================================================================

# Exit bitmask: N=8, S=4, E=2, W=1
func _get_cell_exits(item: int, orient: int) -> int:
	if item == 3: # track-corner
		match orient:
			0: return 5   # S+W
			16: return 6  # S+E
			10: return 10 # N+E
			22: return 9  # N+W
			_: return 5
	# Straight, finish, ramp — symmetric
	if orient == 0 or orient == 10:
		return 12 # N+S
	return 3      # E+W

func _get_connectivity_mask(cell: Vector2i) -> int:
	var mask := 0
	if not grid_map:
		return mask

	# N neighbor (cell.x, cell.y - 1) has S exit (& 4)
	var n_item = grid_map.get_cell_item(Vector3i(cell.x, 0, cell.y - 1))
	if n_item in [3, 4, 5, 6]:
		var n_orient = grid_map.get_cell_item_orientation(Vector3i(cell.x, 0, cell.y - 1))
		if _get_cell_exits(n_item, n_orient) & 4:
			mask |= 8

	# S neighbor (cell.x, cell.y + 1) has N exit (& 8)
	var s_item = grid_map.get_cell_item(Vector3i(cell.x, 0, cell.y + 1))
	if s_item in [3, 4, 5, 6]:
		var s_orient = grid_map.get_cell_item_orientation(Vector3i(cell.x, 0, cell.y + 1))
		if _get_cell_exits(s_item, s_orient) & 8:
			mask |= 4

	# E neighbor (cell.x + 1, cell.y) has W exit (& 1)
	var e_item = grid_map.get_cell_item(Vector3i(cell.x + 1, 0, cell.y))
	if e_item in [3, 4, 5, 6]:
		var e_orient = grid_map.get_cell_item_orientation(Vector3i(cell.x + 1, 0, cell.y))
		if _get_cell_exits(e_item, e_orient) & 1:
			mask |= 2

	# W neighbor (cell.x - 1, cell.y) has E exit (& 2)
	var w_item = grid_map.get_cell_item(Vector3i(cell.x - 1, 0, cell.y))
	if w_item in [3, 4, 5, 6]:
		var w_orient = grid_map.get_cell_item_orientation(Vector3i(cell.x - 1, 0, cell.y))
		if _get_cell_exits(w_item, w_orient) & 2:
			mask |= 1

	return mask

func _get_presence_mask(cell: Vector2i) -> int:
	var mask := 0
	if not grid_map:
		return mask
	const ROAD_ITEMS = [3, 4, 5, 6]
	if grid_map.get_cell_item(Vector3i(cell.x, 0, cell.y - 1)) in ROAD_ITEMS: mask |= 8
	if grid_map.get_cell_item(Vector3i(cell.x, 0, cell.y + 1)) in ROAD_ITEMS: mask |= 4
	if grid_map.get_cell_item(Vector3i(cell.x + 1, 0, cell.y)) in ROAD_ITEMS: mask |= 2
	if grid_map.get_cell_item(Vector3i(cell.x - 1, 0, cell.y)) in ROAD_ITEMS: mask |= 1
	return mask

func _resolve_cell(cell: Vector2i) -> void:
	if not grid_map:
		return
	var cell3 = Vector3i(cell.x, 0, cell.y)
	var cur_item = grid_map.get_cell_item(cell3)
	if cur_item not in [3, 4, 6]:
		return

	# Finish tile keeps its finish identity (item 4)
	if cur_item == 4:
		return

	var mask = _get_connectivity_mask(cell)
	if mask == 0:
		var p_mask = _get_presence_mask(cell)
		if p_mask & 12:
			mask = 12
		elif p_mask & 3:
			mask = 3
		else:
			mask = 0

	var info = AUTOTILE_TABLE[mask]
	grid_map.set_cell_item(cell3, info["item"], info["orient"])

func _resolve_cell_and_neighbors(cell: Vector2i) -> void:
	_resolve_cell(cell)
	_resolve_cell(Vector2i(cell.x, cell.y - 1))
	_resolve_cell(Vector2i(cell.x, cell.y + 1))
	_resolve_cell(Vector2i(cell.x + 1, cell.y))
	_resolve_cell(Vector2i(cell.x - 1, cell.y))

func _apply_placement(cell: Vector2i) -> void:
	if not grid_map:
		return
	if cell.x > 5000 or cell.x < -5000:
		return

	var cell3 = Vector3i(cell.x, 0, cell.y)
	var existing_item = grid_map.get_cell_item(cell3)

	if current_tool_type == ToolType.ROAD:
		_remove_prop_at(cell)

		# Finish Line Click -> 180° Flip direction (mrdoob editor feature)
		if existing_item == 4:
			var cur_orient = grid_map.get_cell_item_orientation(cell3)
			var flipped = ORIENT_FLIP.get(cur_orient, cur_orient)
			grid_map.set_cell_item(cell3, 4, flipped)
			if sound_effects and sound_effects.has_method("play_button_click"):
				sound_effects.play_button_click()
			return

		# Ramp or specific items placed with manual rotation
		if current_road_item == 5:
			grid_map.set_cell_item(cell3, 5, ORIENTATIONS[current_rot_idx])
		else:
			# Auto-tile road placement
			grid_map.set_cell_item(cell3, 6, 0)
			_resolve_cell_and_neighbors(cell)

		if sound_effects and sound_effects.has_method("play_checkpoint_beep"):
			sound_effects.play_checkpoint_beep()

	elif current_tool_type == ToolType.PROP:
		if current_prop_path != "" and ResourceLoader.exists(current_prop_path):
			_remove_prop_at(cell)
			var scene = load(current_prop_path)
			if scene:
				var prop_instance = scene.instantiate()
				var loc = grid_map.map_to_local(cell3)
				var gpos = grid_map.to_global(loc)
				prop_instance.position = Vector3(gpos.x, 0.0, gpos.z)
				prop_instance.rotation = Vector3(0.0, ORIENT_ANGLES[current_rot_idx], 0.0)
				prop_instance.scale = Vector3(1.0, 1.0, 1.0)
				custom_props_root.add_child(prop_instance)
				placed_props_map[cell] = prop_instance
				if sound_effects and sound_effects.has_method("play_checkpoint_beep"):
					sound_effects.play_checkpoint_beep()

	elif current_tool_type == ToolType.ERASE:
		# Protected Start/Finish Line cannot be erased
		if existing_item == 4:
			return

		_remove_prop_at(cell)
		grid_map.set_cell_item(cell3, GridMap.INVALID_CELL_ITEM)
		_resolve_cell_and_neighbors(cell)
		if sound_effects and sound_effects.has_method("play_button_click"):
			sound_effects.play_button_click()

func _remove_prop_at(cell: Vector2i) -> void:
	if placed_props_map.has(cell):
		var p = placed_props_map[cell]
		if is_instance_valid(p):
			p.queue_free()
		placed_props_map.erase(cell)

# ==============================================================================
# VISUAL HELPERS
# ==============================================================================

func _update_cursor_color(color: Color) -> void:
	if cursor_box_mesh and cursor_box_mesh.material_override:
		var mat = cursor_box_mesh.material_override as StandardMaterial3D
		mat.albedo_color = color

func _update_ghost_preview() -> void:
	for c in ghost_preview.get_children():
		c.queue_free()

	ghost_preview.rotation = Vector3(0.0, ORIENT_ANGLES[current_rot_idx], 0.0)

	if current_tool_type == ToolType.ROAD:
		if grid_map and grid_map.mesh_library:
			var mesh = grid_map.mesh_library.get_item_mesh(current_road_item)
			if mesh:
				var mi = MeshInstance3D.new()
				mi.mesh = mesh
				mi.scale = Vector3(0.75, 0.75, 0.75) # Match GridMap scale
				var mat = StandardMaterial3D.new()
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color = Color(1.0, 1.0, 1.0, 0.6)
				mi.material_override = mat
				ghost_preview.add_child(mi)

	elif current_tool_type == ToolType.PROP:
		if current_prop_path != "" and ResourceLoader.exists(current_prop_path):
			var sc = load(current_prop_path)
			if sc:
				var inst = sc.instantiate()
				inst.scale = Vector3(1.0, 1.0, 1.0)
				ghost_preview.add_child(inst)
