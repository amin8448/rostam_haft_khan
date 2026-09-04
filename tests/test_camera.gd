extends SceneTree

## The world-owned camera, design doc section 7.
##
## Expected:
##   limits from room bounds     0, 0, 1920, 832   khan1_01_marsh
##   position smoothing          enabled, speed 7  section 7 says 6 to 8
##   focus shift on a tap jump   0 px              29 px hop, inside the 40 px
##                                                 dead zone, so no bob
##   focus shift on a full jump  rise - 40 px      dead zone eats the first 40
##   look-ahead facing right    +60 px
##   look-ahead facing left     -60 px
##   focus past top-left         clamps to     0 + 32
##   focus past bottom-right     clamps to  1920 - 32, 832 - 32
##
## The headless viewport is 64x64 and ignores root.size and --resolution, so
## the clamp targets use half of 64 rather than half of the real window.

const Support = preload("res://tests/test_support.gd")

const DEAD_ZONE: float = 40.0
const HALF_VIEWPORT: float = 32.0
const BOUNDS: Rect2 = Rect2(0, 0, 1920, 832)

const TAP_PRESS: int = 10
const TAP_RELEASE: int = 11
const TAP_DONE: int = 45
const FULL_PRESS: int = 46
const FULL_RELEASE: int = 92
const FULL_DONE: int = 100
const RIGHT_PRESS: int = 105
const LEFT_PRESS: int = 185
const LEFT_DONE: int = 265
const CORNER_A: int = 270
const CORNER_B: int = 273

var _player: CharacterBody2D
var _cam: Camera2D
var _tick: int = 0
var _failures: int = 0
var _rest_focus_y: float = 0.0
var _rest_player_y: float = 0.0
var _tap_shift: float = 0.0
var _tap_rise: float = 0.0
var _full_shift: float = 0.0
var _full_rise: float = 0.0


func _initialize() -> void:
	var main: Node = (load("res://scenes/world/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	_player = main.get_node("Rostam") as CharacterBody2D
	_cam = main.get_node("GameCamera") as Camera2D


func _physics_process(_delta: float) -> bool:
	_tick += 1

	if _tick > TAP_PRESS and _tick < TAP_DONE:
		_tap_shift = maxf(_tap_shift, absf(_cam.global_position.y - _rest_focus_y))
		_tap_rise = maxf(_tap_rise, _rest_player_y - _player.global_position.y)
	elif _tick > FULL_PRESS and _tick < FULL_DONE:
		_full_shift = maxf(_full_shift, absf(_cam.global_position.y - _rest_focus_y))
		_full_rise = maxf(_full_rise, _rest_player_y - _player.global_position.y)

	match _tick:
		5:
			_failures += 0 if Support.exact("limit_left", _cam.limit_left, int(BOUNDS.position.x)) else 1
			_failures += 0 if Support.exact("limit_top", _cam.limit_top, int(BOUNDS.position.y)) else 1
			_failures += 0 if Support.exact("limit_right", _cam.limit_right, int(BOUNDS.end.x)) else 1
			_failures += 0 if Support.exact("limit_bottom", _cam.limit_bottom, int(BOUNDS.end.y)) else 1
			_failures += 0 if Support.exact("smoothing enabled", _cam.position_smoothing_enabled, true) else 1
			_failures += 0 if Support.near("smoothing speed", _cam.position_smoothing_speed, 7.0, "") else 1
		TAP_PRESS:
			_rest_focus_y = _cam.global_position.y
			_rest_player_y = _player.global_position.y
			Input.action_press("jump")
		TAP_RELEASE:
			Input.action_release("jump")
		TAP_DONE:
			# A hop smaller than the dead zone must not move the camera at all.
			_failures += 0 if Support.near("tap jump player rise", _tap_rise, 29.0) else 1
			_failures += 0 if Support.near("tap jump focus shift", _tap_shift, 0.0) else 1
			Input.action_press("jump")
		FULL_RELEASE:
			Input.action_release("jump")
		FULL_DONE:
			# Derived from the rise measured in this same run, so this checks the
			# dead zone relationship rather than re-testing the jump.
			_failures += 0 if Support.near("full jump focus shift", _full_shift, _full_rise - DEAD_ZONE) else 1
			Input.action_press("move_right")
		LEFT_PRESS:
			_failures += 0 if Support.near("look-ahead facing right",
					_cam.global_position.x - _player.global_position.x, 60.0) else 1
			Input.action_release("move_right")
			Input.action_press("move_left")
		LEFT_DONE:
			_failures += 0 if Support.near("look-ahead facing left",
					_cam.global_position.x - _player.global_position.x, -60.0) else 1
			Input.action_release("move_left")
		CORNER_A:
			_player.global_position = Vector2(-400.0, -400.0)
		CORNER_A + 1:
			# One tick after the teleport so the dead zone has taken the new
			# target, then snap so smoothing is not mid-flight when we read it.
			_cam.snap()
		CORNER_A + 2:
			var a: Vector2 = _cam.get_screen_center_position()
			_failures += 0 if Support.near("clamp past left limit", a.x, BOUNDS.position.x + HALF_VIEWPORT) else 1
			_failures += 0 if Support.near("clamp past top limit", a.y, BOUNDS.position.y + HALF_VIEWPORT) else 1
		CORNER_B:
			_player.global_position = Vector2(4000.0, 4000.0)
		CORNER_B + 1:
			_cam.snap()
		CORNER_B + 2:
			var b: Vector2 = _cam.get_screen_center_position()
			_failures += 0 if Support.near("clamp past right limit", b.x, BOUNDS.end.x - HALF_VIEWPORT) else 1
			_failures += 0 if Support.near("clamp past bottom limit", b.y, BOUNDS.end.y - HALF_VIEWPORT) else 1
			quit(Support.report("test_camera", _failures))
			return true
	return false
