extends Node
## 배경음: the tracks on their own bus, "BGM" (default_bus_layout.tres, -1 dB, made here if missing; every file sits at
## -14 LUFS), out of the witch-time "Slow" bus and under the sound effects.
##   · title.ogg (164.44 s, loops) plays while the title is up (title.gd's music clock, beat.gd, follows its position);
##     on the web it can only start after the first tap or key — the title's gate — and it is (re)started on every
##     input event until it is really running, so a first try before the gesture is never the last one.
##   · town.ogg (a 75 s seamless loop, 96 BPM) plays on the town street and on the guild hall's floors (both are "the
##     village": going through the hall door does not restart it), fades out over FADE s when you go down into a
##     dungeon or to the training ground, and fades back in where it left off when you come back. When the title hands
##     off into the game the two cross-fade over XFADE s and the town starts from 0, not from where it once paused.
##   · battle.ogg (105.79 s, loops back to 4.99) starts from 0 on entering the dungeon and plays through every room;
##     room-to-room moves never restart it, leaving to town stops it (the town resumes where it paused), and the next
##     sortie starts it from 0 again.
##   · boss.ogg (174.35 s, a 13.5 s fade-in intro, loops back to 13.49) starts from 0 when the boss room is entered
##     while the battle track fades out over one bar (BAR_OUT); when the boss is down it fades out over BOSS_OUT.
##   · lowhp.ogg (60.24 s, loops back to 20.18) is an overlay on a third player: under 30 % HP in the dungeon it fades
##     in over LOW_IN s, started on the next bar line of the battle / boss clock so it lands on the grid (from 0 the
##     first time a sortie, the intro; from the loop point after), while the battle / boss player is ducked LOW_DUCK dB;
##     from 40 % HP (hysteresis) it fades out over LOW_OUT s and the duck lets go. Never in town.
##   · duck(db, ms): an impact dips whatever plays by db for ms ms (DUCK_ATK ms in, DUCK_REL ms out) — arena.sfx() calls
##     it for heavy / parry (4 dB, 120 ms) and the ult's impact (6 dB, 250 ms) while a dungeon track plays.
## The training ground stays silent. The 배경음 setting (arena.music) fades whatever plays out and pauses it.
## clock() is the music clock (beat.gd) of the track that is audible — the title's own while the title is up, else
## town / battle / boss — fed from that player's position; grid() is the dungeon clock the sfx snap to (null elsewhere).

const STREAM := preload("res://assets/bgm/town.ogg")
const TITLE := preload("res://assets/bgm/title.ogg")
const BATTLE := preload("res://assets/bgm/battle.ogg")
const BOSS := preload("res://assets/bgm/boss.ogg")
const LOWHP := preload("res://assets/bgm/lowhp.ogg")
const BEAT := preload("res://scripts/beat.gd")
const BMAPS := preload("res://scripts/beat_maps.gd")
const BUS := &"BGM"
const BUS_DB := -1.0
const MAPS_TOWN := ["town", "hall"]
const FADE := 0.8                 # s, 0 -> full and back
const XFADE := 1.2                # s, the title -> town cross-fade
const DUN_IN := 0.25              # s, battle / boss in (the files carry their own intros)
const BAR_OUT := 4.0 * 60.0 / 95.7   # s, battle out when the boss room is entered: one bar (2.508)
const BOSS_OUT := 1.5             # s, boss out when the boss is down
const LOW_ON := 0.30              # the low-HP overlay comes in under this HP fraction …
const LOW_OFF := 0.40             # … and goes out from this one
const LOW_IN := 0.6               # s
const LOW_OUT := 1.0              # s
const LOW_DUCK := 6.0             # dB off the battle / boss track while the overlay is in
const DUCK_ATK := 0.04            # s, an impact duck's attack
const DUCK_REL := 0.12            # s, its release
## the grids (bpm nominal, t0 the first downbeat, len the file, loop the .import's loop_offset); the dungeon tracks
## and the town ride measured beat maps (beat_maps.gd) on top, their tempo ramps a couple of BPM over the file
const GRID := {
	"title": {"bpm": 184.57, "t0": 0.09, "half_time": true, "len": 164.44, "loop": 0.0},
	"town": {"bpm": 96.0, "t0": 0.65, "half_time": false, "len": 75.0, "loop": 0.0},
	"battle": {"bpm": 95.7, "t0": 0.12, "half_time": false, "len": 105.79, "loop": 4.99},
	"boss": {"bpm": 95.7, "t0": 0.70, "half_time": false, "len": 174.35, "loop": 13.49},
	"lowhp": {"bpm": 95.7, "t0": 0.12, "half_time": false, "len": 60.24, "loop": 20.18},
}

var arena
var ap: AudioStreamPlayer         # the town
var tap: AudioStreamPlayer        # the title
var bp: AudioStreamPlayer         # battle
var bsp: AudioStreamPlayer        # boss
var lp: AudioStreamPlayer         # the low-HP overlay
var gain := 0.0                   # 0..1, the town's fade
var tgain := 0.0                  # 0..1, the title's fade
var bgain := 0.0                  # battle
var bsgain := 0.0                 # boss
var lgain := 0.0                  # lowhp
var paused_at := -1.0             # where the town stopped when it faded out (s), -1 = never started
var clocks := {}                  # "town" / "battle" / "boss" / "lowhp" -> beat.gd
var low := false                  # the low-HP state (with hysteresis)
var low_due := -1.0               # s until the overlay starts (-1 = not scheduled)
var low_pos := 0.0                # where it starts from
var low_intro := false            # the overlay's intro has been heard this sortie
var duck_db := 0.0                # the impact duck's depth (dB)
var duck_t := 0.0                 # s left of the dip
var duck_v := 0.0                 # the duck's current level (dB, ramped)
var was_dun := false              # last frame's "in the dungeon" (the sortie's intro flags reset on entry)


static func ensure_bus() -> int:
	var i := AudioServer.get_bus_index(BUS)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, BUS)
		AudioServer.set_bus_send(i, &"Master")
		AudioServer.set_bus_volume_db(i, BUS_DB)
	return i

## a track's grid for beat.gd: GRID plus its measured beat map
static func grid_of(name: String) -> Dictionary:
	var g: Dictionary = GRID[name].duplicate()
	if BMAPS.MAPS.has(name):
		g["beats"] = PackedFloat32Array(BMAPS.MAPS[name]["beats"])
		g["i0"] = BMAPS.MAPS[name]["i0"]
	return g

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS      # menus pause the world, not the music
	ensure_bus()
	var st: AudioStreamOggVorbis = STREAM
	st.loop = true                               # town.ogg.import has loop=true too
	ap = _player(st)
	var tt: AudioStreamOggVorbis = TITLE
	tt.loop = true
	tap = _player(tt)
	bp = _player(_looped(BATTLE, 4.99))
	bsp = _player(_looped(BOSS, 13.49))
	lp = _player(_looped(LOWHP, 20.18))
	for n in ["town", "battle", "boss", "lowhp"]:
		clocks[n] = BEAT.new(grid_of(n))

## the .import files carry these too; set again here so a stale import cannot lose the loop
static func _looped(st: AudioStreamOggVorbis, off: float) -> AudioStreamOggVorbis:
	st.loop = true
	st.loop_offset = off
	return st

func _player(st: AudioStream) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.bus = BUS
	p.set_meta("raw", true)                      # slow_bus.gd leaves it alone
	p.volume_db = -80.0
	add_child(p)
	return p

## the title screen is up (the settings page over it counts: the title's music stays)
func title_up() -> bool:
	if arena == null or arena.ui_root == null or arena.ui_root.title == null: return false
	var T = arena.ui_root.title
	return T.active or T.in_opts

## should the town be heard now
func wanted() -> bool:
	if arena == null or not arena.music: return false
	if title_up(): return false
	return MAPS_TOWN.has(arena.level_kind())

## should the title track be heard now (once the title has gone live: on the web that is the first tap)
func wanted_title() -> bool:
	if arena == null or not arena.music or not title_up(): return false
	return arena.ui_root.title.live

## the dungeon's current room is the boss's and the boss is still up
func boss_fight() -> bool:
	if arena == null or arena.level_kind() != "dungeon": return false
	var L = arena.level
	if L == null or not L.has_method("room"): return false
	var rm: Dictionary = L.room()
	return rm.get("type", "") == "boss" and not rm.get("cleared", false)

## the boss room, cleared: the boss track is going out, nothing takes its place until town
func boss_done() -> bool:
	if arena == null or arena.level_kind() != "dungeon": return false
	var L = arena.level
	if L == null or not L.has_method("room"): return false
	var rm: Dictionary = L.room()
	return rm.get("type", "") == "boss" and rm.get("cleared", false)

func wanted_battle() -> bool:
	if arena == null or not arena.music or title_up(): return false
	return arena.level_kind() == "dungeon" and not boss_fight() and not boss_done()

func wanted_boss() -> bool:
	if arena == null or not arena.music or title_up(): return false
	return boss_fight()

## the player's HP fraction (player.gd hp / MAX_HP)
func hp_frac() -> float:
	if arena == null or arena.player == null: return 1.0
	var P = arena.player
	return clampf(P.hp / maxf(1.0, P.MAX_HP), 0.0, 1.0)

## should the low-HP overlay be heard: under LOW_ON in the dungeon, until LOW_OFF (never in town, never muted)
func wanted_low() -> bool:
	if arena == null or not arena.music or title_up() or arena.level_kind() != "dungeon": return false
	if not (bp.playing or bsp.playing): return false
	var f := hp_frac()
	if low and f >= LOW_OFF: low = false
	elif not low and f < LOW_ON: low = true
	return low

func _process(delta: float) -> void:
	var dt := minf(delta, 0.1)
	var w := wanted()
	var wt := wanted_title()
	var wb := wanted_battle()
	var wbs := wanted_boss()
	var dun: bool = arena != null and arena.level_kind() == "dungeon"
	if dun and not was_dun: low_intro = false   # a new sortie: the overlay's intro again
	was_dun = dun
	# the title track: in over FADE, out over the cross-fade
	tgain = clampf(tgain + (dt / FADE if wt else -dt / XFADE), 0.0, 1.0)
	if wt and not tap.playing: tap.play(0.0)
	if tgain <= 0.0 and tap.playing and not wt: tap.stop()
	# the town: in over the cross-fade while the title is still fading, else over FADE
	var up := XFADE if tgain > 0.0 else FADE
	gain = clampf(gain + (dt / up if w else -dt / FADE), 0.0, 1.0)
	if w and not ap.playing: _start()
	if gain <= 0.0 and ap.playing and not w:
		paused_at = ap.get_playback_position()
		ap.stop()
		clocks["town"].stop()
	# battle: from 0 on entry; out over a bar when the boss room takes over, over FADE on the way to town
	var bout := BAR_OUT if wbs else FADE
	bgain = clampf(bgain + (dt / DUN_IN if wb else -dt / bout), 0.0, 1.0)
	if wb and not bp.playing:
		bp.play(0.0)
		clocks["battle"].start(0.0)
	if bgain <= 0.0 and bp.playing and not wb:
		bp.stop()
		clocks["battle"].stop()
	# the boss: from 0 (its own fade-in intro) when the boss room is entered; out over BOSS_OUT when the boss is down
	var bsout := BOSS_OUT if boss_done() else FADE
	bsgain = clampf(bsgain + (dt / DUN_IN if wbs else -dt / bsout), 0.0, 1.0)
	if wbs and not bsp.playing:
		bsp.play(0.0)
		clocks["boss"].start(0.0)
	if bsgain <= 0.0 and bsp.playing and not wbs:
		bsp.stop()
		clocks["boss"].stop()
	# the low-HP overlay: scheduled onto the next bar line, in over LOW_IN, out over LOW_OUT
	var wl := wanted_low()
	if wl and not lp.playing and low_due < 0.0:
		low_pos = 0.0 if not low_intro else lp.stream.loop_offset
		low_due = low_start_in(low_pos)
	if not wl: low_due = -1.0
	if low_due >= 0.0 and not lp.playing:
		low_due -= dt
		if low_due <= 0.0:
			low_due = -1.0
			lp.play(low_pos)
			clocks["lowhp"].start(low_pos)
			low_intro = true
	lgain = clampf(lgain + (dt / LOW_IN if (wl and lp.playing) else -dt / LOW_OUT), 0.0, 1.0)
	if lgain <= 0.0 and lp.playing and not wl:
		lp.stop()
		clocks["lowhp"].stop()
	# the impact duck: DUCK_ATK in, holds for the rest of the dip, DUCK_REL out (a step that crosses the dip's end
	# does both parts)
	var rel := dt
	if duck_t > 0.0:
		var h := minf(dt, duck_t)
		duck_t -= h
		rel = dt - h
		duck_v = minf(duck_db, duck_v + duck_db * h / DUCK_ATK)
	if rel > 0.0 and duck_t <= 0.0 and duck_v > 0.0:
		duck_v = maxf(0.0, duck_v - duck_db * rel / DUCK_REL)
		if duck_v <= 0.0: duck_db = 0.0
	# an equal-power-ish curve: the fade sounds even, not a sudden drop at the end
	var dk := -duck_v
	tap.volume_db = _db(tgain) + dk
	ap.volume_db = _db(gain) + dk
	bp.volume_db = _db(bgain) + dk - LOW_DUCK * lgain
	bsp.volume_db = _db(bsgain) + dk - LOW_DUCK * lgain
	lp.volume_db = _db(lgain) + dk
	# the clocks follow their players (the wall clock inside beat.gd carries them where the position does not move)
	for n in clocks:
		var c = clocks[n]
		if c.live: c.step(dt, BEAT.stream_pos(_player_of(n)))

static func _db(g: float) -> float:
	return linear_to_db(maxf(0.00001, g * g))

## seconds until the low-HP overlay should start from `pos` so that its own bar line (the first downbeat at 0, the
## loop point's bar at the loop offset) lands on the next bar line of the dungeon clock; at once without a grid
func low_start_in(pos: float) -> float:
	var g = grid()
	if g == null: return 0.0
	var L = clocks["lowhp"]
	var ahead: float = L.time_of(roundf(L.beat_at(pos) / 4.0) * 4.0) - pos    # the overlay's bar line, after its start
	var due: float = g.next_bar(grid_now()) - ahead
	if due < 0.0: due += g.bar_len()                                          # too close: the bar after
	return maxf(0.0, due)

## the dungeon grid's time for something started now: the stream's position at the mix (a sound started now plays
## with it; the output latency delays both alike) while the clock follows the stream, else the clock's own time
func grid_now() -> float:
	var g = grid()
	if g == null: return -1.0
	if g.healthy and not g.hold:
		var pos: float = BEAT.mix_pos(_player_of(audible()))
		if pos >= 0.0: return g.wrap_t(pos)
	return g.music_t

func _player_of(n: String) -> AudioStreamPlayer:
	match n:
		"town": return ap
		"title": return tap
		"battle": return bp
		"boss": return bsp
		"lowhp": return lp
	return null

## the town starts: from 0 when it takes over from the title, else where it paused
func _start() -> void:
	ap.play(0.0 if tgain > 0.0 else maxf(0.0, paused_at))
	clocks["town"].start(0.0 if tgain > 0.0 else maxf(0.0, paused_at))

## a tap / click / key: the browser's audio may only now be allowed to run
func _input(ev: InputEvent) -> void:
	if not (ev is InputEventKey or ev is InputEventMouseButton or ev is InputEventScreenTouch or ev is InputEventJoypadButton): return
	if not ev.is_pressed(): return
	poke()

## start whatever is wanted and not yet running (the title calls it right after its gate's tap)
func poke() -> void:
	if wanted() and not ap.playing: _start()
	if wanted_title() and not tap.playing: tap.play(0.0)
	if wanted_battle() and not bp.playing:
		bp.play(0.0)
		clocks["battle"].start(0.0)
	if wanted_boss() and not bsp.playing:
		bsp.play(0.0)
		clocks["boss"].start(0.0)

func playing() -> bool:
	return ap.playing and gain > 0.0

## the title track's position for the music clock (s; -1 when it is not playing)
func title_pos() -> float:
	return BEAT.stream_pos(tap)

## an impact: dip the music by db dB for ms ms (DUCK_ATK in, DUCK_REL out after)
func duck(db: float, ms: float) -> void:
	duck_db = maxf(duck_db if duck_t > 0.0 else 0.0, db)
	duck_t = maxf(duck_t, ms / 1000.0)

## the name of the track that is audible: "title" / "boss" / "battle" / "town" / ""
func audible() -> String:
	if title_up() and arena.ui_root.title.live: return "title"
	if bsp.playing and bsgain > 0.0: return "boss"
	if bp.playing and bgain > 0.0: return "battle"
	if ap.playing and gain > 0.0: return "town"
	return ""

## the music clock (beat.gd) of the audible track: the title's own under the title, else town / battle / boss;
## null when nothing plays (the training ground, 배경음 off)
func clock():
	var a := audible()
	if a == "": return null
	if a == "title": return arena.ui_root.title.beat
	return clocks[a]

## the dungeon clock the sound effects snap to: battle or boss while it really plays, null in town / training / title
func grid():
	var a := audible()
	if a != "battle" and a != "boss": return null
	var c = clocks[a]
	return c if c.live else null

## seconds to the next 16th of the dungeon grid, -1 without one — from the stream's position right now (grid_now),
## not the frame-old music_t, so a snap is neither a frame late nor the output latency early
func next_sixteenth() -> float:
	var g = grid()
	if g == null: return -1.0
	return g.next_sixteenth(grid_now())
