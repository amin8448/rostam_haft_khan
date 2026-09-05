extends SceneTree

## Rostam's run and jump, design doc section 4.
##
## Expected:
##   resting y              612 px    ground surface 640, capsule half-height 28
##   full jump height       119 px    confirmed by playtest, about 3.7 tiles
##   tap jump height         29 px    confirmed by playtest, about 0.9 tiles
##   acceleration to 320     0.10 s
##   deceleration to 0       0.08 s
##   facing after Right         1
##   state after stopping    IDLE     enum value 0
##
## Runs on the flat stretch at cols 2..14 of khan1_01_marsh, which is kept
## clear of platforms precisely so run feel is measurable here.

const Support = preload("res://tests/test_support.gd")

const JUMP_PRESS: int = 30
const JUMP_RELEASE: int = 71
const TAP_PRESS: int = 110
const TAP_RELEASE: int = 111
const TAP_DONE: int = 131
const RUN_PRESS: int = 170
const RUN_RELEASE: int = 210
const FINISH: int = 280

var _player: CharacterBody2D
var _tick: int = 0
var _failures: int = 0
var _rest_y: float = 0.0
var _apex: float = 0.0
var _full_height: float = 0.0
var _tap_height: float = 0.0
var _accel_ticks: int = -1
var _decel_ticks: int = -1


func _initialize() -> void:
	var main: Node = (load("res://scenes/world/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	_player = main.get_node("Rostam") as CharacterBody2D


func _physics_process(delta: float) -> bool:
	_tick += 1
	var y: float = _player.global_position.y

	if _tick > JUMP_PRESS and _tick < JUMP_RELEASE:
		_apex = minf(_apex, y)
	elif _tick > TAP_PRESS and _tick < TAP_DONE:
		_apex = minf(_apex, y)

	if _tick > RUN_PRESS and _tick <= RUN_RELEASE and _accel_ticks < 0 \
			and absf(_player.velocity.x) >= 319.0:
		_accel_ticks = _tick - RUN_PRESS
	if _tick > RUN_RELEASE and _decel_ticks < 0 and is_zero_approx(_player.velocity.x):
		_decel_ticks = _tick - RUN_RELEASE

	match _tick:
		JUMP_PRESS:
			_rest_y = y
			_apex = y
			_failures += 0 if Support.near("resting y", y, 612.0) else 1
			_failures += 0 if Support.exact("on floor at rest", _player.is_on_floor(), true) else 1
			Input.action_press("jump")
		JUMP_RELEASE:
			Input.action_release("jump")
			_full_height = _rest_y - _apex
			_failures += 0 if Support.near("full jump height", _full_height, 119.0) else 1
		TAP_PRESS:
			_apex = y
			Input.action_press("jump")
		TAP_RELEASE:
			Input.action_release("jump")
		TAP_DONE:
			_tap_height = _rest_y - _apex
			_failures += 0 if Support.near("tap jump height", _tap_height, 29.0) else 1
		RUN_PRESS:
			Input.action_press("move_right")
		RUN_RELEASE:
			Input.action_release("move_right")
		FINISH:
			_failures += 0 if Support.near("accel to full speed", _accel_ticks * delta, 0.1, "s") else 1
			_failures += 0 if Support.near("decel to a stop", _decel_ticks * delta, 0.08, "s") else 1
			_failures += 0 if Support.exact("facing after Right", _player.get_facing(), 1) else 1
			_failures += 0 if Support.exact("state after stopping", _player.state, 0) else 1
			quit(Support.report("test_movement", _failures))
			return true
	return false
