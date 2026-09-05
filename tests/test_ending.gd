extends SceneTree

## The end of the slice, design doc section 8.
##
## Expected:
##   after the fight       the den's east door leads to the complete screen
##   jump on that screen   back to room 1's spawn on full health
##   the respawn point     reset to room 1, whatever it was before
##   room 5 afterwards     the Lion alive again, with no save system involved
##
## The fight is skipped rather than fought: what is under test here is what
## happens after it, and test_lion already covers the fight itself.

const Support = preload("res://tests/test_support.gd")

const TIMEOUT: int = 2400
const DEN: String = "res://scenes/rooms/khan1_05_den.tscn"
const MARSH: String = "res://scenes/rooms/khan1_01_marsh.tscn"
const MARSH_SPAWN: Vector2 = Vector2(144, 612)
const ON_TRIGGER: Vector2 = Vector2(380, 548)
## Standing in the east door of the den.
const IN_EAST_DOOR: Vector2 = Vector2(1200, 548)

var _main: Node
var _mgr: RoomManager
var _arena: Room
var _lion: Lion
var _player: Rostam
var _complete: CanvasLayer
var _tick: int = 0
var _failures: int = 0

var _phase: String = "fight"
var _phase_start: int = 0


func _initialize() -> void:
	_main = (load("res://scenes/world/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_player = _main.get_node("Rostam") as Rostam
	_complete = _main.get_node("CompleteScreen") as CanvasLayer


func _physics_process(_delta: float) -> bool:
	_tick += 1
	if _tick > TIMEOUT:
		printerr("test_ending: timed out in phase ", _phase)
		quit(1)
		return true

	if _tick == 1:
		_mgr = _main.get_node("RoomManager") as RoomManager
		# Rest at the camp first, so the restart has a respawn point to clear
		# that is not already room 1.
		_mgr.set_respawn("res://scenes/rooms/khan1_04_camp.tscn", Vector2(640, 484))
		_mgr.enter_room(DEN, &"EntryWest")
		_arena = _mgr.get_current_room()
		_lion = _arena.get_node("Lion") as Lion
		return false

	match _phase:
		"fight":
			_run_fight()
		"door":
			_run_door()
		"restart":
			_run_restart()
		"relive":
			_run_relive()
		"done":
			quit(Support.report("test_ending", _failures))
			return true
	return false


func _run_fight() -> void:
	if _tick == 5:
		_player.respawn(ON_TRIGGER)
		return
	if _tick == 20:
		_failures += 0 if Support.exact("east door locked before the fight ends",
				(_arena.get_node("EastDoor") as Door).locked, true) else 1
		return
	# Straight to phase 2: the fight itself is test_lion's job.
	if _tick > 20 and not _lion.in_phase_two():
		_lion.take_damage(2, Vector2.ZERO, null)
		return
	if _arena.is_finished():
		_failures += 0 if Support.exact("east door unlocked after the fight",
				(_arena.get_node("EastDoor") as Door).locked, false) else 1
		_player.respawn(IN_EAST_DOOR)
		_phase = "door"
		_phase_start = _tick


func _run_door() -> void:
	if _tick < _phase_start + 60 and not _complete.is_showing():
		return
	_failures += 0 if Support.exact("the east door ends the slice",
			_complete.is_showing(), true) else 1
	_phase = "restart"
	_phase_start = _tick


func _run_restart() -> void:
	var at: int = _tick - _phase_start
	if at == 5:
		Input.action_press("jump")
		return
	if at == 6:
		Input.action_release("jump")
		return
	if at < 40:
		return

	_failures += 0 if Support.exact("the screen closes", _complete.is_showing(), false) else 1
	_failures += 0 if Support.exact("restarts in room 1",
			_mgr.get_current_room_path().get_file(), MARSH.get_file()) else 1
	_failures += 0 if Support.near("restarts on the spawn x",
			_player.global_position.x, MARSH_SPAWN.x) else 1
	_failures += 0 if Support.near("restarts on the spawn y",
			_player.global_position.y, MARSH_SPAWN.y) else 1
	_failures += 0 if Support.exact("restarts on full health",
			_player.health, _player.max_health) else 1
	_failures += 0 if Support.exact("control is his again", _player.is_pinned(), false) else 1
	_failures += 0 if Support.exact("respawn point reset to room 1",
			_mgr.get_respawn_room().get_file(), MARSH.get_file()) else 1
	_failures += 0 if Support.exact("respawn position reset",
			_mgr.get_respawn_position(), MARSH_SPAWN) else 1

	_mgr.enter_room(DEN, &"EntryWest")
	_phase = "relive"
	_phase_start = _tick


func _run_relive() -> void:
	if _tick != _phase_start + 5:
		return
	var lion: Lion = _mgr.get_current_room().get_node("Lion") as Lion
	_failures += 0 if Support.exact("the Lion is alive again", lion.health, lion.max_health) else 1
	_failures += 0 if Support.exact("and asleep again", lion.is_awake(), false) else 1
	_failures += 0 if Support.exact("the den's east door is locked again",
			(_mgr.get_current_room().get_node("EastDoor") as Door).locked, true) else 1
	_phase = "done"
