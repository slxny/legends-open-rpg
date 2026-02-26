extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var close_button: Button = $Panel/MarginContainer/VBox/TopBar/CloseButton
@onready var scroll: ScrollContainer = $Panel/MarginContainer/VBox/Scroll
@onready var entries_container: VBoxContainer = $Panel/MarginContainer/VBox/Scroll/Entries
@onready var version_label: Label = $Panel/MarginContainer/VBox/TopBar/VersionLabel

var _is_visible: bool = false
var _is_mobile: bool = false

const GAME_VERSION := "v0.72.1"

const CHANGELOG: Array[Dictionary] = [
	{
		"version": "v0.72.1",
		"title": "Fix overlay close on landscape mobile",
		"date": "2026-02-25",
		"entries": [
			"Rebuilt MAP and OPT overlays with full-screen wrapper to capture all touch input",
			"Tap anywhere outside the panel to close (dimmer backdrop)",
			"X close buttons now properly receive touch events on all orientations",
			"Fixed CMD overlay height calculation that caused it to overflow off-screen",
		]
	},
	{
		"version": "v0.71.1",
		"title": "Fix overlay close buttons on landscape mobile",
		"date": "2026-02-25",
		"entries": [
			"MAP and OPT overlays now have a dimmer backdrop — tap anywhere outside to close",
			"Fixed CMD overlay positioning (content was overflowing off-screen in landscape)",
			"X close buttons now reliably receive touch input on all overlays",
		]
	},
	{
		"version": "v0.71.0",
		"title": "Landscape mobile: MAP/OPT buttons and proper close buttons",
		"date": "2026-02-25",
		"entries": [
			"Landscape mobile now has MAP and OPT buttons like portrait mode",
			"Minimap overlay with close button works in landscape",
			"Pause menu, help dialog, and command overlay all fit landscape viewports",
			"All close buttons and fonts properly scaled for short landscape screens",
		]
	},
	{
		"version": "v0.70.9",
		"title": "Messenger browser fix, hero select matches loading screen",
		"date": "2026-02-25",
		"entries": [
			"Removed unreliable 'Open in Browser' button from messenger in-app browser detection",
			"Now shows clear instructions to tap menu and choose 'Open in Browser' instead",
			"Hero select screen restyled to match loading screen: dark background, gold glowing title, matching decorative elements",
			"Added no-cache headers to prevent messenger browsers from serving stale pages",
		]
	},
	{
		"version": "v0.70.8",
		"title": "Messages moved below resource bar, level up shows transition",
		"date": "2026-02-25",
		"entries": [
			"Gold, wood, pickup, and upgrade messages now appear below the resource bar instead of overlapping it",
			"Mobile: message position scales with screen size (8% from top)",
			"Level up now shows LVL 4 → LVL 5 format instead of just the new level number",
		]
	},
	{
		"version": "v0.70.7",
		"title": "Woodworker upgrades max level raised to 100",
		"date": "2026-02-25",
		"entries": [
			"All four woodworker upgrades (Bow, Shield, Totem, Watchtower) now go up to level 100",
		]
	},
	{
		"version": "v0.70.6",
		"title": "Dungeon unlock message at level 10",
		"date": "2026-02-25",
		"entries": [
			"Reaching level 10 now shows a dramatic center-screen message: DUNGEON UNLOCKED — check in town!",
			"Level Up messages also now appear as dramatic center-screen text",
		]
	},
	{
		"version": "v0.70.5",
		"title": "Tutorial hints spaced out to 30s minimum",
		"date": "2026-02-25",
		"entries": [
			"Hints now appear at least 30 seconds apart — less spammy, more breathing room",
			"First ability tip still appears early (15s) since it's critical for new players",
			"Dismissing a hint no longer causes the next one to pop up in 2 seconds",
		]
	},
	{
		"version": "v0.70.4",
		"title": "NPC panels auto-close when you walk away",
		"date": "2026-02-25",
		"entries": [
			"Shop, armory, tavern, and woodworker panels now auto-close when you walk ~150px away from the NPC",
			"No more having to manually close panels after walking off",
		]
	},
	{
		"version": "v0.70.2",
		"title": "Inventory text scales with screen size",
		"date": "2026-02-25",
		"entries": [
			"All inventory fonts and button sizes now scale relative to screen height (base 1080p)",
			"Portrait mode gets bigger, more readable text for item stats and comparisons",
			"Detail panel font scaled up from 22 to 30 (at 1080p base) so stats are easy to read",
		]
	},
	{
		"version": "v0.70.1",
		"title": "Inventory: fixed detail panel at bottom, no more overlay",
		"date": "2026-02-25",
		"entries": [
			"Item detail now shows in a fixed panel at the bottom of the inventory — never covers the item list",
			"Bag items: single tap to preview stats + comparison, double-tap to equip",
			"Compact text format: item name, stats, and equipped comparison all fit in 2-3 lines",
			"Mobile: smaller button sizes and fonts so more items fit on screen",
			"Removed popup overlay completely — detail panel is always visible and never blocks interaction",
		]
	},
	{
		"version": "v0.69.2",
		"title": "Bag item detail shows inline, not as overlay",
		"date": "2026-02-25",
		"entries": [
			"Item detail and comparison now appears inline below the bag grid, inside the scroll area",
			"No more fullscreen overlay blocking bag items — buttons stay accessible for double-tap to equip",
			"Single tap selects and shows stats + comparison below, double-tap equips",
		]
	},
	{
		"version": "v0.69.1",
		"title": "Bag items: tap to preview, double-tap to equip",
		"date": "2026-02-25",
		"entries": [
			"Single tap/click on a bag item now shows its stats and a comparison with your equipped item",
			"Stat differences shown (e.g. +5 Strength, -2 Agility) so you can decide before equipping",
			"Double-tap/click to actually equip the item",
		]
	},
	{
		"version": "v0.68.6",
		"title": "Performance optimizations",
		"date": "2026-02-25",
		"entries": [
			"Outline shaders now applied on-demand (hover only) instead of always running on every enemy and tree",
			"Fog of war overlay redraws throttled to max 3x/sec instead of every movement tick",
			"Minimap refresh rate reduced from 4x/sec to 2x/sec",
			"Ambient particle count reduced from 15 to 6",
		]
	},
	{
		"version": "v0.68.5",
		"title": "All panels fully opaque and dark",
		"date": "2026-02-25",
		"entries": [
			"All UI panels (shop, armory, tavern, woodworking, inventory, hero stats, changelog, pause) now have dark opaque backgrounds",
			"Text behind panels no longer bleeds through — much easier to read",
		]
	},
	{
		"version": "v0.68.4",
		"title": "Dungeon enemies are much harder",
		"date": "2026-02-25",
		"entries": [
			"All dungeon crypt enemies got major stat buffs — the dungeon is now genuinely dangerous",
			"Attack damage roughly doubled across all dungeon enemies to match overworld scaling",
			"Flan: speed 40->65, cooldown 2.5->1.6s, damage 12->35, aggro 80->120",
			"Mimic: speed 30->70, cooldown 2.0->1.4s, damage 24->42, aggro 60->120",
			"Ghoul: speed 60->85, cooldown 1.6->1.2s, damage 18->38",
			"Crypt Knight: damage 22->48, cooldown 1.8->1.3s, aggro 130->150",
			"Lich: damage 20->55, speed 50->65, cooldown 2.2->1.4s, aggro 160->180",
			"Bats and snakes also significantly buffed in damage, speed, and aggro range",
		]
	},
	{
		"version": "v0.68.3",
		"title": "Bigger, consistent close buttons everywhere",
		"date": "2026-02-25",
		"entries": [
			"All close/X buttons are now the same size across every panel and dialog",
			"Desktop: 120x40 with font size 20 (up from 90x30 / 40x32 inconsistent sizes)",
			"Mobile: consistent 160x130 with font size 60 across all panels",
			"Hint dismiss X button also enlarged for easier tapping",
		]
	},
	{
		"version": "v0.68.2",
		"title": "Minibosses are bigger",
		"date": "2026-02-25",
		"entries": [
			"All minibosses now use a uniform 2.2x sprite scale (up from 1.5x) — unmistakably large",
		]
	},
	{
		"version": "v0.68.1",
		"title": "Endless miniboss respawns + time played saved",
		"date": "2026-02-25",
		"entries": [
			"After all 8 scheduled bosses spawn, new bosses keep coming indefinitely",
			"Every 5 minutes, if no minibosses are alive, 2 random bosses spawn scaled to your level",
			"Time played is now saved — wave/boss timers resume where you left off after loading",
			"Boss spawn schedule and wave progress persist correctly across save/load",
		]
	},
	{
		"version": "v0.68.0",
		"title": "More minibosses + aggressive roaming + special attacks",
		"date": "2026-02-25",
		"entries": [
			"4 new minibosses: Shadow Fang (Lv5-7), War Spider (Lv12-14), Bone Lord (Lv18-22), Inferno Wyrm (Lv34-40)",
			"8 total minibosses now spawn on a schedule from 5 to 40 minutes",
			"Minibosses roam much wider (~1500px vs ~400px) and avoid town center",
			"Minibosses patrol faster (85% speed) with shorter idle pauses — restless and threatening",
			"Shadow Fang: savage pounce attack with crouch-leap-bite animation",
			"War Spider: venom barrage with rapid jabs and toxic green burst",
			"Bone Lord: death cleave with spinning slash and purple impact",
			"Inferno Wyrm: uses fire breath like Elder Drake — ultimate late-game boss",
		]
	},
	{
		"version": "v0.67.4",
		"title": "Rats slightly less aggressive",
		"date": "2026-02-25",
		"entries": [
			"Rat aggro range reduced from 120 to 90 — they won't chase you from as far away",
		]
	},
	{
		"version": "v0.67.3",
		"title": "Minibosses always visible on minimap",
		"date": "2026-02-25",
		"entries": [
			"Minibosses now always show on the minimap as pulsing red diamonds once spawned",
			"No longer hidden by fog of war — you can track them from anywhere on the map",
			"Diamond indicator made larger and brighter red with outline for better visibility",
		]
	},
	{
		"version": "v0.67.2",
		"title": "Inventory fits on landscape mobile",
		"date": "2026-02-25",
		"entries": [
			"Inventory now fits on landscape mobile — compact slots, smaller fonts, tighter layout",
			"Equipment slots and bag grid properly sized for landscape (46px / 42px vs 110px portrait)",
			"Bag uses 4 columns in landscape (vs 2 portrait) so all 16 slots fit on screen",
			"Item detail is now a floating popup overlay — no longer eats fixed space at the bottom",
			"Detail popup auto-dismisses after 4 seconds so it doesn't block interaction",
			"Stats label and fixed detail panel hidden on mobile to maximize content space",
		]
	},
	{
		"version": "v0.67.1",
		"title": "Multi-touch potion usage",
		"date": "2026-02-25",
		"entries": [
			"Use potions while holding the joystick or attack button (multi-touch)",
			"Potion buttons now respond to any finger, not just the first touch",
			"Fixes Godot Button control ignoring second-finger taps on mobile",
		]
	},
	{
		"version": "v0.67.0",
		"title": "Double-click/tap to buy & upgrade everywhere",
		"date": "2026-02-25",
		"entries": [
			"Double-click/tap to quick-buy items in the shop (Buy tab)",
			"Double-click/tap to quick-sell items in the shop (Sell tab)",
			"Double-click/tap to quick-build upgrades at the woodworker",
			"Double-click/tap to quick-upgrade at the armory",
			"Single click still shows detail panel with stats — both options available",
		]
	},
	{
		"version": "v0.66.9",
		"title": "Armory double-click upgrade + scaling bonuses",
		"date": "2026-02-24",
		"entries": [
			"Armory: single click shows detail panel, double-click/tap quick-upgrades",
			"Weapon Forge bonuses now scale slightly with level (accelerating at higher levels)",
			"Armor Forge bonuses now scale slightly with level (armor and HP accelerate)",
		]
	},
	{
		"version": "v0.66.8",
		"title": "Consistent single-click detail across all shops",
		"date": "2026-02-24",
		"entries": [
			"Single click instantly shows detail panel in armory and woodworker (no more delay)",
			"Removed double-click quick-upgrade from armory and woodworker for consistency",
			"All shops now use the same pattern: click to view stats → button to buy/upgrade",
		]
	},
	{
		"version": "v0.66.7",
		"title": "Tavern back to random visit + UI polish",
		"date": "2026-02-24",
		"entries": [
			"Tavern reverted to simple random visit — single button, random buff/debuff outcome",
			"Tavern shows result text and active buff timer after visiting",
			"Armory keeps sleek detail panel with manual select → view stats → upgrade flow",
		]
	},
	{
		"version": "v0.66.6",
		"title": "Armory & Tavern UI redesign + double-click quick-build",
		"date": "2026-02-24",
		"entries": [
			"Armory redesigned with sleek upgrade list + detail panel (matches woodworker/shop)",
			"Tavern redesigned with browsable buff list + detail panel",
			"Double-click to quick-upgrade in armory, tavern, and woodworker",
			"All NPC dialogs now share consistent UI pattern: compact list → detail on click",
		]
	},
	{
		"version": "v0.66.5",
		"title": "Fix Shadow Ranger attack breaking permanently",
		"date": "2026-02-24",
		"entries": [
			"Fix critical bug: hit-freeze await could leave Engine.time_scale at 0.1 permanently",
			"Attacks now properly reset on death/respawn — no more stuck attack state",
			"Projectile tweens now owned by projectile node — prevents double-free errors",
			"Added safety resets for attack flags and time_scale on death and respawn",
		]
	},
	{
		"version": "v0.66.4",
		"title": "Woodworker UI redesign + enemy stuck fix",
		"date": "2026-02-24",
		"entries": [
			"Woodworker menu redesigned to match shop layout — concise upgrade list",
			"Click/tap an upgrade to see full details, bonuses, and build button",
			"Enemies no longer get stuck on the hero while moving",
			"Enemy attack state closing speed greatly reduced",
		]
	},
	{
		"version": "v0.66.3",
		"title": "Fix enemies getting stuck on the hero",
		"date": "2026-02-24",
		"entries": [
			"Enemies no longer chase the player at full speed while in attack state",
			"Narrowed attack disengage range so enemies let go sooner when player moves away",
			"Added player-repulsion push so enemies don't pile on top of the hero",
		]
	},
	{
		"version": "v0.66.2",
		"title": "Fix PWA orientation and mobile detection",
		"date": "2026-02-24",
		"entries": [
			"Fix PWA (Add to Home Screen) forcing landscape — now allows any orientation",
			"PWA/standalone mode on Android now correctly detects as mobile device",
			"Prioritize CSS pointer:coarse media query — most reliable touch detection for PWAs",
		]
	},
	{
		"version": "v0.66.1",
		"title": "Fix PWA (Add to Home Screen) always showing desktop layout",
		"date": "2026-02-24",
		"entries": [
			"PWA/standalone mode on Android now correctly detects as mobile",
			"Added CSS pointer:coarse media query check — reliably identifies touch-primary devices",
			"Works for Chrome Add to Home Screen, Samsung Internet, and other PWA launchers",
		]
	},
	{
		"version": "v0.66.0",
		"title": "Robust mobile detection with JavaScript fallback",
		"date": "2026-02-24",
		"entries": [
			"Fix landscape on phones showing desktop layout instead of mobile",
			"Centralized mobile detection via GameManager.is_mobile_device()",
			"JavaScript user-agent fallback for web exports where Godot API is unreliable",
			"All 20+ files now use the unified detection for consistent mobile layouts",
		]
	},
	{
		"version": "v0.65.9",
		"title": "Bigger close buttons, tap-outside-to-close, custom cursor",
		"date": "2026-02-24",
		"entries": [
			"Custom gold cursor — 15% larger on mobile for better visibility",
			"All panel X/close buttons enlarged on mobile for easier tapping",
			"Tap outside any open panel to close it (shop, inventory, tavern, etc.)",
			"Early-game tooltip explaining the cursor for new players",
		]
	},
	{
		"version": "v0.65.8",
		"title": "Custom branded loading screen and cinematic title intro",
		"date": "2026-02-24",
		"entries": [
			"Loading screen now shows 'OPEN LEGENDS RPG' title in gold with glowing text animation",
			"Modern slim progress bar with gold shimmer effect replaces the default Godot loading bar",
			"Loading percentage displayed below the bar",
			"Loading screen fades out smoothly when the game is ready",
			"Hero select intro: title fades in with scale punch, subtitle follows, then cards slide up",
			"Each element animates in sequence for a cinematic reveal",
		]
	},
	{
		"version": "v0.65.7",
		"title": "Fix loading in Facebook Messenger and in-app browsers",
		"date": "2026-02-24",
		"entries": [
			"Game now detects in-app browsers (Facebook, Instagram, Snapchat, TikTok, etc.)",
			"Shows a branded 'Open in Browser' page instead of hanging on a loading screen",
			"Tap the button to launch in Chrome/Safari where the game runs properly",
		]
	},
	{
		"version": "v0.65.6",
		"title": "Custom boot screen with cinematic title fade-in",
		"date": "2026-02-24",
		"entries": [
			"Boot splash now shows a dark screen instead of the Godot logo",
			"Title screen fades in cinematically from the dark boot background",
			"Smooth overlay dissolve followed by content reveal for a branded launch experience",
		]
	},
	{
		"version": "v0.65.5",
		"title": "Arrow Rain now reliably hits all nearby enemies",
		"date": "2026-02-24",
		"entries": [
			"Arrow Rain (triple-tap) now centered on the hero instead of offset in attack direction",
			"AoE radius increased from 70 to 150 — covers a much larger area",
			"Arrow count doubled from 6 to 12 for denser visual coverage",
			"Guaranteed AoE damage sweep hits all enemies in radius (no more gaps from random arrow placement)",
		]
	},
	{
		"version": "v0.65.4",
		"title": "Mobile virtual joystick",
		"date": "2026-02-24",
		"entries": [
			"Added floating virtual joystick on the left side of the screen for mobile movement",
			"Touch the left 40% of the screen to summon the joystick, drag to move in any direction",
			"Joystick adapts size for portrait and landscape orientations",
			"Tap-to-move still works outside the joystick area",
			"Joystick styled to match the SC:BW aesthetic (dark base, gold ring and knob)",
		]
	},
	{
		"version": "v0.65.3",
		"title": "Click/tap to aim dash attacks and specials",
		"date": "2026-02-24",
		"entries": [
			"Click or tap anywhere to set attack direction for dash strikes, charge attacks, and specials",
			"Desktop: left/right click sets aim direction (0.6s window) used by next attack",
			"Mobile: any non-ATK finger tap sets aim direction for the next attack",
			"Direction priority: held keys > recent click/tap > mobile touch > velocity > facing",
		]
	},
	{
		"version": "v0.65.2",
		"title": "Fix charge attack direction getting stuck",
		"date": "2026-02-24",
		"entries": [
			"Fixed charge attack direction getting overridden by click-to-move velocity",
			"Movement-based facing no longer resets aim direction while charging",
		]
	},
	{
		"version": "v0.65.1",
		"title": "8-direction hero sprites and charge aim arrow",
		"date": "2026-02-24",
		"entries": [
			"Heroes now face 8 directions instead of 4 — diagonal movement uses unique sprites",
			"New down-side and up-side diagonal idle and walk cycle sprites for both heroes",
			"Angle-based octant detection for smooth 8-way facing transitions",
			"Charge attack now shows a directional arrow indicator pointing where you'll attack",
			"Arrow updates in real-time as you aim during charge hold",
		]
	},
	{
		"version": "v0.65.0",
		"title": "Unique attack animations for all enemy types",
		"date": "2026-02-24",
		"entries": [
			"Every enemy type now has a unique attack animation matching their character",
			"Wolf bite with head shake, spider fang stab, bandit sword slash, skeleton sword swing",
			"Dark mage staff bolt, ogre fist slam, cave snake strike, bat swoop, flan bounce, mimic chomp",
			"Ghoul claw swipe, crypt knight armored swing, and all dungeon enemies",
			"15% chance for special attacks with 1.2-1.4x bonus damage and dramatic animations",
			"Troll mega punch, wolf savage lunge, spider venom strike, mimic devour, and more",
		]
	},
	{
		"version": "v0.64.5",
		"title": "Tap-to-aim during charge attack",
		"date": "2026-02-24",
		"entries": [
			"Mobile: tap anywhere on screen with a second finger while charging to aim the attack",
			"Desktop: click anywhere while holding attack to change aim direction",
			"Taps during charge set facing instead of issuing a move command",
		]
	},
	{
		"version": "v0.64.4",
		"title": "Power Strike rework — AoE lunge slam",
		"date": "2026-02-24",
		"entries": [
			"Power Strike now lunges the hero 80 units forward with a big bouncy slam",
			"Hits up to 5 enemies in a directional cone with 1.5x splash damage",
			"Triple slash VFX fan, stronger knockback (120), and bigger screen shake",
			"Satisfying spring-bounce recovery animation after impact",
		]
	},
	{
		"version": "v0.64.3",
		"title": "Fix charge attack aiming",
		"date": "2026-02-24",
		"entries": [
			"Character now faces aim direction throughout the entire charge hold",
			"Mobile: drag-to-aim works immediately when holding ATK, not just after charge is full",
			"Desktop: arrow keys update facing continuously while charging",
		]
	},
	{
		"version": "v0.64.2",
		"title": "Fill empty map areas with enemy camps",
		"date": "2026-02-24",
		"entries": [
			"Added 20 new enemy camps across previously empty outer and far zones",
			"Wolves, skeletons, spiders, bandits, trolls, dark mages, and ogres now fill gaps",
			"No more large empty stretches when exploring far from town",
		]
	},
	{
		"version": "v0.64.1",
		"title": "Mobile charge attack drag-to-aim",
		"date": "2026-02-24",
		"entries": [
			"Hold ATK to charge, then drag finger to aim the charged slash/sniper shot direction",
			"Hero faces the drag direction in real-time while charging for visual feedback",
			"Works just like holding arrow keys on desktop to aim before releasing",
		]
	},
	{
		"version": "v0.64.0",
		"title": "Dungeon minimap, larger crypt, enemy bounds",
		"date": "2026-02-24",
		"entries": [
			"Minimap now switches to dungeon layout when entering the Crypt",
			"Dungeon minimap shows enemy dots, exit beacon (green), and player position",
			"Click-to-move on minimap works within the dungeon",
			"Minimap restores to Haven's Rest layout on dungeon exit",
			"Dungeon Crypt doubled in size from 1000x1000 to 2000x2000",
			"Added 4 more enemy camps (12 total) spread across the larger dungeon",
			"Enemies now stay within dungeon walls instead of wandering into the void",
		]
	},
	{
		"version": "v0.63.3",
		"title": "Larger ATK button on mobile",
		"date": "2026-02-24",
		"entries": [
			"Mobile ATK button is now 20% larger for easier tapping",
		]
	},
	{
		"version": "v0.63.2",
		"title": "Fix dungeon enter/exit teleport loop",
		"date": "2026-02-24",
		"entries": [
			"Fixed entering dungeon immediately triggering exit beacon (teleport loop)",
			"Moved exit beacon away from dungeon spawn point",
			"Added 1s teleport cooldown to prevent beacon re-trigger after any teleport",
		]
	},
	{
		"version": "v0.63.1",
		"title": "Rat nerf + Bleeding debuff",
		"date": "2026-02-24",
		"entries": [
			"Rats nerfed: 50% reduced XP, attack damage, and attribute growth scaling",
			"Rats now have a 2% chance per hit to cause Bleeding (damage over time for 5 seconds)",
			"Bleeding effect shows red pulsing aura, BLEEDING! label, and blood drip particles",
			"New bleed tick SFX plays each second while bleeding",
		]
	},
	{
		"version": "v0.63.0",
		"title": "Underground Crypt dungeon",
		"date": "2026-02-24",
		"entries": [
			"New dungeon stairwell in town — enter the Crypt (requires Level 10)",
			"8 new dungeon enemy types: Cave Snake, Dungeon Bat, Vampire Bat, Flan, Mimic, Ghoul, Crypt Knight, Lich",
			"Each enemy has unique procedural sprite and death SFX",
			"Dark underground atmosphere with stone corridors",
			"Exit beacon to return to town",
			"Dungeon enter/exit sound effects",
		]
	},
	{
		"version": "v0.62.3",
		"title": "Fix ATK button overlapping OPT menu on mobile",
		"date": "2026-02-24",
		"entries": [
			"ATK button now hides when OPT or MAP overlay is open on mobile",
			"ATK button reappears when overlay is closed",
		]
	},
	{
		"version": "v0.62.2",
		"title": "Improved shop & save/load SFX",
		"date": "2026-02-24",
		"entries": [
			"Sell SFX: obvious CHA-CHING with drawer slam, coin cascade, and bright register bell",
			"Buy SFX: descending coins (spending) + soft thud (goods received) — distinct from sell",
			"New save game SFX: quill scratch on parchment + warm confirmation chime",
			"New load game SFX: page unfurling + ascending chime (world restored)",
		]
	},
	{
		"version": "v0.62.0",
		"title": "Double-tap quick-sell in shop",
		"date": "2026-02-24",
		"entries": [
			"Double-tap/double-click an item in the Sell tab to instantly sell it",
			"Hint label shown above sell list as a reminder",
			"Single-tap still opens item detail panel as before",
		]
	},
	{
		"version": "v0.61.5",
		"title": "Fix minimap tap-to-expand on mobile",
		"date": "2026-02-24",
		"entries": [
			"Small minimap in bottom bar is now tappable to open expanded view",
			"Fixed minimap consuming touch events even when in preview mode",
			"Click-to-move only active in the expanded overlay, not the small preview",
		]
	},
	{
		"version": "v0.61.2",
		"title": "Menu button on all platforms",
		"date": "2026-02-23",
		"entries": [
			"Desktop: Menu button added to command card grid (also Esc key)",
			"Mobile portrait: Menu button added to OPT command overlay",
			"Mobile landscape: Menu button added to compact command grid",
			"Removed unreliable floating top-bar menu button on mobile",
		]
	},
	{
		"version": "v0.61.1",
		"title": "Fix miniboss minimap diamond not appearing",
		"date": "2026-02-23",
		"entries": [
			"Mini-boss camps now spawn enemies immediately regardless of distance",
			"Fixes pulsing diamond indicator not showing on minimap when boss spawns far away",
		]
	},
	{
		"version": "v0.61.0",
		"title": "New enemy: Tree God Elk",
		"date": "2026-02-23",
		"entries": [
			"Added Tree God Elk — majestic nature-infused elk enemy (Lv8-11)",
			"Unique procedural sprite: bark body, branching antlers with green leaf tips, glowing green eyes",
			"Unique antler charge attack animation: rear up, stamp, gore charge, antler toss",
			"Unique nature collapse death animation: stagger wobble, root tendrils grow outward, green fade",
			"Spawns at 6:00 wave between trolls and dark mages",
		]
	},
	{
		"version": "v0.60.4",
		"title": "Miniboss minimap indicator",
		"date": "2026-02-23",
		"entries": [
			"Active minibosses now show as pulsing orange diamond on the minimap",
			"Diamond pulses to draw attention when '!! MINI-BOSS INCOMING !!' announces",
			"Indicator disappears when the miniboss is defeated",
		]
	},
	{
		"version": "v0.60.3",
		"title": "Button visual feedback across all UI",
		"date": "2026-02-23",
		"entries": [
			"All buttons now have hover glow, press feedback, and styled borders",
			"Pause menu: Resume, Save, Load, Changelog, Help, Quit, and Close buttons styled",
			"Tavern: Close and Visit buttons now have press/hover states",
			"Shop: Close, Buy/Sell tabs, Buy/Sell action, and Back buttons styled",
			"Changelog: Close button styled",
			"HUD: Menu button, command overlay buttons, and map overlay close button styled",
			"Help dialog: Close button styled",
		]
	},
	{
		"version": "v0.60.2",
		"title": "Fix mobile top bar cutoff & add kills to stats panel",
		"date": "2026-02-23",
		"entries": [
			"Top bar uses generous percentage-based padding for rounded screen corners",
			"Portrait: 6% horizontal + 4% top padding, Landscape: 5% horizontal padding",
			"Menu button and Kills label no longer hidden behind rounded corners or notch",
			"Hero stats panel now shows Total Kills and Next Milestone target",
		]
	},
	{
		"version": "v0.60.0",
		"title": "Kill Counter & Milestone Rewards",
		"date": "2026-02-23",
		"entries": [
			"Replaced alignment display with a kill counter in the top bar",
			"Kill counter tracks total enemies slain and updates in real-time",
			"Milestone rewards at 100, 200, 500, 1K, 2K, 5K, and 10K kills",
			"Each milestone grants gold and a random gear drop near the player",
			"Higher milestones drop rarer gear (Common → Legendary)",
			"Milestone progress saved and restored with save/load",
		]
	},
	{
		"version": "v0.59.0",
		"title": "Potion system overhaul: stacking % health potions",
		"date": "2026-02-23",
		"entries": [
			"Replaced all consumables with 3 potion types: Small (33% HP), Medium (50% HP), Great (100% HP)",
			"Potions now stack up to 99x in 3 dedicated HUD slots",
			"Healing scales with max HP — potions stay useful at every level",
			"Weak enemies drop Small Potions, mid enemies drop Medium, strong enemies drop Great",
			"Shop updated with all 3 potion tiers",
			"Removed mana potions and elixirs (simplified to health potions only)",
		]
	},
	{
		"version": "v0.58.1",
		"title": "Fix mobile command overlay potion indices",
		"date": "2026-02-23",
		"entries": [
			"Fixed mobile command overlay potion buttons pointing at wrong grid children after ability removal",
		]
	},
	{
		"version": "v0.58.0",
		"title": "Beacon entry sound effects",
		"date": "2026-02-23",
		"entries": [
			"Shop entrance plays welcoming door chime with coin sparkle",
			"Tavern entrance plays cozy wooden door thud with warm hearth tones",
			"Woodworker entrance plays rustic workshop creak with tool clinks",
			"Info beacon plays ethereal mystical knowledge chime",
		]
	},
	{
		"version": "v0.57.6",
		"title": "Desktop hero select screen overhaul",
		"date": "2026-02-23",
		"entries": [
			"Larger hero cards (420x520) with bigger fonts across the board",
			"Hero name now 36px uppercase with hero color accent",
			"Styled select buttons with hero-colored normal/hover/pressed states",
			"Bigger game title (64px), subtitle (22px), byline (20px), and version button (18px)",
			"Added color accent bar at top of each card",
		]
	},
	{
		"version": "v0.57.5",
		"title": "Fix hero load: restore _spawn_projectile",
		"date": "2026-02-23",
		"entries": [
			"Restored _spawn_projectile() to player.gd — was deleted during ability removal but is still used by Shadow Ranger's normal ranged attack and Shadow Step special attack",
		]
	},
	{
		"version": "v0.57.4",
		"title": "Fix hero not loading after ability removal",
		"date": "2026-02-23",
		"entries": [
			"Fixed crash on hero load: hud.gd setup() still referenced player.ability_mgr after AbilityManager was removed",
			"Removed leftover ability_font_size unused variable from hero_select.gd",
		]
	},
	{
		"version": "v0.57.3",
		"title": "Remove Q/E Abilities",
		"date": "2026-02-23",
		"entries": [
			"Removed Q and E ability system entirely from desktop and mobile",
			"Removed Ability1/Ability2 buttons from HUD command card (both scene and script)",
			"Removed ability tooltip system — panel, timer, hover/long-press handlers, builder function",
			"Removed ability buttons from mobile command overlay",
			"Removed Q/E input actions from project input map",
			"Removed AbilityManager node from player scene and all ability execution logic from player script",
			"Removed ability definitions from hero data (Cleave, Shield Wall, Multi-Shot, Evasion)",
			"Removed ability display from hero select screen",
			"Removed Q/E tutorial hints from all platforms; removed 'Hold ability button' mobile tip",
		]
	},
	{
		"version": "v0.57.2",
		"title": "Fix intermittent mobile browser hang on load",
		"date": "2026-02-23",
		"entries": [
			"export_presets: inject AudioContext pre-unlock script in HTML head — prevents Godot audio server stall on iOS/Android (browsers block AudioContext until first user gesture)",
			"AudioManager: trim startup pregeneration from 57 sounds down to 14 essentials — reduces JS thread hold time by ~4x on first frames; all other sounds lazy-load imperceptibly on first use",
			"AudioManager: add one-frame settle delay before pregeneration starts, and reduce batch size from 8 to 3 per frame",
			"SpriteGenerator: reduce web batch size from 10 to 4 sprites/frame; add one-frame settle delay before first batch — keeps hero-select screen responsive on slow mobile CPUs",
		]
	},
	{
		"version": "v0.57.1",
		"title": "Warmer Hero Respawn Sound",
		"date": "2026-02-23",
		"entries": [
			"Respawn complete SFX overhauled: extended to 2.2s (was 0.9s) with deep sub-bass swell, detuned choir unison pairs for natural warmth, harmonics that bloom in progressively, and staggered sparkle cascades",
		]
	},
	{
		"version": "v0.57.0",
		"title": "Mobile UI Overhaul — Bigger Buttons & Better Feedback",
		"date": "2026-02-23",
		"entries": [
			"Armory: upgrade buttons enlarged (320x110), styled hover/pressed/disabled states, tap SFX on press, forge sound lowered",
			"Woodworker: build buttons enlarged (300x100), styled hover/pressed/disabled states, tap SFX on press, build sound lowered",
			"Shop: item rows taller (100px), action buttons bigger (280/220), fonts increased across all labels",
			"Inventory: equipment slots taller (110px), bag grid items taller (110px), unequip buttons bigger (96x96), wider grid spacing",
			"Both armory and woodworker now flash the panel on successful upgrade for visual confirmation",
			"All upgrade/build buttons now have proper hover glow, press feedback, and disabled styling",
			"Item list spacing increased on mobile for easier tapping between rows",
		]
	},
	{
		"version": "v0.56.0",
		"title": "Overhauled Tutorial Tooltips",
		"date": "2026-02-23",
		"entries": [
			"Tooltips are now hero-specific — Blade Knight and Shadow Ranger get their own ability and special attack tips",
			"Mobile tooltips no longer reference keyboard keys (Q/E/SPACE) — uses 'ATK button' and 'left/right ability' instead",
			"Desktop tooltips use proper key names (Q, E, SPACE, I, Esc)",
			"Added close (X) button to tooltip panel — works on both mobile and desktop",
			"New tips: heal beacons and immunity, shops and town upgrades, tree chopping and wood yields, item drops and equipment, visual sprite upgrades every 5 levels, miniboss red beacons",
			"Ability tips now include their description (what the ability actually does)",
			"Special attack tips include damage multipliers and projectile counts",
		]
	},
	{
		"version": "v0.55.0",
		"title": "Hero Sprite Tier Upgrades",
		"date": "2026-02-23",
		"entries": [
			"Both Blade Knight and Shadow Ranger now get visual sprite upgrades every 5 levels (t1–t10)",
			"Blade Knight evolves from steel blue armor to radiant gold with growing crest, shoulder/shield emblems, and longer sword glow",
			"Shadow Ranger evolves from forest green to spectral violet with glowing eyes, bowstring aura, hood trim, and luminous arrow tips",
		]
	},
	{
		"version": "v0.54.1",
		"title": "Level Up SFX On Every Level",
		"date": "2026-02-23",
		"entries": [
			"Level-up rushing SFX now plays on every level up, not just at sprite upgrade milestones",
		]
	},
	{
		"version": "v0.54.0",
		"title": "Hero Long-Press Outline Feedback",
		"date": "2026-02-23",
		"entries": [
			"Touching and holding on the hero (mobile) now highlights the character with a bright green outline while holding",
			"Outline disappears when finger lifts, drifts away, or the stats panel opens",
		]
	},
	{
		"version": "v0.53.0",
		"title": "Proximity Beacon Labels & Longer Tooltips",
		"date": "2026-02-23",
		"entries": [
			"Info and Heal beacon labels now only appear when the hero is nearby (same range as NPC labels)",
			"Tutorial hint tooltips now display for 12 seconds instead of 6 for easier reading",
		]
	},
	{
		"version": "v0.52.0",
		"title": "Shop Q-Key & Consistent Mobile Close Buttons",
		"date": "2026-02-23",
		"entries": [
			"Shop now shows Close [Q] hint on desktop (was missing Q shortcut label)",
			"Mobile close buttons no longer show [Q] text — just a clean X",
			"All mobile X/close buttons are now the same larger size across every panel and modal",
		]
	},
	{
		"version": "v0.51.1",
		"title": "Cap Rat Spawn Level to Hero Level",
		"date": "2026-02-23",
		"entries": [
			"Rats no longer spawn at a higher level than the hero",
		]
	},
	{
		"version": "v0.51.0",
		"title": "Fix Enemies Getting Stuck & Hero Pathfinding",
		"date": "2026-02-23",
		"entries": [
			"Fixed enemies getting stuck oscillating instead of attacking (separation push now fans out around player, not away)",
			"Reduced disengage range from 4x to 2x attack range so enemies stay in combat",
			"Enemies now check range before dealing damage (no phantom hits from across the screen)",
			"Hero now steers around trees and buildings instead of getting stuck on them",
		]
	},
	{
		"version": "v0.50.0",
		"title": "Troll Combat Overhaul — Slow Heavy Attacks",
		"date": "2026-02-23",
		"entries": [
			"Trolls now attack with a slow, powerful overhead club slam (2.8s cooldown vs 1.2s default)",
			"New troll swing animation: long wind-up, menacing pause, heavy slam with impact shake, slow recovery",
			"Troll base attack damage increased (18 base vs formula default) — fewer hits but each one hurts",
			"Attack cooldown is now per-enemy-type (trolls 2.8s, others remain 1.2s)",
			"Troll attack range slightly increased (45 vs 40) to match their long arms",
		]
	},
	{
		"version": "v0.49.0",
		"title": "Fix Save/Load — All Stats & Resources Now Saved",
		"date": "2026-02-23",
		"entries": [
			"Wood amount is now saved and restored (was lost on every load)",
			"All woodwork upgrade levels (Bow, Shield, Totem, Watchtower) are now saved",
			"Hero stats (HP, STR, AGI, INT, armor, ATK, mana) now properly recalculated on load from level growth",
			"Armory and woodwork stat bonuses re-applied on load (weapon/armor/HP/XP bonuses were zeroed out)",
			"Skill points are now saved and restored",
			"Backwards-compatible: old saves load safely with defaults for new fields",
		]
	},
	{
		"version": "v0.48.1",
		"title": "Fix Desktop Tooltip Race Condition",
		"date": "2026-02-23",
		"entries": [
			"Fixed potential crash when quickly moving mouse away from ability buttons during tooltip delay",
		]
	},
	{
		"version": "v0.48.0",
		"title": "Tooltip & Hint System Overhaul",
		"date": "2026-02-23",
		"entries": [
			"Fixed tutorial hints being invisible (positioned off-screen due to anchor bug)",
			"Added gameplay hints: inventory, potions, beacons, trees, pause menu Help",
			"Mobile: hold Q or E for 0.6s to see ability tooltip (mana cost, cooldown, damage)",
			"Mobile: tap hint popups to dismiss them early",
			"Desktop: hover Q/E buttons for ability tooltips (unchanged)",
		]
	},
	{
		"version": "v0.47.1",
		"title": "Fix Top Bar Cutoff on Mobile Fullscreen",
		"date": "2026-02-23",
		"entries": [
			"Top resource bar (Gold, Wood, Alignment) no longer gets clipped at the right edge on mobile fullscreen",
			"Added safe-area-aware right padding so labels stay visible on devices with notches or rounded corners",
		]
	},
	{
		"version": "v0.47.0",
		"title": "Enemy Scaling Overhaul",
		"date": "2026-02-23",
		"entries": [
			"Enemies now scale much closer to the hero's level (85% stat growth vs 60% before)",
			"Respawned enemies stay stronger longer: decay 4% per respawn instead of 10%, floor raised from 60% to 80%",
			"XP per enemy level increased from +5 to +8, gold from +2 to +3 per level",
		]
	},
	{
		"version": "v0.46.1",
		"title": "Fix Reinforced Bow Build SFX",
		"date": "2026-02-23",
		"entries": [
			"Reinforced bow craft sound now ascends in pitch instead of descending, matching other positive upgrade sounds",
		]
	},
	{
		"version": "v0.46.0",
		"title": "More Enemies in the Wilds & Performance Optimization",
		"date": "2026-02-23",
		"entries": [
			"Added 20 new creep camps across mid-to-far zones (wolves, spiders, trolls, dark mages, ogres)",
			"Wave spawns now deploy more camps per wave (3-4 → 5-6) for denser encounters",
			"Reduced base respawn timer from 45s to 30s and wave respawn from 60s to 40s",
			"Performance: enemy separation now checks only camp-mates instead of all enemies globally (O(n²) → O(k))",
		]
	},
	{
		"version": "v0.45.1",
		"title": "More Opaque Panels & Fix Duplicate Close Button",
		"date": "2026-02-23",
		"entries": [
			"All dialog panels (shop, armory, inventory, tavern, etc.) are now much more opaque for better readability (78% -> 93%)",
			"Fixed inventory close button duplicating every time the panel was opened on mobile",
		]
	},
	{
		"version": "v0.45.0",
		"title": "Safari & Cross-Browser Fullscreen Fix",
		"date": "2026-02-23",
		"entries": [
			"iOS Safari: shows a one-time hint to 'Add to Home Screen' for fullscreen (API not supported by Apple)",
			"iOS Safari: maximizes viewport via CSS so the game fills as much screen as possible",
			"Fullscreen now re-engages on next tap if the user exits it (listeners no longer removed)",
			"Added vendor prefixes for older Firefox, Edge, and Safari fullscreen APIs",
			"Tries multiple fullscreen targets (document, body, canvas) for broader compatibility",
		]
	},
	{
		"version": "v0.44.2",
		"title": "More Forgiving Multi-Tap Specials",
		"date": "2026-02-23",
		"entries": [
			"Tap window for double-tap and triple-tap special attacks widened from 120ms to 180ms",
			"Whirlwind (triple-tap) and Power Strike (double-tap) are now much easier to trigger",
			"Same improvement applies to both desktop spacebar and mobile ATK button",
		]
	},
	{
		"version": "v0.44.1",
		"title": "Fix Charge Attack Getting Stuck on Mobile",
		"date": "2026-02-23",
		"entries": [
			"Fixed charge attack VFX getting stuck if finger lifts during an attack animation",
			"Added safety fallback that force-clears charge state if touch release event is lost",
			"Charge glow and sprite shake now always stop immediately on release",
		]
	},
	{
		"version": "v0.44.0",
		"title": "Hero Immunity Visual Feedback",
		"date": "2026-02-23",
		"entries": [
			"Hero now glows green with a pulsing aura when standing on a heal beacon",
			"Floating 'IMMUNE' label bobs above the hero while immunity is active",
			"Hero sprite pulses with a green tint to clearly show protected status",
			"All immunity visuals cleanly fade when stepping off the beacon",
		]
	},
	{
		"version": "v0.43.4",
		"title": "Fix Map Overlay Size in Landscape",
		"date": "2026-02-23",
		"entries": [
			"Map overlay no longer fills the entire screen in landscape mode",
			"Landscape map is now a compact centered panel (50% height, 45% width)",
		]
	},
	{
		"version": "v0.43.3",
		"title": "Fix Chrome Mobile Fullscreen (Again)",
		"date": "2026-02-23",
		"entries": [
			"Switched fullscreen trigger from touchstart/pointerdown to touchend/click events",
			"Chrome treats touchstart as passive, which silently blocks fullscreen requests",
			"Fullscreen listeners now persist until fullscreen actually succeeds instead of removing on first tap",
		]
	},
	{
		"version": "v0.43.2",
		"title": "Larger Mobile Buttons",
		"date": "2026-02-23",
		"entries": [
			"Close/X buttons are bigger and easier to tap on mobile across all dialogs",
			"Shop Buy/Sell and Back buttons enlarged for mobile",
			"Armory upgrade button enlarged for mobile",
		]
	},
	{
		"version": "v0.43.1",
		"title": "Fix Mobile Chrome Fullscreen",
		"date": "2026-02-23",
		"entries": [
			"Fixed fullscreen not triggering on Chrome mobile by using a native JS listener",
			"Fullscreen request now fires inside the browser's own event handler to satisfy user-activation requirements",
		]
	},
	{
		"version": "v0.43.0",
		"title": "Mobile Fullscreen & PWA Support",
		"date": "2026-02-23",
		"entries": [
			"Fullscreen now works more reliably on Android mobile browsers",
			"Enabled PWA so the game can be installed via 'Add to Home Screen'",
			"iOS users can add to home screen for a fullscreen experience",
		]
	},
	{
		"version": "v0.42.6",
		"title": "Consistent Panel Transparency & Mobile UX",
		"date": "2026-02-23",
		"entries": [
			"All menu/dialog panels now share the same 78% opacity for readability",
			"Inventory mobile close button is larger and easier to tap",
		]
	},
	{
		"version": "v0.42.5",
		"title": "More Transparent Inventory Panel",
		"date": "2026-02-23",
		"entries": [
			"Inventory panel is now more see-through (opacity 92% → 78%)",
		]
	},
	{
		"version": "v0.42.4",
		"title": "Fix Mob Group Pathfinding & Attack",
		"date": "2026-02-23",
		"entries": [
			"Enemies no longer physically block each other when chasing the hero",
			"Mobs in a group now swarm and attack aggressively instead of lining up",
			"Replaced hard enemy-to-enemy collision with soft proximity separation",
			"Enemies in attack state close distance on the hero more urgently",
		]
	},
	{
		"version": "v0.42.3",
		"title": "Game Messages Fit Portrait Screens",
		"date": "2026-02-23",
		"entries": [
			"Info beacon and other game messages now word-wrap on narrow screens",
			"Message container stretches to full viewport width with padding",
		]
	},
	{
		"version": "v0.42.2",
		"title": "Sleeker Hero Stats Panel",
		"date": "2026-02-23",
		"entries": [
			"Redesigned hero stats panel with a darker, semi-transparent backdrop",
			"Color-coded stat labels: HP in red, Mana in blue, bonuses in green/red",
			"Buff entries now have subtle tinted backgrounds and arrow icons",
			"Styled close button with hover effects and rounded corners",
			"Panel background uses rounded corners, border glow, and drop shadow",
			"Fixed readability on both desktop and mobile",
		]
	},
	{
		"version": "v0.42.1",
		"title": "Bigger MAP & OPT Buttons in Portrait",
		"date": "2026-02-23",
		"entries": [
			"MAP and OPT are now large square buttons flanking the bars",
			"MAP on the left, OPT (commands) on the right — much easier to tap",
			"Bottom bar height unchanged — buttons fill the full panel height",
		]
	},
	{
		"version": "v0.42.0",
		"title": "Long-Press Hero for Stats (Mobile)",
		"date": "2026-02-23",
		"entries": [
			"Hold your hero for 2 seconds on mobile to open the detailed stats panel",
			"Same panel as desktop right-click — shows HP, Mana, STR, AGI, INT, buffs",
			"Cancels if finger moves too far, so it won't interfere with movement or ATK",
			"Tutorial hints at ~20s, ~3min, and ~8min remind players about this feature",
		]
	},
	{
		"version": "v0.41.1",
		"title": "Fix ATK Button Positioning in Landscape",
		"date": "2026-02-23",
		"entries": [
			"ATK button now repositions on viewport resize via size_changed signal",
			"Fixes button placed off-screen when viewport size differs at _ready() time",
			"Button adapts correctly when switching between portrait and landscape",
		]
	},
	{
		"version": "v0.41.0",
		"title": "Cleaner Level-Up Notifications",
		"date": "2026-02-23",
		"entries": [
			"Level-up message shortened to 'Level Up! Lv X' — no more hero tier text",
			"Individual stat gains (+HP, +STR, etc.) now show as top-down notifications",
			"Level-up no longer triggers big center screen text — top-down only",
			"Removed duplicate LEVEL UP message from sprite upgrade milestones",
		]
	},
	{
		"version": "v0.40.2",
		"title": "Fix ATK Button Hidden in Landscape",
		"date": "2026-02-23",
		"entries": [
			"ATK button canvas layer raised to 11 so it renders above the HUD (layer 10)",
			"Fixes button being invisible in landscape where HUD bottom panel covered it",
		]
	},
	{
		"version": "v0.40.1",
		"title": "Thicker Mobile HP/MP/XP Bars",
		"date": "2026-02-23",
		"entries": [
			"HP/MP/XP bars doubled to 40px on mobile (portrait and landscape)",
			"ATK button and hint panel repositioned for taller bottom panel",
		]
	},
	{
		"version": "v0.40.0",
		"title": "Mobile MAP Button & Minimap Overlay",
		"date": "2026-02-23",
		"entries": [
			"Bottom bar now has CMD and MAP buttons stacked in portrait mode",
			"MAP button opens a fullwidth minimap overlay with click-to-move support",
			"Minimap renders at any size — dots and fog scale with the control",
			"Only one overlay open at a time (CMD closes MAP and vice versa)",
		]
	},
	{
		"version": "v0.39.5",
		"title": "Smooth Bars & Uniform Thickness",
		"date": "2026-02-23",
		"entries": [
			"Removed segmented drawing from HP/MP/XP bars — now smooth continuous fill",
			"All three bars (HP, MP, XP) are the same 20px height on every format",
			"No more per-platform bar size overrides — desktop, landscape, and portrait all match",
		]
	},
	{
		"version": "v0.39.2",
		"title": "Reliable Mobile Detection via Touchscreen API",
		"date": "2026-02-23",
		"entries": [
			"Mobile detection now uses DisplayServer.is_touchscreen_available() as primary check",
			"Fixes mobile layout not loading on high-res phones where both dimensions exceed 700px",
			"Works reliably in both portrait and landscape on all mobile devices",
		]
	},
	{
		"version": "v0.39.1",
		"title": "Fix Mobile Detection in Landscape",
		"date": "2026-02-23",
		"entries": [
			"Fixed mobile detection across all screens — landscape on mobile now correctly uses mobile layout",
			"Hero select screen in landscape on mobile now shows same mobile cards instead of desktop layout",
			"Detection changed from width-only check to min-dimension check (works for both orientations)",
		]
	},
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
	_style_btn(close_button, Color(1.0, 0.4, 0.3))
	version_label.text = GAME_VERSION

func open() -> void:
	_is_visible = true
	panel.visible = true
	var vp_size = get_viewport().get_visible_rect().size
	_is_mobile = GameManager.is_mobile_device()
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
		close_button.text = "X"
		close_button.custom_minimum_size = Vector2(160, 130)
		close_button.add_theme_font_size_override("font_size", 60)
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

func _style_btn(btn: Button, accent: Color = Color(0.9, 0.75, 0.3)) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.11, 0.08, 0.95)
	normal.border_color = accent * Color(0.5, 0.5, 0.5, 0.6)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(4)
	var hover = normal.duplicate()
	hover.bg_color = Color(0.18, 0.16, 0.12, 0.95)
	hover.border_color = accent * Color(0.8, 0.8, 0.8, 0.8)
	var pressed = normal.duplicate()
	pressed.bg_color = Color(0.25, 0.22, 0.14, 0.95)
	pressed.border_color = accent
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)

func _unhandled_input(event: InputEvent) -> void:
	if not _is_visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ability_1"):
		close()
		get_viewport().set_input_as_handled()
		return
	var pos := Vector2(-1, -1)
	if event is InputEventMouseButton and event.pressed:
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pos = event.position
	if pos.x >= 0 and not panel.get_global_rect().has_point(pos):
		close()
		get_viewport().set_input_as_handled()
