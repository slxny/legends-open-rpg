extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var close_button: Button = $Panel/MarginContainer/VBox/TopBar/CloseButton
@onready var scroll: ScrollContainer = $Panel/MarginContainer/VBox/Scroll
@onready var entries_container: VBoxContainer = $Panel/MarginContainer/VBox/Scroll/Entries
@onready var version_label: Label = $Panel/MarginContainer/VBox/TopBar/VersionLabel

var _is_visible: bool = false
var _is_mobile: bool = false

const GAME_VERSION := "v0.39.0"

const CHANGELOG: Array[Dictionary] = [
	{
		"version": "v0.39.0",
		"title": "Minimal Mobile HUD — Maximum Map Visibility",
		"date": "2026-02-23",
		"entries": [
			"Bottom HUD in mobile portrait slashed from 380px to ~82px — reclaims ~300px of screen for the map",
			"Command card, minimap, and hero name/level all hidden from the bottom bar in portrait",
			"Bottom bar now shows only HP, MP, XP bars plus a single CMD button",
			"CMD button opens a floating overlay with all 9 command buttons (abilities, potions, items, save/load, log)",
			"Overlay auto-closes after tapping any command for quick one-tap access",
			"ATK button repositioned to sit just above the new thinner bottom bar",
			"Inventory and shop buttons enlarged with visual hover/press states and tap/hover SFX",
		]
	},
	{
		"version": "v0.38.1",
		"title": "Mobile Button Improvements for Inventory & Shop",
		"date": "2026-02-23",
		"entries": [
			"Inventory equipment buttons enlarged from 80px to 96px on mobile with bigger 34px font",
			"Inventory bag grid buttons enlarged from 76px to 92px on mobile with bigger 30px font",
			"Shop item rows enlarged from 60px to 80px on mobile with bigger 36px font",
			"Shop tab and action buttons enlarged for easier tapping on mobile",
			"All inventory and shop buttons now have styled normal/hover/pressed states with golden borders",
			"Added subtle tap SFX on button press and soft hover SFX on mouse enter",
			"Empty inventory slots now have a distinct dimmed style instead of just modulated opacity",
			"Shop item rows highlight with a golden border on hover and brighten on press",
		]
	},
	{
		"version": "v0.38.0",
		"title": "Landscape HUD Radical Compaction",
		"date": "2026-02-23",
		"entries": [
			"Landscape bottom panel slashed from 64px to 36px — nearly half the old height",
			"Minimap and hero name hidden in landscape to reclaim all wasted space",
			"HP/MP bars shrunk to 8px, XP bar to 3px with zero spacing between them",
			"Save/Load/Log buttons hidden in landscape (use Menu instead) — grid drops from 3x3 to 3x2",
			"Command buttons reduced to 52x14px for minimal footprint",
			"Top bar and menu button also shrunk for maximum game view",
			"ATK button repositioned closer to the thinner panel",
		]
	},
	{
		"version": "v0.37.2",
		"title": "Fix Bag Overlay Item Stats Hidden Behind HUD",
		"date": "2026-02-23",
		"entries": [
			"Fixed inventory item stats panel being hidden behind the bottom HUD on desktop",
			"Inventory panel now stops above the bottom HUD so item details are always fully visible",
		]
	},
	{
		"version": "v0.37.1",
		"title": "Fix Beacon Healing & Immunity",
		"date": "2026-02-23",
		"entries": [
			"Fixed heal beacon not healing or granting immunity: beacon_type was not set to 'heal' in the scene, so all healing and immunity code paths were skipped",
		]
	},
	{
		"version": "v0.37.0",
		"title": "Inventory UI Redesign",
		"date": "2026-02-23",
		"entries": [
			"Redesigned inventory as a compact right-side panel that no longer blocks the map",
			"Added tabbed Equipment/Bag layout so items and gear aren't crammed together",
			"Item stats now shown inline when hovering or tapping — no more off-screen tooltips",
			"Compact hero stats bar at the bottom shows HP, MP, ATK, armor, and attributes at a glance",
			"Equipment tab shows slot labels with unequip buttons for easy gear management",
			"Bag tab uses a clean grid with item names color-coded by rarity",
			"Panel is semi-transparent so the game world stays visible behind it",
			"Full-screen layout on mobile with larger tap targets and text",
		]
	},
	{
		"version": "v0.36.2",
		"title": "Beacon Immunity Timing Fix",
		"date": "2026-02-23",
		"entries": [
			"Fixed heal beacon immunity not working: moved heal/immunity logic to _physics_process so it runs in the same phase as enemy attacks (was in _process, which runs after enemies already attacked each frame)",
			"Heal beacon now grants immunity instantly on collision entry — no more one-frame vulnerability window",
			"Heal beacon now triggers healing immediately when hero steps on from outside",
			"Immunity flag is now also properly cleared on collision exit for reliable cleanup",
		]
	},
	{
		"version": "v0.36.1",
		"title": "Full Beacon Immunity",
		"date": "2026-02-23",
		"entries": [
			"Heal beacon now blocks ALL damage at the stats level — no code path can bypass it",
			"Mana is no longer consumed while on heal beacon (abilities are free)",
			"Enemy effects (knockback, paralyze, slow) are blocked while on heal beacon",
		]
	},
	{
		"version": "v0.36.0",
		"title": "Landscape HUD Ultra-Compact",
		"date": "2026-02-23",
		"entries": [
			"Landscape bottom panel reduced from 90px to 64px (~30% shorter)",
			"Command buttons shrunk from 24px to 18px height, 'Commands' label hidden in landscape",
			"HP/MP bars reduced to 12px, XP bar to 6px, minimap to 60x50 for minimal footprint",
			"Top bar and menu button also shrunk for maximum game view in landscape",
		]
	},
	{
		"version": "v0.35.1",
		"title": "Heal Beacon True Immunity",
		"date": "2026-02-23",
		"entries": [
			"Heroes on a heal beacon are now fully immune to all damage (attacks do nothing)",
			"HP and mana are still restored to full every frame while on beacon",
			"Immunity flag is set/cleared as the hero enters/leaves beacon range",
		]
	},
	{
		"version": "v0.35.0",
		"title": "Landscape HUD Further Compacted",
		"date": "2026-02-23",
		"entries": [
			"Landscape bottom panel height reduced from 130px to 90px (~30% smaller)",
			"HP/MP bars shrunk from 22px to 14px, XP bar from 14px to 8px in landscape",
			"Command buttons reduced from 74x36 to 64x24, minimap from 110x90 to 80x65",
			"Top bar and all landscape font sizes reduced for more visible game area",
		]
	},
	{
		"version": "v0.34.1",
		"title": "Heal Beacon Immunity",
		"date": "2026-02-23",
		"entries": [
			"Heal beacon now restores HP/MP every frame so hero never loses health while standing on it",
			"Heal SFX and message only play when the beacon actually heals damage (silent at full HP)",
		]
	},
	{
		"version": "v0.34.0",
		"title": "Landscape Layout Optimization",
		"date": "2026-02-23",
		"entries": [
			"Bottom HUD panel height reduced ~30% for much more game view in landscape",
			"HP/MP/XP bars, command buttons, and minimap all compacted for landscape",
			"Mobile landscape layout significantly tighter (bottom panel 220px → 130px)",
			"Bar label font now auto-scales to bar height instead of fixed mobile/desktop sizes",
			"Browser auto-enters fullscreen on first tap to hide the address bar",
		]
	},
	{
		"version": "v0.33.1",
		"title": "Heal Beacon Full Area Fix",
		"date": "2026-02-23",
		"entries": [
			"Heal beacon now uses distance check so the entire visible area heals",
			"Heal SFX only plays once on entry, resets when you leave and return",
		]
	},
	{
		"version": "v0.33.0",
		"title": "Shop UI Redesign",
		"date": "2026-02-23",
		"entries": [
			"Completely redesigned shop with sleek tabbed Buy/Sell layout",
			"Tap any item to see full stats, description, rarity, and level requirement",
			"Buy and Sell buttons now inside the item detail panel for easy access",
			"Shop now shows feedback messages for purchases, sales, and errors",
			"ESC/Q closes item detail first, then closes the shop",
			"Much better mobile layout with larger tap targets and readable text",
		]
	},
	{
		"version": "v0.32.0",
		"title": "Loading Performance Optimization",
		"date": "2026-02-23",
		"entries": [
			"Reduced hero select loading lag (faster sprite and audio pre-generation)",
			"Reduced world loading lag (terrain and town now load asynchronously)",
			"Smoother transition when traveling outside the city walls",
		]
	},
	{
		"version": "v0.31.0",
		"title": "Heal Beacon Improvements",
		"date": "2026-02-23",
		"entries": [
			"Heal beacon now heals continuously while standing anywhere on it",
			"Heal SFX only plays when stepping on, not while staying on the beacon",
			"Fixed beacon collision areas not matching visual size (shared shape bug)",
		]
	},
	{
		"version": "v0.30.2",
		"title": "Version Display Fix",
		"date": "2026-02-23",
		"entries": [
			"Hero select version button now auto-reads from changelog (no more stale version)",
		]
	},
	{
		"version": "v0.30.1",
		"title": "Beacon Rendering Fix",
		"date": "2026-02-23",
		"entries": [
			"Fixed hero disappearing behind heal beacon and other beacons",
		]
	},
	{
		"version": "v0.30.0",
		"title": "Rat Swarm AI Fix",
		"date": "2026-02-23",
		"entries": [
			"Fixed rats glitching out and freezing when multiple are in combat",
			"Rats no longer get stuck oscillating between chase and attack states",
			"Swarms of enemies now properly surround and attack the player",
			"Capped enemy separation force so packs don't push each other into gridlock",
		]
	},
	{
		"version": "v0.29.0",
		"title": "Touch Attack Fixes & Pause Menu Close Button",
		"date": "2026-02-22 19:00",
		"entries": [
			"ATK button now flashes bright gold and scale-punches on every tap for clear feedback",
			"Fixed multi-touch special attacks not triggering (touches on UI were silently lost)",
			"Hold finger + double-tap ATK now reliably triggers Power Strike / Piercing Shot",
			"Two fingers on screen + tap ATK now reliably triggers Dash Strike / Shadow Step",
			"Attack direction on mobile is now derived from finger position relative to the player",
			"Pause menu now has a close X button in the top-right corner (matches all other menus)",
		]
	},
	{
		"version": "v0.28.0",
		"title": "Mobile Special Attacks & Pinch Zoom",
		"date": "2026-02-22 12:00",
		"entries": [
			"Added ATK button on mobile for special attacks (tap, double-tap, triple-tap, hold)",
			"Fast taps on ATK = same as fast spacebar presses (Power Strike, Whirlwind, etc.)",
			"Hold ATK for 1.5s = Charged Slash / Sniper Shot, just like holding spacebar",
			"Diagonal attacks on mobile: move diagonally then tap ATK for Dash Strike / Shadow Step",
			"Pinch-to-zoom on mobile with two-finger touch tracking",
			"Mobile zoom allows more zoom-in and less zoom-out than desktop (better for small screens)",
			"Tutorial hints updated for mobile controls (ATK button instead of SPACE key)",
		]
	},
	{
		"version": "v0.27.0",
		"title": "Combat Balance",
		"date": "2026-02-21",
		"entries": [
			"Rat damage raised from 8 to 12 (they now bite harder)",
			"Enemies can now override base attack damage per type",
			"Removed passive HP regeneration — use potions and heal beacons instead",
			"Mana still regenerates passively (needed for abilities)",
		]
	},
	{
		"version": "v0.26.0",
		"title": "Pause Menu",
		"date": "2026-02-21",
		"entries": [
			"Escape key now opens a pause menu instead of quitting",
			"Pause menu includes: Resume, Save Game, Load Game, Changelog, Help, Quit Game",
			"Game pauses while the menu is open",
			"Help screen with full controls reference and gameplay tips",
			"Mobile: small 'Menu' button in the top-left corner of the HUD",
			"Escape closes the pause menu when it's already open",
		]
	},
	{
		"version": "v0.25.0",
		"title": "Title Screen Branding",
		"date": "2026-02-21",
		"entries": [
			"Added 'OPEN LEGENDS RPG' game title with golden styling above hero select",
			"Added 'FORGE YOUR LEGEND' tagline beneath the title",
			"Added 'by Steve Levine' byline with clickable link to OpenClassActions.com",
		]
	},
	{
		"version": "v0.24.0",
		"title": "Mobile Text Scaling",
		"date": "2026-02-21",
		"entries": [
			"Enemy name labels doubled for mobile (9px → 18px)",
			"Enemy damage numbers doubled for mobile (14px → 28px normal, 28px → 44px crit)",
			"Enemy info popup text doubled for mobile (11px → 22px)",
			"Shop dialog: item names, prices, and Buy/Sell buttons doubled for mobile",
			"Inventory: equipment/bag buttons and stats text doubled for mobile",
			"Tavern dialog: all text and buttons doubled for mobile",
			"Armory dialog: upgrade text, costs, and buttons doubled for mobile",
			"Woodworking dialog: all upgrade text and buttons doubled for mobile",
			"Hero stats panel: all stats, buff entries, and timers doubled for mobile",
			"Town NPC name labels and beacon labels doubled for mobile",
			"Game messages and dramatic center messages doubled for mobile",
			"HP/Mana/XP bar label text doubled for mobile",
			"All dialog panels now expand to near-fullscreen on mobile",
		]
	},
	{
		"version": "v0.23.0",
		"title": "Enemy AI Aggro Fixes",
		"date": "2026-02-21",
		"entries": [
			"Fixed enemies ignoring the player while walking home (RETURN state now re-aggros)",
			"Fixed knockback pushing enemies past chase range causing them to go passive",
			"Fixed enemies falling asleep mid-walk during RETURN state",
		]
	},
	{
		"version": "v0.22.0",
		"title": "Mobile UI Overhaul",
		"date": "2026-02-21",
		"entries": [
			"Hero select: title/subtitle, card names, type tags, and SELECT buttons all doubled for mobile",
			"In-game HUD: command card buttons doubled from 68x44 to 144x90 with 22px font",
			"HUD top bar resource labels doubled to 32px on mobile",
			"HP/Mana/XP bars, unit info, and minimap all scaled up for mobile",
			"Ability tooltips and tutorial hints scaled to 26-30px font on mobile",
			"All command buttons are now large enough to tap comfortably on phones",
			"Tapping ability buttons (Q/E) now casts abilities on mobile",
			"Tapping potion buttons (1/2/3) now uses consumables on mobile",
			"Tapping Items button now opens inventory on mobile",
			"Disabled tooltip hover on mobile so taps cast instead of showing tooltips",
		]
	},
	{
		"version": "v0.21.0",
		"title": "Licensing & IP Protection",
		"date": "2026-02-21",
		"entries": [
			"Added All Rights Reserved LICENSE for full project protection",
			"Added MIT + Proprietary Assets dual-license option (LICENSE-MIT)",
			"Added ASSETS_LICENSE.txt covering all art, music, characters, and branding",
			"Added CONTRIBUTING.md with IP ownership terms for contributors",
			"Updated README with clear licensing section",
		]
	},
	{
		"version": "v0.20.0",
		"title": "Massive Text Size Increase",
		"date": "2026-02-21",
		"entries": [
			"Changelog headers and entry text are now 2x bigger on both desktop and mobile",
			"Version Log button on hero select is 3x bigger on mobile",
			"Changelog title bar, close button, and version label scaled up to match",
			"Desktop changelog panel enlarged to fit the bigger text",
		]
	},
	{
		"version": "v0.19.0",
		"title": "Full Cache-Busting",
		"date": "2026-02-21",
		"entries": [
			"All JS, CSS, and image assets in the web build are now cache-busted with a git hash",
			"Service worker script is also cache-busted to prevent stale cross-origin isolation",
			"Fixes browsers showing outdated versions after new deploys",
		]
	},
	{
		"version": "v0.18.0",
		"title": "Mobile Changelog Readability",
		"date": "2026-02-21",
		"entries": [
			"Changelog text is now much larger and easier to read on mobile",
			"Changelog panel expands to fill the screen on mobile devices",
			"Close button and title bar are larger on mobile for easier tapping",
			"Version headers now word-wrap on narrow screens",
		]
	},
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
	var vp_size = get_viewport().get_visible_rect().size
	_is_mobile = vp_size.x < 700 or (vp_size.x < vp_size.y)
	_resize_panel(vp_size)
	_build_entries()
	scroll.scroll_vertical = 0

func _resize_panel(vp_size: Vector2) -> void:
	if _is_mobile:
		# Fill most of the screen on mobile
		var margin = 10.0
		panel.offset_left = -vp_size.x / 2.0 + margin
		panel.offset_right = vp_size.x / 2.0 - margin
		panel.offset_top = -vp_size.y / 2.0 + margin
		panel.offset_bottom = vp_size.y / 2.0 - margin
		close_button.custom_minimum_size = Vector2(220, 68)
		close_button.add_theme_font_size_override("font_size", 38)
		version_label.add_theme_font_size_override("font_size", 40)
		$Panel/MarginContainer/VBox/TopBar/Title.add_theme_font_size_override("font_size", 56)
	else:
		panel.offset_left = -420.0
		panel.offset_right = 420.0
		panel.offset_top = -380.0
		panel.offset_bottom = 380.0

func close() -> void:
	_is_visible = false
	panel.visible = false

func _build_entries() -> void:
	for child in entries_container.get_children():
		child.queue_free()

	var header_size = 56 if _is_mobile else 32
	var entry_size = 42 if _is_mobile else 24
	var spacer_height = 24 if _is_mobile else 12

	for patch in CHANGELOG:
		# Version header with date
		var header = Label.new()
		var date_str: String = patch.get("date", "")
		if date_str != "":
			header.text = "%s — %s  (%s)" % [patch["version"], patch["title"], date_str]
		else:
			header.text = "%s — %s" % [patch["version"], patch["title"]]
		header.add_theme_font_size_override("font_size", header_size)
		header.add_theme_color_override("font_color", Color(0.4, 0.75, 1.0))
		header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		entries_container.add_child(header)

		# Entries
		for entry in patch["entries"]:
			var line = Label.new()
			line.text = "  • " + entry
			line.add_theme_font_size_override("font_size", entry_size)
			line.add_theme_color_override("font_color", Color(0.78, 0.76, 0.7))
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			entries_container.add_child(line)

		# Spacer between versions
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, spacer_height)
		entries_container.add_child(spacer)

func _unhandled_input(event: InputEvent) -> void:
	if _is_visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ability_1")):
		close()
		get_viewport().set_input_as_handled()
