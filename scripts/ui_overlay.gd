class_name UIOverlay extends CanvasLayer

# Full In-Game UI Overlay for Kenny Racing
# - Start Screen with:
#   * Vehicle selection: Grundtyp (horizontal scroll/carousel) & Farbe (horizontal scroll/chips)
#   * World selection: 🌲 Wald, 🏟️ Stadion, 🏜️ Rallye
#   * Control mode toggle: Intuitiv / Klassisch
#   * "🏗️ Streckenbuilder & Bausätze" Modal Dialog
# - Touch Virtual Joystick (Analog Stick)
# - HUD with 4-Lap Counter and Race Timer
# - Wrong Way Warning ("Falsche Richtung! Bitte umdrehen!")
# - Countdown and Lap Announcements
# - Victory Screen with Stars, Time, and Replay Buttons

@export var race_manager: RaceManager
@export var vehicle: Vehicle
@export var sound_effects: SoundEffects
@export var track_manager: TrackManager

# Root Controls
var root_control: Control
var start_screen: Control
var hud_screen: Control
var victory_screen: Control
var builder_dialog: Control

# HUD Elements
var lap_label: Label
var time_label: Label
var wrong_way_panel: PanelContainer
var wrong_way_tween: Tween
var center_notification: Label
var virtual_joystick: VirtualJoystick
var mode_hud_button: Button

# Vehicle Selection Data
const VEHICLE_TYPES = ["truck", "racecar", "motorcycle"]
const VEHICLE_DATA = {
	"truck": {
		"name": "🚚 Racing Truck",
		"desc": "Klassischer Allround-Renn-Truck mit 4 Rädern & Drift-Reifen",
		"colors": [
			{"id": "yellow", "label": "🟡 Gelb", "color": Color(0.92, 0.82, 0.15)},
			{"id": "red", "label": "🔴 Rot", "color": Color(0.88, 0.22, 0.22)},
			{"id": "green", "label": "🟢 Grün", "color": Color(0.22, 0.8, 0.35)},
			{"id": "purple", "label": "🟣 Violett", "color": Color(0.68, 0.28, 0.88)}
		]
	},
	"racecar": {
		"name": "🏎️ Rennwagen",
		"desc": "Schneller Formel-Flitzer aus dem Kenney Racing-Kit",
		"colors": [
			{"id": "red", "label": "🔴 Rot", "color": Color(0.88, 0.22, 0.22)},
			{"id": "green", "label": "🟢 Grün", "color": Color(0.22, 0.8, 0.35)},
			{"id": "orange", "label": "🟠 Orange", "color": Color(0.95, 0.52, 0.12)},
			{"id": "white", "label": "⚪ Weiß", "color": Color(0.88, 0.9, 0.95)}
		]
	},
	"motorcycle": {
		"name": "🏍️ Motorrad",
		"desc": "Sportliches Renn-Bike mit dynamischer Schräglage",
		"colors": [
			{"id": "red", "label": "🔴 Renn-Rot", "color": Color(0.88, 0.22, 0.22)}
		]
	}
}

var current_type_idx: int = 0
var current_color_idx: int = 0

# Start Screen Nodes
var type_label: Label
var type_desc_label: Label
var color_chips_box: HBoxContainer
var color_buttons: Array[Button] = []
var world_buttons: Dictionary = {}
var mode_start_button: Button

# Builder Dialog Nodes
var builder_world_tabs: Dictionary = {}
var builder_content_box: VBoxContainer
var builder_active_world: String = "forest"

# Victory Screen Elements
var victory_time_label: Label

func _ready() -> void:
	layer = 10
	_resolve_dependencies()
	_create_ui_hierarchy()
	_connect_race_signals()
	_show_screen("menu")

func _resolve_dependencies() -> void:
	if not race_manager:
		race_manager = get_node_or_null("../RaceManager")
	if not vehicle:
		vehicle = get_node_or_null("../Vehicle")
	if not sound_effects:
		sound_effects = get_node_or_null("../SoundEffects")
	if not track_manager:
		track_manager = get_node_or_null("../TrackManager")

func _create_ui_hierarchy() -> void:
	root_control = Control.new()
	root_control.name = "RootUI"
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	_create_hud()
	_create_start_screen()
	_create_victory_screen()
	_create_builder_dialog()

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
	top_bar.offset_left = 24
	top_bar.offset_top = 20
	top_bar.offset_right = -24
	top_bar.offset_bottom = 70
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_theme_constant_override("separation", 16)
	hud_screen.add_child(top_bar)

	# Lap Badge (Runde 1 / 4)
	var lap_panel = PanelContainer.new()
	lap_panel.add_theme_stylebox_override("panel", _create_panel_style(Color(0.1, 0.15, 0.28, 0.9), Color(0.3, 0.7, 1.0), 18, 2))
	top_bar.add_child(lap_panel)

	lap_label = Label.new()
	lap_label.text = "🏁 RUNDE 1 / 4"
	lap_label.add_theme_font_size_override("font_size", 22)
	lap_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
	lap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lap_panel.add_child(lap_label)

	# Timer Badge
	var time_panel = PanelContainer.new()
	time_panel.add_theme_stylebox_override("panel", _create_panel_style(Color(0.1, 0.15, 0.28, 0.85), Color(1, 1, 1, 0.2), 18))
	top_bar.add_child(time_panel)

	time_label = Label.new()
	time_label.text = "⏱️ 00:00.00"
	time_label.add_theme_font_size_override("font_size", 20)
	time_label.add_theme_color_override("font_color", Color.WHITE)
	time_panel.add_child(time_label)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(spacer)

	# Quick Menu Button
	var menu_btn = Button.new()
	menu_btn.text = "🏠 Menü"
	menu_btn.add_theme_font_size_override("font_size", 16)
	_apply_button_style(menu_btn, Color(0.2, 0.25, 0.38, 0.85), Color(0.28, 0.35, 0.52))
	menu_btn.pressed.connect(_on_menu_button_pressed)
	top_bar.add_child(menu_btn)

	# --- WRONG WAY ALERT (Falsche Richtung!) ---
	wrong_way_panel = PanelContainer.new()
	wrong_way_panel.name = "WrongWayAlert"
	wrong_way_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	wrong_way_panel.offset_top = 85
	wrong_way_panel.offset_left = -220
	wrong_way_panel.offset_right = 220
	wrong_way_panel.offset_bottom = 155
	wrong_way_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	wrong_way_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrong_way_panel.add_theme_stylebox_override("panel", _create_panel_style(Color(0.85, 0.12, 0.12, 0.95), Color(1.0, 0.8, 0.1), 22, 3))
	hud_screen.add_child(wrong_way_panel)

	var ww_vbox = VBoxContainer.new()
	ww_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	wrong_way_panel.add_child(ww_vbox)

	var ww_title = Label.new()
	ww_title.text = "⚠️ FALSCHE RICHTUNG! ⚠️"
	ww_title.add_theme_font_size_override("font_size", 22)
	ww_title.add_theme_color_override("font_color", Color.WHITE)
	ww_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ww_vbox.add_child(ww_title)

	var ww_sub = Label.new()
	ww_sub.text = "↩️ Bitte umdrehen!"
	ww_sub.add_theme_font_size_override("font_size", 16)
	ww_sub.add_theme_color_override("font_color", Color(1.0, 0.92, 0.4))
	ww_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ww_vbox.add_child(ww_sub)

	wrong_way_panel.visible = false

	# --- CENTER NOTIFICATION (Countdown & Lap Announcements) ---
	center_notification = Label.new()
	center_notification.name = "CenterNotification"
	center_notification.set_anchors_preset(Control.PRESET_CENTER)
	center_notification.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center_notification.grow_vertical = Control.GROW_DIRECTION_BOTH
	center_notification.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_notification.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_notification.add_theme_font_size_override("font_size", 64)
	center_notification.add_theme_color_override("font_color", Color(1.0, 0.95, 0.2))
	center_notification.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.2))
	center_notification.add_theme_constant_override("outline_size", 10)
	center_notification.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_screen.add_child(center_notification)

	# --- VIRTUAL JOYSTICK (Bottom-Left) ---
	virtual_joystick = VirtualJoystick.new()
	virtual_joystick.name = "VirtualJoystick"
	virtual_joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	virtual_joystick.offset_left = 60
	virtual_joystick.offset_bottom = -60
	virtual_joystick.offset_top = -260
	virtual_joystick.offset_right = 260
	virtual_joystick.analog_moved.connect(_on_joystick_moved)
	virtual_joystick.analog_released.connect(_on_joystick_released)
	hud_screen.add_child(virtual_joystick)

	# --- ACTION BUTTONS (Bottom-Right) ---
	var action_box = VBoxContainer.new()
	action_box.name = "ActionButtons"
	action_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	action_box.offset_right = -40
	action_box.offset_bottom = -40
	action_box.offset_left = -230
	action_box.offset_top = -170
	action_box.add_theme_constant_override("separation", 12)
	hud_screen.add_child(action_box)

	# Respawn Button ("Auto zurücksetzen")
	var respawn_btn = Button.new()
	respawn_btn.text = "🔄 Auto zurücksetzen"
	respawn_btn.add_theme_font_size_override("font_size", 16)
	_apply_button_style(respawn_btn, Color(0.9, 0.42, 0.15, 0.9), Color(1.0, 0.55, 0.25))
	respawn_btn.pressed.connect(_on_respawn_pressed)
	action_box.add_child(respawn_btn)

	# Control Mode Toggle Button
	mode_hud_button = Button.new()
	mode_hud_button.text = "🕹️ Modus: Intuitiv"
	mode_hud_button.add_theme_font_size_override("font_size", 15)
	_apply_button_style(mode_hud_button, Color(0.2, 0.55, 0.85, 0.85), Color(0.3, 0.65, 0.95))
	mode_hud_button.pressed.connect(_on_toggle_control_mode)
	action_box.add_child(mode_hud_button)

# ==============================================================================
# 2. START SCREEN CREATION (Vehicle & World Selection)
# ==============================================================================

func _create_start_screen() -> void:
	start_screen = Control.new()
	start_screen.name = "StartScreen"
	start_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(start_screen)

	# Dimmed backdrop
	var bg_dim = ColorRect.new()
	bg_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_dim.color = Color(0.05, 0.08, 0.15, 0.65)
	start_screen.add_child(bg_dim)

	# Main Card with ScrollContainer for perfect responsiveness
	var card = PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -310
	card.offset_top = -320
	card.offset_right = 310
	card.offset_bottom = 320
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	card.add_theme_stylebox_override("panel", _create_panel_style(Color(0.1, 0.14, 0.24, 0.96), Color(0.35, 0.7, 1.0, 0.9), 26, 3))
	start_screen.add_child(card)

	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)

	var card_vbox = VBoxContainer.new()
	card_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(card_vbox)

	# Title
	var title = Label.new()
	title.text = "🏎️ KENNY RACING"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.3))
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.2))
	title.add_theme_constant_override("outline_size", 6)
	card_vbox.add_child(title)

	# Subtitle
	var sub = Label.new()
	sub.text = "🌟 Belohnungsspiel für clevere Rennfahrerinnen! 🌟"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	card_vbox.add_child(sub)

	# Goal Badge
	var goal_lbl = Label.new()
	goal_lbl.text = "🏆 Ziel: 4 Runden meistern & gewinnen!"
	goal_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goal_lbl.add_theme_font_size_override("font_size", 14)
	goal_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	card_vbox.add_child(goal_lbl)

	card_vbox.add_child(HSeparator.new())

	# --------------------------------------------------------------------------
	# A) FAHRZEUGAUSWAHL: GRUNDTYP (Seitlicher Scroll / Karussell)
	# --------------------------------------------------------------------------
	var v_header = Label.new()
	v_header.text = "1. Fahrzeug-Typ wählen (Seitlich scrollen):"
	v_header.add_theme_font_size_override("font_size", 15)
	v_header.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	card_vbox.add_child(v_header)

	var type_carousel = HBoxContainer.new()
	type_carousel.alignment = BoxContainer.ALIGNMENT_CENTER
	type_carousel.add_theme_constant_override("separation", 10)
	card_vbox.add_child(type_carousel)

	var prev_type_btn = Button.new()
	prev_type_btn.text = "◀"
	prev_type_btn.add_theme_font_size_override("font_size", 18)
	_apply_button_style(prev_type_btn, Color(0.2, 0.35, 0.55), Color(0.35, 0.6, 0.9), 14)
	prev_type_btn.pressed.connect(_on_prev_vehicle_type)
	type_carousel.add_child(prev_type_btn)

	var type_panel = PanelContainer.new()
	type_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_panel.add_theme_stylebox_override("panel", _create_panel_style(Color(0.15, 0.22, 0.36, 0.9), Color(0.3, 0.65, 0.95), 16, 2))
	type_carousel.add_child(type_panel)

	var type_inner_vbox = VBoxContainer.new()
	type_panel.add_child(type_inner_vbox)

	type_label = Label.new()
	type_label.text = "🚚 Racing Truck"
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 18)
	type_label.add_theme_color_override("font_color", Color.WHITE)
	type_inner_vbox.add_child(type_label)

	type_desc_label = Label.new()
	type_desc_label.text = "Klassischer Allround-Renn-Truck"
	type_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_desc_label.add_theme_font_size_override("font_size", 12)
	type_desc_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	type_inner_vbox.add_child(type_desc_label)

	var next_type_btn = Button.new()
	next_type_btn.text = "▶"
	next_type_btn.add_theme_font_size_override("font_size", 18)
	_apply_button_style(next_type_btn, Color(0.2, 0.35, 0.55), Color(0.35, 0.6, 0.9), 14)
	next_type_btn.pressed.connect(_on_next_vehicle_type)
	type_carousel.add_child(next_type_btn)

	# --------------------------------------------------------------------------
	# B) FAHRZEUGAUSWAHL: FARBE (Horizontaler Scroll / Chips)
	# --------------------------------------------------------------------------
	var color_header = Label.new()
	color_header.text = "2. Farbe wählen:"
	color_header.add_theme_font_size_override("font_size", 14)
	color_header.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	card_vbox.add_child(color_header)

	var color_scroll = ScrollContainer.new()
	color_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	color_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	color_scroll.custom_minimum_size = Vector2(0, 48)
	card_vbox.add_child(color_scroll)

	color_chips_box = HBoxContainer.new()
	color_chips_box.alignment = BoxContainer.ALIGNMENT_CENTER
	color_chips_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_chips_box.add_theme_constant_override("separation", 8)
	color_scroll.add_child(color_chips_box)

	_refresh_vehicle_display()

	card_vbox.add_child(HSeparator.new())

	# --------------------------------------------------------------------------
	# C) WELTAUSWAHL (STRECKE & BAUSATZ-WELT)
	# --------------------------------------------------------------------------
	var world_header = Label.new()
	world_header.text = "3. Rennwelt & Strecke:"
	world_header.add_theme_font_size_override("font_size", 14)
	world_header.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	card_vbox.add_child(world_header)

	var world_hbox = HBoxContainer.new()
	world_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	world_hbox.add_theme_constant_override("separation", 8)
	card_vbox.add_child(world_hbox)

	var worlds = [
		{"id": "forest", "label": "🌲 Wald", "col": Color(0.2, 0.6, 0.3)},
		{"id": "stadium", "label": "🏟️ Stadion", "col": Color(0.2, 0.5, 0.85)},
		{"id": "rally", "label": "🏜️ Rallye", "col": Color(0.85, 0.5, 0.15)}
	]

	for w in worlds:
		var w_btn = Button.new()
		w_btn.text = w["label"]
		w_btn.add_theme_font_size_override("font_size", 14)
		_apply_button_style(w_btn, w["col"] * 0.8, w["col"], 14)
		var wid: String = w["id"]
		w_btn.pressed.connect(func(): _select_world(wid))
		world_hbox.add_child(w_btn)
		world_buttons[wid] = w_btn

	_highlight_selected_world_button("forest")

	# Streckenbuilder / Bausätze Button
	var builder_btn = Button.new()
	builder_btn.text = "🏗️ Streckenbuilder & Bausätze ansehen"
	builder_btn.add_theme_font_size_override("font_size", 14)
	_apply_button_style(builder_btn, Color(0.25, 0.35, 0.52), Color(0.45, 0.65, 0.95), 14)
	builder_btn.pressed.connect(_open_builder_dialog)
	card_vbox.add_child(builder_btn)

	card_vbox.add_child(HSeparator.new())

	# Control Mode Button
	mode_start_button = Button.new()
	mode_start_button.text = "🕹️ Steuerung: Intuitiv (Stick zeigt Richtung)"
	mode_start_button.add_theme_font_size_override("font_size", 14)
	_apply_button_style(mode_start_button, Color(0.18, 0.45, 0.75), Color(0.3, 0.65, 0.95), 14)
	mode_start_button.pressed.connect(_on_toggle_control_mode)
	card_vbox.add_child(mode_start_button)

	# Big START Button
	var start_btn = Button.new()
	start_btn.text = "▶️ JETZT SPIELEN!"
	start_btn.add_theme_font_size_override("font_size", 22)
	_apply_button_style(start_btn, Color(0.18, 0.78, 0.42), Color(0.35, 0.95, 0.55), 20)
	start_btn.pressed.connect(_on_start_button_pressed)
	card_vbox.add_child(start_btn)

# ==============================================================================
# 3. STRECKENBUILDER & BAUSÄTZE MODAL DIALOG
# ==============================================================================

func _create_builder_dialog() -> void:
	builder_dialog = Control.new()
	builder_dialog.name = "BuilderDialog"
	builder_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	builder_dialog.visible = false
	root_control.add_child(builder_dialog)

	# Dark backdrop
	var bg_dim = ColorRect.new()
	bg_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_dim.color = Color(0.04, 0.06, 0.12, 0.85)
	builder_dialog.add_child(bg_dim)

	# Modal Card
	var card = PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -340
	card.offset_top = -290
	card.offset_right = 340
	card.offset_bottom = 290
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	card.add_theme_stylebox_override("panel", _create_panel_style(Color(0.1, 0.14, 0.24, 0.98), Color(0.4, 0.75, 1.0), 24, 3))
	builder_dialog.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "🏗️ STRECKENBUILDER & BAUSÄTZE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	vbox.add_child(title)

	var desc = Label.new()
	desc.text = "Wähle eine Welt, um die unterschiedlichen Bausätze und Bauteile zu sehen:"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
	vbox.add_child(desc)

	# World Tabs
	var tabs_box = HBoxContainer.new()
	tabs_box.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs_box.add_theme_constant_override("separation", 8)
	vbox.add_child(tabs_box)

	var tab_defs = [
		{"id": "forest", "label": "🌲 Wald & Natur"},
		{"id": "stadium", "label": "🏟️ Grand Prix Stadion"},
		{"id": "rally", "label": "🏜️ Wüsten-Rallye"}
	]

	for t in tab_defs:
		var tab_btn = Button.new()
		tab_btn.text = t["label"]
		tab_btn.add_theme_font_size_override("font_size", 14)
		var tid: String = t["id"]
		tab_btn.pressed.connect(func(): _show_builder_world(tid))
		tabs_box.add_child(tab_btn)
		builder_world_tabs[tid] = tab_btn

	vbox.add_child(HSeparator.new())

	# Scrollable Kit Content
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	builder_content_box = VBoxContainer.new()
	builder_content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	builder_content_box.add_theme_constant_override("separation", 12)
	scroll.add_child(builder_content_box)

	vbox.add_child(HSeparator.new())

	# Action Buttons
	var action_hbox = HBoxContainer.new()
	action_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	action_hbox.add_theme_constant_override("separation", 14)
	vbox.add_child(action_hbox)

	var apply_world_btn = Button.new()
	apply_world_btn.text = "🏁 In dieser Welt fahren!"
	apply_world_btn.add_theme_font_size_override("font_size", 16)
	_apply_button_style(apply_world_btn, Color(0.2, 0.72, 0.4), Color(0.35, 0.9, 0.55), 16)
	apply_world_btn.pressed.connect(_on_builder_drive_in_world)
	action_hbox.add_child(apply_world_btn)

	var close_btn = Button.new()
	close_btn.text = "✕ Schließen"
	close_btn.add_theme_font_size_override("font_size", 16)
	_apply_button_style(close_btn, Color(0.3, 0.35, 0.48), Color(0.45, 0.52, 0.65), 16)
	close_btn.pressed.connect(_close_builder_dialog)
	action_hbox.add_child(close_btn)

	_show_builder_world("forest")

func _show_builder_world(world_id: String) -> void:
	builder_active_world = world_id

	for wid in builder_world_tabs:
		var btn: Button = builder_world_tabs[wid]
		if wid == world_id:
			_apply_button_style(btn, Color(0.25, 0.6, 0.95), Color(0.45, 0.85, 1.0), 14)
		else:
			_apply_button_style(btn, Color(0.18, 0.25, 0.38), Color(0.3, 0.4, 0.55), 14)

	# Populate kits
	for c in builder_content_box.get_children():
		c.queue_free()

	if not TrackManager.WORLDS_INFO.has(world_id):
		return
	var winfo = TrackManager.WORLDS_INFO[world_id]

	var header_lbl = Label.new()
	header_lbl.text = winfo["tagline"]
	header_lbl.add_theme_font_size_override("font_size", 13)
	header_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5))
	builder_content_box.add_child(header_lbl)

	for kit in winfo["kits"]:
		var kit_panel = PanelContainer.new()
		kit_panel.add_theme_stylebox_override("panel", _create_panel_style(Color(0.14, 0.2, 0.32, 0.85), Color(0.3, 0.55, 0.85), 16, 2))
		builder_content_box.add_child(kit_panel)

		var kvbox = VBoxContainer.new()
		kvbox.add_theme_constant_override("separation", 6)
		kit_panel.add_child(kvbox)

		var k_title = Label.new()
		k_title.text = kit["category"] + " — " + kit["description"]
		k_title.add_theme_font_size_override("font_size", 14)
		k_title.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0))
		kvbox.add_child(k_title)

		for item in kit["items"]:
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			kvbox.add_child(row)

			var dot = Label.new()
			dot.text = "•"
			dot.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
			row.add_child(dot)

			var iname = Label.new()
			iname.text = item["name"]
			iname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			iname.add_theme_font_size_override("font_size", 13)
			row.add_child(iname)

			var isize = Label.new()
			isize.text = item["size"]
			isize.add_theme_font_size_override("font_size", 12)
			isize.add_theme_color_override("font_color", Color(0.65, 0.75, 0.9))
			row.add_child(isize)

func _open_builder_dialog() -> void:
	if sound_effects:
		sound_effects.play_click()
	builder_dialog.visible = true
	_show_builder_world(builder_active_world)

func _close_builder_dialog() -> void:
	if sound_effects:
		sound_effects.play_click()
	builder_dialog.visible = false

func _on_builder_drive_in_world() -> void:
	if sound_effects:
		sound_effects.play_click()
	builder_dialog.visible = false
	_select_world(builder_active_world)
	_on_start_button_pressed()

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
	card.offset_top = -220
	card.offset_right = 280
	card.offset_bottom = 220
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	card.add_theme_stylebox_override("panel", _create_panel_style(Color(0.1, 0.15, 0.28, 0.96), Color(1.0, 0.85, 0.2), 26, 4))
	victory_screen.add_child(card)

	var v_vbox = VBoxContainer.new()
	v_vbox.add_theme_constant_override("separation", 14)
	card.add_child(v_vbox)

	var win_title = Label.new()
	win_title.text = "🎉 SUPER GEMACHT! 🏆"
	win_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_title.add_theme_font_size_override("font_size", 30)
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

	var stars = Label.new()
	stars.text = "⭐⭐⭐"
	stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars.add_theme_font_size_override("font_size", 42)
	v_vbox.add_child(stars)

	victory_time_label = Label.new()
	victory_time_label.text = "⏱️ Deine Zeit: 01:25.00"
	victory_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory_time_label.add_theme_font_size_override("font_size", 20)
	victory_time_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	v_vbox.add_child(victory_time_label)

	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 14)
	v_vbox.add_child(btn_hbox)

	var replay_btn = Button.new()
	replay_btn.text = "🔄 Nochmal spielen"
	replay_btn.add_theme_font_size_override("font_size", 18)
	_apply_button_style(replay_btn, Color(0.2, 0.65, 0.95), Color(0.35, 0.8, 1.0))
	replay_btn.pressed.connect(_on_start_button_pressed)
	btn_hbox.add_child(replay_btn)

	var main_menu_btn = Button.new()
	main_menu_btn.text = "🏠 Hauptmenü"
	main_menu_btn.add_theme_font_size_override("font_size", 18)
	_apply_button_style(main_menu_btn, Color(0.25, 0.3, 0.45), Color(0.35, 0.42, 0.6))
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
	race_manager.wrong_way_toggled.connect(_on_wrong_way_toggled)
	race_manager.race_finished.connect(_on_race_finished)

func _process(_delta: float) -> void:
	if race_manager and race_manager.current_state == RaceManager.GameState.RACING:
		time_label.text = "⏱️ " + race_manager.format_time(race_manager.race_time)

func _show_screen(name_str: String) -> void:
	start_screen.visible = (name_str == "menu")
	hud_screen.visible = (name_str == "hud")
	victory_screen.visible = (name_str == "victory")

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

	var label_start = "🕹️ Steuerung: Intuitiv (Stick zeigt Richtung)" if is_direct else "🕹️ Steuerung: Klassisch (Gas & Lenken)"
	var label_hud = "🕹️ Modus: Intuitiv" if is_direct else "🕹️ Modus: Klassisch"

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

func _on_lap_updated(cur_lap: int, total: int) -> void:
	lap_label.text = "🏁 RUNDE %d / %d" % [cur_lap, total]

	if cur_lap > 1:
		var txt = "🎉 RUNDE %d / %d!" % [cur_lap, total]
		if cur_lap == total:
			txt = "🔥 LETZTE RUNDE (%d / %d)!" % [cur_lap, total]
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

func _on_wrong_way_toggled(is_wrong: bool) -> void:
	if wrong_way_panel:
		wrong_way_panel.visible = is_wrong
		if is_wrong:
			if wrong_way_tween and wrong_way_tween.is_valid():
				wrong_way_tween.kill()
			wrong_way_tween = create_tween().set_loops()
			wrong_way_tween.tween_property(wrong_way_panel, "modulate:a", 0.4, 0.35)
			wrong_way_tween.tween_property(wrong_way_panel, "modulate:a", 1.0, 0.35)
		else:
			if wrong_way_tween and wrong_way_tween.is_valid():
				wrong_way_tween.kill()
			wrong_way_panel.modulate.a = 1.0

func _on_race_finished(total_time: float) -> void:
	_show_screen("victory")
	if victory_time_label and race_manager:
		victory_time_label.text = "⏱️ Deine Zeit: " + race_manager.format_time(total_time)

# ==============================================================================
# 7. UI STYLING HELPERS
# ==============================================================================

func _create_panel_style(bg: Color, border: Color = Color.TRANSPARENT, radius: int = 18, border_w: int = 2) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	if border != Color.TRANSPARENT:
		sb.border_width_left = border_w
		sb.border_width_top = border_w
		sb.border_width_right = border_w
		sb.border_width_bottom = border_w
		sb.border_color = border
	return sb

func _apply_button_style(btn: Button, bg: Color, border: Color = Color.TRANSPARENT, radius: int = 16) -> void:
	var normal_sb = _create_panel_style(bg, border, radius, 2)
	var hover_sb = _create_panel_style(bg.lightened(0.15), border.lightened(0.2), radius, 2)
	var pressed_sb = _create_panel_style(bg.darkened(0.15), border.darkened(0.1), radius, 2)

	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.8))
	btn.add_theme_color_override("font_pressed_color", Color(0.85, 0.85, 0.85))
