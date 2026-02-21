extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var close_button: Button = $Panel/MarginContainer/VBox/TopBar/CloseButton
@onready var scroll: ScrollContainer = $Panel/MarginContainer/VBox/Scroll
@onready var entries_container: VBoxContainer = $Panel/MarginContainer/VBox/Scroll/Entries
@onready var version_label: Label = $Panel/MarginContainer/VBox/TopBar/VersionLabel

var _is_visible: bool = false

const GAME_VERSION := "v0.17.0"

const CHANGELOG: Array[Dictionary] = [
	{
		"version": "v0.17.0",
		"title": "Changelog Timestamps",
		"date": "2026-02-21",
		"entries": [
			"All changelog entries now display the date they were released",
			"Version bump to v0.17.0",
		]
	},
	{
		"version": "v0.16.0",
		"title": "Mobile Tap Targeting",
		"date": "2026-02-21",
		"entries": [
			"Enemy and tree click/tap targets are now much more forgiving on mobile",
			"Added expanded touch areas around enemies for easier tapping",
			"Added expanded touch areas around harvestable trees for easier tapping",
			"Physics queries now use area overlap instead of point intersection for fat-finger tolerance",
			"Hero select cards are now fully tappable — tap anywhere on the card, not just the SELECT button",
			"Card hover highlight now triggers on the entire card on desktop",
		]
	},
	{
		"version": "v0.15.0",
		"title": "Combat & Equipment Fixes",
		"date": "2026-02-21",
		"entries": [
			"Clicking or spacebar-attacking an enemy now auto-attacks until you move or act",
			"Auto-attacks are always plain basic swings — no combos or specials",
			"Player automatically chases target if it walks out of melee range",
			"Fixed enemies gluing onto hero and moving in sync during combat",
			"Fixed rats and small enemies freezing instead of attacking in groups",
			"Enemies hit while retreating home now fight back instead of ignoring you",
			"Equipping items now shows an error message when level requirement is not met",
			"Ravager's Cleaver can now be equipped immediately after dropping",
		]
	},
	{
		"version": "v0.14.0",
		"title": "Clickable Tree Harvesting",
		"date": "2026-02-21",
		"entries": [
			"Left-click trees to walk to them and auto-chop — no more mashing spacebar",
			"Harvestable trees now glow with a green outline on mouse hover",
			"Right-click any tree to inspect its wood yield before chopping",
			"Wood yields increased 5x: small ~15, medium ~30, large ~60",
			"Each tree has a randomized wood amount that varies by size",
		]
	},
	{
		"version": "v0.13.0",
		"title": "Enemy Overhaul",
		"date": "2026-02-21",
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
		"date": "2026-02-21",
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
		"date": "2026-02-20",
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
		"date": "2026-02-20",
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
		"date": "2026-02-20",
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
		"date": "2026-02-20",
		"entries": [
			"Simplified dash strike: diagonal keys + space",
			"Massively expanded items, affixes, enemy types, and map population",
			"Fixed dash strike not hitting enemies",
		]
	},
	{
		"version": "v0.7.0",
		"title": "Smoothness & Polish",
		"date": "2026-02-20",
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
		"date": "2026-02-20",
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
		"date": "2026-02-20",
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
		"date": "2026-02-20",
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
		"date": "2026-02-20",
		"entries": [
			"Enlarged map to 12000x9000",
			"Added enemy patrol behavior",
		]
	},
	{
		"version": "v0.2.0",
		"title": "Core Architecture",
		"date": "2026-02-20",
		"entries": [
			"Implemented SC:BW-style deterministic architecture with full game systems",
			"Fixed parser and trigger system errors",
		]
	},
	{
		"version": "v0.1.0",
		"title": "Initial Release",
		"date": "2026-02-20",
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
		# Version header with date
		var header = Label.new()
		var date_str: String = patch.get("date", "")
		if date_str != "":
			header.text = "%s — %s  (%s)" % [patch["version"], patch["title"], date_str]
		else:
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
