extends SceneTree

## Rostam's attack, design doc section 5.
##
## Expected, read from Rostam's own @export arrays so retuning them retunes the
## test rather than breaking it:
##   swing 1 wind-up / active     0.08 s / 0.08 s
##   swing 2 wind-up / active     0.08 s / 0.08 s
##   swing 3 wind-up / active     0.12 s / 0.10 s   longer, and a bigger box
##   forward step per swing       12 px
##   three swings on the dummy    3 damage, 3 health to 0
##   hit pause on a landed hit    0.05 s
##   combo after 0.4 s idle       back to swing 1
##   air attack                   swing index 3, once per airborne period
##
## The timing phase swings at empty air on purpose. A swing that connects also
## triggers the 0.05 s hit pause, which correctly suspends the swing timer but
## leaves the blade on screen, so a hitting swing measures about four ticks
## wider than its active window. Timing and damage have to be measured
## separately or the first is just measuring the second.
##
## Timings use near_time, which allows one physics tick: a hitbox can only open
## on a tick boundary, and for a 0.08 s window one tick already exceeds 10%.
##
## Note there are two physics ticks between Input.action_press here and Rostam
## acting on it, so checkpoints leave three.

const Support = preload("res://tests/test_support.gd")

const TIMEOUT: int = 1200
## Somewhere with nothing in reach: the dummy is at x=400, the hazard at x=1632.
const EMPTY_GROUND: Vector2 = Vector2(200, 612)
## High enough that a full air swing plus a second attempt both fit before
## landing resets the one-air-attack rule.
const HIGH_AIR: Vector2 = Vector2(300, 150)

var _player: Rostam
var _sword: Hitbox
var _dummy: Node2D
var _tick: int = 0
var _failures: int = 0

var _records: Array[Dictionary] = []
var _swing_start: int = -1
var _swing_index: int = -1
var _active_start: int = -1
var _active_end: int = -1
var _start_x: float = 0.0
var _prev_x: float = 0.0
var _clean_durations: Array[float] = []

var _phase: String = "timing"
var _phase_start: int = 0
var _air_index: int = -1


func _initialize() -> void:
	var main: Node = (load("res://scenes/world/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	_player = main.get_node("Rostam") as Rostam
	_sword = _player.get_node("Visuals/SwordHitbox") as Hitbox
	_dummy = main.get_node("Room/TrainingDummy") as Node2D


func _physics_process(_delta: float) -> bool:
	_tick += 1
	if _tick > TIMEOUT:
		printerr("test_combat: timed out in phase ", _phase)
		quit(1)
		return true

	# main.gd puts Rostam on the room spawn in _ready, so move him after that
	# and give him a few ticks to settle before anything is measured.
	if _tick == 3:
		_player.global_position = EMPTY_GROUND
		_phase_start = _tick + 15
		return false

	_observe()

	match _phase:
		"timing":
			_run_timing()
		"damage":
			_run_damage()
		"reset":
			_run_reset()
		"air":
			_run_air()
		"done":
			quit(Support.report("test_combat", _failures))
			return true
	return false


## Closes a record when the swing index changes as well as when attacking stops,
## because a buffered attack chains straight from one swing into the next
## without ever leaving the ATTACK state.
func _observe() -> void:
	var attacking: bool = _player.is_attacking()
	var index: int = _player.get_swing_index()

	if _swing_start >= 0 and (not attacking or index != _swing_index):
		_records.append({
			"index": _swing_index,
			"windup": float(_active_start - _swing_start) / 60.0,
			"active": float(_active_end - _active_start) / 60.0,
			"duration": float(_tick - _swing_start) / 60.0,
			"step": _player.global_position.x - _start_x,
		})
		_swing_start = -1

	if attacking and _swing_start < 0:
		_swing_start = _tick
		_swing_index = index
		# The tick a swing first shows up, Rostam has already taken the first
		# part of its forward step, so the previous tick is the real origin.
		_start_x = _prev_x
		_active_start = -1
		_active_end = -1

	if _swing_start >= 0:
		if _sword.is_active() and _active_start < 0:
			_active_start = _tick
		elif not _sword.is_active() and _active_start >= 0 and _active_end < 0:
			_active_end = _tick

	_prev_x = _player.global_position.x


func _tap(at: int) -> void:
	if _tick == _phase_start + at:
		Input.action_press("attack")
	elif _tick == _phase_start + at + 1:
		Input.action_release("attack")


func _run_timing() -> void:
	_tap(0)
	_tap(20)
	_tap(40)
	if _tick != _phase_start + 70:
		return

	for slot in _records.size():
		var record: Dictionary = _records[slot]
		var i: int = record["index"]
		_failures += 0 if Support.exact("swing %d is index %d" % [slot + 1, slot], i, slot) else 1
		_failures += 0 if Support.near_time("swing %d wind-up" % (slot + 1),
				record["windup"], _player.swing_windup[i]) else 1
		_failures += 0 if Support.near_time("swing %d active window" % (slot + 1),
				record["active"], _player.swing_active[i]) else 1
		_failures += 0 if Support.near("swing %d forward step" % (slot + 1),
				record["step"], _player.swing_step[i]) else 1
	_failures += 0 if Support.exact("three swings recorded", _records.size(), 3) else 1

	for record in _records:
		_clean_durations.append(record["duration"])
	_records.clear()
	_player.global_position = Vector2(_dummy.global_position.x - 40.0, 612.0)
	_phase = "damage"
	_phase_start = _tick + 15


func _run_damage() -> void:
	_tap(0)
	_tap(20)
	_tap(40)
	if _tick != _phase_start + 70:
		return

	_failures += 0 if Support.exact("three swings kill the dummy", _dummy.health, 0) else 1
	_failures += 0 if Support.exact("dummy is gone", _dummy.is_alive(), false) else 1

	# Hit pause measured as what it actually does rather than by reading a
	# timer: the same swing takes this much longer when it connects.
	if _records.is_empty() or _clean_durations.is_empty():
		printerr("test_combat: no swing recorded in the damage phase")
		quit(1)
		return
	var stretched: float = _records[0]["duration"] - _clean_durations[0]
	_failures += 0 if Support.near_time("hit pause stretches a swing",
			stretched, _sword.hit_pause) else 1

	_records.clear()
	_phase = "reset"
	_phase_start = _tick + 40


func _run_reset() -> void:
	# The last swing ended well over 0.4 s ago, so this must start the combo
	# again at the first swing rather than continuing to a fourth.
	_tap(0)
	if _tick == _phase_start + 5:
		_failures += 0 if Support.exact("combo resets after 0.4 s",
				_player.get_swing_index(), 0) else 1
	elif _tick == _phase_start + 40:
		_player.global_position = HIGH_AIR
		_player.velocity = Vector2.ZERO
		_phase = "air"
		_phase_start = _tick + 3


func _run_air() -> void:
	_tap(0)
	if _tick == _phase_start + 5:
		_air_index = _player.get_swing_index()
		_failures += 0 if Support.exact("air attack while airborne",
				not _player.is_on_floor(), true) else 1
		_failures += 0 if Support.exact("air attack swing index",
				_air_index, Rostam.AIR_SWING) else 1
	elif _tick == _phase_start + 20:
		_failures += 0 if Support.exact("air swing has finished",
				_player.is_attacking(), false) else 1
	# A second press in the same jump must do nothing: section 5 allows one air
	# attack, with no combo.
	_tap(21)
	if _tick == _phase_start + 26:
		_failures += 0 if Support.exact("still airborne for the retry",
				not _player.is_on_floor(), true) else 1
		_failures += 0 if Support.exact("air attack does not combo",
				_player.is_attacking(), false) else 1
		_phase = "done"
