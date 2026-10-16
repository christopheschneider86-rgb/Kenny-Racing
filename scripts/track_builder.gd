class_name TrackBuilder extends Node

# Track Builder for Kenny Racing
# Allows kids and parents to interactively design custom racetracks:
# - Place road tiles (Start/Finish, Straight, Corner, Ramp)
# - Place thematic props matching the selected World
# - Rotate, erase, clear, or restore default circuit
# - Immediate test drive with 1 click

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
var current_rot_idx: int = 0

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
	box.size = Vector3(7.4, 0.08, 7.4)
	cursor_box_mesh.mesh = box

	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 0.8, 1.0, 0.35)
	cursor_box_mesh.material_override = mat
	cursor_root.add_child(cursor_box_mesh)

	ghost_preview = Node3D.new()
	ghost_preview.name = "GhostPreview"
	cursor_root.add_child(ghost_preview)

# ==============================================================================
# PUBLIC CONTROL METHODS
# ==============================================================================

func open_builder() -> void:
	is_active = true
	cursor_root.visible = true
	if view_node and view_node.has_method("set_builder_mode"):
		view_node.set_builder_mode(true)
	if vehicle:
		vehicle.input_disabled = true
	builder_mode_toggled.emit(true)
	_update_ghost_preview()

func close_builder() -> void:
	is_active = false
	cursor_root.visible = false
	if view_node and view_node.has_method("set_builder_mode"):
		view_node.set_builder_mode(false)
	builder_mode_toggled.emit(false)

func select_road_tool(item_id: int) -> void:
	current_tool_type = ToolType.ROAD
	current_road_item = item_id
	current_prop_path = ""
	current_prop_name = ""
	_update_cursor_color(Color(0.2, 0.8, 1.0, 0.35))
	_update_ghost_preview()
	var road_names = {3: "Kurve", 4: "Start / Ziel", 5: "Rampe", 6: "Gerade"}
	tool_changed.emit("road", item_id, road_names.get(item_id, "Straße"))

func select_prop_tool(glb_path: String, prop_title: String) -> void:
	current_tool_type = ToolType.PROP
	current_prop_path = glb_path
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
	if not grid_map:
		return
	clear_all()
	for cell in initial_cells:
		var d = initial_cells[cell]
		grid_map.set_cell_item(cell, d["item"], d["orientation"])
	if track_manager:
		track_manager.set_world(track_manager.active_world_id)
	if sound_effects and sound_effects.has_method("play_checkpoint_beep"):
		sound_effects.play_checkpoint_beep()

func clear_all() -> void:
	if grid_map:
		grid_map.clear()
	for k in placed_props_map:
		var node = placed_props_map[k]
		if is_instance_valid(node):
			node.queue_free()
	placed_props_map.clear()
	if sound_effects and sound_effects.has_method("play_button_click"):
		sound_effects.play_button_click()

func start_test_drive() -> void:
	close_builder()
	# Find Start/Finish tile in grid
	var start_pos = Vector3(3.75, 0.0, 3.75)
	var forward = Vector3(0.0, 0.0, 1.0)

	if grid_map:
		var used = grid_map.get_used_cells()
		for cell in used:
			if grid_map.get_cell_item(cell) == 4: # track-finish
				var loc = grid_map.map_to_local(cell)
				start_pos = grid_map.to_global(loc)
				start_pos.y = 0.0
				var orient = grid_map.get_cell_item_orientation(cell)
				forward = _get_forward_from_orientation(orient)
				break

	if vehicle:
		vehicle.respawn_to(start_pos, forward)
		vehicle.input_disabled = false

	if race_manager:
		race_manager.start_race_countdown()

# ==============================================================================
# INPUT & POINTER PROCESSING
# ==============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return

	# Shortcut 'R' for rotation
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

	# Mouse Button / Touch Click
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

func _apply_placement(cell: Vector2i) -> void:
	if not grid_map:
		return
	if cell.x > 5000 or cell.x < -5000:
		return

	var cell3 = Vector3i(cell.x, 0, cell.y)
	var orient = ORIENTATIONS[current_rot_idx]

	if current_tool_type == ToolType.ROAD:
		# If there was a custom prop here, remove it
		_remove_prop_at(cell)
		grid_map.set_cell_item(cell3, current_road_item, orient)
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
		_remove_prop_at(cell)
		grid_map.set_cell_item(cell3, GridMap.INVALID_CELL_ITEM)
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

func _get_forward_from_orientation(orient: int) -> Vector3:
	match orient:
		0: return Vector3(0.0, 0.0, 1.0)
		16: return Vector3(-1.0, 0.0, 0.0)
		10: return Vector3(0.0, 0.0, -1.0)
		22: return Vector3(1.0, 0.0, 0.0)
		_: return Vector3(0.0, 0.0, 1.0)
