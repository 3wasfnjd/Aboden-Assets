class_name AbodenShotCatalog
extends RefCounted
## The blaster's shot styles (حزمة أسلحة عبودين): their names, icons, sounds, what unlocked
## them originally, a line on each, and their flight numbers (SHOT_STYLE). The single
## source of truth: AbodenBlaster reads its numbers from here.
##
## The first twelve numbers are the original game's (docs/CHANGELOG.md); AB-W-013 ... 022
## are the kit's own (v1.2).

## In catalogue order (AB-W-001, 002, ...): the four starter styles, then the ones challenges
## unlocked, then the ten of v1.2 (AB-W-013 ... 022). New weapons go at the end with the next code.
const ORDER := ["bolt", "mini", "bubble", "firework", "confetti", "bouncy", "laser", "boomerang", "glob", "rocket", "lightning", "dallah", "falcon", "freeze", "blackhole", "dates", "bakhoor", "lasso", "hose", "cluster", "magnet", "shield"]

## The dallah's ding (fair_ding) is soft: its level when fired and when it spills, and the
## least time between two of its dings (a held trigger, both hands, spills landing together).
const DALLAH_FIRE_K := 0.3
const DALLAH_SPILL_K := 0.22
const DALLAH_DING_GAP := 0.3
## The least time between two thumps of the dallah's coffee beans hitting things.
const BEAN_THUMP_GAP := 0.15

## The flight of each style. Metres and seconds, scaled by the host's blaster_scale()
## (game units per metre): speed (m/s), grav (times g = 9.8 m/s², negative floats up), life
## (s), r (hit radius, m), cool (the least time between two shots of a hand, s; holding the
## trigger fires at that rate), sk (the firing sound's k), and per style: burst (blast radius,
## m), pellets/cone (count, half-angle in radians), bounces/pops (caps; 1e9 = unlimited),
## range (m)/pierce (targets), reach (m)/swing (m), splat (radius, m), turn (rad/s)/seek (m),
## chain (targets)/hop (m)/cone (rad), spray (s between beans). "bean" is the dallah's pellet.
## v1.2: dive (m: the falcon screeches and stoops this close to its prey), frost (s a target
## stays frozen), linger (s a parked shot stays: the black hole's pull, the bakhoor's smoke, the
## magnet's field; for these `life` is the flight before it parks), field (pull radius, m), tug
## (pull speed, m/s), cloud (smoke radius, m), slow (speed factor in the smoke, 0..1), drag (s the
## lasso pulls what it caught), push (m/s a hose drop sets a target moving, blaster_push), shove
## (m a hose drop moves a target, for a host with blaster_pull only; its `pellets` drops a shot
## leave spread over the `cool` that follows, so a held trigger is one steady stream), ahead (m the shield sits in
## front of the hand; its `r` is the bubble's radius). "bomblet" is the cluster bomb's little bomb.
const SHOT_STYLE := {
	"bolt": {"speed": 45.0, "grav": 0.0, "life": 1.2, "r": 0.02, "cool": 0.12, "sk": 0.18},
	"mini": {"speed": 11.0, "grav": 1.0, "life": 3.2, "r": 0.022, "cool": 0.12, "sk": 0.18},
	"bubble": {"speed": 4.2, "grav": -0.06, "life": 3.6, "r": 0.06, "cool": 0.16, "sk": 0.18},
	"firework": {"speed": 20.0, "grav": 0.35, "life": 0.85, "r": 0.025, "cool": 0.2, "burst": 0.55, "sk": 0.18},
	"confetti": {"speed": 24.0, "grav": 0.45, "life": 0.9, "r": 0.018, "cool": 0.3, "pellets": 5, "cone": 0.12, "sk": 0.5},
	"bouncy": {"speed": 15.0, "grav": 1.0, "life": 10.0, "r": 0.03, "cool": 0.22, "bounces": 1000000000, "pops": 1000000000, "sk": 1.35},
	"laser": {"speed": 0.0, "grav": 0.0, "life": 0.25, "r": 0.015, "cool": 0.32, "range": 30.0, "pierce": 3, "sk": 0.5},
	"boomerang": {"speed": 10.0, "grav": 0.0, "life": 1.5, "r": 0.06, "cool": 0.55, "reach": 6.0, "swing": 1.6, "sk": 0.5},
	"glob": {"speed": 12.0, "grav": 1.0, "life": 2.5, "r": 0.045, "cool": 0.35, "splat": 0.4, "sk": 0.7},
	"rocket": {"speed": 20.0, "grav": 0.0, "life": 2.6, "r": 0.03, "cool": 0.6, "burst": 0.75, "turn": 6.0, "seek": 16.0, "sk": 1.0},
	"lightning": {"speed": 0.0, "grav": 0.0, "life": 0.32, "r": 0.02, "cool": 0.45, "range": 22.0, "chain": 4, "hop": 3.0, "cone": 0.32, "sk": 1.0},
	"dallah": {"speed": 13.0, "grav": 0.55, "life": 1.1, "r": 0.05, "cool": 0.5, "spray": 0.08, "sk": DALLAH_FIRE_K},
	"bean": {"speed": 7.0, "grav": 1.0, "life": 0.6, "r": 0.014, "cool": 0.0, "sk": 0.5},
	"falcon": {"speed": 9.0, "grav": 0.0, "life": 4.0, "r": 0.05, "cool": 1.2, "turn": 4.0, "seek": 14.0, "dive": 2.5, "sk": 0.6},
	"freeze": {"speed": 0.0, "grav": 0.0, "life": 0.3, "r": 0.02, "cool": 0.5, "range": 12.0, "pierce": 1, "frost": 3.0, "sk": 0.6},
	"blackhole": {"speed": 6.0, "grav": 0.0, "life": 0.8, "r": 0.06, "cool": 1.5, "linger": 1.5, "field": 2.5, "tug": 2.0, "burst": 0.9, "sk": 0.3},
	"dates": {"speed": 16.0, "grav": 0.3, "life": 1.2, "r": 0.016, "cool": 0.1, "cone": 0.035, "sk": 0.5},
	"bakhoor": {"speed": 7.0, "grav": 1.0, "life": 2.5, "r": 0.04, "cool": 0.9, "linger": 4.0, "cloud": 0.9, "slow": 0.4, "sk": 0.5},
	"lasso": {"speed": 11.0, "grav": 0.5, "life": 0.9, "r": 0.07, "cool": 1.0, "drag": 1.2, "tug": 3.0, "sk": 0.6},
	"hose": {"speed": 12.0, "grav": 1.0, "life": 0.6, "r": 0.02, "cool": 0.12, "pellets": 6, "cone": 0.03, "push": 1.5, "shove": 0.03, "sk": 0.5},
	"cluster": {"speed": 10.0, "grav": 0.8, "life": 0.7, "r": 0.04, "cool": 1.0, "pellets": 6, "sk": 0.6},
	"bomblet": {"speed": 2.5, "grav": 1.0, "life": 0.9, "r": 0.022, "cool": 0.0, "burst": 0.35, "sk": 0.8},
	"magnet": {"speed": 9.0, "grav": 0.0, "life": 0.7, "r": 0.04, "cool": 1.2, "linger": 3.0, "field": 2.2, "tug": 2.5, "sk": 0.6},
	"shield": {"speed": 0.0, "grav": 0.0, "life": 3.0, "r": 0.45, "cool": 4.0, "ahead": 0.45, "sk": 0.6},
}

## The shots that park where they stop and stay `linger` seconds (black hole, bakhoor, magnet).
const PARKS := ["blackhole", "bakhoor", "magnet"]
## The falcon: wing beats (radians a second), and how long it looks for prey before it comes home.
const FALCON_FLAP := 14.0
const FALCON_PATIENCE := 1.5
## The bakhoor's smoke slows what is in it again every BAKHOOR_TICK seconds, for BAKHOOR_HOLD
## seconds each time (so a target that leaves the cloud is soon back to speed).
const BAKHOOR_TICK := 0.25
const BAKHOOR_HOLD := 0.5
## The magnet bends these of the kit's own shots toward it (metal enough), at tug x MAGNET_BEND m/s².
const MAGNET_PULLS := ["mini", "confetti", "bouncy", "bean", "dates", "bomblet"]
const MAGNET_BEND := 4.0
## Least time between two of these sounds (a held hose, a cluster's bomblets going off together).
const HOSE_HISS_GAP := 0.12
const BOMBLET_POP_GAP := 0.06

## Bouncy balls bounce about for their whole (long) life, at most this many at once (a new
## one takes the place of the oldest; a headset keeps its frame rate).
const BOUNCY_MAX := 20
## They keep hopping and rolling (metres a second, x blaster_scale): at least this high a
## bounce and this fast along the floor; past BOUNCY_ROAM metres from the eye (when the host's
## blaster_roam() says so: no walls out there) they turn back toward the player.
const BOUNCY_HOP := 3.2
const BOUNCY_ROLL := 1.6
const BOUNCY_ROAM := 6.0
## Angle between the shots of a fan (radians): the triple shot.
const FAN_STEP := 0.11
## How fast a boomerang spins (radians a second): about four turns.
const BOOMERANG_SPIN := 24.0

## The shots' colours (sRGB hex).
## Firework blooms (two of these per bloom; the last, white, only as the second).
const FIRE_COLS := ["e2603f", "f2c14e", "6fa8d6", "7bbf8a", "c9a2e6", "fffaf2"]
const CONFETTI_COLS := ["ff5c8a", "ffd23f", "3ec7ff", "7ee05a", "b98cff", "ff8a3d"]
const BOUNCY_COLS := ["ff4f9a", "4fd1ff", "b6f03c", "ffb02e", "a77bff"]
## Arabic coffee beans: lightly roasted, golden to brown, a green cardamom now and then.
const BEAN_COLS := ["b07a3c", "8a5a2b", "c99a5a", "6f8f3a"]
## Dates (glossy, dark to amber) and the crumbs they break into.
const DATE_COLS := ["5a2a12", "6e3416", "4a2210", "7b3d1a"]
const CRUMB_COLS := ["6e3416", "8a4a22", "b5773f", "4a2210"]
## The shemagh's red and white (the lasso's rope and loop).
const SHEMAGH_COLS := ["c8102e", "f4f1ea"]
## The hose's water and the black hole's swirl.
const HOSE_COLS := ["4fb8ff", "9fdcff", "3fa0f0"]
const VOID_COLS := ["8b5cf6", "c4b5fd", "6d28d9", "e9d5ff"]
## The muzzle flash per style (others: ffe9b0; a bubble has none).
const MUZZLE := {"laser": "ff6b8f", "lightning": "cfe8ff", "glob": "9fe3ff", "confetti": "fff2c2", "rocket": "ffb347", "dallah": "ffe3a0",
	"falcon": "f1e3c8", "freeze": "bfefff", "blackhole": "b48cff", "dates": "ffe0b0", "bakhoor": "ffcf8a", "hose": "9fe3ff",
	"cluster": "fff2c2", "magnet": "ff9a9a"}
## Styles without a muzzle flash.
const NO_MUZZLE := ["bubble", "shield"]
## Mini shots are little balls in five looks, each shot in the next look and a colour from
## this list ("" = the look's own colour, STYLE_COLORS).
const MINI_STYLES := ["jelly", "fur", "bubble", "clay", "fabric"]
const MINI_COLORS := ["", "ff69b4", "ff505c", "ff9b3d", "ffdf45", "58db83", "58b9ff", "b878ff"]
## Bubble shots: soap bubbles (a swirling film) in soft tints.
const BUBBLE_TINTS := ["cfe8ff", "ffd6f0", "d6ffe4", "fff2c2", "e2d4ff", "c8fff6", "ffe0cc"]
## Each mini ball look's own colour.
const STYLE_COLORS := {"jelly": "ff69b4", "fabric": "b36bff", "clay": "ff9b3d", "fur": "f1ebe1", "bubble": "cfe8ff"}

## What unlocked each style originally (data only: the kit never locks a style): "" = from
## the start; else that challenge id finished. Ids and titles in CHALLENGES. The ten of v1.2
## were not in the original game: "" (no unlock).
const SHOT_UNLOCKS := {
	"bolt": "", "mini": "", "bubble": "", "firework": "",
	"confetti": "hoop3", "bouncy": "firework10", "laser": "skyPop5", "boomerang": "pop20",
	"glob": "laser30", "rocket": "boomerang3", "lightning": "rocket20", "dallah": "chain4",
	"falcon": "", "freeze": "", "blackhole": "", "dates": "", "bakhoor": "", "lasso": "", "hose": "", "cluster": "", "magnet": "", "shield": "",
}

## The challenge ids the blaster reports (blaster_challenge(id, value)) and the ones above:
## [goal, ar, en, how]. how: "add" = value is +1 each time (sum them), "best" = value is the
## current count (keep the best), "unlock" = only named as an unlock (the kit never sends it).
const CHALLENGES := {
	"hoop3": [3, "٣ سلات متتابعة", "3 hoops in a row", "unlock"],
	"firework10": [10, "فجّر ١٠ أهداف بالألعاب النارية", "Blast 10 targets with fireworks", "unlock"],
	"skyPop5": [5, "فجّر ٥ أهداف فوق رأسك", "Pop 5 targets above your head", "add"],
	"pop20": [20, "فرقع ٢٠ هدفًا", "Pop 20 targets", "add"],
	"laser30": [30, "اصب ٣٠ هدف بالليزر", "Hit 30 targets with the laser", "unlock"],
	"boomerang3": [3, "بوميرانغ يصيب ويرجع ليدك ٣ مرات", "Catch 3 boomerangs that hit something", "add"],
	"rocket20": [20, "اصب ٢٠ هدف بالصواريخ", "Hit 20 targets with rockets", "unlock"],
	"chain4": [4, "صاعقة وحدة تصيب ٤ أهداف", "Chain 4 targets with one lightning bolt", "best"],
	"bouncy3": [3, "طلقة نطّاطة وحدة تصيب ٣ أهداف", "Hit 3 targets with one bouncy ball", "best"],
}
## The original game counted the hits of these styles (blaster_credit(kind, n)) toward a challenge.
const CREDIT_CHALLENGES := {"firework": "firework10", "laser": "laser30", "rocket": "rocket20", "dallah": "dallah15", "bean": "dallah15"}

## Classification (docs/CATALOG.md): the families a style belongs to (its "tags").
const CATEGORIES := {
	"direct": ["قذيفة مباشرة", "Direct projectile"],
	"ballistic": ["باليستية", "Ballistic"],
	"instant": ["فورية/شعاع", "Instant / beam"],
	"area": ["منطقة تأثير/انفجار", "Area of effect / blast"],
	"homing": ["موجّهة", "Homing"],
	"returning": ["مرتدّة/عائدة", "Returning"],
	"spray": ["رشّ/متعدد", "Spray / multi-shot"],
	"bouncing": ["ارتداد/نطّ", "Bouncing"],
	"defence": ["دفاع/حماية", "Defence / shield"],
}

## Every weapon's permanent code: CODE_PREFIX + a three-digit number, in the order weapons are
## added (never reused: a removed weapon keeps its number retired; the next one takes the next).
const CODE_PREFIX := "AB-W-"
## Codes reserved for planned weapons (docs/CATALOG.md, the Roadmap): code -> [ar, en, id].
## Empty since v1.2 (AB-W-013 ... 022 are weapons now); a new idea takes next_code().
const RESERVED := {}
## Packs (families of weapons that ship together; a game picks the packs it wants). AB-W-001 ...
## 022 are "playful"; "military" is the tabletop pack of «حرب البارجة» (AB-W-023 ... AB-W-040:
## ballistic and cruise missiles, artillery, rockets, air strikes, drones, air defence, the
## torpedo, the nuclear test), whose own
## catalogue and launcher are in military/ (AbodenMilitaryCatalog, AbodenMilitaryLauncher).
## Ids are per pack: the playful "cluster" (AB-W-020) and the military "cluster" (AB-W-027) are
## two weapons, each in its own catalogue (the code is what is unique across the kit).
const PACKS := {
	"playful": ["مرحة", "Playful"],
	"military": ["عسكرية", "Military"],
}
## The tag axes of the index (docs/CATALOG.md): value -> [ar, en]. Values marked (planned) are
## there for the coming packs; no current weapon uses them yet (the military pack uses called,
## lofted, waypoints, vertical, intercept, falloff, scan, defence and support; v1.2 playful uses area,
## held, lingering, defence and support).
const AXES := {
	"delivery": {"projectile": ["قذيفة", "Projectile"], "hitscan": ["شعاع فوري", "Hitscan"], "area": ["منطقة", "Area"],
		"called": ["ضربة مُستدعاة", "Called strike"]},
	"trajectory": {"straight": ["مستقيم", "Straight"], "ballistic": ["قوسي", "Ballistic"], "homing": ["موجّه", "Homing"],
		"returning": ["عائد", "Returning"], "floating": ["طافٍ", "Floating"],
		"held": ["مع اليد", "Held at the hand"],
		"lofted": ["قوس عالٍ وعودة للغلاف", "Lofted / re-entry"],
		"waypoints": ["نقاط مسار منخفضة", "Waypoints, terrain-following"],
		"vertical": ["من الأعلى", "Top-down"],
		"intercept": ["اعتراض", "Intercept"]},
	"hit": {"single": ["هدف واحد", "Single"], "pierce": ["اختراق", "Pierce"], "chain": ["تسلسل", "Chain"],
		"splash": ["انفجار/رذاذ", "Splash"], "bounce": ["ارتداد", "Bounce"],
		"falloff": ["انفجار بتناقص الضرر", "Blast with fall-off"],
		"lingering": ["منطقة باقية", "Lingering zone"],
		"scan": ["كشف واستطلاع", "Scan / spot (no blast)"]},
	"role": {"attack": ["هجوم", "Attack"], "defence": ["دفاع/اعتراض", "Defence / interception"],
		"support": ["إسناد", "Support"]},
}
## Unlock tiers (rarity), from the original challenge order (new weapons: by power).
const TIERS := [["أساسي", "Starter"], ["سهل", "Easy"], ["متوسط", "Medium"], ["متقدم", "Advanced"], ["نخبة", "Elite"]]
## Development status: stable = مستقر, experimental = تجريبي, planned = مخطط.
const STATUS := {"stable": ["مستقر", "Stable"], "experimental": ["تجريبي", "Experimental"], "planned": ["مخطط", "Planned"]}

## id -> {code (permanent catalogue code, CODE_PREFIX + number, never reused), pack (PACKS), ar,
## en, icon, sound (its firing sound), sounds (every sound it makes), ar_desc, en_desc, tags
## (CATEGORIES), delivery / trajectory / hit / role (AXES), tier (TIERS), status (STATUS), version (the kit
## version that last changed it)}.
const SHOTS := {
	"bolt": {"code": "AB-W-001", "pack": "playful", "ar": "برق", "en": "Bolt", "icon": "bolt", "sound": "pew", "sounds": ["pew", "thump"],
		"ar_desc": "طلقة سريعة مضيئة بذيل ووميض", "en_desc": "A fast glowing bolt with a trail and a flash",
		"tags": ["direct"], "delivery": "projectile", "trajectory": "straight", "hit": "single", "role": "attack", "tier": 0, "status": "stable", "version": "1.0"},
	"mini": {"code": "AB-W-002", "pack": "playful", "ar": "كرات صغيرة", "en": "Mini Ball", "icon": "mini", "sound": "whoosh", "sounds": ["whoosh", "thump"],
		"ar_desc": "كرات صغيرة ملوّنة تتشقلب وترتد", "en_desc": "Little tumbling balls that bounce on",
		"tags": ["ballistic", "bouncing"], "delivery": "projectile", "trajectory": "ballistic", "hit": "bounce", "role": "attack", "tier": 0, "status": "stable", "version": "1.0"},
	"bubble": {"code": "AB-W-003", "pack": "playful", "ar": "فقاعة", "en": "Bubble", "icon": "bubble", "sound": "whoosh", "sounds": ["whoosh", "start_pop", "thump"],
		"ar_desc": "فقاعات صابون ملونة تتمايل ببطء", "en_desc": "Slow, wobbling rainbow soap bubbles",
		"tags": ["direct"], "delivery": "projectile", "trajectory": "floating", "hit": "single", "role": "attack", "tier": 0, "status": "stable", "version": "1.0"},
	"firework": {"code": "AB-W-004", "pack": "playful", "ar": "ألعاب نارية", "en": "Firework", "icon": "firework", "sound": "firework_launch", "sounds": ["firework_launch", "firework_burst"],
		"ar_desc": "صاروخ ناري يتفتح ويفرقع ما حوله", "en_desc": "A rocket that blooms and pops all around it",
		"tags": ["ballistic", "area"], "delivery": "projectile", "trajectory": "ballistic", "hit": "splash", "role": "attack", "tier": 0, "status": "stable", "version": "1.0"},
	"confetti": {"code": "AB-W-005", "pack": "playful", "ar": "قصاصات", "en": "Confetti", "icon": "confetti", "sound": "swish", "sounds": ["swish", "start_pop", "thump"],
		"ar_desc": "مدفع قصاصات: خمس كرات في مخروط", "en_desc": "Confetti cannon: five pellets in a cone",
		"tags": ["spray", "ballistic"], "delivery": "projectile", "trajectory": "ballistic", "hit": "single", "role": "attack", "tier": 1, "status": "stable", "version": "1.0"},
	"bouncy": {"code": "AB-W-006", "pack": "playful", "ar": "نطّاطة", "en": "Bouncy", "icon": "bouncy", "sound": "squeak", "sounds": ["squeak", "bricks_tink"],
		"ar_desc": "كرة مطاطية تنطّ بالمكان عشر ثوانٍ", "en_desc": "A rubber ball that bounces about for ten seconds",
		"tags": ["bouncing", "ballistic"], "delivery": "projectile", "trajectory": "ballistic", "hit": "bounce", "role": "attack", "tier": 1, "status": "stable", "version": "1.0"},
	"laser": {"code": "AB-W-007", "pack": "playful", "ar": "ليزر", "en": "Laser", "icon": "laser", "sound": "pew", "sounds": ["pew", "thump"],
		"ar_desc": "شعاع فوري يخترق حتى ٣ أهداف", "en_desc": "An instant beam through up to 3 targets",
		"tags": ["instant"], "delivery": "hitscan", "trajectory": "straight", "hit": "pierce", "role": "attack", "tier": 2, "status": "stable", "version": "1.0"},
	"boomerang": {"code": "AB-W-008", "pack": "playful", "ar": "بوميرانغ", "en": "Boomerang", "icon": "boomerang", "sound": "swish", "sounds": ["swish", "thump"],
		"ar_desc": "ينطلق ويلتف ويعود إلى يدك", "en_desc": "Curves out and comes back to your hand",
		"tags": ["returning"], "delivery": "projectile", "trajectory": "returning", "hit": "pierce", "role": "attack", "tier": 2, "status": "stable", "version": "1.0"},
	"glob": {"code": "AB-W-009", "pack": "playful", "ar": "ماء", "en": "Water", "icon": "glob", "sound": "squeak", "sounds": ["squeak", "splash", "thump"],
		"ar_desc": "كرة ماء تنفجر برذاذ يفرقع ما حولها", "en_desc": "A water ball that bursts in a popping splash",
		"tags": ["ballistic", "area"], "delivery": "projectile", "trajectory": "ballistic", "hit": "splash", "role": "attack", "tier": 3, "status": "stable", "version": "1.0"},
	"rocket": {"code": "AB-W-010", "pack": "playful", "ar": "صاروخ", "en": "Rocket", "icon": "rocket", "sound": "whoosh", "sounds": ["whoosh", "boom"],
		"ar_desc": "صاروخ موجّه، كل صاروخ يلاحق هدفه", "en_desc": "Homing rockets, each after its own target",
		"tags": ["homing", "area"], "delivery": "projectile", "trajectory": "homing", "hit": "splash", "role": "attack", "tier": 3, "status": "stable", "version": "1.0"},
	"lightning": {"code": "AB-W-011", "pack": "playful", "ar": "صاعقة", "en": "Lightning", "icon": "lightning", "sound": "cans_clang", "sounds": ["cans_clang", "bricks_tink"],
		"ar_desc": "صاعقة تقفز بين ٤ أهداف", "en_desc": "Lightning that chains through 4 targets",
		"tags": ["instant"], "delivery": "hitscan", "trajectory": "homing", "hit": "chain", "role": "attack", "tier": 4, "status": "stable", "version": "1.0"},
	"dallah": {"code": "AB-W-012", "pack": "playful", "ar": "دلّة", "en": "Dallah", "icon": "dallah", "sound": "fair_ding", "sounds": ["fair_ding", "thump"],
		"ar_desc": "دلّة قهوة دوّارة ترش حبات البن", "en_desc": "A spinning coffee pot spraying coffee beans",
		"tags": ["ballistic", "spray"], "delivery": "projectile", "trajectory": "ballistic", "hit": "pierce", "role": "attack", "tier": 4, "status": "stable", "version": "1.0"},
	"falcon": {"code": "AB-W-013", "pack": "playful", "ar": "الصقر", "en": "Falcon", "icon": "falcon", "sound": "flap", "sounds": ["flap", "screech", "thump"],
		"ar_desc": "صقر ينقضّ على هدف لا يلاحقه غيره ثم يعود إلى يدك", "en_desc": "A falcon that stoops on a target no other falcon has, then comes back to your hand",
		"tags": ["homing", "returning"], "delivery": "projectile", "trajectory": "homing", "hit": "single", "role": "attack", "tier": 3, "status": "stable", "version": "1.2"},
	"freeze": {"code": "AB-W-014", "pack": "playful", "ar": "الثلج", "en": "Freeze Ray", "icon": "freeze", "sound": "ice_zap", "sounds": ["ice_zap", "ice_crack", "thump"],
		"ar_desc": "شعاع جليدي فوري يجمّد الهدف ثلاث ثوانٍ", "en_desc": "An instant icy beam that freezes a target for three seconds",
		"tags": ["instant"], "delivery": "hitscan", "trajectory": "straight", "hit": "single", "role": "support", "tier": 2, "status": "stable", "version": "1.2"},
	"blackhole": {"code": "AB-W-015", "pack": "playful", "ar": "الثقب الأسود", "en": "Black Hole", "icon": "blackhole", "sound": "whoosh", "sounds": ["whoosh", "whoomp"],
		"ar_desc": "دوامة تتوقف وتجذب ما حولها ثم تنفجر للداخل", "en_desc": "A vortex that stops, pulls in what is near, then implodes",
		"tags": ["area"], "delivery": "projectile", "trajectory": "straight", "hit": "splash", "role": "attack", "tier": 4, "status": "stable", "version": "1.2"},
	"dates": {"code": "AB-W-016", "pack": "playful", "ar": "رشاش التمر", "en": "Date Blaster", "icon": "dates", "sound": "put", "sounds": ["put", "thump"],
		"ar_desc": "أسرع سلاح: حبات تمر لامعة تتفتت عند الإصابة", "en_desc": "The fastest weapon: glossy dates that crumble on a hit",
		"tags": ["direct", "spray"], "delivery": "projectile", "trajectory": "ballistic", "hit": "single", "role": "attack", "tier": 1, "status": "stable", "version": "1.2"},
	"bakhoor": {"code": "AB-W-017", "pack": "playful", "ar": "المبخرة", "en": "Bakhoor", "icon": "bakhoor", "sound": "swish", "sounds": ["swish", "ember", "thump"],
		"ar_desc": "مبخرة تُقذف فتترك سحابة بخور تُبطئ ما فيها", "en_desc": "A lobbed incense burner that leaves a slowing cloud of bakhoor smoke",
		"tags": ["area", "ballistic"], "delivery": "projectile", "trajectory": "ballistic", "hit": "lingering", "role": "support", "tier": 2, "status": "stable", "version": "1.2"},
	"lasso": {"code": "AB-W-018", "pack": "playful", "ar": "حبل الشماغ", "en": "Shemagh Lasso", "icon": "lasso", "sound": "whoosh", "sounds": ["whoosh", "snap", "thump"],
		"ar_desc": "حبل بنقشة الشماغ يلتقط الهدف ويسحبه نحوك", "en_desc": "A shemagh-patterned rope that catches a target and pulls it to you",
		"tags": ["ballistic", "returning"], "delivery": "projectile", "trajectory": "ballistic", "hit": "single", "role": "support", "tier": 2, "status": "stable", "version": "1.2"},
	"hose": {"code": "AB-W-019", "pack": "playful", "ar": "خرطوم الماء", "en": "Water Hose", "icon": "hose", "sound": "hose_hiss", "sounds": ["hose_hiss", "splash"],
		"ar_desc": "تيار ماء متصل يدفع الأهداف بعيدًا", "en_desc": "A steady stream of water that pushes targets away",
		"tags": ["spray", "ballistic"], "delivery": "projectile", "trajectory": "ballistic", "hit": "single", "role": "support", "tier": 1, "status": "stable", "version": "1.2"},
	"cluster": {"code": "AB-W-020", "pack": "playful", "ar": "القنبلة العنقودية", "en": "Cluster Bomb", "icon": "cluster", "sound": "swish", "sounds": ["swish", "start_pop", "cluster_pop"],
		"ar_desc": "قنبلة مرحة تتفرق إلى ست قنابل صغيرة ملوّنة", "en_desc": "A playful bomb that scatters into six little colourful bombs",
		"tags": ["area", "spray"], "delivery": "projectile", "trajectory": "ballistic", "hit": "splash", "role": "attack", "tier": 3, "status": "stable", "version": "1.2"},
	"magnet": {"code": "AB-W-021", "pack": "playful", "ar": "المغناطيس", "en": "Magnet", "icon": "magnet", "sound": "zing", "sounds": ["zing", "cans_clang", "thump"],
		"ar_desc": "مغناطيس يعلق في الهواء ويجذب المعدن والقذائف", "en_desc": "A magnet that hangs in the air and pulls in metal and projectiles",
		"tags": ["area"], "delivery": "projectile", "trajectory": "straight", "hit": "lingering", "role": "support", "tier": 3, "status": "stable", "version": "1.2"},
	"shield": {"code": "AB-W-022", "pack": "playful", "ar": "الدرع", "en": "Shield Bubble", "icon": "shield", "sound": "shield_up", "sounds": ["shield_up", "shield_block", "start_pop"],
		"ar_desc": "فقاعة درع أمام يدك تصد القذائف ثلاث ثوانٍ", "en_desc": "A shield bubble at your hand that stops projectiles for three seconds",
		"tags": ["defence"], "delivery": "area", "trajectory": "held", "hit": "lingering", "role": "defence", "tier": 2, "status": "stable", "version": "1.2"},
}


static func ids() -> Array:
	return ORDER


static func has(id: String) -> bool:
	return SHOTS.has(id)


static func info(id: String) -> Dictionary:
	return SHOTS.get(id, {})


## The flight numbers of a style ({} if none).
static func style(id: String) -> Dictionary:
	return SHOT_STYLE.get(id, {})


## The name in a language ("ar" or "en").
static func name_of(id: String, lang := "ar") -> String:
	return str(info(id).get(lang, id))


## What unlocked `id` originally: "" (open) or a challenge id (CHALLENGES).
static func need(id: String) -> String:
	return str(SHOT_UNLOCKS.get(id, ""))


## The unlock's title, [ar, en] ("", "" when open from the start).
static func need_text(id: String) -> Array:
	var c: Array = CHALLENGES.get(need(id), [])
	return [c[1], c[2]] if not c.is_empty() else ["", ""]


## The original rule, as data: whether `id` is open given progress (challenge id -> value).
## The kit itself never locks a style; a game that wants unlocks can call this.
static func available(id: String, progress: Dictionary) -> bool:
	if not SHOTS.has(id):
		return false
	if int(progress.get("shot:" + id, 0)) == 1:
		return true
	var n := need(id)
	if n == "":
		return true
	var c: Array = CHALLENGES.get(n, [])
	return not c.is_empty() and int(progress.get(n, 0)) >= int(c[0])


## The ids of a pack, in catalogue order.
static func pack(name: String) -> Array:
	return ORDER.filter(func(id: String) -> bool: return str(SHOTS[id].get("pack", "")) == name)


## The style with this catalogue code ("" if none).
static func by_code(code: String) -> String:
	for id: String in SHOTS:
		if str(SHOTS[id].get("code", "")) == code:
			return id
	return ""


## The code the next new idea takes (one past the highest in SHOTS, RESERVED and the military
## pack, military/military_catalog.gd): AB-W-034 in v1.2.
static func next_code() -> String:
	var top := 0
	for id: String in SHOTS:
		top = maxi(top, int(str(SHOTS[id].get("code", "")).trim_prefix(CODE_PREFIX)))
	for code: String in RESERVED:
		top = maxi(top, int(code.trim_prefix(CODE_PREFIX)))
	var military: Dictionary = load("res://addons/aboden_blaster/military/military_catalog.gd").WEAPONS
	for id: String in military:
		top = maxi(top, int(str(military[id].code).trim_prefix(CODE_PREFIX)))
	return CODE_PREFIX + "%03d" % (top + 1)
