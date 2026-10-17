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
var track_select_screen: Control
var hud_screen: Control
var victory_screen: Control
var builder_screen: Control
var import_export_dialog: Control
var theme_select_dialog: Control

# Streckenwahl & Dialog elements
var track_select_cards_box: VBoxContainer
var track_count_label: Label
var add_track_button: Button
var active_track_label: Label
var builder_title_label: Label
var dialog_text_edit: TextEdit
var dialog_title: Label
var dialog_action_btn: Button
var current_dialog_slot: int = 1
var is_import_mode: bool = false

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
	_create_track_select_screen()
	_create_victory_screen()
	_create_track_builder_ui()
	_create_import_export_dialog()
	_create_theme_select_dialog()

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
	action_box.offset_top = -140
	action_box.add_theme_constant_override("separation", 10)
	hud_screen.add_child(action_box)

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

	# 3. TRACK & WORLD SELECTION
	var track_header = Label.new()
	track_header.text = "3. Rennstrecke wählen:"
	track_header.add_theme_font_size_override("font_size", 14)
	track_header.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	card_vbox.add_child(track_header)

	active_track_label = Label.new()
	active_track_label.text = "Strecke: Original (Standard)"
	active_track_label.add_theme_font_size_override("font_size", 13)
	active_track_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	card_vbox.add_child(active_track_label)

	var track_buttons_hbox = HBoxContainer.new()
	track_buttons_hbox.add_theme_constant_override("separation", 8)
	card_vbox.add_child(track_buttons_hbox)

	var orig_track_btn = Button.new()
	orig_track_btn.text = "Originalstrecke"
	orig_track_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	orig_track_btn.custom_minimum_size = Vector2(0, 40)
	orig_track_btn.add_theme_font_size_override("font_size", 13)
	_apply_button_style(orig_track_btn, Color(0.18, 0.45, 0.35), Color(0.35, 0.85, 0.55), 12, "res://sprites/icons/tree.png")
	orig_track_btn.pressed.connect(func():
		if sound_effects: sound_effects.play_click()
		if track_manager:
			track_manager.apply_original_track()
		_update_active_track_label()
		_show_temporary_banner("Originalstrecke geladen!", 2.0)
	)
	track_buttons_hbox.add_child(orig_track_btn)

	var track_select_btn = Button.new()
	track_select_btn.text = "Eigene Strecken"
	track_select_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track_select_btn.custom_minimum_size = Vector2(0, 40)
	track_select_btn.add_theme_font_size_override("font_size", 13)
	_apply_button_style(track_select_btn, Color(0.18, 0.45, 0.78), Color(0.35, 0.7, 1.0), 12, "res://sprites/icons/road_straight.png")
	track_select_btn.pressed.connect(func():
		_show_screen("track_select")
	)
	track_buttons_hbox.add_child(track_select_btn)

	card_vbox.add_child(HSeparator.new())

	# Control Mode Button
	mode_start_button = Button.new()
	mode_start_button.text = "Modus: Intuitiv"
	mode_start_button.custom_minimum_size = Vector2(0, 38)
	mode_start_button.add_theme_font_size_override("font_size", 13)
	_apply_button_style(mode_start_button, Color(0.18, 0.35, 0.55), Color(0.3, 0.55, 0.85), 12, "res://sprites/icons/steering.png")
	mode_start_button.pressed.connect(_on_toggle_control_mode)
	card_vbox.add_child(mode_start_button)

	# Big START Button
	var start_btn = Button.new()
	start_btn.text = "Rennen starten (4 Runden)"
	start_btn.custom_minimum_size = Vector2(0, 48)
	start_btn.add_theme_font_size_override("font_size", 16)
	_apply_button_style(start_btn, Color(0.18, 0.72, 0.35), Color(0.35, 0.95, 0.55), 15, "res://sprites/icons/flag_checkers.png")
	start_btn.pressed.connect(_on_start_button_pressed)
	card_vbox.add_child(start_btn)

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
	back_btn.text = "Zurück zur Streckenauswahl"
	back_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back_btn.offset_left = 18
	back_btn.offset_top = 18
	back_btn.offset_right = 240
	back_btn.offset_bottom = 66
	back_btn.add_theme_font_size_override("font_size", 14)
	_apply_button_style(back_btn, Color(0.18, 0.22, 0.35, 0.95), Color(0.45, 0.7, 1.0), 14, "res://sprites/icons/back.png")
	back_btn.pressed.connect(func():
		if track_builder:
			track_builder.close_builder()
		_show_screen("track_select")
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
	top_hbox.add_theme_constant_override("separation", 10)
	top_panel.add_child(top_hbox)

	builder_title_label = Label.new()
	builder_title_label.text = "Strecke bearbeiten"
	builder_title_label.add_theme_font_size_override("font_size", 16)
	builder_title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	top_hbox.add_child(builder_title_label)

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
			cam_view.builder_pos = Vector3(0.0, 0.0, 0.0)
	)
	top_hbox.add_child(center_btn)

	top_hbox.add_child(VSeparator.new())

	# Clear Grid
	var clear_btn = Button.new()
	clear_btn.text = "Strecke leeren"
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

	_refresh_builder_tools_for_world("forest")

func _open_builder() -> void:
	if sound_effects:
		sound_effects.play_click()
	_show_screen("builder")
	if track_builder:
		track_builder.open_builder()
		track_builder.select_road_item(6)

func _refresh_builder_tools_for_world(world_id: String) -> void:
	if not builder_road_scroll_box:
		return

	for c in builder_road_scroll_box.get_children():
		c.queue_free()
	builder_road_buttons.clear()

	var tools = []
	if world_id == "forest":
		tools = [
			{"id": 6, "type": "road", "name": "Straße (Auto-Tile)", "icon": "res://sprites/icons/road_straight.png"},
			{"id": 0, "type": "ground", "name": "Waldboden / Wiese", "icon": "res://sprites/icons/tree.png"},
			{"id": 1, "type": "ground", "name": "Wald-Gruppe", "icon": "res://sprites/icons/tree.png"},
			{"id": 2, "type": "ground", "name": "Zeltplatz", "icon": "res://sprites/icons/tree.png"},
			{"id": 5, "type": "road", "name": "Rampe", "icon": "res://sprites/icons/road_ramp.png"},
			{"id": -1, "type": "erase", "name": "Radiergummi", "icon": "res://sprites/icons/trash.png"}
		]
	else:
		tools = [
			{"id": 6, "type": "road", "name": "Straße (Auto-Tile)", "icon": "res://sprites/icons/road_straight.png"},
			{"id": 5, "type": "road", "name": "Rampe", "icon": "res://sprites/icons/road_ramp.png"},
			{"id": -1, "type": "erase", "name": "Radiergummi", "icon": "res://sprites/icons/trash.png"}
		]

	for item in tools:
		var btn = Button.new()
		btn.text = item["name"]
		btn.add_theme_font_size_override("font_size", 13)
		var t_type: String = item["type"]
		var t_id: int = item["id"]
		var t_name: String = item["name"]
		var base_col = Color(0.55, 0.2, 0.2, 0.85) if t_type == "erase" else (Color(0.18, 0.48, 0.28, 0.85) if t_type == "ground" else Color(0.2, 0.4, 0.65, 0.85))
		var border_col = Color(0.85, 0.3, 0.3) if t_type == "erase" else (Color(0.35, 0.9, 0.5) if t_type == "ground" else Color(0.35, 0.7, 1.0))
		_apply_button_style(btn, base_col, border_col, 12, item["icon"])
		btn.pressed.connect(func():
			if t_type == "erase":
				if track_builder: track_builder.select_erase_tool()
			elif t_type == "ground":
				if track_builder: track_builder.select_ground_item(t_id, t_name)
			else:
				if track_builder: track_builder.select_road_item(t_id)
			_highlight_builder_road_button(t_id)
		)
		builder_road_scroll_box.add_child(btn)
		builder_road_buttons[t_id] = btn

	_highlight_builder_road_button(6)
	_refresh_builder_props_for_world(world_id)

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
	if type_icon_rect:
		var tex = _load_icon_texture(data["icon"])
		if tex:
			type_icon_rect.texture = tex

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
	if track_select_screen:
		track_select_screen.visible = (name_str == "track_select")
		if name_str == "track_select":
			_refresh_track_select_screen()
	if name_str == "menu":
		_update_active_track_label()

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

static var _icon_cache: Dictionary = {}

static func _load_icon_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if _icon_cache.has(path):
		return _icon_cache[path]

	var tex: Texture2D = null

	# 1. Standard Godot resource load (handles imported textures and .ctex)
	if ResourceLoader.has_cached(path):
		tex = ResourceLoader.get_cached_ref(path) as Texture2D
	if not tex:
		var res = load(path)
		if res is Texture2D:
			tex = res

	# 2. Image loader fallback (handles raw PNG files in PCK or disk directly)
	if not tex and FileAccess.file_exists(path):
		var img = Image.new()
		if img.load(path) == OK and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
		else:
			var bytes = FileAccess.get_file_as_bytes(path)
			if bytes.size() > 0:
				var img2 = Image.new()
				if img2.load_png_from_buffer(bytes) == OK and not img2.is_empty():
					tex = ImageTexture.create_from_image(img2)

	if tex:
		_icon_cache[path] = tex
	return tex

func _create_icon_rect(icon_path: String, size: Vector2) -> TextureRect:
	var tr = TextureRect.new()
	if icon_path != "":
		var tex = _load_icon_texture(icon_path)
		if tex:
			tr.texture = tex
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

	if icon_path != "":
		var tex = _load_icon_texture(icon_path)
		if tex:
			btn.icon = tex
			btn.expand_icon = true
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.add_theme_constant_override("icon_max_width", 26)
			btn.add_theme_constant_override("h_separation", 8)


# ==============================================================================
# 8. TRACK SELECTION & SLOTS UI
# ==============================================================================

func _create_track_select_screen() -> void:
	track_select_screen = Control.new()
	track_select_screen.name = "TrackSelectScreen"
	track_select_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	track_select_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track_select_screen.visible = false
	root_control.add_child(track_select_screen)

	var main_panel = PanelContainer.new()
	main_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_panel.offset_left = 24
	main_panel.offset_top = 18
	main_panel.offset_right = -24
	main_panel.offset_bottom = -18
	main_panel.add_theme_stylebox_override("panel", _create_panel_style(Color(0.06, 0.09, 0.16, 0.96), Color(0.35, 0.7, 1.0, 0.9), 24, 2))
	track_select_screen.add_child(main_panel)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	main_panel.add_child(main_vbox)

	var top_bar = HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 14)
	main_vbox.add_child(top_bar)

	var back_to_menu_btn = Button.new()
	back_to_menu_btn.text = "Zurück zum Menü"
	back_to_menu_btn.custom_minimum_size = Vector2(170, 44)
	back_to_menu_btn.add_theme_font_size_override("font_size", 14)
	_apply_button_style(back_to_menu_btn, Color(0.2, 0.25, 0.4), Color(0.4, 0.6, 0.9), 14, "res://sprites/icons/back.png")
	back_to_menu_btn.pressed.connect(func(): _show_screen("menu"))
	top_bar.add_child(back_to_menu_btn)

	var title_vbox = VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(title_vbox)

	var heading = Label.new()
	heading.text = "STRECKENBAUER & EIGENE STRECKEN"
	heading.add_theme_font_size_override("font_size", 20)
	heading.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35))
	title_vbox.add_child(heading)

	track_count_label = Label.new()
	track_count_label.text = "0 / 10 Strecken gebaut"
	track_count_label.add_theme_font_size_override("font_size", 12)
	track_count_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	title_vbox.add_child(track_count_label)

	# + Button to Create New Track
	add_track_button = Button.new()
	add_track_button.text = "+ Neue Strecke"
	add_track_button.custom_minimum_size = Vector2(150, 44)
	add_track_button.add_theme_font_size_override("font_size", 14)
	_apply_button_style(add_track_button, Color(0.18, 0.72, 0.35), Color(0.35, 0.95, 0.55), 14)
	add_track_button.pressed.connect(_on_create_track_pressed)
	top_bar.add_child(add_track_button)

	var import_track_btn = Button.new()
	import_track_btn.text = "Importieren"
	import_track_btn.custom_minimum_size = Vector2(130, 44)
	import_track_btn.add_theme_font_size_override("font_size", 13)
	_apply_button_style(import_track_btn, Color(0.25, 0.35, 0.5), Color(0.45, 0.65, 0.9), 14, "res://sprites/icons/import.png")
	import_track_btn.pressed.connect(_on_global_import_pressed)
	top_bar.add_child(import_track_btn)

	main_vbox.add_child(HSeparator.new())

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	track_select_cards_box = VBoxContainer.new()
	track_select_cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track_select_cards_box.add_theme_constant_override("separation", 10)
	scroll.add_child(track_select_cards_box)

func _on_create_track_pressed() -> void:
	if sound_effects:
		sound_effects.play_click()
	if not track_manager or not track_manager.can_create_custom_track():
		_show_temporary_banner("Maximal 10 Strecken erlaubt! Lösche zuerst eine Strecke.", 2.5)
		return
	if theme_select_dialog:
		theme_select_dialog.visible = true

func _on_global_import_pressed() -> void:
	if sound_effects:
		sound_effects.play_click()
	if not track_manager or not track_manager.can_create_custom_track():
		_show_temporary_banner("Maximal 10 Strecken erlaubt! Lösche zuerst eine Strecke.", 2.5)
		return
	_show_import_dialog(0)

func _delete_custom_track_card(slot_idx: int) -> void:
	if sound_effects:
		sound_effects.play_click()
	if track_manager:
		track_manager.delete_custom_track(slot_idx)
		_show_temporary_banner("Strecke gelöscht!", 2.0)
		_refresh_track_select_screen()

func _create_theme_select_dialog() -> void:
	theme_select_dialog = Control.new()
	theme_select_dialog.name = "ThemeSelectDialog"
	theme_select_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	theme_select_dialog.visible = false
	root_control.add_child(theme_select_dialog)

	var dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.75)
	theme_select_dialog.add_child(dim)

	var card = PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -230
	card.offset_top = -140
	card.offset_right = 230
	card.offset_bottom = 140
	card.add_theme_stylebox_override("panel", _create_panel_style(Color(0.08, 0.12, 0.22, 0.98), Color(0.35, 0.75, 1.0), 22, 2))
	theme_select_dialog.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	var title = Label.new()
	title.text = "Thema für neue Strecke wählen"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	vbox.add_child(title)

	var sub = Label.new()
	sub.text = "Wähle das Thema für deinen Rundkurs.\n(Das Thema kann danach nicht mehr geändert werden)"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.8, 0.88, 1.0))
	vbox.add_child(sub)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	var forest_btn = Button.new()
	forest_btn.text = "🌲 Wald & Natur"
	forest_btn.custom_minimum_size = Vector2(170, 50)
	forest_btn.add_theme_font_size_override("font_size", 14)
	_apply_button_style(forest_btn, Color(0.18, 0.52, 0.28), Color(0.35, 0.9, 0.5), 14, "res://sprites/icons/tree.png")
	forest_btn.pressed.connect(func(): _on_theme_chosen("forest"))
	hbox.add_child(forest_btn)

	var stadium_btn = Button.new()
	stadium_btn.text = "🏟️ Stadion & Racing"
	stadium_btn.custom_minimum_size = Vector2(170, 50)
	stadium_btn.add_theme_font_size_override("font_size", 14)
	_apply_button_style(stadium_btn, Color(0.18, 0.42, 0.78), Color(0.35, 0.7, 1.0), 14, "res://sprites/icons/stadium.png")
	stadium_btn.pressed.connect(func(): _on_theme_chosen("stadium"))
	hbox.add_child(stadium_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Abbrechen"
	cancel_btn.custom_minimum_size = Vector2(120, 36)
	cancel_btn.add_theme_font_size_override("font_size", 13)
	_apply_button_style(cancel_btn, Color(0.3, 0.35, 0.45), Color(0.5, 0.6, 0.7), 12)
	cancel_btn.pressed.connect(func(): theme_select_dialog.visible = false)
	vbox.add_child(cancel_btn)

func _on_theme_chosen(theme_id: String) -> void:
	if sound_effects:
		sound_effects.play_click()
	theme_select_dialog.visible = false
	if track_manager:
		var new_idx = track_manager.create_custom_track(theme_id)
		if new_idx > 0:
			_refresh_track_select_screen()
			_open_builder_for_slot(new_idx)

func _refresh_track_select_screen() -> void:
	if not track_select_cards_box or not track_manager:
		return

	for c in track_select_cards_box.get_children():
		c.queue_free()

	if track_count_label:
		var c_count = track_manager.get_custom_track_count()
		track_count_label.text = "%d / 10 Strecken gebaut" % c_count
	if add_track_button:
		add_track_button.disabled = not track_manager.can_create_custom_track()

	var custom_count = track_manager.track_slots.size() - 1

	if custom_count <= 0:
		var empty_box = VBoxContainer.new()
		empty_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		empty_box.alignment = BoxContainer.ALIGNMENT_CENTER
		empty_box.add_theme_constant_override("separation", 10)
		track_select_cards_box.add_child(empty_box)

		var empty_lbl = Label.new()
		empty_lbl.text = "Noch keine eigenen Strecken vorhanden.\nKlicke oben auf '+ Neue Strecke', um deinen ersten Rundkurs zu bauen!"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 15)
		empty_lbl.add_theme_color_override("font_color", Color(0.65, 0.8, 0.95))
		empty_box.add_child(empty_lbl)
		return

	# Show ONLY custom tracks (slots 1..N). Original is slot 0 and managed separately.
	for slot_idx in range(1, track_manager.track_slots.size()):
		var slot: Dictionary = track_manager.track_slots[slot_idx]
		var is_active = (slot_idx == track_manager.active_slot_idx)

		var card = PanelContainer.new()
		var border_color = Color(0.3, 0.95, 0.6) if is_active else Color(0.25, 0.5, 0.8)
		var bg_color = Color(0.08, 0.16, 0.25, 0.9) if is_active else Color(0.07, 0.1, 0.18, 0.9)
		card.add_theme_stylebox_override("panel", _create_panel_style(bg_color, border_color, 16, 2 if is_active else 1))
		track_select_cards_box.add_child(card)

		var card_hbox = HBoxContainer.new()
		card_hbox.add_theme_constant_override("separation", 14)
		card.add_child(card_hbox)

		var icon_path = "res://sprites/icons/tree.png" if slot["theme"] == "forest" else "res://sprites/icons/stadium.png"
		var icon_rect = _create_icon_rect(icon_path, Vector2(48, 48))
		card_hbox.add_child(icon_rect)

		var info_vbox = VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.add_theme_constant_override("separation", 3)
		card_hbox.add_child(info_vbox)

		var name_row = HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 8)
		info_vbox.add_child(name_row)

		var slot_title = Label.new()
		slot_title.text = slot["name"]
		slot_title.add_theme_font_size_override("font_size", 16)
		slot_title.add_theme_color_override("font_color", Color.WHITE)
		name_row.add_child(slot_title)

		var theme_tag = Label.new()
		theme_tag.text = "[ %s ]" % ("WALD" if slot["theme"] == "forest" else "STADION")
		theme_tag.add_theme_font_size_override("font_size", 11)
		theme_tag.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
		name_row.add_child(theme_tag)

		if is_active:
			var active_badge = Label.new()
			active_badge.text = "✓ AKTIV"
			active_badge.add_theme_font_size_override("font_size", 11)
			active_badge.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
			name_row.add_child(active_badge)

		var desc_lbl = Label.new()
		var theme_name = "Wald & Natur" if slot["theme"] == "forest" else "Grand Prix Stadion"
		var cell_count = slot["cells"].size()
		desc_lbl.text = "Thema: %s (festgelegt)   •   %d Kacheln" % [theme_name, cell_count]
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
		info_vbox.add_child(desc_lbl)

		var btns_hbox = HBoxContainer.new()
		btns_hbox.add_theme_constant_override("separation", 6)
		card_hbox.add_child(btns_hbox)

		var s_idx := slot_idx

		var play_btn = Button.new()
		play_btn.text = "Fahren"
		play_btn.custom_minimum_size = Vector2(95, 38)
		play_btn.add_theme_font_size_override("font_size", 13)
		_apply_button_style(play_btn, Color(0.18, 0.72, 0.35), Color(0.35, 0.95, 0.55), 10, "res://sprites/icons/flag_checkers.png")
		play_btn.pressed.connect(func(): _start_race_on_slot(s_idx))
		btns_hbox.add_child(play_btn)

		var build_btn = Button.new()
		build_btn.text = "Bauen"
		build_btn.custom_minimum_size = Vector2(90, 38)
		build_btn.add_theme_font_size_override("font_size", 13)
		_apply_button_style(build_btn, Color(0.2, 0.45, 0.85), Color(0.4, 0.75, 1.0), 10, "res://sprites/icons/edit.png")
		build_btn.pressed.connect(func(): _open_builder_for_slot(s_idx))
		btns_hbox.add_child(build_btn)

		var del_btn = Button.new()
		del_btn.text = "Löschen"
		del_btn.custom_minimum_size = Vector2(85, 38)
		del_btn.add_theme_font_size_override("font_size", 12)
		_apply_button_style(del_btn, Color(0.55, 0.2, 0.2), Color(0.85, 0.3, 0.3), 10, "res://sprites/icons/trash.png")
		del_btn.pressed.connect(func(): _delete_custom_track_card(s_idx))
		btns_hbox.add_child(del_btn)

		var exp_btn = Button.new()
		exp_btn.text = "Export"
		exp_btn.custom_minimum_size = Vector2(85, 38)
		exp_btn.add_theme_font_size_override("font_size", 12)
		_apply_button_style(exp_btn, Color(0.25, 0.35, 0.5), Color(0.45, 0.65, 0.9), 10, "res://sprites/icons/export.png")
		exp_btn.pressed.connect(func(): _export_slot(s_idx))
		btns_hbox.add_child(exp_btn)

func _create_import_export_dialog() -> void:
	import_export_dialog = Control.new()
	import_export_dialog.name = "ImportExportDialog"
	import_export_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	import_export_dialog.visible = false
	root_control.add_child(import_export_dialog)

	var dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.7)
	import_export_dialog.add_child(dim)

	var card = PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -260
	card.offset_top = -180
	card.offset_right = 260
	card.offset_bottom = 180
	card.add_theme_stylebox_override("panel", _create_panel_style(Color(0.08, 0.12, 0.22, 0.98), Color(0.4, 0.75, 1.0), 22, 2))
	import_export_dialog.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	dialog_title = Label.new()
	dialog_title.text = "Strecke Exportieren"
	dialog_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog_title.add_theme_font_size_override("font_size", 18)
	dialog_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	vbox.add_child(dialog_title)

	var hint = Label.new()
	hint.text = "Kopiere diesen Streckencode oder füge einen Code ein:"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	vbox.add_child(hint)

	dialog_text_edit = TextEdit.new()
	dialog_text_edit.custom_minimum_size = Vector2(480, 160)
	dialog_text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	dialog_text_edit.add_theme_font_size_override("font_size", 12)
	vbox.add_child(dialog_text_edit)

	var btns_row = HBoxContainer.new()
	btns_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btns_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btns_row)

	dialog_action_btn = Button.new()
	dialog_action_btn.text = "Kopieren"
	dialog_action_btn.custom_minimum_size = Vector2(180, 40)
	dialog_action_btn.add_theme_font_size_override("font_size", 14)
	_apply_button_style(dialog_action_btn, Color(0.18, 0.72, 0.35), Color(0.35, 0.95, 0.55), 12, "res://sprites/icons/export.png")
	dialog_action_btn.pressed.connect(_on_dialog_action_pressed)
	btns_row.add_child(dialog_action_btn)

	var close_btn = Button.new()
	close_btn.text = "Schließen"
	close_btn.custom_minimum_size = Vector2(130, 40)
	close_btn.add_theme_font_size_override("font_size", 14)
	_apply_button_style(close_btn, Color(0.3, 0.35, 0.45), Color(0.5, 0.6, 0.75), 12)
	close_btn.pressed.connect(func(): import_export_dialog.visible = false)
	btns_row.add_child(close_btn)

func _show_export_dialog(slot_idx: int, code: String) -> void:
	current_dialog_slot = slot_idx
	is_import_mode = false
	dialog_title.text = "Strecke Exportieren"
	dialog_text_edit.text = code
	dialog_text_edit.editable = false
	dialog_action_btn.text = "In Zwischenablage kopieren"
	import_export_dialog.visible = true

func _show_import_dialog(slot_idx: int) -> void:
	current_dialog_slot = slot_idx
	is_import_mode = true
	dialog_title.text = "Neue Strecke Importieren" if slot_idx == 0 else "Strecke Importieren"
	dialog_text_edit.text = ""
	dialog_text_edit.editable = true
	dialog_text_edit.placeholder_text = "Füge hier deinen Streckencode ein..."
	dialog_action_btn.text = "Strecke Laden"
	import_export_dialog.visible = true

func _on_dialog_action_pressed() -> void:
	if is_import_mode:
		var code = dialog_text_edit.text.strip_edges()
		if code == "":
			_show_temporary_banner("Bitte Code eingeben!", 2.0)
			return
		if track_manager:
			var ok = false
			if current_dialog_slot == 0:
				var new_idx = track_manager.import_as_new_track(code)
				ok = (new_idx > 0)
			else:
				ok = track_manager.import_slot_string(current_dialog_slot, code)
			if ok:
				_show_temporary_banner("Strecke erfolgreich importiert!", 2.0)
				import_export_dialog.visible = false
				_refresh_track_select_screen()
			else:
				_show_temporary_banner("Ungültiger Streckencode oder Maximum erreicht!", 2.5)
	else:
		DisplayServer.clipboard_set(dialog_text_edit.text)
		_show_temporary_banner("Code in die Zwischenablage kopiert!", 2.0)

func _start_race_on_slot(slot_idx: int) -> void:
	if sound_effects:
		sound_effects.play_click()
	if track_manager:
		track_manager.apply_slot(slot_idx)
	_update_active_track_label()
	_show_screen("hud")
	if race_manager:
		race_manager.start_race_countdown()

func _open_builder_for_slot(slot_idx: int) -> void:
	if sound_effects:
		sound_effects.play_click()
	if track_manager:
		track_manager.apply_slot(slot_idx)
		var slot_data = track_manager.get_slot_data(slot_idx)
		builder_active_world = slot_data.get("theme", "forest")
		if builder_title_label:
			var theme_label = "Wald & Natur" if builder_active_world == "forest" else "Stadion & Racing"
			builder_title_label.text = "%s • Thema: %s" % [slot_data.get("name", "Strecke"), theme_label]
		_refresh_builder_tools_for_world(builder_active_world)
	_update_active_track_label()
	_open_builder()

func _export_slot(slot_idx: int) -> void:
	if sound_effects:
		sound_effects.play_click()
	if not track_manager:
		return
	var code = track_manager.export_slot_string(slot_idx)
	DisplayServer.clipboard_set(code)
	_show_export_dialog(slot_idx, code)
	_show_temporary_banner("Streckencode kopiert!", 2.0)

func _import_slot(slot_idx: int) -> void:
	if sound_effects:
		sound_effects.play_click()
	_show_import_dialog(slot_idx)

func _update_active_track_label() -> void:
	if active_track_label and track_manager:
		var slot = track_manager.get_active_slot_data()
		active_track_label.text = "Strecke: " + slot["name"]
