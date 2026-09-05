extends SceneTree

## Resting at the camp, design doc section 7 and future_systems.md item 1.
##
## Expected:
##   before resting        respawn is still room 1's spawn
##   resting               health 2 back to 5
##   resting               respawn becomes this grazing ground, in room 4
##   dying after resting   respawn at the camp, not back at room 1
##
## Nothing here names the camp except the room it warps to. The respawn is a
## room path and a position, so a second grazing ground would exercise exactly
## the same code.

const Support = preload("res://tests/test_support.gd")

const TIMEOUT: int = 900
const CAMP: String = "res://scenes/rooms/khan1_04_camp.tscn"
const MARSH: String = "res://scenes/rooms/khan1_01_marsh.tscn"
const REST_POINT: Vector2 = Vector2(640, 484)

var _main: Node
var _mgr: RoomManager
var _player: Rostam
var _ground: GrazingGround
var _tick: int = 0
var _failures: int = 0

var _phase: String = "arrive"
var _phase_start: int = 0
var _death_tick: int = -1


func _initialize() -> void:
	_main = (load("res://scenes/world/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_player = _main.get_node("Rostam") as Rostam


func _physics_process(_delta: float) -> bool:
	_tick += 1
	if _tick > TIMEOUT:
		printerr("test_grazing_ground: timed out in phase ", _phase)
		quit(1)
		return true

	if _tick == 1:
		_mgr = _main.get_node("RoomManager") as RoomManager
		_failures += 0 if Support.exact("starts respawning at room 1",
				_mgr.get_respawn_room().get_file(), MARSH.get_file()) else 1
		_mgr.enter_room(CAMP, &"EntryWest")
		_ground = _mgr.get_current_room().get_node("GrazingGround") as GrazingGround
		return false

	match _phase:
		"arrive":
			_run_arrive()
		"rest":
			_run_rest()
		"kill":
			_run_kill()
		"death":
			_run_death()
		"done":
			quit(Support.report("test_grazing_ground", _failures))
			return true
	return false


func _run_arrive() -> void:
	if _tick == 5:
		_player.respawn(_ground.get_rest_position())
		# Down to 2 of 5, so a refill is visible rather than a no-op.
		_player.take_damage(3, Vector2.ZERO, null)
	elif _tick == 20:
		_failures += 0 if Support.exact("health before resting", _player.health, 2) else 1
		_failures += 0 if Support.exact("standing on the grazing ground",
				_ground.is_player_inside(), true) else 1
		_phase = "rest"
		_phase_start = _tick


func _run_rest() -> void:
	var at: int = _tick - _phase_start
	if at == 2:
		Input.action_press("interact")
	elif at == 3:
		Input.action_release("interact")
	elif at == 10:
		_failures += 0 if Support.exact("resting refills health",
				_player.health, _player.max_health) else 1
		_failures += 0 if Support.exact("respawn room becomes the camp",
				_mgr.get_respawn_room().get_file(), CAMP.get_file()) else 1
		_failures += 0 if Support.near("respawn x is the rest point",
				_mgr.get_respawn_position().x, REST_POINT.x) else 1
		_failures += 0 if Support.near("respawn y is the rest point",
				_mgr.get_respawn_position().y, REST_POINT.y) else 1

		# Move clear of the ground, so the respawn is what puts him back rather
		# than him never having left.
		_player.global_position = Vector2(300, 484)
		_phase = "kill"


## The damage that set up the refill left 0.8 s of invulnerability behind, and a
## killing blow inside that window is simply refused. Wait it out.
func _run_kill() -> void:
	if _player.is_invulnerable():
		return
	_player.take_damage(_player.max_health, Vector2.ZERO, null)
	_failures += 0 if Support.exact("the killing blow landed", _player.is_dead(), true) else 1
	_death_tick = _tick
	_phase = "death"


func _run_death() -> void:
	if _tick != _death_tick + 60:
		return
	_failures += 0 if Support.exact("dying respawns in the camp",
			_mgr.get_current_room_path().get_file(), CAMP.get_file()) else 1
	_failures += 0 if Support.near("respawns on the grazing ground x",
			_player.global_position.x, REST_POINT.x) else 1
	_failures += 0 if Support.near("respawns on the grazing ground y",
			_player.global_position.y, REST_POINT.y) else 1
	_failures += 0 if Support.exact("respawn health", _player.health, _player.max_health) else 1
	_phase = "done"
