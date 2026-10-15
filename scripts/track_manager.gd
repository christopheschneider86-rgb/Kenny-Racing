class_name TrackManager extends Node

# Track and World Manager for Kenny Racing
# - Manages thematic Worlds: Forest, Stadium, and Rally
# - Structures the 112 Building Kits (Bausätze) from kenney_racing-kit into clear categories
# - Dynamically updates 3D World Scenery, Lighting, and Decoration
# - Provides building block metadata for the in-game Track Builder

signal world_changed(world_id: String)

enum WorldTheme { FOREST = 0, STADIUM = 1, RALLY = 2 }

@export var current_world: WorldTheme = WorldTheme.FOREST
@export var sun_light: DirectionalLight3D
@export var environment: WorldEnvironment

var scenery_root: Node3D
var active_world_id: String = "forest"

# Definition of the Worlds and their Building Kits (Bausätze)
const WORLDS_INFO = {
	"forest": {
		"name": "🌲 Wald & Natur",
		"tagline": "Grüne Rundstrecke im Wald mit Campingzelten und Baumreihen",
		"sun_color": Color(1.0, 0.98, 0.92),
		"sun_energy": 1.1,
		"ambient_color": Color(0.3, 0.5, 0.35),
		"kits": [
			{
				"category": "🛣️ Straßen & Fahrbahn",
				"description": "Klassischer Asphalt mit rot-weißen Randsteinen",
				"items": [
					{"id": "track-finish", "name": "Start- / Ziellinie mit Bogen", "size": "10 x 10 m", "path": "res://models/track-finish.glb"},
					{"id": "track-straight", "name": "Gerade Strecke", "size": "10 x 10 m", "path": "res://models/track-straight.glb"},
					{"id": "track-corner", "name": "90°-Kurve", "size": "10 x 10 m", "path": "res://models/track-corner.glb"},
					{"id": "track-bump", "name": "Bodenwelle", "size": "10 x 10 m", "path": "res://models/track-bump.glb"}
				]
			},
			{
				"category": "🌲 Bäume & Vegetation",
				"description": "Dichte Tannen, Laubbäume und Gras",
				"items": [
					{"id": "decoration-forest", "name": "Wald-Gruppe", "size": "10 x 10 m", "path": "res://models/decoration-forest.glb"},
					{"id": "treeLarge", "name": "Großer Laubbaum", "size": "3 x 3 m", "path": "res://kenney_racing-kit/Models/GLTF format/treeLarge.glb"},
					{"id": "treeSmall", "name": "Kleiner Baum", "size": "2 x 2 m", "path": "res://kenney_racing-kit/Models/GLTF format/treeSmall.glb"},
					{"id": "grass", "name": "Grasbüschel", "size": "1 x 1 m", "path": "res://kenney_racing-kit/Models/GLTF format/grass.glb"}
				]
			},
			{
				"category": "⛺ Camping & Zeltlager",
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
		"name": "🏟️ Grand Prix Stadion",
		"tagline": "Motorsport-Arena mit Tribünen, Boxengasse, Flutlicht und Anzeigetafeln",
		"sun_color": Color(0.98, 0.98, 1.0),
		"sun_energy": 1.25,
		"ambient_color": Color(0.35, 0.45, 0.6),
		"kits": [
			{
				"category": "🛣️ GP-Strecke & Boxengasse",
				"description": "Professioneller Streckenteppich und Boxenausfahrt",
				"items": [
					{"id": "roadStartPositions", "name": "Startaufstellung-Grid", "size": "10 x 10 m", "path": "res://kenney_racing-kit/Models/GLTF format/roadStartPositions.glb"},
					{"id": "roadPitStraight", "name": "Boxengassen-Gerade", "size": "10 x 10 m", "path": "res://kenney_racing-kit/Models/GLTF format/roadPitStraight.glb"},
					{"id": "roadStraightBridge", "name": "Brücken-Fahrbahn", "size": "10 x 10 m", "path": "res://kenney_racing-kit/Models/GLTF format/roadStraightBridge.glb"},
					{"id": "overheadRoundColored", "name": "Überkopf-Startbrücke", "size": "6 x 10 m", "path": "res://kenney_racing-kit/Models/GLTF format/overheadRoundColored.glb"}
				]
			},
			{
				"category": "🏟️ Tribünen & Boxen",
				"description": "Zuschauer-Ränge und Team-Hauptquartiere",
				"items": [
					{"id": "grandStandCovered", "name": "Überdachte Haupttribüne", "size": "10 x 8 m", "path": "res://kenney_racing-kit/Models/GLTF format/grandStandCovered.glb"},
					{"id": "grandStandRound", "name": "Kurven-Tribüne", "size": "10 x 10 m", "path": "res://kenney_racing-kit/Models/GLTF format/grandStandRound.glb"},
					{"id": "pitsGarage", "name": "Team-Garage mit Rolltor", "size": "10 x 6 m", "path": "res://kenney_racing-kit/Models/GLTF format/pitsGarage.glb"},
					{"id": "pitsOffice", "name": "Rennleitungs-Turm", "size": "6 x 6 m", "path": "res://kenney_racing-kit/Models/GLTF format/pitsOffice.glb"}
				]
			},
			{
				"category": "💡 Flutlicht & Sponsoring",
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
		"name": "🏜️ Wüsten-Rallye & Sand",
		"tagline": "Staubige Rallyestrecke mit Sprungschanzen, Sandkurven und Reifenstapeln",
		"sun_color": Color(1.0, 0.9, 0.75),
		"sun_energy": 1.3,
		"ambient_color": Color(0.55, 0.45, 0.3),
		"kits": [
			{
				"category": "🛣️ Rallye-Track & Schanzen",
				"description": "Sprunghügel und staubige Sandpassagen",
				"items": [
					{"id": "roadCornerLargeSand", "name": "Sand-Auslaufkurve", "size": "10 x 10 m", "path": "res://kenney_racing-kit/Models/GLTF format/roadCornerLargeSand.glb"},
					{"id": "ramp", "name": "Große Sprungschanze", "size": "10 x 10 m", "path": "res://kenney_racing-kit/Models/GLTF format/ramp.glb"},
					{"id": "roadBump", "name": "Rallye-Bodenwelle", "size": "10 x 10 m", "path": "res://kenney_racing-kit/Models/GLTF format/roadBump.glb"},
					{"id": "roadStraightSkew", "name": "Schräge Schikane", "size": "10 x 10 m", "path": "res://kenney_racing-kit/Models/GLTF format/roadStraightSkew.glb"}
				]
			},
			{
				"category": "🛡️ Barrieren & Zäune",
				"description": "Streckenabsicherung und Aufprallschutz",
				"items": [
					{"id": "barrierRed", "name": "Rote Aufprall-Barriere", "size": "4 x 1 m", "path": "res://kenney_racing-kit/Models/GLTF format/barrierRed.glb"},
					{"id": "barrierWhite", "name": "Weiße Aufprall-Barriere", "size": "4 x 1 m", "path": "res://kenney_racing-kit/Models/GLTF format/barrierWhite.glb"},
					{"id": "fenceStraight", "name": "Sicherheitszaun", "size": "8 x 2 m", "path": "res://kenney_racing-kit/Models/GLTF format/fenceStraight.glb"},
					{"id": "railDouble", "name": "Doppelte Stahlleitplanke", "size": "8 x 1 m", "path": "res://kenney_racing-kit/Models/GLTF format/railDouble.glb"}
				]
			},
			{
				"category": "🚩 Pylonen & Flaggen",
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

	if not sun_light:
		sun_light = get_node_or_null("../Sun")
	if not environment:
		environment = get_node_or_null("../Environment")

	set_world(active_world_id)

func set_world(world_id: String) -> void:
	if not WORLDS_INFO.has(world_id):
		world_id = "forest"

	active_world_id = world_id
	var info = WORLDS_INFO[world_id]

	# Clear previous dynamic scenery
	for c in scenery_root.get_children():
		c.queue_free()

	# Lighting adjustments
	if sun_light:
		sun_light.light_color = info["sun_color"]
		sun_light.light_energy = info["sun_energy"]

	# Build scenery for chosen world
	if world_id == "stadium":
		_build_stadium_scenery()
	elif world_id == "rally":
		_build_rally_scenery()
	else:
		_build_forest_scenery()

	world_changed.emit(active_world_id)

# ==============================================================================
# WORLD SCENERY BUILDERS
# ==============================================================================

func _build_stadium_scenery() -> void:
	# Grandstands along main straight (facing track)
	var grandstand_z = [-7.5, 0.0, 7.5]
	for z in grandstand_z:
		_spawn_prop("res://kenney_racing-kit/Models/GLTF format/grandStandCovered.glb",
			Vector3(9.5, 0.0, z), Vector3(0, -PI/2, 0), Vector3(8, 8, 8))

	# Pit Garages on opposite straight side
	_spawn_prop("res://kenney_racing-kit/Models/GLTF format/pitsGarage.glb",
		Vector3(-5.5, 0.0, 3.5), Vector3(0, PI/2, 0), Vector3(8, 8, 8))
	_spawn_prop("res://kenney_racing-kit/Models/GLTF format/pitsGarage.glb",
		Vector3(-5.5, 0.0, 11.0), Vector3(0, PI/2, 0), Vector3(8, 8, 8))
	_spawn_prop("res://kenney_racing-kit/Models/GLTF format/pitsOffice.glb",
		Vector3(-5.5, 0.0, -4.0), Vector3(0, PI/2, 0), Vector3(8, 8, 8))

	# Overhead Gantry at Start/Finish
	_spawn_prop("res://kenney_racing-kit/Models/GLTF format/overheadRoundColored.glb",
		Vector3(3.75, 0.0, 3.75), Vector3(0, 0, 0), Vector3(8, 8, 8))

	# Billboards along far back-straight
	_spawn_prop("res://kenney_racing-kit/Models/GLTF format/billboard.glb",
		Vector3(-11.24, 0.0, -23.0), Vector3(0, 0, 0), Vector3(8, 8, 8))
	_spawn_prop("res://kenney_racing-kit/Models/GLTF format/billboardDouble_exclusive.glb",
		Vector3(-3.75, 0.0, -23.0), Vector3(0, 0, 0), Vector3(8, 8, 8))

	# Floodlights at 4 corners
	var flood_positions = [
		Vector3(9.5, 0.0, 18.7),
		Vector3(-24.0, 0.0, 18.7),
		Vector3(-24.0, 0.0, -24.0),
		Vector3(9.5, 0.0, -24.0)
	]
	for p in flood_positions:
		_spawn_prop("res://kenney_racing-kit/Models/GLTF format/lightPostLarge.glb",
			p, Vector3.ZERO, Vector3(8, 8, 8))

	# Checkered flags
	_spawn_prop("res://kenney_racing-kit/Models/GLTF format/flagCheckers.glb",
		Vector3(1.0, 0.0, 3.75), Vector3.ZERO, Vector3(8, 8, 8))
	_spawn_prop("res://kenney_racing-kit/Models/GLTF format/flagCheckers.glb",
		Vector3(6.5, 0.0, 3.75), Vector3.ZERO, Vector3(8, 8, 8))

func _build_rally_scenery() -> void:
	# Red & White Barriers on outer curves
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
			p, Vector3.ZERO, Vector3(7, 7, 7))

	# Fences
	_spawn_prop("res://kenney_racing-kit/Models/GLTF format/fenceStraight.glb",
		Vector3(8.5, 0.0, 0.0), Vector3(0, PI/2, 0), Vector3(7, 7, 7))
	_spawn_prop("res://kenney_racing-kit/Models/GLTF format/fenceStraight.glb",
		Vector3(8.5, 0.0, 7.5), Vector3(0, PI/2, 0), Vector3(7, 7, 7))

	# Banner Towers
	_spawn_prop("res://kenney_racing-kit/Models/GLTF format/bannerTowerRed.glb",
		Vector3(7.5, 0.0, 3.75), Vector3.ZERO, Vector3(7, 7, 7))
	_spawn_prop("res://kenney_racing-kit/Models/GLTF format/bannerTowerGreen.glb",
		Vector3(0.0, 0.0, 3.75), Vector3.ZERO, Vector3(7, 7, 7))

	# Pylons
	var pylon_positions = [
		Vector3(2.5, 0.0, 7.0), Vector3(2.5, 0.0, 13.0),
		Vector3(-3.75, 0.0, 17.0), Vector3(-11.24, 0.0, 17.0)
	]
	for py in pylon_positions:
		_spawn_prop("res://kenney_racing-kit/Models/GLTF format/pylon.glb",
			py, Vector3.ZERO, Vector3(6, 6, 6))

func _build_forest_scenery() -> void:
	# Trees around the track
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
			p, Vector3.ZERO, Vector3(7, 7, 7))

	# Tents
	_spawn_prop("res://kenney_racing-kit/Models/GLTF format/tent.glb",
		Vector3(12.0, 0.0, -2.0), Vector3(0, PI/3, 0), Vector3(6, 6, 6))
	_spawn_prop("res://kenney_racing-kit/Models/GLTF format/tentLong.glb",
		Vector3(13.0, 0.0, 4.0), Vector3(0, -PI/4, 0), Vector3(6, 6, 6))

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
