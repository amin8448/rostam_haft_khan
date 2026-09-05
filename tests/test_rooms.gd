extends SceneTree

## Room transitions, design doc section 7.
##
## Expected:
##   through room 1's east door   arrive on room 2's EntryWest marker
##   camera limits                room 2's bounds, on the first tick after
##   camera position              already on its target, not smoothing across
##                                from where it was in room 1
##   velocity                     carried through the door
##   dying in room 2              respawn at room 1's spawn, the last respawn
##                                point, since nothing has been rested at
##
## Velocity is checked by releasing the movement key the instant the door fires.
## If it were not carried, twelve ticks of fade would have braked him to a stop;
## carried, he arrives at run speed less one tick of deceleration.

const Support = preload("res://tests/test_support.gd")

const TIMEOUT: int = 1200
const REEDS: String = "res://scenes/rooms/khan1_02_reeds.tscn"
const REEDS_ENTRY: Vector2 = Vector2(160, 740)
const REEDS_BOUNDS: Rect2 = Rect2(0, 0, 1280, 960)
const MARSH_SPAWN: Vector2 = Vector2(144, 612)
## Just left of room 1's east door, on the pocket of ground beside the wall.
const BEFORE_DOOR: Vector2 = Vector2(1786, 612)
## Half the headless viewport, which is 64x64 whatever the project says.
const HALF_VIEW: float = 32.0

var _main: Node
var _mgr: RoomManager
var _player: Rostam
var _camera: GameCamera
var _tick: int = 0
var _failures: int = 0

var _phase: String = "walk"
var _swap_tick: int = -1
var _vel_at_door: Vector2 = Vector2.ZERO
var _door_fired: bool = false
var _death_tick: int = -1


func _initialize() -> void:
	_main = (load("res://scenes/world/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_player = _main.get_node("Rostam") as Rostam
	_camera = _main.get_node("GameCamera") as GameCamera


func _physics_process(_delta: float) -> bool:
	_tick += 1
	if _tick > TIMEOUT:
		printerr("test_rooms: timed out in phase ", _phase)
		quit(1)
		return true

	if _tick == 1:
		_mgr = _main.get_node("RoomManager") as RoomManager
		_mgr.room_entered.connect(_on_room_entered)
		var door: Door = _mgr.get_current_room().get_node("EastDoor") as Door
		door.entered.connect(_on_door)
		return false

	match _phase:
		"walk":
			_run_walk()
		"arrived":
			_run_arrived()
		"death":
			_run_death()
		"done":
			quit(Support.report("test_rooms", _failures))
			return true
	return false


func _on_door(_door: Door) -> void:
	# Let go the moment it fires, so anything left in velocity afterwards can
	# only have been carried rather than freshly pressed.
	_vel_at_door = _player.velocity
	_door_fired = true
	Input.action_release("move_right")


func _on_room_entered(room: Room) -> void:
	if _mgr.get_current_room_path() == REEDS and _swap_tick < 0:
		_swap_tick = _tick
		_phase = "arrived"
	elif _death_tick > 0 and room != null:
		_phase = "death"


func _run_walk() -> void:
	if _tick == 5:
		_player.respawn(BEFORE_DOOR)
	elif _tick > 10 and not _door_fired:
		# Stop pressing once the door fires, or the key is still held through
		# the fade and he simply runs off again after respawning.
		Input.action_press("move_right")


func _run_arrived() -> void:
	# Two ticks after the swap. The snap itself happens in the fade's tween
	# callback, on an idle frame, and get_screen_center_position() is a cached
	# value that only refreshes on the camera's next process step. One tick is
	# too early and reads the previous room's centre. Two is enough, and still
	# far too soon for smoothing to have covered the 1028 px between rooms: at
	# speed 7 it would have moved about 210 px by now, not all of it.
	if _tick != _swap_tick + 2:
		return

	_failures += 0 if Support.near("arrives on the entry marker x",
			_player.global_position.x, REEDS_ENTRY.x) else 1
	_failures += 0 if Support.near("arrives on the entry marker y",
			_player.global_position.y, REEDS_ENTRY.y) else 1

	_failures += 0 if Support.exact("limit_left", _camera.limit_left, int(REEDS_BOUNDS.position.x)) else 1
	_failures += 0 if Support.exact("limit_top", _camera.limit_top, int(REEDS_BOUNDS.position.y)) else 1
	_failures += 0 if Support.exact("limit_right", _camera.limit_right, int(REEDS_BOUNDS.end.x)) else 1
	_failures += 0 if Support.exact("limit_bottom", _camera.limit_bottom, int(REEDS_BOUNDS.end.y)) else 1

	# Snapped: the drawn centre is already on the focus point. Had it smoothed
	# from room 1 it would still be hundreds of pixels to the right.
	var focus: Vector2 = _camera.global_position
	var expected: Vector2 = Vector2(
		clampf(focus.x, REEDS_BOUNDS.position.x + HALF_VIEW, REEDS_BOUNDS.end.x - HALF_VIEW),
		clampf(focus.y, REEDS_BOUNDS.position.y + HALF_VIEW, REEDS_BOUNDS.end.y - HALF_VIEW))
	var centre: Vector2 = _camera.get_screen_center_position()
	# 20 px, not 0. The camera is built to lag slightly, and Rostam has carried
	# his velocity a few pixels by now, so a couple of pixels of trail is the
	# correct behaviour. What this rules out is smoothing across the 1028 px
	# between the two rooms, which would read as about 1035 px here.
	_failures += 0 if Support.at_most("camera snapped, did not smooth across",
			centre.distance_to(expected), 20.0) else 1

	_failures += 0 if Support.at_least("velocity carried through the door",
			_player.velocity.x, 200.0, "px/s") else 1
	_failures += 0 if Support.at_least("velocity at the door was full speed",
			_vel_at_door.x, 300.0, "px/s") else 1

	_failures += 0 if Support.exact("respawn point untouched by travel",
			_mgr.get_respawn_position(), MARSH_SPAWN) else 1

	_death_tick = _tick
	_player.take_damage(_player.max_health, Vector2.ZERO, null)
	_phase = "death"


func _run_death() -> void:
	# He is killed mid-transition on purpose: the death has to wait for the
	# door's fade to finish and then run its own, so this allows for both.
	if _tick != _death_tick + 90:
		return

	_failures += 0 if Support.exact("dying in room 2 sends him back to room 1",
			_mgr.get_current_room_path().get_file(), "khan1_01_marsh.tscn") else 1
	_failures += 0 if Support.near("respawn x", _player.global_position.x, MARSH_SPAWN.x) else 1
	_failures += 0 if Support.near("respawn y", _player.global_position.y, MARSH_SPAWN.y) else 1
	_failures += 0 if Support.exact("respawn health", _player.health, _player.max_health) else 1
	_phase = "done"
