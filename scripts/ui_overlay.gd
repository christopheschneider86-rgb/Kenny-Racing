class_name UIOverlay extends CanvasLayer

# Full In-Game UI Overlay for Kenny Racing
# - Start Screen with:
#   * Vehicle selection: Grundtyp & Farbe with live 3D preview & physics stats
#   * World selection: Wald, Stadion, Rallye
#   * Control mode toggle: Intuitiv / Klassisch
#   * Streckenbauer with dedicated Back button
# - Touch Virtual Joystick (Analog Stick)
# - HUD with 4-Lap Counter, Lap Timer, and Best Lap Record (with real PNG icons)
# - Countdown and Lap Announcements
# - Victory Screen with Stars, Total Time, Best Lap Time, and Replay Buttons

@export var race_manager: Node
@export var vehicle: Node3D
@export var sound_effects: Node
@export var track_manager: Node
@export var track_builder: Node

# Root Controls
var root_control: Control
var start_screen: Control
var hud_screen: Control
var victory_screen: Control
var builder_screen: Control

# HUD Elements
var lap_label: Label
var time_label: Label
var best_time_label: Label
var center_notification: Label
var virtual_joystick: VirtualJoystick
var mode_hud_button: Button

# Vehicle Selection Data
const VEHICLE_TYPES = ["truck", "racecar", "motorcycle"]
const VEHICLE_DATA = {
	"truck": {
		"name": "Racing Truck",
		"desc": "Robuster Allround-Renn-Truck mit 4 Rädern & hoher Stabilität",
		"stats": "Tempo: 7/10  •  Beschleunigung: 6/10  •  Grip: 9/10",
		"icon": "res://sprites/icons/truck.png",
		"colors": [
			{"id": "yellow", "label": "Gelb", "color": Color(0.92, 0.82, 0.15)},
			{"id": "red", "label": "Rot", "color": Color(0.88, 0.22, 0.22)},
			{"id": "green", "label": "Grün", "color": Color(0.22, 0.8, 0.35)},
			{"id": "purple", "label": "Violett", "color": Color(0.68, 0.28, 0.88)}
		]
	},
	"racecar": {
		"name": "Rennauto",
		"desc": "Schneller Formel-Flitzer mit hoher Endgeschwindigkeit & Drifts",
		"stats": "Tempo: 10/10  •  Beschleunigung: 8/10  •  Grip: 7/10",
		"icon": "res://sprites/icons/racecar.png",
		"colors": [
			{"id": "red", "label": "Rot", "color": Color(0.88, 0.22, 0.22)},
			{"id": "green", "label": "Grün", "color": Color(0.22, 0.8, 0.35)},
			{"id": "orange", "label": "Orange", "color": Color(0.95, 0.52, 0.12)},
			{"id": "white", "label": "Weiß", "color": Color(0.88, 0.9, 0.95)}
		]
	},
	"motorcycle": {
		"name": "Motorrad",
		"desc": "Sportliches Renn-Bike mit dynamischer Schräglage & Raketenantrieb",
		"stats": "Tempo: 8/10  •  Beschleunigung: 10/10  •  Agilität: 10/10",
		"icon": "res://sprites/icons/motorcycle.png",
		"colors": [
			{"id": "red", "label": "Renn-Rot", "color": Color(0.88, 0.22, 0.22)}
		]
	}
}

# Thematic Props per World for the Track Builder
const THEME_PROPS = {
	"forest": [
		{"name": "Großer Baum", "path": "res://kenney_racing-kit/Models/GLTF format/treeLarge.glb"},
		{"name": "Camping-Zelt", "path": "res://kenney_racing-kit/Models/GLTF format/tent.glb"},
		{"name": "Großes Zelt", "path": "res://kenney_racing-kit/Models/GLTF format/tentLong.glb"},
	],
	"stadium": [
		{"name": "Tribüne", "path": "res://kenney_racing-kit/Models/GLTF format/grandStandCovered.glb"},
		{"name": "Boxengasse", "path": "res://kenney_racing-kit/Models/GLTF format/pitsGarage.glb"},
		{"name": "Flutlicht", "path": "res://kenney_racing-kit/Models/GLTF format/lightPostLarge.glb"},
		{"name": "Zielflagge", "path": "res://kenney_racing-kit/Models/GLTF format/flagCheckers.glb"},
		{"name": "Werbetafel", "path": "res://kenney_racing-kit/Models/GLTF format/billboard.glb"},
	],
	"rally": [
		{"name": "Rote Bande", "path": "res://kenney_racing-kit/Models/GLTF format/barrierRed.glb"},
		{"name": "Weiße Bande", "path": "res://kenney_racing-kit/Models/GLTF format/barrierWhite.glb"},
		{"name": "Pylone", "path": "res://kenney_racing-kit/Models/GLTF format/pylon.glb"},
		{"name": "Rallye-Turm", "path": "res://kenney_racing-kit/Models/GLTF format/bannerTowerRed.glb"},
		{"name": "Zaun", "path": "res://kenney_racing-kit/Models/GLTF format/fenceStraight.glb"},
	]
}

var current_type_idx: int = 0
var current_color_idx: int = 0

# Start Screen Nodes
var type_icon_rect: TextureRect
var type_label: Label
var type_desc_label: Label
var type_stats_label: Label
var color_chips_box: HBoxContainer
var color_buttons: Array[Button] = []
var world_buttons: Dictionary = {}
var mode_start_button: Button

# Builder UI Elements
var builder_world_buttons: Dictionary = {}
var builder_road_buttons: Dictionary = {}
var builder_prop_buttons: Array[Button] = []
var builder_road_scroll_box: HBoxContainer
var builder_props_scroll_box: HBoxContainer
var builder_rotate_button: Button
var builder_category_tab: String = "road"
var builder_category_buttons: Dictionary = {}
var builder_active_world: String = "forest"

# Victory Screen Elements
var victory_time_label: Label
var victory_best_label: Label

func _ready() -> void:
	layer = 10
	_resolve_dependencies()
	_create_ui_hierarchy()
	_connect_race_signals()
	_connect_builder_signals()
	_show_screen("menu")
	_apply_vehicle_to_world()

func _resolve_dependencies() -> void:
	if not race_manager:
		race_manager = get_node_or_null("../RaceManager")
	if not vehicle:
		vehicle = get_node_or_null("../Vehicle")
	if not sound_effects:
		sound_effects = get_node_or_null("../SoundEffects")
	if not track_manager:
		track_manager = get_node_or_null("../TrackManager")
	if not track_builder:
		track_builder = get_node_or_null("../TrackBuilder")

func _create_ui_hierarchy() -> void:
	root_control = Control.new()
	root_control.name = "RootUI"
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	_create_hud()
	_create_start_screen()
	_create_victory_screen()
	_create_track_builder_ui()

# ==============================================================================
# 1. HUD CREATION
# ==============================================================================

func _create_hud() -> void:
	hud_screen = Control.new()
	hud_screen.name = "HUDScreen"
	hud_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(hud_screen)

	# --- TOP BAR ---
	var top_bar = HBoxContainer.new()
	top_bar.name = "TopBar"
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 20
	top_bar.offset_top = 16
	top_bar.offset_right = -20
	top_bar.offset_bottom = 68
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_theme_constant_override("separation", 12)
	hud_screen.add_child(top_bar)

	# Lap Badge (mit Flaggen-Icon)
	var lap_panel = PanelContainer.new()
	lap_panel.add_theme_stylebox_override("panel", _create_panel_style(Color(0.1, 0.15, 0.28, 0.92), Color(0.3, 0.7, 1.0), 16, 2))
	top_bar.add_child(lap_panel)

	var lap_box = HBoxContainer.new()
	lap_box.add_theme_constant_override("separation", 8)
	lap_panel.add_child(lap_box)

	var lap_icon = _create_icon_rect("res://sprites/icons/flag_checkers.png", Vector2(26, 26))
	lap_box.add_child(lap_icon)

	lap_label = Label.new()
	lap_label.text = "Runde: 1 / 4"
	lap_label.add_theme_font_size_override("font_size", 20)
	lap_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.35))
	lap_box.add_child(lap_label)

	# Timer Badge (mit Stoppuhr-Icon)
	var time_panel = PanelContainer.new()
	time_panel.add_theme_stylebox_override("panel", _create_panel_style(Color(0.1, 0.15, 0.28, 0.88), Color(1, 1, 1, 0.25), 16))
	top_bar.add_child(time_panel)

	var time_box = HBoxContainer.new()
	time_box.add_theme_constant_override("separation", 8)
	time_panel.add_child(time_box)

	var time_icon = _create_icon_rect("res://sprites/icons/timer.png", Vector2(22, 22))
	time_box.add_child(time_icon)

	time_label = Label.new()
	time_label.text = "Zeit: 00:00.00"
	time_label.add_theme_font_size_override("font_size", 18)
	time_label.add_theme_color_override("font_color", Color.WHITE)
	time_box.add_child(time_label)

	# Best Lap Badge (mit Stern-Icon)
	var best_panel = PanelContainer.new()
	best_panel.add_theme_stylebox_override("panel", _create_panel_style(Color(0.08, 0.22, 0.16, 0.88), Color(0.3, 0.85, 0.5, 0.8), 16))
	top_bar.add_child(best_panel)

	var best_box = HBoxContainer.new()
	best_box.add_theme_constant_override("separation", 8)
	best_panel.add_child(best_box)

	var best_icon = _create_icon_rect("res://sprites/icons/star.png", Vector2(22, 22))
	best_box.add_child(best_icon)

	best_time_label = Label.new()
	best_time_label.text = "Beste: --:--.--"
	best_time_label.add_theme_font_size_override("font_size", 16)
	best_time_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.7))
	best_box.add_child(best_time_label)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(spacer)

	# Quick Menu Button
	var menu_btn = Button.new()
	menu_btn.text = "Hauptmenü"
	menu_btn.add_theme_font_size_override("font_size", 15)
	_apply_button_style(menu_btn, Color(0.2, 0.25, 0.38, 0.9), Color(0.35, 0.45, 0.65), 14, "res://sprites/icons/home.png")
	menu_btn.pressed.connect(_on_menu_button_pressed)
	top_bar.add_child(menu_btn)

	# --- CENTER NOTIFICATION ---
	center_notification = Label.new()
	center_notification.name = "CenterNotification"
	center_notification.set_anchors_preset(Control.PRESET_CENTER)
	center_notification.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center_notification.grow_vertical = Control.GROW_DIRECTION_BOTH
	center_notification.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_notification.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_notification.add_theme_font_size_override("font_size", 60)
	center_notification.add_theme_color_override("font_color", Color(1.0, 0.95, 0.2))
	center_notification.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.2))
	center_notification.add_theme_constant_override("outline_size", 10)
	center_notification.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_screen.add_child(center_notification)

	# --- VIRTUAL JOYSTICK ---
	virtual_joystick = VirtualJoystick.new()
	virtual_joystick.name = "VirtualJoystick"
	virtual_joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	virtual_joystick.offset_left = 50
	virtual_joystick.offset_bottom = -50
	virtual_joystick.offset_top = -250
	virtual_joystick.offset_right = 250
	virtual_joystick.analog_moved.connect(_on_joystick_moved)
	virtual_joystick.analog_released.connect(_on_joystick_released)
	hud_screen.add_child(virtual_joystick)

	# --- ACTION BUTTONS ---
	var action_box = VBoxContainer.new()
	action_box.name = "ActionButtons"
	action_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	action_box.offset_right = -35
	action_box.offset_bottom = -35
	action_box.offset_left = -230
	action_box.offset_top = -220
	action_box.add_theme_constant_override("separation", 10)
	hud_screen.add_child(action_box)

	var hud_builder_btn = Button.new()
	hud_builder_btn.text = "Streckenbauer"
	hud_builder_btn.add_theme_font_size_override("font_size", 15)
	_apply_button_style(hud_builder_btn, Color(0.18, 0.45, 0.78, 0.9), Color(0.3, 0.65, 0.95), 14, "res://sprites/icons/tools.png")
	hud_builder_btn.pressed.connect(_open_builder)
	action_box.add_child(hud_builder_btn)

	var respawn_btn = Button.new()
	respawn_btn.text = "Auto zurücksetzen"
	respawn_btn.add_theme_font_size_override("font_size", 15)
	_apply_button_style(respawn_btn, Color(0.85, 0.4, 0.15, 0.9), Color(1.0, 0.55, 0.25), 14, "res://sprites/icons/reset.png")
	respawn_btn.pressed.connect(_on_respawn_pressed)
	action_box.add_child(respawn_btn)

	mode_hud_button = Button.new()
	mode_hud_button.text = "Modus: Intuitiv"
	mode_hud_button.add_theme_font_size_override("font_size", 15)
	_apply_button_style(mode_hud_button, Color(0.2, 0.55, 0.85, 0.85), Color(0.3, 0.65, 0.95), 14, "res://sprites/icons/steering.png")
	mode_hud_button.pressed.connect(_on_toggle_control_mode)
	action_box.add_child(mode_hud_button)

# ==============================================================================
# 2. START SCREEN CREATION
# ==============================================================================

func _create_start_screen() -> void:
	start_screen = Control.new()
	start_screen.name = "StartScreen"
	start_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(start_screen)

	var bg_dim = ColorRect.new()
	bg_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_dim.color = Color(0.02, 0.04, 0.08, 0.15)
	start_screen.add_child(bg_dim)

	# 3D Showroom Badge
	var showroom_badge = PanelContainer.new()
	showroom_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	showroom_badge.offset_left = -270
	showroom_badge.offset_top = 20
	showroom_badge.offset_right = -24
	showroom_badge.offset_bottom = 75
	showroom_badge.add_theme_stylebox_override("panel", _create_panel_style(Color(0.08, 0.12, 0.22, 0.85), Color(1.0, 0.85, 0.25, 0.8), 16, 2))
	start_screen.add_child(showroom_badge)

	var showroom_vbox = VBoxContainer.new()
	showroom_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	showroom_badge.add_child(showroom_vbox)

	var showroom_title = Label.new()
	showroom_title.text = "3D-SHOWROOM"
	showroom_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	showroom_title.add_theme_font_size_override("font_size", 14)
	showroom_title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35))
	showroom_vbox.add_child(showroom_title)

	var showroom_hint = Label.new()
	showroom_hint.text = "Fahrzeug dreht sich live in 3D"
	showroom_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	showroom_hint.add_theme_font_size_override("font_size", 11)
	showroom_hint.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	showroom_vbox.add_child(showroom_hint)

	# Left-docked Control Card
	var card = PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	card.offset_left = 24
	card.offset_top = 20
	card.offset_right = 380
	card.offset_bottom = -20
	card.add_theme_stylebox_override("panel", _create_panel_style(Color(0.08, 0.12, 0.22, 0.93), Color(0.35, 0.7, 1.0, 0.85), 22, 2))
	start_screen.add_child(card)

	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)

	var card_vbox = VBoxContainer.new()
	card_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_vbox.add_theme_constant_override("separation", 9)
	scroll.add_child(card_vbox)

	# Title
	var title = Label.new()
	title.text = "KENNY RACING"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.3))
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.2))
	title.add_theme_constant_override("outline_size", 5)
	card_vbox.add_child(title)

	var sub = Label.new()
	sub.text = "Belohnungsspiel für clevere Rennfahrerinnen!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	card_vbox.add_child(sub)

	var goal_lbl = Label.new()
	goal_lbl.text = "Ziel: 4 Runden meistern & gewinnen!"
	goal_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goal_lbl.add_theme_font_size_override("font_size", 13)
	goal_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	card_vbox.add_child(goal_lbl)

	card_vbox.add_child(HSeparator.new())

	# 1. VEHICLE TYPE
	var v_header = Label.new()
	v_header.text = "1. Fahrzeug-Typ wählen:"
	v_header.add_theme_font_size_override("font_size", 14)
	v_header.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	card_vbox.add_child(v_header)

	var type_carousel = HBoxContainer.new()
	type_carousel.alignment = BoxContainer.ALIGNMENT_CENTER
	type_carousel.add_theme_constant_override("separation", 8)
	card_vbox.add_child(type_carousel)

	var prev_type_btn = Button.new()
	prev_type_btn.text = "◀"
	prev_type_btn.add_theme_font_size_override("font_size", 16)
	_apply_button_style(prev_type_btn, Color(0.2, 0.35, 0.55), Color(0.35, 0.6, 0.9), 12)
	prev_type_btn.pressed.connect(_on_prev_vehicle_type)
	type_carousel.add_child(prev_type_btn)

	var type_panel = PanelContainer.new()
	type_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_panel.add_theme_stylebox_override("panel", _create_panel_style(Color(0.15, 0.22, 0.36, 0.9), Color(0.3, 0.65, 0.95), 14, 2))
	type_carousel.add_child(type_panel)

	var type_inner_hbox = HBoxContainer.new()
	type_inner_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	type_inner_hbox.add_theme_constant_override("separation", 8)
	type_panel.add_child(type_inner_hbox)

	type_icon_rect = _create_icon_rect("res://sprites/icons/truck.png", Vector2(36, 36))
	type_inner_hbox.add_child(type_icon_rect)

	var type_text_vbox = VBoxContainer.new()
	type_inner_hbox.add_child(type_text_vbox)

	type_label = Label.new()
	type_label.text = "Racing Truck"
	type_label.add_theme_font_size_override("font_size", 16)
	type_label.add_theme_color_override("font_color", Color.WHITE)
	type_text_vbox.add_child(type_label)

	type_desc_label = Label.new()
	type_desc_label.text = "Robuster Allround-Renn-Truck"
	type_desc_label.add_theme_font_size_override("font_size", 11)
	type_desc_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	type_text_vbox.add_child(type_desc_label)

	var next_type_btn = Button.new()
	next_type_btn.text = "▶"
	next_type_btn.add_theme_font_size_override("font_size", 16)
	_apply_button_style(next_type_btn, Color(0.2, 0.35, 0.55), Color(0.35, 0.6, 0.9), 12)
	next_type_btn.pressed.connect(_on_next_vehicle_type)
	type_carousel.add_child(next_type_btn)

	type_stats_label = Label.new()
	type_stats_label.text = "Tempo: 7/10 • Beschleunigung: 6/10 • Grip: 9/10"
	type_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_stats_label.add_theme_font_size_override("font_size", 11)
	type_stats_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.75))
	card_vbox.add_child(type_stats_label)

	# 2. COLOR
	var color_header = Label.new()
	color_header.text = "2. Farbe wählen:"
	color_header.add_theme_font_size_override("font_size", 14)
	color_header.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	card_vbox.add_child(color_header)

	var color_scroll = ScrollContainer.new()
	color_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	color_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	color_scroll.custom_minimum_size = Vector2(0, 42)
	card_vbox.add_child(color_scroll)

	color_chips_box = HBoxContainer.new()
	color_chips_box.alignment = BoxContainer.ALIGNMENT_CENTER
	color_chips_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_chips_box.add_theme_constant_override("separation", 6)
	color_scroll.add_child(color_chips_box)

	_refresh_vehicle_display()

	card_vbox.add_child(HSeparator.new())

	# 3. WORLD
	var world_header = Label.new()
	world_header.text = "3. Rennwelt & Thema:"
	world_header.add_theme_font_size_override("font_size", 14)
	world_header.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	card_vbox.add_child(world_header)

	var world_hbox = HBoxContainer.new()
	world_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	world_hbox.add_theme_constant_override("separation", 6)
	card_vbox.add_child(world_hbox)

	var worlds = [
		{"id": "forest", "label": "Wald", "col": Color(0.2, 0.6, 0.3), "icon": "res://sprites/icons/tree.png"},
		{"id": "stadium", "label": "Stadion", "col": Color(0.2, 0.5, 0.85), "icon": "res://sprites/icons/stadium.png"},
		{"id": "rally", "label": "Rallye", "col": Color(0.85, 0.5, 0.15), "icon": "res://sprites/icons/rally.png"}
	]

	for w in worlds:
		var w_btn = Button.new()
		w_btn.text = w["label"]
		w_btn.add_theme_font_size_override("font_size", 13)
		_apply_button_style(w_btn, w["col"] * 0.8, w["col"], 12, w["icon"])
		var wid: String = w["id"]
		w_btn.pressed.connect(func(): _select_world(wid))
		world_hbox.add_child(w_btn)
		world_buttons[wid] = w_btn

	_highlight_selected_world_button("forest")

	card_vbox.add_child(HSeparator.new())

	# Control Mode Button
	mode_start_button = Button.new()
	mode_start_button.text = "Modus: Intuitiv"
	mode_start_button.add_theme_font_size_override("font_size", 13)
	_apply_button_style(mode_start_button, Color(0.18, 0.45, 0.75), Color(0.3, 0.65, 0.95), 12, "res://sprites/icons/steering.png")
	mode_start_button.pressed.connect(_on_toggle_control_mode)
	card_vbox.add_child(mode_start_button)

	# Big START Button
	var start_btn = Button.new()
	start_btn.text = "Rennen starten (4 Runden)"
	start_btn.add_theme_font_size_override("font_size", 16)
	_apply_button_style(start_btn, Color(0.18, 0.72, 0.35), Color(0.35, 0.95, 0.55), 15, "res://sprites/icons/flag_checkers.png")
	start_btn.pressed.connect(_on_start_button_pressed)
	card_vbox.add_child(start_btn)

	# Interactive Streckenbauer Button
	var builder_btn = Button.new()
	builder_btn.text = "Streckenbauer (Eigene Strecke)"
	builder_btn.add_theme_font_size_override("font_size", 15)
	_apply_button_style(builder_btn, Color(0.2, 0.45, 0.85), Color(0.4, 0.75, 1.0), 15, "res://sprites/icons/tools.png")
	builder_btn.pressed.connect(_open_builder)
	card_vbox.add_child(builder_btn)

# ==============================================================================
# 3. INTERACTIVE TRACK BUILDER UI
# ==============================================================================

func _create_track_builder_ui() -> void:
	builder_screen = Control.new()
	builder_screen.name = "TrackBuilderScreen"
	builder_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	builder_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	builder_screen.visible = false
	root_control.add_child(builder_screen)

	# Prominent Back Button (Top-Left)
	var back_btn = Button.new()
	back_btn.text = "Zurück zum Menü"
	back_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back_btn.offset_left = 18
	back_btn.offset_top = 18
	back_btn.offset_right = 210
	back_btn.offset_bottom = 66
	back_btn.add_theme_font_size_override("font_size", 15)
	_apply_button_style(back_btn, Color(0.18, 0.22, 0.35, 0.95), Color(0.45, 0.7, 1.0), 14, "res://sprites/icons/back.png")
	back_btn.pressed.connect(func():
		if track_builder:
			track_builder.close_builder()
		_show_screen("menu")
	)
	builder_screen.add_child(back_btn)

	# TOP TOOL BAR
	var top_panel = PanelContainer.new()
	top_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_left = 225
	top_panel.offset_top = 18
	top_panel.offset_right = -18
	top_panel.offset_bottom = 66
	top_panel.add_theme_stylebox_override("panel", _create_panel_style(Color(0.08, 0.12, 0.22, 0.92), Color(0.35, 0.7, 1.0, 0.8), 16, 2))
	builder_screen.add_child(top_panel)

	var top_hbox = HBoxContainer.new()
	top_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_hbox.add_theme_constant_override("separation", 8)
	top_panel.add_child(top_hbox)

	var b_title = Label.new()
	b_title.text = "Streckenbauer"
	b_title.add_theme_font_size_override("font_size", 16)
	b_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	top_hbox.add_child(b_title)

	top_hbox.add_child(VSeparator.new())

	# World selector
	var b_worlds = [
		{"id": "forest", "label": "Wald", "col": Color(0.2, 0.6, 0.3), "icon": "res://sprites/icons/tree.png"},
		{"id": "stadium", "label": "Stadion", "col": Color(0.2, 0.5, 0.85), "icon": "res://sprites/icons/stadium.png"},
		{"id": "rally", "label": "Rallye", "col": Color(0.85, 0.5, 0.15), "icon": "res://sprites/icons/rally.png"}
	]
	for w in b_worlds:
		var w_btn = Button.new()
		w_btn.text = w["label"]
		w_btn.add_theme_font_size_override("font_size", 13)
		_apply_button_style(w_btn, w["col"] * 0.8, w["col"], 10, w["icon"])
		var wid: String = w["id"]
		w_btn.pressed.connect(func(): _select_builder_world(wid))
		top_hbox.add_child(w_btn)
		builder_world_buttons[wid] = w_btn
	_highlight_builder_world_button("forest")

	top_hbox.add_child(VSeparator.new())

	# Zoom
	var zoom_out_btn = Button.new()
	zoom_out_btn.text = "- Zoom"
	zoom_out_btn.add_theme_font_size_override("font_size", 12)
	_apply_button_style(zoom_out_btn, Color(0.2, 0.3, 0.45), Color(0.4, 0.6, 0.9), 10)
	zoom_out_btn.pressed.connect(func():
		var cam_view = get_node_or_null("../View")
		if cam_view and cam_view.has_method("zoom_builder"):
			cam_view.zoom_builder(4.0)
	)
	top_hbox.add_child(zoom_out_btn)

	var zoom_in_btn = Button.new()
	zoom_in_btn.text = "+ Zoom"
	zoom_in_btn.add_theme_font_size_override("font_size", 12)
	_apply_button_style(zoom_in_btn, Color(0.2, 0.3, 0.45), Color(0.4, 0.6, 0.9), 10)
	zoom_in_btn.pressed.connect(func():
		var cam_view = get_node_or_null("../View")
		if cam_view and cam_view.has_method("zoom_builder"):
			cam_view.zoom_builder(-4.0)
	)
	top_hbox.add_child(zoom_in_btn)

	var center_btn = Button.new()
	center_btn.text = "Zentrieren"
	center_btn.add_theme_font_size_override("font_size", 12)
	_apply_button_style(center_btn, Color(0.2, 0.3, 0.45), Color(0.4, 0.6, 0.9), 10)
	center_btn.pressed.connect(func():
		var cam_view = get_node_or_null("../View")
		if cam_view:
			cam_view.builder_pos = Vector3(-7.5, 0.0, -7.5)
	)
	top_hbox.add_child(center_btn)

	top_hbox.add_child(VSeparator.new())

	# Restore Default Track
	var restore_btn = Button.new()
	restore_btn.text = "Standard"
	restore_btn.add_theme_font_size_override("font_size", 12)
	_apply_button_style(restore_btn, Color(0.25, 0.4, 0.6), Color(0.45, 0.7, 1.0), 10, "res://sprites/icons/reset.png")
	restore_btn.pressed.connect(func():
		if track_builder:
			track_builder.restore_default_track()
		_show_temporary_banner("Standard-Strecke wiederhergestellt!", 2.0)
	)
	top_hbox.add_child(restore_btn)

	# Clear Grid
	var clear_btn = Button.new()
	clear_btn.text = "Leeren"
	clear_btn.add_theme_font_size_override("font_size", 12)
	_apply_button_style(clear_btn, Color(0.55, 0.2, 0.2), Color(0.85, 0.3, 0.3), 10, "res://sprites/icons/trash.png")
	clear_btn.pressed.connect(func():
		if track_builder:
			track_builder.clear_all()
		_show_temporary_banner("Strecke geleert!", 2.0)
	)
	top_hbox.add_child(clear_btn)

	# BOTTOM TOOL BAR
	var bottom_panel = PanelContainer.new()
	bottom_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_panel.offset_left = 18
	bottom_panel.offset_top = -115
	bottom_panel.offset_right = -18
	bottom_panel.offset_bottom = -16
	bottom_panel.add_theme_stylebox_override("panel", _create_panel_style(Color(0.08, 0.12, 0.22, 0.94), Color(0.35, 0.7, 1.0, 0.8), 20, 2))
	builder_screen.add_child(bottom_panel)

	var bottom_vbox = VBoxContainer.new()
	bottom_vbox.add_theme_constant_override("separation", 8)
	bottom_panel.add_child(bottom_vbox)

	var b_controls_row = HBoxContainer.new()
	b_controls_row.alignment = BoxContainer.ALIGNMENT_CENTER
	b_controls_row.add_theme_constant_override("separation", 10)
	bottom_vbox.add_child(b_controls_row)

	# Category Tabs
	var cat_road_btn = Button.new()
	cat_road_btn.text = "Straßen"
	cat_road_btn.add_theme_font_size_override("font_size", 14)
	_apply_button_style(cat_road_btn, Color(0.2, 0.45, 0.75), Color(0.4, 0.75, 1.0), 12, "res://sprites/icons/road_straight.png")
	cat_road_btn.pressed.connect(func(): _switch_builder_category("road"))
	b_controls_row.add_child(cat_road_btn)
	builder_category_buttons["road"] = cat_road_btn

	var cat_props_btn = Button.new()
	cat_props_btn.text = "Deko & Bausatz"
	cat_props_btn.add_theme_font_size_override("font_size", 14)
	_apply_button_style(cat_props_btn, Color(0.2, 0.3, 0.45), Color(0.3, 0.45, 0.7), 12, "res://sprites/icons/tree.png")
	cat_props_btn.pressed.connect(func(): _switch_builder_category("props"))
	b_controls_row.add_child(cat_props_btn)
	builder_category_buttons["props"] = cat_props_btn

	b_controls_row.add_child(VSeparator.new())

	# Rotate Button
	builder_rotate_button = Button.new()
	builder_rotate_button.text = "Drehen (R): 0°"
	builder_rotate_button.add_theme_font_size_override("font_size", 14)
	_apply_button_style(builder_rotate_button, Color(0.25, 0.35, 0.55), Color(0.45, 0.65, 0.95), 14, "res://sprites/icons/reset.png")
	builder_rotate_button.pressed.connect(func():
		if track_builder:
			track_builder.rotate_piece()
	)
	b_controls_row.add_child(builder_rotate_button)

	b_controls_row.add_child(VSeparator.new())

	# Big Test Drive Button
	var drive_btn = Button.new()
	drive_btn.text = "Testfahrt starten"
	drive_btn.add_theme_font_size_override("font_size", 15)
	_apply_button_style(drive_btn, Color(0.18, 0.72, 0.35), Color(0.35, 0.95, 0.55), 15, "res://sprites/icons/flag_checkers.png")
	drive_btn.pressed.connect(func():
		if track_builder:
			track_builder.start_test_drive()
		_show_screen("hud")
		_show_temporary_banner("Testfahrt! Fahre auf deiner Strecke!", 2.5)
	)
	b_controls_row.add_child(drive_btn)

	# Tools Row
	var tools_scroll = ScrollContainer.new()
	tools_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tools_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	tools_scroll.custom_minimum_size = Vector2(0, 44)
	bottom_vbox.add_child(tools_scroll)

	var tools_stack = MarginContainer.new()
	tools_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools_scroll.add_child(tools_stack)

	# Road items container
	builder_road_scroll_box = HBoxContainer.new()
	builder_road_scroll_box.alignment = BoxContainer.ALIGNMENT_CENTER
	builder_road_scroll_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	builder_road_scroll_box.add_theme_constant_override("separation", 8)
	tools_stack.add_child(builder_road_scroll_box)

	var roads = [
		{"id": 4, "name": "Start / Ziel", "icon": "res://sprites/icons/flag_checkers.png"},
		{"id": 6, "name": "Gerade", "icon": "res://sprites/icons/road_straight.png"},
		{"id": 3, "name": "Kurve", "icon": "res://sprites/icons/road_corner.png"},
		{"id": 5, "name": "Rampe", "icon": "res://sprites/icons/road_ramp.png"},
		{"id": -1, "name": "Löschen", "icon": "res://sprites/icons/trash.png"}
	]
	for r in roads:
		var r_btn = Button.new()
		r_btn.text = r["name"]
		r_btn.add_theme_font_size_override("font_size", 13)
		var item_id: int = r["id"]
		var base_col = Color(0.55, 0.2, 0.2, 0.85) if item_id == -1 else Color(0.2, 0.4, 0.65, 0.85)
		var border_col = Color(0.85, 0.3, 0.3) if item_id == -1 else Color(0.35, 0.7, 1.0)
		_apply_button_style(r_btn, base_col, border_col, 12, r["icon"])
		r_btn.pressed.connect(func():
			if item_id == -1:
				if track_builder: track_builder.select_erase_tool()
			else:
				if track_builder: track_builder.select_road_tool(item_id)
			_highlight_builder_road_button(item_id)
		)
		builder_road_scroll_box.add_child(r_btn)
		builder_road_buttons[item_id] = r_btn

	_highlight_builder_road_button(6)

	# Props items container
	builder_props_scroll_box = HBoxContainer.new()
	builder_props_scroll_box.alignment = BoxContainer.ALIGNMENT_CENTER
	builder_props_scroll_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	builder_props_scroll_box.add_theme_constant_override("separation", 8)
	builder_props_scroll_box.visible = false
	tools_stack.add_child(builder_props_scroll_box)

	_refresh_builder_props_for_world("forest")

func _open_builder() -> void:
	if sound_effects:
		sound_effects.play_click()
	_show_screen("builder")
	if track_builder:
		track_builder.open_builder()

func _select_builder_world(world_id: String) -> void:
	builder_active_world = world_id
	_select_world(world_id)
	_highlight_builder_world_button(world_id)
	_refresh_builder_props_for_world(world_id)

func _highlight_builder_world_button(world_id: String) -> void:
	for wid in builder_world_buttons:
		var btn: Button = builder_world_buttons[wid]
		if wid == world_id:
			btn.text = "✓ " + btn.text.replace("✓ ", "")
		else:
			btn.text = btn.text.replace("✓ ", "")

func _switch_builder_category(cat: String) -> void:
	builder_category_tab = cat
	builder_road_scroll_box.visible = (cat == "road")
	builder_props_scroll_box.visible = (cat == "props")

	if cat == "road":
		_apply_button_style(builder_category_buttons["road"], Color(0.2, 0.45, 0.75), Color(0.4, 0.75, 1.0), 12, "res://sprites/icons/road_straight.png")
		_apply_button_style(builder_category_buttons["props"], Color(0.2, 0.3, 0.45), Color(0.3, 0.45, 0.7), 12, "res://sprites/icons/tree.png")
		if track_builder:
			track_builder.select_road_tool(6)
			_highlight_builder_road_button(6)
	else:
		_apply_button_style(builder_category_buttons["props"], Color(0.2, 0.5, 0.35), Color(0.35, 0.85, 0.55), 12, "res://sprites/icons/tree.png")
		_apply_button_style(builder_category_buttons["road"], Color(0.2, 0.3, 0.45), Color(0.3, 0.45, 0.7), 12, "res://sprites/icons/road_straight.png")
		var props = THEME_PROPS.get(builder_active_world, THEME_PROPS["forest"])
		if props.size() > 0 and track_builder:
			track_builder.select_prop_tool(props[0]["path"], props[0]["name"])
			if builder_prop_buttons.size() > 0:
				_highlight_builder_prop_button(builder_prop_buttons[0])

func _highlight_builder_road_button(active_item: int) -> void:
	for item_id in builder_road_buttons:
		var btn: Button = builder_road_buttons[item_id]
		var clean_txt = btn.text.replace("✓ ", "")
		if item_id == active_item:
			btn.text = "✓ " + clean_txt
			_apply_button_style(btn, Color(0.3, 0.6, 0.95), Color.WHITE, 12)
		else:
			btn.text = clean_txt
			var base_col = Color(0.55, 0.2, 0.2, 0.85) if item_id == -1 else Color(0.2, 0.35, 0.55, 0.85)
			_apply_button_style(btn, base_col, base_col.lightened(0.25), 12)

func _refresh_builder_props_for_world(world_id: String) -> void:
	for c in builder_props_scroll_box.get_children():
		c.queue_free()
	builder_prop_buttons.clear()

	var props_list = THEME_PROPS.get(world_id, THEME_PROPS["forest"])
	for p_info in props_list:
		var p_btn = Button.new()
		p_btn.text = p_info["name"]
		p_btn.add_theme_font_size_override("font_size", 13)
		_apply_button_style(p_btn, Color(0.2, 0.38, 0.28, 0.9), Color(0.35, 0.8, 0.5), 12, "res://sprites/icons/tree.png")
		var p_path: String = p_info["path"]
		var p_name: String = p_info["name"]
		p_btn.pressed.connect(func():
			if track_builder:
				track_builder.select_prop_tool(p_path, p_name)
			_highlight_builder_prop_button(p_btn)
		)
		builder_props_scroll_box.add_child(p_btn)
		builder_prop_buttons.append(p_btn)

	if builder_category_tab == "props" and builder_prop_buttons.size() > 0:
		_highlight_builder_prop_button(builder_prop_buttons[0])

func _highlight_builder_prop_button(active_btn: Button) -> void:
	for btn in builder_prop_buttons:
		var clean_txt = btn.text.replace("✓ ", "")
		if btn == active_btn:
			btn.text = "✓ " + clean_txt
			_apply_button_style(btn, Color(0.25, 0.65, 0.4), Color.WHITE, 12)
		else:
			btn.text = clean_txt
			_apply_button_style(btn, Color(0.2, 0.38, 0.28, 0.9), Color(0.35, 0.8, 0.5), 12)

func _connect_builder_signals() -> void:
	if not track_builder:
		return
	track_builder.orientation_changed.connect(func(deg: int):
		if builder_rotate_button:
			builder_rotate_button.text = "Drehen (R): %d°" % deg
	)

# ==============================================================================
# 4. VICTORY SCREEN CREATION
# ==============================================================================

func _create_victory_screen() -> void:
	victory_screen = Control.new()
	victory_screen.name = "VictoryScreen"
	victory_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(victory_screen)

	var bg_dim = ColorRect.new()
	bg_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_dim.color = Color(0.04, 0.08, 0.16, 0.75)
	victory_screen.add_child(bg_dim)

	var card = PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -280
	card.offset_top = -230
	card.offset_right = 280
	card.offset_bottom = 230
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	card.add_theme_stylebox_override("panel", _create_panel_style(Color(0.1, 0.15, 0.28, 0.96), Color(1.0, 0.85, 0.2), 26, 4))
	victory_screen.add_child(card)

	var v_vbox = VBoxContainer.new()
	v_vbox.add_theme_constant_override("separation", 12)
	card.add_child(v_vbox)

	var win_title = Label.new()
	win_title.text = "SUPER GEMACHT!"
	win_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_title.add_theme_font_size_override("font_size", 28)
	win_title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.3))
	win_title.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.2))
	win_title.add_theme_constant_override("outline_size", 6)
	v_vbox.add_child(win_title)

	var win_sub = Label.new()
	win_sub.text = "Du hast alle 4 Runden erfolgreich gemeistert!"
	win_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_sub.add_theme_font_size_override("font_size", 16)
	win_sub.add_theme_color_override("font_color", Color.WHITE)
	v_vbox.add_child(win_sub)

	# Stars row with PNG icons
	var stars_hbox = HBoxContainer.new()
	stars_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_hbox.add_theme_constant_override("separation", 12)
	v_vbox.add_child(stars_hbox)

	for _i in range(3):
		var star_icon = _create_icon_rect("res://sprites/icons/star.png", Vector2(40, 40))
		stars_hbox.add_child(star_icon)

	victory_time_label = Label.new()
	victory_time_label.text = "Gesamtzeit: 01:25.00"
	victory_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory_time_label.add_theme_font_size_override("font_size", 19)
	victory_time_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	v_vbox.add_child(victory_time_label)

	victory_best_label = Label.new()
	victory_best_label.text = "Schnellste Runde: 00:20.00"
	victory_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory_best_label.add_theme_font_size_override("font_size", 17)
	victory_best_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	v_vbox.add_child(victory_best_label)

	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 14)
	v_vbox.add_child(btn_hbox)

	var replay_btn = Button.new()
	replay_btn.text = "Nochmal spielen"
	replay_btn.add_theme_font_size_override("font_size", 17)
	_apply_button_style(replay_btn, Color(0.2, 0.65, 0.95), Color(0.35, 0.8, 1.0), 14, "res://sprites/icons/reset.png")
	replay_btn.pressed.connect(_on_start_button_pressed)
	btn_hbox.add_child(replay_btn)

	var main_menu_btn = Button.new()
	main_menu_btn.text = "Hauptmenü"
	main_menu_btn.add_theme_font_size_override("font_size", 17)
	_apply_button_style(main_menu_btn, Color(0.25, 0.3, 0.45), Color(0.35, 0.42, 0.6), 14, "res://sprites/icons/home.png")
	main_menu_btn.pressed.connect(_on_menu_button_pressed)
	btn_hbox.add_child(main_menu_btn)

# ==============================================================================
# 5. VEHICLE SELECTION CONTROLLER
# ==============================================================================

func _on_prev_vehicle_type() -> void:
	if sound_effects:
		sound_effects.play_click()
	current_type_idx = (current_type_idx - 1 + VEHICLE_TYPES.size()) % VEHICLE_TYPES.size()
	current_color_idx = 0
	_refresh_vehicle_display()

func _on_next_vehicle_type() -> void:
	if sound_effects:
		sound_effects.play_click()
	current_type_idx = (current_type_idx + 1) % VEHICLE_TYPES.size()
	current_color_idx = 0
	_refresh_vehicle_display()

func _refresh_vehicle_display() -> void:
	var type_key = VEHICLE_TYPES[current_type_idx]
	var data = VEHICLE_DATA[type_key]

	if type_label:
		type_label.text = data["name"]
	if type_desc_label:
		type_desc_label.text = data["desc"]
	if type_stats_label:
		type_stats_label.text = data["stats"]
	if type_icon_rect and ResourceLoader.exists(data["icon"]):
		type_icon_rect.texture = load(data["icon"])

	for c in color_chips_box.get_children():
		c.queue_free()
	color_buttons.clear()

	var colors: Array = data["colors"]
	if current_color_idx >= colors.size():
		current_color_idx = 0

	for i in range(colors.size()):
		var cinfo = colors[i]
		var cbtn = Button.new()
		cbtn.text = cinfo["label"]
		cbtn.add_theme_font_size_override("font_size", 13)
		var c_idx := i
		cbtn.pressed.connect(func(): _select_color_index(c_idx))
		color_chips_box.add_child(cbtn)
		color_buttons.append(cbtn)

	_update_color_button_highlights()
	_apply_vehicle_to_world()

func _select_color_index(idx: int) -> void:
	if sound_effects:
		sound_effects.play_click()
	current_color_idx = idx
	_update_color_button_highlights()
	_apply_vehicle_to_world()

func _update_color_button_highlights() -> void:
	var type_key = VEHICLE_TYPES[current_type_idx]
	var colors = VEHICLE_DATA[type_key]["colors"]

	for i in range(color_buttons.size()):
		var btn = color_buttons[i]
		var cinfo = colors[i]
		if i == current_color_idx:
			_apply_button_style(btn, cinfo["color"] * 0.95, Color.WHITE, 14)
			btn.text = "✓ " + cinfo["label"].replace("✓ ", "")
		else:
			_apply_button_style(btn, cinfo["color"] * 0.7, cinfo["color"], 14)
			btn.text = cinfo["label"].replace("✓ ", "")

func _apply_vehicle_to_world() -> void:
	var type_key = VEHICLE_TYPES[current_type_idx]
	var colors = VEHICLE_DATA[type_key]["colors"]
	var color_id: String = colors[current_color_idx]["id"]

	if vehicle:
		vehicle.set_vehicle(type_key, color_id)

func _select_world(world_id: String) -> void:
	if sound_effects:
		sound_effects.play_click()
	if track_manager:
		track_manager.set_world(world_id)
	_highlight_selected_world_button(world_id)

func _highlight_selected_world_button(world_id: String) -> void:
	for wid in world_buttons:
		var btn: Button = world_buttons[wid]
		if wid == world_id:
			btn.text = "✓ " + btn.text.replace("✓ ", "")
		else:
			btn.text = btn.text.replace("✓ ", "")

# ==============================================================================
# 6. SIGNALS & LOGIC
# ==============================================================================

func _connect_race_signals() -> void:
	if not race_manager:
		return

	race_manager.race_state_changed.connect(_on_race_state_changed)
	race_manager.countdown_tick.connect(_on_countdown_tick)
	race_manager.lap_updated.connect(_on_lap_updated)
	race_manager.race_finished.connect(_on_race_finished)

func _process(delta: float) -> void:
	if start_screen and start_screen.visible:
		if vehicle and vehicle.has_method("rotate_showroom"):
			vehicle.rotate_showroom(delta)

	if race_manager and race_manager.current_state == RaceManager.GameState.RACING:
		time_label.text = "Zeit: " + race_manager.format_time(race_manager.race_time)

func _show_screen(name_str: String) -> void:
	start_screen.visible = (name_str == "menu")
	hud_screen.visible = (name_str == "hud")
	victory_screen.visible = (name_str == "victory")
	if builder_screen:
		builder_screen.visible = (name_str == "builder")

func _on_start_button_pressed() -> void:
	if sound_effects:
		sound_effects.play_click()
	_show_screen("hud")
	if race_manager:
		race_manager.start_race_countdown()

func _on_menu_button_pressed() -> void:
	if sound_effects:
		sound_effects.play_click()
	_show_screen("menu")
	if race_manager:
		race_manager.show_main_menu()

func _on_respawn_pressed() -> void:
	if sound_effects:
		sound_effects.play_click()
	if race_manager:
		race_manager.respawn_vehicle()

func _on_toggle_control_mode() -> void:
	if sound_effects:
		sound_effects.play_click()
	if not vehicle:
		return

	var new_mode = vehicle.toggle_control_mode()
	var is_direct = (new_mode == Vehicle.ControlMode.DIRECT_DIRECTION)

	var label_start = "Modus: Intuitiv" if is_direct else "Modus: Klassisch"
	var label_hud = "Modus: Intuitiv" if is_direct else "Modus: Klassisch"

	if mode_start_button:
		mode_start_button.text = label_start
	if mode_hud_button:
		mode_hud_button.text = label_hud

func _on_joystick_moved(vec: Vector2) -> void:
	if vehicle:
		vehicle.set_joystick_input(vec, true)

func _on_joystick_released() -> void:
	if vehicle:
		vehicle.set_joystick_input(Vector2.ZERO, false)

func _on_race_state_changed(state: int) -> void:
	if state == RaceManager.GameState.MENU:
		_show_screen("menu")
	elif state == RaceManager.GameState.COUNTDOWN or state == RaceManager.GameState.RACING:
		_show_screen("hud")
	elif state == RaceManager.GameState.FINISHED:
		_show_screen("victory")

func _on_countdown_tick(text: String) -> void:
	center_notification.text = text
	if text != "":
		center_notification.scale = Vector2(1.4, 1.4)
		var tween = create_tween()
		tween.tween_property(center_notification, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_lap_updated(cur_lap: int, total: int, best_lap: float = 0.0) -> void:
	lap_label.text = "Runde: %d / %d" % [cur_lap, total]
	if best_time_label:
		if best_lap > 0.0 and race_manager:
			best_time_label.text = "Beste: " + race_manager.format_time(best_lap)
		else:
			best_time_label.text = "Beste: --:--.--"

	if cur_lap > 1:
		var txt = "Runde %d / %d!" % [cur_lap, total]
		if cur_lap == total:
			txt = "LETZTE RUNDE (%d / %d)!" % [cur_lap, total]
		_show_temporary_banner(txt, 1.8)

func _show_temporary_banner(msg: String, duration: float) -> void:
	center_notification.text = msg
	center_notification.scale = Vector2(1.3, 1.3)
	center_notification.modulate.a = 1.0

	var tween = create_tween()
	tween.tween_property(center_notification, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(duration)
	tween.tween_property(center_notification, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func():
		center_notification.text = ""
		center_notification.modulate.a = 1.0
	)

func _on_race_finished(total_time: float, best_lap: float = 0.0) -> void:
	_show_screen("victory")
	if victory_time_label and race_manager:
		victory_time_label.text = "Gesamtzeit: " + race_manager.format_time(total_time)
	if victory_best_label and race_manager:
		if best_lap > 0.0:
			victory_best_label.text = "Schnellste Runde: " + race_manager.format_time(best_lap)
		else:
			victory_best_label.text = "Schnellste Runde: " + race_manager.format_time(total_time / 4.0)

# ==============================================================================
# 7. UI STYLING & ICON HELPERS
# ==============================================================================

func _create_icon_rect(icon_path: String, size: Vector2) -> TextureRect:
	var tr = TextureRect.new()
	if icon_path != "" and ResourceLoader.exists(icon_path):
		tr.texture = load(icon_path)
	tr.custom_minimum_size = size
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return tr

func _create_panel_style(bg: Color, border: Color = Color.TRANSPARENT, radius: int = 18, border_w: int = 2) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	if border != Color.TRANSPARENT:
		sb.border_width_left = border_w
		sb.border_width_top = border_w
		sb.border_width_right = border_w
		sb.border_width_bottom = border_w
		sb.border_color = border
	return sb

func _apply_button_style(btn: Button, bg: Color, border: Color = Color.TRANSPARENT, radius: int = 14, icon_path: String = "") -> void:
	var normal_sb = _create_panel_style(bg, border, radius, 2)
	var hover_sb = _create_panel_style(bg.lightened(0.15), border.lightened(0.2), radius, 2)
	var pressed_sb = _create_panel_style(bg.darkened(0.15), border.darkened(0.1), radius, 2)

	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.8))
	btn.add_theme_color_override("font_pressed_color", Color(0.85, 0.85, 0.85))

	if icon_path != "" and ResourceLoader.exists(icon_path):
		btn.icon = load(icon_path)
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_constant_override("h_separation", 8)
