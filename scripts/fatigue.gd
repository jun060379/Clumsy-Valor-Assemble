extends RefCounted
## 피로도 (sortie.js STM): 160 max, a boss chest costs 40, 1 comes back every 6 minutes of real time.
## Only the number and its clock for now: nothing spends it yet.

const MAX := 160
const COST := 40
const PER := 360000.0          # ms per point
const PATH := "user://fatigue.cfg"

var v := MAX
var t := 0.0                   # unix ms the current point started regenerating


func _init() -> void:
	t = now()
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		v = int(cf.get_value("stm", "v", MAX))
		t = float(cf.get_value("stm", "t", now()))

static func now() -> float:
	return Time.get_unix_time_from_system() * 1000.0

## stam(): catch up with the clock
func value() -> int:
	var n := now()
	if v >= MAX:
		t = n
		return v
	var k := int(floor((n - t) / PER))
	if k > 0:
		v = mini(MAX, v + k)
		t += k * PER
		if v >= MAX: t = n
		save()
	return v

## ms until the next point (0 when full)
func next_ms() -> float:
	if value() >= MAX: return 0.0
	return PER - fmod(now() - t, PER)

func spend(n: int) -> bool:
	if value() < n: return false
	if v >= MAX: t = now()
	v -= n
	save()
	return true

func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("stm", "v", v)
	cf.set_value("stm", "t", t)
	cf.save(PATH)
