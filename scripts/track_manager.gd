class_name TrackManager extends Node

# Track and World Manager for Kenny Racing
# - Manages thematic Worlds: Forest (Standard), Stadium (Racing), and Rally
# - Manages Track Slots:
#     - Slot 0: "Original (Standard)" - Read-only / Immutable default circuit
#     - Slot 1..3: Custom track slots with builder, theme toggle, delete, import & export
# - Saves custom tracks to user://custom_tracks.json
# - Dynamically updates 3D World Scenery, Lighting, and Decoration

signal world_changed(world_id: String)
signal track_slot_applied(slot_idx: int, slot_data: Dictionary)
signal track_slots_updated()

enum WorldTheme { FOREST = 0, STADIUM = 1, RALLY = 2 }

@export var current_world: WorldTheme = WorldTheme.FOREST
@export var grid_map: GridMap
@export var sun_light: DirectionalLight3D
@export var environment: WorldEnvironment

var scenery_root: Node3D
var active_world_id: String = "forest"
var spectator_trucks: Array[Node3D] = []

const SLOTS_SAVE_PATH = "user://custom_tracks.json"

# The immutable 16-cell Original circuit
const DEFAULT_ORIGINAL_CELLS: Array = [
	{"x": -3, "z": 0, "item": 0, "orient": 0},
	{"x": -3, "z": 1, "item": 1, "orient": 22},
	{"x": -3, "z": 2, "item": 1, "orient": 16},
	{"x": 1, "z": -1, "item": 1, "orient": 10},
	{"x": 1, "z": 0, "item": 1, "orient": 10},
	{"x": 1, "z": 1, "item": 1, "orient": 10},
	{"x": 1, "z": 2, "item": 0, "orient": 0},
	{"x": 1, "z": 3, "item": 1, "orient": 10},
	{"x": 0, "z": 3, "item": 0, "orient": 0},
	{"x": -1, "z": 3, "item": 1, "orient": 10},
	{"x": -2, "z": 3, "item": 1, "orient": 10},
	{"x": -3, "z": 3, "item": 1, "orient": 10},
	{"x": -4, "z": -2, "item": 2, "orient": 10},
	{"x": -4, "z": -1, "item": 0, "orient": 0},
	{"x": -4, "z": -4, "item": 1, "orient": 10},
	{"x": -4, "z": -3, "item": 1, "orient": 16},
	{"x": -3, "z": -4, "item": 1, "orient": 10},
	{"x": -2, "z": -4, "item": 1, "orient": 10},
	{"x": -1, "z": -4, "item": 2, "orient": 22},
	{"x": 0, "z": -4, "item": 1, "orient": 10},
	{"x": 1, "z": -4, "item": 1, "orient": 10},
	{"x": 1, "z": -3, "item": 1, "orient": 10},
	{"x": 1, "z": -2, "item": 1, "orient": 10},
	{"x": -4, "z": 0, "item": 1, "orient": 16},
	{"x": -4, "z": 1, "item": 1, "orient": 16},
	{"x": -4, "z": 2, "item": 0, "orient": 16},
	{"x": -4, "z": 3, "item": 0, "orient": 0},
	{"x": -4, "z": 4, "item": 1, "orient": 10},
	{"x": -3, "z": 4, "item": 0, "orient": 0},
	{"x": -2, "z": 4, "item": 1, "orient": 10},
	{"x": -1, "z": 4, "item": 1, "orient": 10},
	{"x": 0, "z": 4, "item": 1, "orient": 10},
	{"x": 1, "z": 4, "item": 1, "orient": 10},
	{"x": 2, "z": 4, "item": 1, "orient": 10},
	{"x": 2, "z": 3, "item": 1, "orient": 10},
	{"x": 2, "z": 2, "item": 1, "orient": 10},
	{"x": 2, "z": 1, "item": 1, "orient": 10},
	{"x": 2, "z": 0, "item": 1, "orient": 10},
	{"x": 2, "z": -1, "item": 1, "orient": 10},
	{"x": 2, "z": -2, "item": 0, "orient": 0},
	{"x": 2, "z": -3, "item": 1, "orient": 10},
	{"x": 2, "z": -4, "item": 1, "orient": 10},
	{"x": 2, "z": -5, "item": 1, "orient": 10},
	{"x": 1, "z": -5, "item": 1, "orient": 10},
	{"x": 0, "z": -5, "item": 1, "orient": 10},
	{"x": 0, "z": -6, "item": 0, "orient": 0},
	{"x": -1, "z": -6, "item": 1, "orient": 10},
	{"x": -1, "z": -5, "item": 1, "orient": 10},
	{"x": -2, "z": -5, "item": 1, "orient": 10},
	{"x": -3, "z": -5, "item": 0, "orient": 0},
	{"x": -4, "z": -5, "item": 1, "orient": 10},
	{"x": -4, "z": -6, "item": 0, "orient": 0},
	{"x": -3, "z": -6, "item": 0, "orient": 0},
	{"x": -2, "z": -6, "item": 0, "orient": 0},
	{"x": 1, "z": -6, "item": 1, "orient": 10},
	{"x": 2, "z": -6, "item": 1, "orient": 10},
	{"x": -5, "z": 4, "item": 1, "orient": 10},
	{"x": -5, "z": 3, "item": 0, "orient": 0},
	{"x": -5, "z": 2, "item": 0, "orient": 16},
	{"x": -5, "z": 1, "item": 0, "orient": 16},
	{"x": -5, "z": 0, "item": 1, "orient": 16},
	{"x": -5, "z": -1, "item": 0, "orient": 16},
	{"x": -5, "z": -2, "item": 1, "orient": 10},
	{"x": -5, "z": -3, "item": 0, "orient": 16},
	{"x": -5, "z": -4, "item": 0, "orient": 0},
	{"x": -5, "z": -5, "item": 1, "orient": 10},
	{"x": -5, "z": -6, "item": 1, "orient": 10},
	{"x": -6, "z": -6, "item": 0, "orient": 0},
	{"x": -6, "z": -5, "item": 1, "orient": 10},
	{"x": -6, "z": -4, "item": 0, "orient": 0},
	{"x": -6, "z": -3, "item": 0, "orient": 16},
	{"x": -6, "z": -2, "item": 0, "orient": 16},
	{"x": -6, "z": -1, "item": 0, "orient": 16},
	{"x": -6, "z": 0, "item": 1, "orient": 10},
	{"x": -6, "z": 1, "item": 1, "orient": 10},
	{"x": -6, "z": 2, "item": 1, "orient": 10},
	{"x": -6, "z": 3, "item": 1, "orient": 10},
	{"x": -6, "z": 4, "item": 1, "orient": 10},
	{"x": -6, "z": -7, "item": 1, "orient": 10},
	{"x": -5, "z": -7, "item": 1, "orient": 10},
	{"x": -4, "z": -7, "item": 0, "orient": 0},
	{"x": -3, "z": -7, "item": 0, "orient": 0},
	{"x": -2, "z": -7, "item": 1, "orient": 10},
	{"x": -1, "z": -7, "item": 1, "orient": 10},
	{"x": 0, "z": -7, "item": 1, "orient": 10},
	{"x": 1, "z": -7, "item": 1, "orient": 10},
	{"x": 2, "z": -7, "item": 1, "orient": 10},
	{"x": 2, "z": -8, "item": 1, "orient": 10},
	{"x": 1, "z": -8, "item": 1, "orient": 10},
	{"x": 0, "z": -8, "item": 1, "orient": 10},
	{"x": -1, "z": -8, "item": 1, "orient": 10},
	{"x": -2, "z": -8, "item": 1, "orient": 10},
	{"x": -3, "z": -8, "item": 1, "orient": 10},
	{"x": -4, "z": -8, "item": 1, "orient": 10},
	{"x": -5, "z": -8, "item": 1, "orient": 10},
	{"x": -6, "z": -8, "item": 1, "orient": 10},
	{"x": -7, "z": -8, "item": 1, "orient": 10},
	{"x": -7, "z": -7, "item": 1, "orient": 10},
	{"x": -7, "z": -6, "item": 1, "orient": 10},
	{"x": -7, "z": -5, "item": 1, "orient": 10},
	{"x": -7, "z": -4, "item": 1, "orient": 10},
	{"x": -7, "z": -3, "item": 1, "orient": 10},
	{"x": -7, "z": -2, "item": 1, "orient": 10},
	{"x": -7, "z": -1, "item": 1, "orient": 10},
	{"x": -7, "z": 0, "item": 1, "orient": 10},
	{"x": -7, "z": 1, "item": 1, "orient": 10},
	{"x": -7, "z": 2, "item": 1, "orient": 10},
	{"x": -7, "z": 3, "item": 1, "orient": 10},
	{"x": -7, "z": 4, "item": 1, "orient": 10},
	{"x": -8, "z": 4, "item": 1, "orient": 10},
	{"x": -8, "z": 3, "item": 1, "orient": 10},
	{"x": -8, "z": 2, "item": 1, "orient": 10},
	{"x": -8, "z": 1, "item": 1, "orient": 10},
	{"x": -8, "z": 0, "item": 1, "orient": 10},
	{"x": -8, "z": -1, "item": 1, "orient": 10},
	{"x": -8, "z": -2, "item": 1, "orient": 10},
	{"x": -8, "z": -3, "item": 1, "orient": 10},
	{"x": -8, "z": -4, "item": 1, "orient": 10},
	{"x": -8, "z": -5, "item": 1, "orient": 10},
	{"x": -8, "z": -6, "item": 1, "orient": 10},
	{"x": -8, "z": -7, "item": 1, "orient": 10},
	{"x": -8, "z": -8, "item": 1, "orient": 10},
	{"x": -8, "z": -9, "item": 1, "orient": 10},
	{"x": -7, "z": -9, "item": 1, "orient": 10},
	{"x": -6, "z": -9, "item": 1, "orient": 10},
	{"x": -5, "z": -9, "item": 1, "orient": 10},
	{"x": -4, "z": -9, "item": 1, "orient": 10},
	{"x": -3, "z": -9, "item": 1, "orient": 10},
	{"x": -2, "z": -9, "item": 1, "orient": 10},
	{"x": -1, "z": -9, "item": 1, "orient": 10},
	{"x": 0, "z": -9, "item": 1, "orient": 10},
	{"x": 1, "z": -9, "item": 1, "orient": 10},
	{"x": 2, "z": -9, "item": 1, "orient": 10},
	{"x": -1, "z": -1, "item": 1, "orient": 22},
	{"x": -1, "z": -2, "item": 1, "orient": 22},
	{"x": -2, "z": -2, "item": 1, "orient": 22},
	{"x": -1, "z": 1, "item": 2, "orient": 22},
	{"x": -1, "z": 0, "item": 1, "orient": 22},
	{"x": 0, "z": 0, "item": 4, "orient": 0},
	{"x": 0, "z": -1, "item": 6, "orient": 0},
	{"x": -2, "z": 0, "item": 6, "orient": 10},
	{"x": -2, "z": 1, "item": 6, "orient": 10},
	{"x": -3, "z": -2, "item": 6, "orient": 0},
	{"x": -2, "z": -3, "item": 6, "orient": 22},
	{"x": -1, "z": -3, "item": 6, "orient": 22},
	{"x": 0, "z": -2, "item": 6, "orient": 0},
	{"x": -1, "z": 2, "item": 6, "orient": 16},
	{"x": -3, "z": -3, "item": 3, "orient": 16},
	{"x": -3, "z": -1, "item": 3, "orient": 10},
	{"x": -2, "z": -1, "item": 3, "orient": 0},
	{"x": 0, "z": -3, "item": 3, "orient": 0},
	{"x": 0, "z": 2, "item": 3, "orient": 22},
	{"x": -2, "z": 2, "item": 3, "orient": 10},
	{"x": 0, "z": 1, "item": 6, "orient": 0},
]

var track_slots: Array = []
var active_slot_idx: int = 0

# Definition of the Worlds and their Building Kits (Bausätze)
const WORLDS_INFO = {
	"forest": {
		"name": "Wald & Natur (Standard)",
		"tagline": "Grüne Rundstrecke im Wald mit Campingzelten und Baumreihen",
		"sun_color": Color(1.0, 0.98, 0.92),
		"sun_energy": 0.85,
		"ambient_color": Color(0.24, 0.28, 0.25),
		"kits": [
			{
				"category": "Straßen & Fahrbahn",
				"description": "Klassischer Asphalt mit rot-weißen Randsteinen",
				"items": [
					{"id": "track-finish", "name": "Start- / Ziellinie mit Bogen", "size": "10 x 10 m", "path": "res://models/track-finish.glb"},
					{"id": "track-straight", "name": "Gerade Strecke", "size": "10 x 10 m", "path": "res://models/track-straight.glb"},
					{"id": "track-corner", "name": "90°-Kurve", "size": "10 x 10 m", "path": "res://models/track-corner.glb"},
					{"id": "track-bump", "name": "Bodenwelle", "size": "10 x 10 m", "path": "res://models/track-bump.glb"}
				]
			},
			{
				"category": "Bäume & Vegetation",
				"description": "Dichte Tannen, Laubbäume und Gras",
				"items": [
					{"id": "decoration-forest", "name": "Wald-Gruppe", "size": "10 x 10 m", "path": "res://models/decoration-forest.glb"},
					{"id": "treeLarge", "name": "Großer Laubbaum", "size": "3 x 3 m", "path": "res://kenney_racing-kit/Models/GLTF format/treeLarge.glb"},
					{"id": "treeSmall", "name": "Kleiner Baum", "size": "2 x 2 m", "path": "res://kenney_racing-kit/Models/GLTF format/treeSmall.glb"},
					{"id": "grass", "name": "Grasbüschel", "size": "1 x 1 m", "path": "res://kenney_racing-kit/Models/GLTF format/grass.glb"}
				]
			},
			{
				"category": "Camping & Zeltlager",
				"description": "Zuschauer-Zelte und Campingerlebnis",
				"items": [
					{"id": "decoration-tents", "name": "Zeltplatz-Kachel", "size": "10 x 10 m", "path": "res://models/decoration-tents.glb"},
					{"id": "tent", "name": "Einzelzelt", "size": "2 x 2 m", "path": "res://kenney_racing-kit/Models/GLTF format/tent.glb"},
					{"id": "tentLong", "name": "Großraumzelt", "size": "2 x 4 m", "path": "res://kenney_racing-kit/Models/GLTF format/tentLong.glb"}
				]
			}
		]
	},
	"stadium": {
		"name": "Grand Prix Stadion (Racing)",
		"tagline": "Motorsport-Arena mit Tribünen, Boxengasse, Flutlicht und Anzeigetafeln",
		"sun_color": Color(0.98, 0.98, 1.0),
		"sun_energy": 0.85,
		"ambient_color": Color(0.26, 0.28, 0.34),
		"kits": [
			{
				"category": "GP-Strecke & Boxengasse",
				"description": "Professioneller Streckenteppich und Boxenausfahrt",
				"items": [
					{"id": "roadStartPositions", "name": "Startaufstellung-Grid", "size": "10 x 10 m", "path": "res://kenney_racing-kit/Models/GLTF format/roadStartPositions.glb"},
					{"id": "roadPitStraight", "name": "Boxengassen-Gerade", "size": "10 x 10 m", "path": "res://kenney_racing-kit/Models/GLTF format/roadPitStraight.glb"},
					{"id": "roadStraightBridge", "name": "Brücken-Fahrbahn", "size": "10 x 10 m", "path": "res://kenney_racing-kit/Models/GLTF format/roadStraightBridge.glb"},
					{"id": "overheadRoundColored", "name": "Überkopf-Startbrücke", "size": "6 x 10 m", "path": "res://kenney_racing-kit/Models/GLTF format/overheadRoundColored.glb"}
				]
			},
			{
				"category": "Tribünen & Boxen",
				"description": "Zuschauer-Ränge und Team-Hauptquartiere",
				"items": [
					{"id": "grandStandCovered", "name": "Überdachte Haupttribüne", "size": "10 x 8 m", "path": "res://kenney_racing-kit/Models/GLTF format/grandStandCovered.glb"},
					{"id": "grandStandRound", "name": "Kurven-Tribüne", "size": "10 x 10 m", "path": "res://kenney_racing-kit/Models/GLTF format/grandStandRound.glb"},
					{"id": "pitsGarage", "name": "Team-Garage mit Rolltor", "size": "10 x 6 m", "path": "res://kenney_racing-kit/Models/GLTF format/pitsGarage.glb"},
					{"id": "pitsOffice", "name": "Rennleitungs-Turm", "size": "6 x 6 m", "path": "res://kenney_racing-kit/Models/GLTF format/pitsOffice.glb"}
				]
			},
			{
				"category": "Flutlicht & Sponsoring",
				"description": "Stadion-Beleuchtung, Kameras und Werbebanden",
				"items": [
					{"id": "lightPostLarge", "name": "Großer Flutlichtmast", "size": "2 x 12 m", "path": "res://kenney_racing-kit/Models/GLTF format/lightPostLarge.glb"},
					{"id": "billboard", "name": "Sponsoren-Anzeigetafel", "size": "8 x 4 m", "path": "res://kenney_racing-kit/Models/GLTF format/billboard.glb"},
					{"id": "flagCheckers", "name": "Große Zielflagge", "size": "2 x 5 m", "path": "res://kenney_racing-kit/Models/GLTF format/flagCheckers.glb"},
					{"id": "camera_exclusive", "name": "TV-Streckenkamera", "size": "2 x 4 m", "path": "res://kenney_racing-kit/Models/GLTF format/camera_exclusive.glb"}
				]
			}
		]
	},
	"rally": {
		"name": "Wüsten-Rallye & Sand",
		"tagline": "Staubige Offroad-Piste mit Sanddünen, Pylonen und Streckenposten",
		"sun_color": Color(1.0, 0.92, 0.78),
		"sun_energy": 0.95,
		"ambient_color": Color(0.35, 0.28, 0.22),
		"kits": [
			{
				"category": "Barrieren & Leitplanken",
				"description": "Schwere Absperrungen und Reifenstapel",
				"items": [
					{"id": "barrierRed", "name": "Rote Aufprall-Barriere", "size": "4 x 1 m", "path": "res://kenney_racing-kit/Models/GLTF format/barrierRed.glb"},
					{"id": "barrierWhite", "name": "Weiße Aufprall-Barriere", "size": "4 x 1 m", "path": "res://kenney_racing-kit/Models/GLTF format/barrierWhite.glb"},
					{"id": "fenceStraight", "name": "Sicherheitszaun", "size": "8 x 2 m", "path": "res://kenney_racing-kit/Models/GLTF format/fenceStraight.glb"},
					{"id": "railDouble", "name": "Doppelte Stahlleitplanke", "size": "8 x 1 m", "path": "res://kenney_racing-kit/Models/GLTF format/railDouble.glb"}
				]
			},
			{
				"category": "Pylonen & Flaggen",
				"description": "Streckenmarkierungen und Rallye-Bannertürme",
				"items": [
					{"id": "pylon", "name": "Orangefarbene Pylone", "size": "1 x 1 m", "path": "res://kenney_racing-kit/Models/GLTF format/pylon.glb"},
					{"id": "bannerTowerRed", "name": "Rallye-Turm Rot", "size": "2 x 8 m", "path": "res://kenney_racing-kit/Models/GLTF format/bannerTowerRed.glb"},
					{"id": "bannerTowerGreen", "name": "Rallye-Turm Grün", "size": "2 x 8 m", "path": "res://kenney_racing-kit/Models/GLTF format/bannerTowerGreen.glb"},
					{"id": "flagTankco", "name": "Sponsoren-Flagge", "size": "1 x 4 m", "path": "res://kenney_racing-kit/Models/GLTF format/flagTankco.glb"}
				]
			}
		]
	}
}

func _ready() -> void:
	scenery_root = Node3D.new()
	scenery_root.name = "DynamicWorldScenery"
	add_child(scenery_root)

	if not grid_map:
		grid_map = get_node_or_null("../GridMap")
	if not sun_light:
		sun_light = get_node_or_null("../Sun")
	if not environment:
		environment = get_node_or_null("../Environment")

	spectator_trucks.clear()
	for truck_name in ["../vehicle-truck-green", "../vehicle-truck-purple", "../vehicle-truck-red"]:
		var t = get_node_or_null(truck_name)
		if t is Node3D:
			spectator_trucks.append(t)

	init_slots()
	apply_slot(0)

const MAX_CUSTOM_TRACKS = 10
const EDITABLE_ITEMS = [0, 1, 2, 3, 4, 5, 6]

# ==============================================================================
# 1. TRACK SLOTS MANAGEMENT
# ==============================================================================

func init_slots() -> void:
	track_slots.clear()
	# Slot 0 is always Original (Standard) - protected against modifications
	track_slots.append({
		"id": "original",
		"name": "Original (Standard)",
		"theme": "forest",
		"is_locked": true,
		"cells": DEFAULT_ORIGINAL_CELLS.duplicate(true)
	})

	var custom_data = _load_slots_from_disk()

	if custom_data is Array:
		for item in custom_data:
			if item is Dictionary and (track_slots.size() - 1) < MAX_CUSTOM_TRACKS:
				var c_theme: String = item.get("theme", "forest")
				var c_cells: Array = item.get("cells", [])
				if c_cells.is_empty():
					c_cells = [{"x": 0, "z": 0, "item": 4, "orient": 0}]
				var s_num = track_slots.size()
				var def_name = "Strecke #%d (%s)" % [s_num, "Wald" if c_theme == "forest" else "Stadion"]
				track_slots.append({
					"id": item.get("id", "track_%d" % s_num),
					"name": item.get("name", def_name),
					"theme": c_theme,
					"is_locked": false,
					"cells": c_cells
				})
	elif custom_data is Dictionary:
		for key in custom_data:
			if (track_slots.size() - 1) >= MAX_CUSTOM_TRACKS:
				break
			var c = custom_data[key]
			var c_theme: String = c.get("theme", "forest")
			var c_cells: Array = c.get("cells", [])
			if c_cells.is_empty():
				c_cells = [{"x": 0, "z": 0, "item": 4, "orient": 0}]
			var s_num = track_slots.size()
			var def_name = "Strecke #%d (%s)" % [s_num, "Wald" if c_theme == "forest" else "Stadion"]
			track_slots.append({
				"id": key,
				"name": c.get("name", def_name),
				"theme": c_theme,
				"is_locked": false,
				"cells": c_cells
			})

	track_slots_updated.emit()

func _load_slots_from_disk() -> Variant:
	if not FileAccess.file_exists(SLOTS_SAVE_PATH):
		return []
	var file = FileAccess.open(SLOTS_SAVE_PATH, FileAccess.READ)
	if not file:
		return []
	var text = file.get_as_text()
	var json = JSON.new()
	if json.parse(text) == OK:
		return json.data
	return []

func save_slots_to_disk() -> void:
	var out: Array = []
	for i in range(1, track_slots.size()):
		var s = track_slots[i]
		out.append({
			"id": s["id"],
			"name": s["name"],
			"theme": s["theme"],
			"cells": s["cells"]
		})
	var file = FileAccess.open(SLOTS_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(out, "\t"))

func get_custom_track_count() -> int:
	return maxi(0, track_slots.size() - 1)

func can_create_custom_track() -> bool:
	return get_custom_track_count() < MAX_CUSTOM_TRACKS

func create_custom_track(theme_id: String) -> int:
	if not can_create_custom_track():
		return -1
	var num = track_slots.size()
	var theme_label = "Wald" if theme_id == "forest" else "Stadion"
	var new_track = {
		"id": "track_%d_%d" % [int(Time.get_unix_time_from_system()), num],
		"name": "Strecke #%d (%s)" % [num, theme_label],
		"theme": theme_id,
		"is_locked": false,
		"cells": [
			{"x": 0, "z": 0, "item": 4, "orient": 0}
		]
	}
	track_slots.append(new_track)
	save_slots_to_disk()
	track_slots_updated.emit()
	return track_slots.size() - 1

func delete_custom_track(slot_idx: int) -> void:
	if slot_idx <= 0 or slot_idx >= track_slots.size():
		return
	track_slots.remove_at(slot_idx)
	save_slots_to_disk()
	if active_slot_idx == slot_idx:
		apply_original_track()
	elif active_slot_idx > slot_idx:
		active_slot_idx -= 1
	track_slots_updated.emit()

func apply_original_track() -> void:
	# Reload untouched pristine Original circuit
	track_slots[0]["cells"] = DEFAULT_ORIGINAL_CELLS.duplicate(true)
	track_slots[0]["theme"] = "forest"
	apply_slot(0)

func apply_slot(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= track_slots.size():
		slot_idx = 0

	active_slot_idx = slot_idx
	var slot = track_slots[active_slot_idx]

	# Apply world theme
	set_world(slot["theme"])

	# Spectator trucks visibility (only on authentic Original circuit)
	for t in spectator_trucks:
		if is_instance_valid(t):
			t.visible = (active_slot_idx == 0)

	# Populate GridMap
	if grid_map:
		for c in grid_map.get_used_cells():
			if grid_map.get_cell_item(c) in EDITABLE_ITEMS:
				grid_map.set_cell_item(c, -1)

		for c in slot["cells"]:
			var cell_pos = Vector3i(int(c["x"]), 0, int(c["z"]))
			grid_map.set_cell_item(cell_pos, int(c["item"]), int(c.get("orient", 0)))

	track_slot_applied.emit(active_slot_idx, slot)
	track_slots_updated.emit()

func save_current_grid_to_slot(slot_idx: int) -> void:
	if slot_idx <= 0 or slot_idx >= track_slots.size():
		return # Original is protected!
	if not grid_map:
		return

	var cells_arr: Array = []
	for c in grid_map.get_used_cells():
		var item = grid_map.get_cell_item(c)
		if item in EDITABLE_ITEMS:
			var orient = grid_map.get_cell_item_orientation(c)
			cells_arr.append({
				"x": c.x,
				"z": c.z,
				"item": item,
				"orient": orient
			})

	track_slots[slot_idx]["cells"] = cells_arr
	save_slots_to_disk()
	track_slots_updated.emit()

func clear_slot(slot_idx: int) -> void:
	if slot_idx <= 0 or slot_idx >= track_slots.size():
		return # Original is protected!

	# Reset to basic starting tile at (0, 0)
	track_slots[slot_idx]["cells"] = [
		{"x": 0, "z": 0, "item": 4, "orient": 0}
	]
	save_slots_to_disk()

	if active_slot_idx == slot_idx:
		apply_slot(slot_idx)

	track_slots_updated.emit()

func export_slot_string(slot_idx: int) -> String:
	if slot_idx < 0 or slot_idx >= track_slots.size():
		slot_idx = 0
	var s = track_slots[slot_idx]
	var payload = {
		"name": s["name"],
		"theme": s["theme"],
		"cells": s["cells"]
	}
	return Marshalls.utf8_to_base64(JSON.stringify(payload))

func import_as_new_track(code_str: String) -> int:
	if not can_create_custom_track():
		return -1

	code_str = code_str.strip_edges()
	var json_str = code_str

	# Attempt Base64 decode first
	var decoded = Marshalls.base64_to_utf8(code_str)
	if decoded != "" and decoded.begins_with("{"):
		json_str = decoded

	var json = JSON.new()
	if json.parse(json_str) != OK or not (json.data is Dictionary):
		return -1

	var data: Dictionary = json.data
	if not data.has("cells") or not (data["cells"] is Array):
		return -1

	var theme_id = data.get("theme", "forest")
	if not WORLDS_INFO.has(theme_id):
		theme_id = "forest"

	var new_idx = create_custom_track(theme_id)
	if new_idx > 0:
		track_slots[new_idx]["cells"] = data["cells"]
		if data.has("name"):
			track_slots[new_idx]["name"] = data["name"]
		save_slots_to_disk()
		track_slots_updated.emit()
	return new_idx

func import_slot_string(slot_idx: int, code_str: String) -> bool:
	if slot_idx <= 0 or slot_idx >= track_slots.size():
		return false # Original is locked

	code_str = code_str.strip_edges()
	var json_str = code_str

	var decoded = Marshalls.base64_to_utf8(code_str)
	if decoded != "" and decoded.begins_with("{"):
		json_str = decoded

	var json = JSON.new()
	if json.parse(json_str) != OK or not (json.data is Dictionary):
		return false

	var data: Dictionary = json.data
	if not data.has("cells") or not (data["cells"] is Array):
		return false

	track_slots[slot_idx]["cells"] = data["cells"]
	save_slots_to_disk()

	if active_slot_idx == slot_idx:
		apply_slot(slot_idx)

	track_slots_updated.emit()
	return true

func get_active_slot_data() -> Dictionary:
	if active_slot_idx >= 0 and active_slot_idx < track_slots.size():
		return track_slots[active_slot_idx]
	return track_slots[0]

func get_slot_data(slot_idx: int) -> Dictionary:
	if slot_idx >= 0 and slot_idx < track_slots.size():
		return track_slots[slot_idx]
	return {}

# ==============================================================================
# 2. WORLD THEME SCENERY
# ==============================================================================

func set_world(world_id: String) -> void:
	if not WORLDS_INFO.has(world_id):
		world_id = "forest"

	active_world_id = world_id
	var info = WORLDS_INFO[world_id]

	# Clear previous dynamic scenery
	if scenery_root:
		for c in scenery_root.get_children():
			c.queue_free()

	# Lighting adjustments
	if sun_light:
		if active_slot_idx == 0:
			sun_light.light_color = Color(1.0, 0.98, 0.94)
			sun_light.light_energy = 0.85
		else:
			sun_light.light_color = info["sun_color"]
			sun_light.light_energy = info["sun_energy"]

	# Build scenery for chosen world (only for custom slots; original has its full authentic 154-tile layout)
	if active_slot_idx > 0:
		if world_id == "stadium":
			_build_stadium_scenery()
		elif world_id == "rally":
			_build_rally_scenery()
		else:
			_build_forest_scenery()

	world_changed.emit(active_world_id)

func _build_stadium_scenery() -> void:
	if not scenery_root:
		return
	_spawn_prop("res://kenney_racing-kit/Models/GLTF format/grandStandCovered.glb",
		Vector3(12.0, 0.0, 3.75), Vector3(0, -PI/2, 0), Vector3(1.2, 1.2, 1.2))
	_spawn_prop("res://kenney_racing-kit/Models/GLTF format/grandStandRound.glb",
		Vector3(12.0, 0.0, 16.0), Vector3(0, -PI/2, 0), Vector3(1.2, 1.2, 1.2))
	_spawn_prop("res://kenney_racing-kit/Models/GLTF format/pitsGarage.glb",
		Vector3(-24.0, 0.0, 0.0), Vector3(0, PI/2, 0), Vector3(1.2, 1.2, 1.2))
	_spawn_prop("res://kenney_racing-kit/Models/GLTF format/pitsOffice.glb",
		Vector3(-24.0, 0.0, 10.0), Vector3(0, PI/2, 0), Vector3(1.2, 1.2, 1.2))

	_spawn_prop("res://kenney_racing-kit/Models/GLTF format/billboard.glb",
		Vector3(-11.24, 0.0, -23.0), Vector3(0, 0, 0), Vector3(1.0, 1.0, 1.0))
	_spawn_prop("res://kenney_racing-kit/Models/GLTF format/billboardDouble_exclusive.glb",
		Vector3(-3.75, 0.0, -23.0), Vector3(0, 0, 0), Vector3(1.0, 1.0, 1.0))

	var flood_positions = [
		Vector3(9.5, 0.0, 18.7),
		Vector3(-24.0, 0.0, 18.7),
		Vector3(-24.0, 0.0, -24.0),
		Vector3(9.5, 0.0, -24.0)
	]
	for p in flood_positions:
		_spawn_prop("res://kenney_racing-kit/Models/GLTF format/lightPostLarge.glb",
			p, Vector3.ZERO, Vector3(1.0, 1.0, 1.0))

	_spawn_prop("res://kenney_racing-kit/Models/GLTF format/flagCheckers.glb",
		Vector3(1.0, 0.0, 3.75), Vector3.ZERO, Vector3(1.0, 1.0, 1.0))
	_spawn_prop("res://kenney_racing-kit/Models/GLTF format/flagCheckers.glb",
		Vector3(6.5, 0.0, 3.75), Vector3.ZERO, Vector3(1.0, 1.0, 1.0))

func _build_rally_scenery() -> void:
	if not scenery_root:
		return
	var barrier_curves = [
		Vector3(7.5, 0.0, 18.7), Vector3(7.5, 0.0, 15.0),
		Vector3(-22.0, 0.0, 18.7), Vector3(-22.0, 0.0, 15.0),
		Vector3(-22.0, 0.0, -18.7), Vector3(-18.7, 0.0, -22.0),
		Vector3(7.5, 0.0, -18.7), Vector3(3.75, 0.0, -22.0)
	]
	var toggle := true
	for p in barrier_curves:
		var glb = "barrierRed.glb" if toggle else "barrierWhite.glb"
		toggle = !toggle
		_spawn_prop("res://kenney_racing-kit/Models/GLTF format/" + glb,
			p, Vector3.ZERO, Vector3(1.0, 1.0, 1.0))

	_spawn_prop("res://kenney_racing-kit/Models/GLTF format/fenceStraight.glb",
		Vector3(8.5, 0.0, 0.0), Vector3(0, PI/2, 0), Vector3(1.0, 1.0, 1.0))
	_spawn_prop("res://kenney_racing-kit/Models/GLTF format/fenceStraight.glb",
		Vector3(8.5, 0.0, 7.5), Vector3(0, PI/2, 0), Vector3(1.0, 1.0, 1.0))

	_spawn_prop("res://kenney_racing-kit/Models/GLTF format/bannerTowerRed.glb",
		Vector3(7.5, 0.0, 3.75), Vector3.ZERO, Vector3(1.0, 1.0, 1.0))
	_spawn_prop("res://kenney_racing-kit/Models/GLTF format/bannerTowerGreen.glb",
		Vector3(0.0, 0.0, 3.75), Vector3.ZERO, Vector3(1.0, 1.0, 1.0))

	var pylon_positions = [
		Vector3(2.5, 0.0, 7.0), Vector3(2.5, 0.0, 13.0),
		Vector3(-3.75, 0.0, 17.0), Vector3(-11.24, 0.0, 17.0)
	]
	for py in pylon_positions:
		_spawn_prop("res://kenney_racing-kit/Models/GLTF format/pylon.glb",
			py, Vector3.ZERO, Vector3(1.0, 1.0, 1.0))

func _build_forest_scenery() -> void:
	if not scenery_root:
		return
	var tree_positions = [
		Vector3(10.0, 0.0, 0.0),
		Vector3(11.0, 0.0, 8.0),
		Vector3(9.0, 0.0, -8.0),
		Vector3(-6.0, 0.0, 8.0),
		Vector3(-6.0, 0.0, -6.0),
		Vector3(-22.0, 0.0, 8.0),
		Vector3(-22.0, 0.0, -12.0),
		Vector3(-10.0, 0.0, -22.0)
	]
	for p in tree_positions:
		_spawn_prop("res://kenney_racing-kit/Models/GLTF format/treeLarge.glb",
			p, Vector3.ZERO, Vector3(1.25, 1.25, 1.25))

	_spawn_prop("res://kenney_racing-kit/Models/GLTF format/tent.glb",
		Vector3(12.0, 0.0, -2.0), Vector3(0, PI/3, 0), Vector3(1.0, 1.0, 1.0))
	_spawn_prop("res://kenney_racing-kit/Models/GLTF format/tentLong.glb",
		Vector3(13.0, 0.0, 4.0), Vector3(0, -PI/4, 0), Vector3(1.0, 1.0, 1.0))

func _spawn_prop(glb_path: String, pos: Vector3, rot: Vector3, sc: Vector3) -> void:
	if not ResourceLoader.exists(glb_path):
		return
	var scene = load(glb_path)
	if not scene:
		return
	var inst = scene.instantiate() as Node3D
	inst.position = pos
	inst.rotation = rot
	inst.scale = sc
	scenery_root.add_child(inst)
