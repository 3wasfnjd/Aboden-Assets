class_name AbodenMilitaryCatalog
extends RefCounted
## The military pack (AB-W-023 ... AB-W-033, and AB-W-034 ... AB-W-040 since v1.2): the
## weapons of the battleship in «حرب البارجة» (Table War), made game-agnostic. The single source of truth for their
## names, codes, catalogue tags and flight numbers (docs/MILITARY.md is generated from
## here by tools/gen_military_docs.gd).
##
## Units: the numbers are in "table units" of a miniature war table (1 unit = 1 m of a
## model about 1 m across; the original scene is 1:2000) and seconds. A game at another
## scale multiplies lengths and speeds by its own factor (AbodenMilitaryLauncher.scale).
## Gravity is a miniature gravity (G = 0.5 units/s^2) so arcs read "big and heavy".
##
## Per weapon:
##   code        permanent catalogue code (never reused)
##   ar, en      names;  ar_desc, en_desc  one line about it
##   arc         "lofted" (high ballistic), "low" (fast flat ballistic), "cruise"
##               (terrain-following path), "sortie" (an aircraft's round trip), "glide"
##               (hypersonic glide: boost, weaving depressed glide, terminal dive),
##               "glidebomb" (released by a jet, glides in), "torpedo" (runs under the
##               water surface), "intercept" (homes on an air target)
##   flight      [min, max] flight time in s (ballistic: picked from the distance)
##   speed       cruise / sortie ground speed (units/s); cruise_alt  height above the ground
##   blast       blast radius factor (1.0 = BLAST_R 2.2 cm)
##   crater_k    crater depth factor;  ejecta  soil chunks thrown on land
##   cooldown    s between two shots;  ammo  rounds when full;  reload  s per round back
##               (0: comes back by itself, e.g. a jet when it lands)
##   salvo       rockets per trigger pull (MLRS), within `spread` of the target
##   split       bomblets released at 62 % of the flight (cluster), within `spread`
##   salvo_gap   s between two of a salvo (0.09 when not given)
##   bombs       what an aircraft releases over the target (within `spread`): `bomb` (a SUB
##               id, "jetbomb" by default), `release_lead` units before the target
##   orbit       recon: circles of this radius round the target; scan_r the radius it sees
##   anti_armor  armour within blast_r x armor_k is knocked out (info.armor_r)
##   speed, turn, kill_r, life  intercept: speed, steering rate (1/s), the distance it
##               bursts at, s before it self-destructs
##   wave_k, wave_t  nuke: the shock wave runs on to nuke_r x wave_k in wave_t s
##   cloud       nuke: mushroom-cloud scale in the open sky (1 under a ceiling)
##   nuke        nuclear test: everything within nuke_r is destroyed, mushroom cloud
##   glow        re-entry glow;  trail  smoke puff interval (s) and trail_col
##   wings       body has wings;  length, radius, col  the body mesh
##   launcher    where on a launch platform it leaves from (vls, box, gun, pod, ramp, silo,
##               deck, tube)
##   aircraft    an aircraft (jet, helicopter, drone) that flies a sortie; heli: helicopter body
##   example     a real-world weapon of the kind (as the game's web HUD shows it)
##   ar_short    the short Arabic name of the game's weapon cards
##   intercept   the game's chance that an enemy SAM site engages it (a hint for the host's
##               own air defence, see AbodenMilitaryLauncher.air_shots / shoot_down)
##   version     the kit version that last changed it
##   delivery / trajectory / hit / role / tier  catalogue axes (see shot_catalog.gd AXES)

const G := 0.5
const BLAST_R := 0.022
const CRATER_R := 0.016
const CRATER_D := 0.0055
const SPLIT_AT := 0.62

const ORDER := ["ballistic", "cruise", "artillery", "mlrs", "cluster", "hypersonic", "bunker", "drone", "antiship", "jet", "nuke",
	"swarm", "aa", "recon", "atgm", "glide", "torpedo", "heli"]
## The order of the game's own weapon panel (its web build, 18 weapons).
const GAME_ORDER := ["recon", "ballistic", "cruise", "hypersonic", "artillery", "mlrs", "cluster", "bunker", "glide", "jet", "heli",
	"drone", "swarm", "atgm", "antiship", "torpedo", "aa", "nuke"]

const WEAPONS := {
	"ballistic": {
		"example": "Iskander", "ar_short": "باليستي", "intercept": 0.35, "version": "1.1",
		"code": "AB-W-023", "ar": "صاروخ باليستي", "en": "Ballistic missile",
		"ar_desc": "قوس عالٍ وسقوط حاد بتوهج إعادة الدخول · انفجار قوي",
		"en_desc": "High arc and a steep, glowing re-entry; a heavy blast",
		"arc": "lofted", "flight": [2.6, 3.0], "blast": 1.45, "ejecta": 90,
		"cooldown": 4.0, "ammo": 6, "reload": 8.0, "glow": true,
		"trail": 0.016, "trail_col": Color(0.88, 0.86, 0.82, 0.6),
		"length": 0.0034, "radius": 0.0006, "col": Color(0.85, 0.86, 0.84), "launcher": "vls",
		"delivery": "projectile", "trajectory": "lofted", "hit": "splash", "role": "attack", "tier": 2,
	},
	"cruise": {
		"example": "Tomahawk", "ar_short": "كروز", "intercept": 0.6, "version": "1.2",
		"code": "AB-W-024", "ar": "صاروخ كروز", "en": "Cruise missile",
		"ar_desc": "يطير منخفضًا ويتبع التضاريس ويصعد قبل التلال · دقيق",
		"en_desc": "Flies low and follows the terrain, climbing before hills; precise",
		"arc": "cruise", "flight": [1.5, 3.0], "speed": 0.42, "cruise_alt": 0.006, "blast": 1.0, "ejecta": 60,
		"cooldown": 3.0, "ammo": 8, "reload": 6.0, "glow": false, "wings": true,
		"trail": 0.022, "trail_col": Color(0.92, 0.92, 0.90, 0.45),
		"length": 0.0028, "radius": 0.00045, "col": Color(0.55, 0.58, 0.55), "launcher": "box",
		"delivery": "projectile", "trajectory": "waypoints", "hit": "splash", "role": "attack", "tier": 1,
	},
	"artillery": {
		"example": "M777", "ar_short": "مدفعية", "intercept": 0.0, "version": "1.1",
		"code": "AB-W-025", "ar": "قذيفة مدفعية", "en": "Artillery shell",
		"ar_desc": "قذائف سريعة كثيرة بقوس منخفض · انفجار صغير",
		"en_desc": "Fast, plentiful shells on a low arc; a small blast",
		"arc": "low", "flight": [1.5, 1.8], "blast": 0.6, "ejecta": 30,
		"cooldown": 0.8, "ammo": 30, "reload": 2.0, "glow": false,
		"trail": 0.03, "trail_col": Color(0.80, 0.79, 0.76, 0.35),
		"length": 0.0018, "radius": 0.00055, "col": Color(0.35, 0.36, 0.33), "launcher": "gun",
		"delivery": "projectile", "trajectory": "ballistic", "hit": "splash", "role": "attack", "tier": 0,
	},
	"mlrs": {
		"example": "HIMARS", "ar_short": "راجمة صواريخ", "intercept": 0.2, "version": "1.1",
		"code": "AB-W-026", "ar": "راجمة صواريخ", "en": "MLRS rocket salvo",
		"ar_desc": "8 صواريخ متتالية كل 90 م.ث تتوزع حول الهدف",
		"en_desc": "8 rockets, one every 90 ms, scattered round the target",
		"arc": "low", "flight": [1.4, 1.7], "blast": 0.5, "ejecta": 14,
		"cooldown": 6.0, "ammo": 4, "reload": 9.0, "glow": false, "salvo": 8, "spread": 0.035,
		"trail": 0.03, "trail_col": Color(0.85, 0.84, 0.80, 0.4),
		"length": 0.0016, "radius": 0.0003, "col": Color(0.48, 0.52, 0.38), "launcher": "pod",
		"delivery": "projectile", "trajectory": "ballistic", "hit": "splash", "role": "attack", "tier": 1,
	},
	"cluster": {
		"example": "ATACMS", "ar_short": "عنقودي", "intercept": 0.35, "version": "1.1",
		"code": "AB-W-027", "ar": "صاروخ عنقودي", "en": "Cluster missile",
		"ar_desc": "ينفتح في الجو ويطلق 10 قنيبلات تغطي منطقة الهدف",
		"en_desc": "Opens in the air and releases 10 bomblets over the target area",
		"arc": "lofted", "flight": [2.6, 3.0], "blast": 0.45, "ejecta": 10,
		"cooldown": 7.0, "ammo": 3, "reload": 12.0, "glow": false, "split": 10, "spread": 0.045,
		"trail": 0.018, "trail_col": Color(0.88, 0.86, 0.82, 0.55),
		"length": 0.003, "radius": 0.0006, "col": Color(0.78, 0.72, 0.50), "launcher": "vls",
		"delivery": "projectile", "trajectory": "lofted", "hit": "splash", "role": "attack", "tier": 2,
	},
	"hypersonic": {
		"example": "Kinzhal", "ar_short": "فرط صوتي", "intercept": 0.08, "version": "1.2",
		"code": "AB-W-028", "ar": "صاروخ فرط صوتي", "en": "Hypersonic glide missile",
		"ar_desc": "يندفع إلى الأعلى ثم ينزلق منخفضًا متمايلًا يمينًا ويسارًا وينقضّ بتوهج · انفجار كبير",
		"en_desc": "Boosts up, then a low glide weaving side to side and a glowing terminal dive; a big blast",
		"arc": "glide", "speed": 1.1, "flight": [1.1, 2.2], "blast": 1.75, "ejecta": 90,
		"cooldown": 8.0, "ammo": 3, "reload": 14.0, "glow": true,
		"trail": 0.012, "trail_col": Color(0.95, 0.92, 0.86, 0.55),
		"length": 0.0030, "radius": 0.0006, "col": Color(0.30, 0.30, 0.32), "launcher": "vls",
		"delivery": "projectile", "trajectory": "lofted", "hit": "splash", "role": "attack", "tier": 3,
	},

	"bunker": {
		"example": "GBU-57", "ar_short": "خارقة تحصينات", "intercept": 0.35, "version": "1.2",
		"code": "AB-W-029", "ar": "خارق التحصينات", "en": "Bunker buster",
		"ar_desc": "قنبلة ثقيلة تحملها طائرة هجومية وتلقيها فوق الهدف · حفرة عميقة للمخابئ",
		"en_desc": "A heavy bomb a strike jet carries and drops over the target; a deep crater for bunkers",
		"arc": "sortie", "speed": 0.14, "cruise_alt": 0.10, "bombs": 1, "bomb": "bunkerbomb", "spread": 0.0,
		"blast": 1.15, "crater_k": 2.2, "ejecta": 110,
		"cooldown": 2.0, "ammo": 2, "reload": 0.0, "glow": false, "wings": true, "aircraft": true,
		"trail": 0.05, "trail_col": Color(0.85, 0.85, 0.85, 0.25),
		"length": 0.0038, "radius": 0.0006, "col": Color(0.50, 0.54, 0.58), "launcher": "deck",
		"delivery": "called", "trajectory": "vertical", "hit": "splash", "role": "attack", "tier": 3,
	},

	"drone": {
		"example": "Shahed-136", "ar_short": "مسيّرة انتحارية", "intercept": 0.75, "version": "1.2",
		"code": "AB-W-030", "ar": "مسيّرة انتحارية", "en": "Kamikaze drone",
		"ar_desc": "بطيئة على ارتفاع فوق التضاريس · دقيقة · انفجار صغير",
		"en_desc": "Slow, high over the terrain; precise, a small blast",
		"arc": "cruise", "flight": [2.5, 8.0], "speed": 0.22, "cruise_alt": 0.02, "blast": 0.7, "ejecta": 30,
		"cooldown": 2.5, "ammo": 10, "reload": 5.0, "glow": false, "wings": true,
		"trail": 0.25, "trail_col": Color(0.9, 0.9, 0.9, 0.15),
		"length": 0.0026, "radius": 0.00045, "col": Color(0.86, 0.86, 0.82), "launcher": "ramp",
		"delivery": "projectile", "trajectory": "waypoints", "hit": "splash", "role": "attack", "tier": 1,
	},
	"antiship": {
		"example": "Harpoon", "ar_short": "مضاد للسفن", "intercept": 0.4, "version": "1.2",
		"code": "AB-W-031", "ar": "صاروخ مضاد للسفن", "en": "Anti-ship missile",
		"ar_desc": "يطير ملاصقًا لسطح البحر · قوي على السفن",
		"en_desc": "Skims the sea; strong against ships",
		"arc": "cruise", "flight": [1.2, 3.0], "speed": 0.5, "cruise_alt": 0.0025, "blast": 1.3, "ejecta": 40,
		"cooldown": 5.0, "ammo": 4, "reload": 10.0, "glow": false, "wings": true,
		"trail": 0.02, "trail_col": Color(0.92, 0.92, 0.90, 0.45),
		"length": 0.003, "radius": 0.0005, "col": Color(0.60, 0.62, 0.66), "launcher": "box",
		"delivery": "projectile", "trajectory": "waypoints", "hit": "splash", "role": "attack", "tier": 2,
	},
	"jet": {
		"example": "F-15E", "ar_short": "مقاتلة", "intercept": 0.4, "version": "1.1",
		"code": "AB-W-032", "ar": "طائرة هجومية", "en": "Strike jet",
		"ar_desc": "تقلع من المنصة وتضرب الهدف بأربع قنابل ثم تعود وتهبط (الرحلة تطول)",
		"en_desc": "Takes off, drops 4 bombs on the target, flies home and lands (a long trip)",
		"arc": "sortie", "speed": 0.14, "cruise_alt": 0.10, "bombs": 4, "bomb": "jetbomb", "spread": 0.012, "blast": 0.8, "ejecta": 20,
		"cooldown": 2.0, "ammo": 2, "reload": 0.0, "glow": false, "wings": true, "aircraft": true,
		"trail": 0.07, "trail_col": Color(0.95, 0.95, 0.95, 0.25),
		"length": 0.008, "radius": 0.0008, "col": Color(0.62, 0.68, 0.74), "launcher": "deck",
		"delivery": "called", "trajectory": "waypoints", "hit": "splash", "role": "attack", "tier": 3,
	},
	"nuke": {
		"example": "B61", "ar_short": "قنبلة نووية", "intercept": 0.3, "version": "1.2",
		"code": "AB-W-033", "ar": "قنبلة نووية", "en": "Nuclear test",
		"ar_desc": "تجربة نووية: وميض وكرة نار تصعد وفطر دخان وموجة صدمة تمتد بعيدًا · يدمر كل شيء في دائرة واسعة",
		"en_desc": "Nuclear test: flash, a rising fireball, a mushroom cloud and a shock wave running far out; destroys everything in a wide radius",
		"arc": "lofted", "flight": [3.4, 3.8], "blast": 1.0, "ejecta": 20, "nuke": true, "nuke_r": 0.16,
		"wave_k": 2.6, "wave_t": 3.0, "cloud": 1.9,
		"cooldown": 30.0, "ammo": 1, "reload": 90.0, "glow": true,
		"trail": 0.012, "trail_col": Color(0.95, 0.95, 0.92, 0.6),
		"length": 0.0042, "radius": 0.0008, "col": Color(0.92, 0.92, 0.90), "launcher": "silo",
		"delivery": "projectile", "trajectory": "lofted", "hit": "falloff", "role": "attack", "tier": 4,
	},
	# --- v1.2: the weapons the game added after build 13 (AB-W-034 ... AB-W-040) ---------
	"swarm": {
		"example": "Lancet", "ar_short": "سرب مسيّرات", "intercept": 0.6, "version": "1.2",
		"code": "AB-W-034", "ar": "سرب مسيّرات", "en": "Drone swarm",
		"ar_desc": "6 مسيّرات صغيرة متتالية تتوزع على الهدف · دقيقة · انفجارات صغيرة",
		"en_desc": "6 small drones one after another, spread over the target; precise, small blasts",
		"arc": "cruise", "flight": [2.0, 9.0], "speed": 0.26, "cruise_alt": 0.016, "blast": 0.35, "ejecta": 8,
		"cooldown": 6.0, "ammo": 3, "reload": 12.0, "glow": false, "wings": true,
		"salvo": 6, "spread": 0.022, "salvo_gap": 0.22,
		"trail": 0.3, "trail_col": Color(0.9, 0.9, 0.9, 0.12),
		"length": 0.0017, "radius": 0.0003, "col": Color(0.74, 0.76, 0.72), "launcher": "ramp",
		"delivery": "projectile", "trajectory": "waypoints", "hit": "splash", "role": "attack", "tier": 2,
	},
	"aa": {
		"example": "Patriot", "ar_short": "دفاع جوي", "intercept": 0.0, "version": "1.2",
		"code": "AB-W-035", "ar": "صاروخ دفاع جوي", "en": "Anti-air missile",
		"ar_desc": "يلاحق هدفًا جويًا ويسقطه بانفجار في الجو · بلا هدف يطير إلى النقطة وينفجر هناك",
		"en_desc": "Homes on an air target and bursts on it; with none it flies to the point and bursts there",
		"arc": "intercept", "speed": 0.55, "turn": 6.0, "kill_r": 0.008, "life": 6.0, "flight": [1.0, 1.4],
		"blast": 0.4, "ejecta": 6,
		"cooldown": 2.0, "ammo": 6, "reload": 10.0, "glow": false,
		"trail": 0.02, "trail_col": Color(0.92, 0.92, 0.90, 0.5),
		"length": 0.0024, "radius": 0.00035, "col": Color(0.92, 0.92, 0.88), "launcher": "vls",
		"delivery": "projectile", "trajectory": "intercept", "hit": "single", "role": "defence", "tier": 2,
	},
	"recon": {
		"example": "ScanEagle", "ar_short": "استطلاع", "intercept": 0.3, "version": "1.2",
		"code": "AB-W-036", "ar": "طائرة استطلاع مسيّرة", "en": "Reconnaissance drone",
		"ar_desc": "تقلع وتدور فوق المنطقة دورتين وتكشف ما تحتها ثم تعود وتهبط · لا تنفجر",
		"en_desc": "Takes off, circles the area twice reporting what it sees below, flies home and lands; no blast",
		"arc": "sortie", "speed": 0.10, "cruise_alt": 0.11, "bombs": 0, "orbit": 0.07, "spread": 0.0,
		"scan_r": 0.075, "blast": 0.0, "ejecta": 0,
		"cooldown": 2.0, "ammo": 1, "reload": 0.0, "glow": false, "wings": true, "aircraft": true,
		"trail": 0.12, "trail_col": Color(0.9, 0.9, 0.9, 0.15),
		"length": 0.0030, "radius": 0.0004, "col": Color(0.78, 0.80, 0.82), "launcher": "deck",
		"delivery": "called", "trajectory": "waypoints", "hit": "scan", "role": "support", "tier": 1,
	},
	"atgm": {
		"example": "Javelin", "ar_short": "مضاد للدروع", "intercept": 0.0, "version": "1.2",
		"code": "AB-W-037", "ar": "صاروخ مضاد للدروع", "en": "Anti-tank missile",
		"ar_desc": "يعلو ثم ينقضّ على الدبابة من فوق · انفجار صغير قاتل للمدرعات",
		"en_desc": "Climbs and dives onto the tank from above; a small blast, deadly to armour",
		"arc": "lofted", "flight": [1.3, 1.6], "blast": 0.32, "ejecta": 6, "anti_armor": true, "armor_k": 2.6,
		"cooldown": 1.5, "ammo": 6, "reload": 6.0, "glow": false,
		"trail": 0.02, "trail_col": Color(0.85, 0.85, 0.82, 0.45),
		"length": 0.0016, "radius": 0.0003, "col": Color(0.42, 0.48, 0.34), "launcher": "box",
		"delivery": "projectile", "trajectory": "vertical", "hit": "single", "role": "attack", "tier": 1,
	},
	"glide": {
		"example": "GBU-39", "ar_short": "قنابل انزلاقية", "intercept": 0.3, "version": "1.2",
		"code": "AB-W-038", "ar": "قنابل انزلاقية", "en": "Glide bombs",
		"ar_desc": "تطلقها طائرة من بعيد فتنزلق بأجنحتها إلى الهدف · 4 قنابل ثم تعود الطائرة",
		"en_desc": "A jet releases 4 of them far out and they glide in on their wings; the jet flies home",
		"arc": "sortie", "speed": 0.15, "cruise_alt": 0.13, "bombs": 4, "bomb": "gbomb", "spread": 0.014,
		"release_lead": 0.16, "blast": 0.7, "ejecta": 16,
		"cooldown": 2.0, "ammo": 2, "reload": 0.0, "glow": false, "wings": true, "aircraft": true,
		"trail": 0.05, "trail_col": Color(0.85, 0.85, 0.85, 0.25),
		"length": 0.0034, "radius": 0.0005, "col": Color(0.55, 0.60, 0.66), "launcher": "deck",
		"delivery": "called", "trajectory": "waypoints", "hit": "splash", "role": "attack", "tier": 2,
	},
	"torpedo": {
		"example": "Mk 48", "ar_short": "طوربيد", "intercept": 0.0, "version": "1.2",
		"code": "AB-W-039", "ar": "طوربيد", "en": "Torpedo",
		"ar_desc": "يُلقى من جانب السفينة ويجري تحت سطح الماء إلى الهدف · يتوقف وينفجر عند الشاطئ",
		"en_desc": "Dropped over the side, it runs under the surface to the target; stops and goes off at the shore",
		"arc": "torpedo", "speed": 0.16, "flight": [0.8, 9.0], "blast": 1.35, "ejecta": 0,
		"cooldown": 4.0, "ammo": 4, "reload": 10.0, "glow": false,
		"trail": 0.05, "trail_col": Color(0.95, 0.98, 1.0, 0.55),
		"length": 0.0032, "radius": 0.0004, "col": Color(0.25, 0.28, 0.30), "launcher": "tube",
		"delivery": "projectile", "trajectory": "straight", "hit": "splash", "role": "attack", "tier": 2,
	},
	"heli": {
		"example": "AH-64 Apache", "ar_short": "مروحية", "intercept": 0.35, "version": "1.2",
		"code": "AB-W-040", "ar": "مروحية هجومية", "en": "Attack helicopter",
		"ar_desc": "منخفضة وبطيئة · رشقة 6 صواريخ من مسافة ثم تعود وتهبط",
		"en_desc": "Low and slow; a volley of 6 rockets from stand-off range, then home to land",
		"arc": "sortie", "speed": 0.09, "cruise_alt": 0.035, "bombs": 6, "bomb": "hrocket", "spread": 0.016,
		"release_lead": 0.07, "blast": 0.45, "ejecta": 10, "heli": true, "aircraft": true,
		"cooldown": 2.0, "ammo": 2, "reload": 0.0, "glow": false,
		"trail": 0.2, "trail_col": Color(0.8, 0.8, 0.8, 0.0),
		"length": 0.0034, "radius": 0.0006, "col": Color(0.34, 0.38, 0.30), "launcher": "deck",
		"delivery": "called", "trajectory": "waypoints", "hit": "splash", "role": "attack", "tier": 3,
	},
}

## Projectiles other weapons release: not weapons of their own (no code). The cluster
## missile's bomblets, the strike jet's bombs, the glide bombs, the helicopter's rockets
## and the bunker buster's bomb (each named by its parent's `bomb`).
const SUB := {
	"submunition": {
		"ar": "قنيبلة", "en": "Submunition", "arc": "lofted", "flight": [0.55, 0.75], "blast": 0.42, "ejecta": 8,
		"glow": false, "trail": 0.06, "trail_col": Color(0.80, 0.78, 0.74, 0.3),
		"length": 0.0009, "radius": 0.0003, "col": Color(0.70, 0.66, 0.46),
	},
	"jetbomb": {
		"ar": "قنبلة", "en": "Bomb", "arc": "lofted", "flight": [0.55, 0.7], "blast": 0.8, "ejecta": 18,
		"glow": false, "trail": 0.08, "trail_col": Color(0.8, 0.8, 0.8, 0.2),
		"length": 0.0014, "radius": 0.00045, "col": Color(0.35, 0.38, 0.32),
	},
	"gbomb": {
		"ar": "قنبلة انزلاقية", "en": "Glide bomb", "intercept": 0.25, "arc": "glidebomb", "speed": 0.2, "flight": [0.6, 3.0], "blast": 0.75, "ejecta": 18,
		"glow": false, "wings": true, "trail": 0.08, "trail_col": Color(0.85, 0.85, 0.85, 0.2),
		"length": 0.0012, "radius": 0.0002, "col": Color(0.50, 0.52, 0.48),
	},
	"hrocket": {
		"ar": "صاروخ مروحية", "en": "Helicopter rocket", "arc": "low", "flight": [0.4, 0.55], "blast": 0.45, "ejecta": 10,
		"anti_armor": true, "armor_k": 2.6,
		"glow": false, "trail": 0.015, "trail_col": Color(0.85, 0.82, 0.78, 0.5),
		"length": 0.0009, "radius": 0.00018, "col": Color(0.45, 0.47, 0.40),
	},
	"bunkerbomb": {
		"ar": "قنبلة خارقة للتحصينات", "en": "Bunker-buster bomb", "intercept": 0.1, "arc": "lofted", "flight": [0.8, 0.9], "blast": 1.15, "crater_k": 2.2, "ejecta": 110,
		"glow": false, "trail": 0.05, "trail_col": Color(0.80, 0.78, 0.74, 0.3),
		"length": 0.0036, "radius": 0.0006, "col": Color(0.40, 0.42, 0.38),
	},
}


static func ids() -> Array:
	return ORDER


static func has(id: String) -> bool:
	return WEAPONS.has(id)


## The weapon (or released projectile) with its id filled in; {} if unknown.
static func get_weapon(id: String) -> Dictionary:
	var w: Dictionary = WEAPONS.get(id, SUB.get(id, {}))
	if w.is_empty():
		return {}
	w = w.duplicate()
	w["id"] = id
	return w


static func name_of(id: String, lang := "ar") -> String:
	return str(get_weapon(id).get(lang, id))


static func by_code(code: String) -> String:
	for id: String in WEAPONS:
		if str(WEAPONS[id].code) == code:
			return id
	return ""


static func next_id(id: String, step := 1) -> String:
	var i := ORDER.find(id)
	return ORDER[posmod(i + step, ORDER.size())]
