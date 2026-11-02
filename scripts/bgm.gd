extends Node
## 배경음: two tracks on their own bus, "BGM" (default_bus_layout.tres, -1 dB, made here if missing; both files sit at
## -14 LUFS), out of the witch-time "Slow" bus and under the sound effects.
##   · title.ogg (164.44 s, loops) plays while the title is up (title.gd's music clock, beat.gd, follows its position);
##     on the web it can only start after the first tap or key — the title's gate — and it is (re)started on every
##     input event until it is really running, so a first try before the gesture is never the last one.
##   · town.ogg (a 75 s seamless loop) plays on the town street and on the guild hall's floors (both are "the village":
##     going through the hall door does not restart it), fades out over FADE s when you go down into a dungeon or to the
##     training ground, and fades back in where it left off when you come back. When the title hands off into the game
##     the two cross-fade over XFADE s and the town starts from 0, not from where it once paused.
## The 배경음 setting (arena.music) fades whatever plays out and pauses it.

const STREAM := preload("res://assets/bgm/town.ogg")
const TITLE := preload("res://assets/bgm/title.ogg")
const BEAT := preload("res://scripts/beat.gd")
const BUS := &"BGM"
const BUS_DB := -1.0
const MAPS := ["town", "hall"]
const FADE := 0.8                 # s, 0 -> full and back
const XFADE := 1.2                # s, the title -> town cross-fade

var arena
var ap: AudioStreamPlayer         # the town
var tap: AudioStreamPlayer        # the title
var gain := 0.0                   # 0..1, the town's fade
var tgain := 0.0                  # 0..1, the title's fade
var paused_at := -1.0             # where the town stopped when it faded out (s), -1 = never started


static func ensure_bus() -> int:
	var i := AudioServer.get_bus_index(BUS)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, BUS)
		AudioServer.set_bus_send(i, &"Master")
		AudioServer.set_bus_volume_db(i, BUS_DB)
	return i

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS      # menus pause the world, not the music
	ensure_bus()
	var st: AudioStreamOggVorbis = STREAM
	st.loop = true                               # town.ogg.import has loop=true too
	ap = _player(st)
	var tt: AudioStreamOggVorbis = TITLE
	tt.loop = true
	tap = _player(tt)

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
	return MAPS.has(arena.level_kind())

## should the title track be heard now (once the title has gone live: on the web that is the first tap)
func wanted_title() -> bool:
	if arena == null or not arena.music or not title_up(): return false
	return arena.ui_root.title.live

func _process(delta: float) -> void:
	var dt := minf(delta, 0.1)
	var w := wanted()
	var wt := wanted_title()
	# the title track: in over FADE, out over the cross-fade
	tgain = clampf(tgain + (dt / FADE if wt else -dt / XFADE), 0.0, 1.0)
	if wt and not tap.playing: tap.play(0.0)
	if tgain <= 0.0 and tap.playing and not wt: tap.stop()
	tap.volume_db = linear_to_db(maxf(0.00001, tgain * tgain))
	# the town: in over the cross-fade while the title is still fading, else over FADE
	var up := XFADE if tgain > 0.0 else FADE
	gain = clampf(gain + (dt / up if w else -dt / FADE), 0.0, 1.0)
	if w and not ap.playing: _start()
	if gain <= 0.0 and ap.playing and not w:
		paused_at = ap.get_playback_position()
		ap.stop()
	# an equal-power-ish curve: the fade sounds even, not a sudden drop at the end
	ap.volume_db = linear_to_db(maxf(0.00001, gain * gain))

## the town starts: from 0 when it takes over from the title, else where it paused
func _start() -> void:
	ap.play(0.0 if tgain > 0.0 else maxf(0.0, paused_at))

## a tap / click / key: the browser's audio may only now be allowed to run
func _input(ev: InputEvent) -> void:
	if not (ev is InputEventKey or ev is InputEventMouseButton or ev is InputEventScreenTouch or ev is InputEventJoypadButton): return
	if not ev.is_pressed(): return
	poke()

## start whatever is wanted and not yet running (the title calls it right after its gate's tap)
func poke() -> void:
	if wanted() and not ap.playing: _start()
	if wanted_title() and not tap.playing: tap.play(0.0)

func playing() -> bool:
	return ap.playing and gain > 0.0

## the title track's position for the music clock (s; -1 when it is not playing)
func title_pos() -> float:
	return BEAT.stream_pos(tap)
