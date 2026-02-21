extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var close_button: Button = $Panel/MarginContainer/VBox/TopBar/CloseButton
@onready var scroll: ScrollContainer = $Panel/MarginContainer/VBox/Scroll
@onready var entries_container: VBoxContainer = $Panel/MarginContainer/VBox/Scroll/Entries
@onready var version_label: Label = $Panel/MarginContainer/VBox/TopBar/VersionLabel

var _is_visible: bool = false

const GAME_VERSION := "v0.13.0"

const CHANGELOG: Array[Dictionary] = [
	{
		"version": "v0.13.0",
		"title": "Enemy Overhaul",
		"entries": [
			"Rats now aggressively pursue players with increased aggro range",
			"Rats randomly alert to player presence even outside direct detection",
			"Added unique sprites for all 6 missing enemy types",
			"Tree chopping now uses a proper pickaxe animation instead of sword attack",
		]
	},
	{
		"version": "v0.12.0",
		"title": "Music & Crafting",
		"entries": [
			"Town music now rotates between 5 completely different tracks every minute",
			"Expanded town theme to 3:12 with 8 distinct sections",
			"Overhauled town theme sound design with richer timbres, vibrato, and atmosphere",
			"Added woodworking system: spend wood to craft upgrades for character progression",
		]
	},
	{
		"version": "v0.11.0",
		"title": "Buildings & Resources",
		"entries": [
			"Added tree chopping system with wood resource collection",
			"Added tavern building with wench visit mechanic (buff/debuff system)",
			"Added hero stats panel with buff/debuff display on right-click",
			"Reduced minion loading lag with staggered spawning and distance-based sleep",
			"Reduced combat lag with object pooling and squared distance optimizations",
		]
	},
	{
		"version": "v0.10.0",
		"title": "Performance & World",
		"entries": [
			"Massive performance overhaul across entire codebase",
			"Fixed remaining performance hotspots across UI and gameplay systems",
			"Massively improved ground tile variety to eliminate repetitive look",
			"Charged slash now hits all enemies in its path, not just one",
			"Power strike requires movement direction held to trigger",
		]
	},
	{
		"version": "v0.9.0",
		"title": "Audio System",
		"entries": [
			"Added procedural audio system with SFX and ambient soundtrack",
			"Overhauled attack SFX — replaced hollow sine waves with richer sounds",
			"Sword swing now sounds like a blade — metallic shing with warm slice feel",
			"Added charge sound system with looping buildup and blast release",
		]
	},
	{
		"version": "v0.8.0",
		"title": "Items & Combat",
		"entries": [
			"Simplified dash strike: diagonal keys + space",
			"Massively expanded items, affixes, enemy types, and map population",
			"Fixed dash strike not hitting enemies",
		]
	},
	{
		"version": "v0.7.0",
		"title": "Smoothness & Polish",
		"entries": [
			"Added large rat swarms near town as starter mobs (15-20 per group)",
			"Fixed hero jitter when idle and during charge attacks",
			"Fixed game choppiness from hit freeze overlap, screen shake stacking, VFX spam",
			"Disabled pixel snap, enabled VSync, softer camera and movement",
			"Bumped physics tick rate 60 -> 120 Hz for smoother movement",
		]
	},
	{
		"version": "v0.6.0",
		"title": "Combat Expansion",
		"entries": [
			"Added unit effects, right-click attack, and improved minion AI",
			"Added special attack system: double-tap, triple-tap, charge, dash strike",
			"Fixed attack input so normal hold/mash always works",
			"Fixed multi-tap specials with 0.12s buffer for proper resolution",
		]
	},
	{
		"version": "v0.5.0",
		"title": "Movement & Animation",
		"entries": [
			"Smooth player movement with acceleration, walk bob, and lean",
			"Added proper walk cycle animation replacing programmatic bob",
			"Fixed jitter from per-frame sprite texture reassignment",
			"Enabled physics interpolation and tightened camera for smooth feel",
		]
	},
	{
		"version": "v0.4.0",
		"title": "Controls",
		"entries": [
			"Arrow key direction now used for abilities (Q/E), not just mouse",
			"Hold Space to auto-attack at normal cooldown rate",
			"Added persistent facing direction and directional idle sprites",
			"Added click-to-move on minimap",
		]
	},
	{
		"version": "v0.3.0",
		"title": "World Expansion",
		"entries": [
			"Enlarged map to 12000x9000",
			"Added enemy patrol behavior",
		]
	},
	{
		"version": "v0.2.0",
		"title": "Core Architecture",
		"entries": [
			"Implemented SC:BW-style deterministic architecture with full game systems",
			"Fixed parser and trigger system errors",
		]
	},
	{
		"version": "v0.1.0",
		"title": "Initial Release",
		"entries": [
			"Fixed crash with Control nodes in Godot 4",
			"Switched from isometric to simple top-down 2D",
			"Fixed game freeze at level 5 from infinite loop in message cleanup",
		]
	},
]

func _ready() -> void:
	panel.visible = false
	close_button.pressed.connect(close)
	version_label.text = GAME_VERSION

func open() -> void:
	_is_visible = true
	panel.visible = true
	_build_entries()
	scroll.scroll_vertical = 0

func close() -> void:
	_is_visible = false
	panel.visible = false

func _build_entries() -> void:
	for child in entries_container.get_children():
		child.queue_free()

	for patch in CHANGELOG:
		# Version header
		var header = Label.new()
		header.text = "%s — %s" % [patch["version"], patch["title"]]
		header.add_theme_font_size_override("font_size", 16)
		header.add_theme_color_override("font_color", Color(0.4, 0.75, 1.0))
		entries_container.add_child(header)

		# Entries
		for entry in patch["entries"]:
			var line = Label.new()
			line.text = "  • " + entry
			line.add_theme_font_size_override("font_size", 12)
			line.add_theme_color_override("font_color", Color(0.78, 0.76, 0.7))
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			entries_container.add_child(line)

		# Spacer between versions
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 6)
		entries_container.add_child(spacer)

func _unhandled_input(event: InputEvent) -> void:
	if _is_visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ability_1")):
		close()
		get_viewport().set_input_as_handled()
