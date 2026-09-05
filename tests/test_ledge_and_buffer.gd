extends SceneTree

## Coyote time, jump buffering and the sprite flip, design doc section 4.
##
## Expected:
##   coyote jump off a ledge    vy -640    jump still fires 0.067 s after
##                                         leaving the ground (window is 0.1 s)
##   buffered jump on landing   vy -640    pressed 0.07 s before touching down,
##                                         and at full height: the button was
##                                         released while still falling, so the
##                                         variable-height cut must not apply
##   facing after Left            -1
##   Visuals.scale.x              -1
##   a one-tick -0.3 nudge        no flip: that is stick rebound past centre,
##                                not a turn, and it sits under facing_threshold
##   a sustained -1.0             flips within 4 ticks
##
## The ledge is the left lip of the pit at col 15, world x 480.
## Note: release an action once, not every tick. Calling Input.action_release
## repeatedly re-fires is_action_just_released and would cut the jump short.

const Support = preload("res://tests/test_support.gd")

enum Phase { COYOTE_WALK, COYOTE_AIR, COYOTE_CHECK, BUFFER_FALL, BUFFER_LAND, FACING, DONE }

## Ticks after leaving the ledge before jumping. 4 ticks is 0.067 s, inside the
## 0.1 s coyote window.
const COYOTE_DELAY: int = 4
## Height above the floor at which the buffered jump is pressed, roughly 0.07 s
## before landing.
const BUFFER_PRESS_Y: float = 557.0
const TIMEOUT: int = 600

var _player: CharacterBody2D
var _visuals: Node2D
var _phase: Phase = Phase.COYOTE_WALK
var _tick: int = 0
var _failures: int = 0
var _left_ground_tick: int = 0
var _press_tick: int = 0
var _land_tick: int = 0
var _pressed_buffer: bool = false
var _coyote_peak: float = 0.0
var _buffer_peak: float = 0.0
var _facing_start: int = -1
var _left_press_tick: int = -1
var _flip_tick: int = -1


func _initialize() -> void:
	var main: Node = (load("res://scenes/world/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	_player = main.get_node("Rostam") as CharacterBody2D
	_visuals = _player.get_node("Visuals") as Node2D
	_player.global_position = Vector2(440.0, 612.0)
	Input.action_press("move_right")


func _physics_process(_delta: float) -> bool:
	_tick += 1
	if _tick > TIMEOUT:
		printerr("test_ledge_and_buffer: timed out in phase ", _phase)
		quit(1)
		return true

	match _phase:
		Phase.COYOTE_WALK:
			if not _player.is_on_floor():
				_left_ground_tick = _tick
				Input.action_release("move_right")
				_phase = Phase.COYOTE_AIR
		Phase.COYOTE_AIR:
			if _tick == _left_ground_tick + COYOTE_DELAY:
				Input.action_press("jump")
				_coyote_peak = _player.velocity.y
				_phase = Phase.COYOTE_CHECK
		Phase.COYOTE_CHECK:
			_coyote_peak = minf(_coyote_peak, _player.velocity.y)
			if _tick > _left_ground_tick + COYOTE_DELAY + 8:
				_failures += 0 if Support.near("coyote jump off ledge", _coyote_peak, -640.0, "px/s") else 1
				Input.action_release("jump")
				_player.global_position = Vector2(300.0, 300.0)
				_player.velocity = Vector2.ZERO
				_buffer_peak = 0.0
				_phase = Phase.BUFFER_FALL
		Phase.BUFFER_FALL:
			if not _pressed_buffer and _player.global_position.y > BUFFER_PRESS_Y:
				Input.action_press("jump")
				_pressed_buffer = true
				_press_tick = _tick
			elif _pressed_buffer and _tick == _press_tick + 1:
				Input.action_release("jump")
			if _player.is_on_floor():
				_land_tick = _tick
				_phase = Phase.BUFFER_LAND
		Phase.BUFFER_LAND:
			_buffer_peak = minf(_buffer_peak, _player.velocity.y)
			if _tick > _land_tick + 10:
				_failures += 0 if Support.near("buffered jump on landing", _buffer_peak, -640.0, "px/s") else 1
				_failures += 0 if Support.exact("airborne after landing", not _player.is_on_floor(), true) else 1
				# No input pressed here: the facing phase needs to start from a
				# clean stick, or the rebound check is measuring a real turn.
				_phase = Phase.FACING
		Phase.FACING:
			_run_facing()
		Phase.DONE:
			quit(Support.report("test_ledge_and_buffer", _failures))
			return true
	return false


## Facing has to ignore a stick that rebounds past centre on release or reversal
## without becoming sluggish about a real turn, so both halves are checked here.
func _run_facing() -> void:
	if _facing_start < 0:
		_facing_start = _tick
		_failures += 0 if Support.exact("facing right before the test",
				_player.get_facing(), 1) else 1

	var at: int = _tick - _facing_start
	if at == 2:
		# One tick at -0.3: weaker than facing_threshold, so it is rebound.
		Input.action_press("move_left", 0.3)
	elif at == 3:
		Input.action_release("move_left")
	elif at == 10:
		_failures += 0 if Support.exact("rebound of -0.3 does not flip",
				_player.get_facing(), 1) else 1
		Input.action_press("move_left")
		_left_press_tick = _tick
	elif at > 10 and _flip_tick < 0 and _player.get_facing() == -1:
		_flip_tick = _tick
	elif at == 24:
		_failures += 0 if Support.exact("sustained -1.0 flips facing",
				_player.get_facing(), -1) else 1
		var ticks: float = float(_flip_tick - _left_press_tick) if _flip_tick > 0 else 99.0
		_failures += 0 if Support.at_most("ticks to flip", ticks, 4.0, "tk") else 1
		_failures += 0 if Support.near("Visuals.scale.x", _visuals.scale.x, -1.0, "") else 1
		Input.action_release("move_left")
		_phase = Phase.DONE
