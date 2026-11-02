extends Node
## 배경음: the town's music (assets/bgm/town.ogg, a 75 s seamless loop). It plays on the town street and on the guild
## hall's floors (both are "the village": going through the hall door does not restart it), fades out over FADE s when
## you go down into a dungeon or to the training ground, and fades back in where it left off when you come back.
## It plays on its own bus, "BGM" (default_bus_layout.tres, -8 dB, made here if missing), so it stays out of the
## witch-time "Slow" bus and under the sound effects. The 배경음 setting (arena.music) fades it out and pauses it.
## Web: the browser only lets audio start after a tap or key; the player is (re)started on every input event until it
## is actually running, so a first try before the gesture is never the last one.

const STREAM := preload("res://assets/bgm/town.ogg")
const BUS := &"BGM"
const BUS_DB := -8.0
const MAPS := ["town", "hall"]
const FADE := 0.8                 # s, 0 -> full and back

var arena
var ap: AudioStreamPlayer
var gain := 0.0                   # 0..1, the fade
var paused_at := -1.0             # where it stopped when it faded out (s), -1 = never started


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
	ap = AudioStreamPlayer.new()
	ap.stream = st
	ap.bus = BUS
	ap.set_meta("raw", true)                     # slow_bus.gd leaves it alone
	ap.volume_db = -80.0
	add_child(ap)

## should it be heard now
func wanted() -> bool:
	if arena == null or not arena.music: return false
	return MAPS.has(arena.level_kind())

func _process(delta: float) -> void:
	var dt := minf(delta, 0.1)
	var w := wanted()
	gain = clampf(gain + (dt if w else -dt) / FADE, 0.0, 1.0)
	if w and not ap.playing: _start()
	if gain <= 0.0 and ap.playing and not w:
		paused_at = ap.get_playback_position()
		ap.stop()
	# an equal-power-ish curve: the fade sounds even, not a sudden drop at the end
	ap.volume_db = linear_to_db(maxf(0.00001, gain * gain))

func _start() -> void:
	ap.play(maxf(0.0, paused_at))

## a tap / click / key: the browser's audio may only now be allowed to run
func _input(ev: InputEvent) -> void:
	if not (ev is InputEventKey or ev is InputEventMouseButton or ev is InputEventScreenTouch or ev is InputEventJoypadButton): return
	if not ev.is_pressed(): return
	if wanted() and not ap.playing: _start()

func playing() -> bool:
	return ap.playing and gain > 0.0
