extends SceneTree

## One shared check over every room in the khan, loaded through the real
## RoomManager rather than instantiated on the side, so this exercises the path
## the game actually uses.
##
## Expected, per room:
##   loads with bounds at least the viewport, or the camera limits fight
##   every Jackal in it patrols for five seconds without its y changing
##
## Rostam is parked on each room's spawn marker, which is at the west end and
## well outside any Jackal's 200 px notice range, so nothing lunges and what is
## measured is patrolling rather than an encounter.

const Support = preload("res://tests/test_support.gd")

const WATCH_TICKS: int = 300
const MIN_BOUNDS: Vector2 = Vector2(1152, 648)
const ROOM_PATHS: Array[String] = [
	"res://scenes/rooms/khan1_01_marsh.tscn",
	"res://scenes/rooms/khan1_02_reeds.tscn",
	"res://scenes/rooms/khan1_03_cliffs.tscn",
	"res://scenes/rooms/khan1_04_camp.tscn",
	"res://scenes/rooms/khan1_05_den.tscn",
]

var _main: Node
var _mgr: RoomManager
var _tick: int = 0
var _failures: int = 0

var _index: int = -1
var _watch_until: int = 0
var _jackals: Array[Jackal] = []
var _start_y: Array[float] = []
var _drift: Array[float] = []


func _initialize() -> void:
	_main = (load("res://scenes/world/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _physics_process(_delta: float) -> bool:
	_tick += 1
	if _tick == 1:
		_mgr = _main.get_node("RoomManager") as RoomManager
		_next_room()
		return false

	if _tick < _watch_until:
		for i in _jackals.size():
			_drift[i] = maxf(_drift[i], absf(_jackals[i].global_position.y - _start_y[i]))
		return false

	_report()
	if _index + 1 >= ROOM_PATHS.size():
		quit(Support.report("test_all_rooms", _failures))
		return true
	_next_room()
	return false


func _next_room() -> void:
	_index += 1
	_mgr.enter_room(ROOM_PATHS[_index], &"PlayerSpawn")
	var room: Room = _mgr.get_current_room()

	_jackals.clear()
	_start_y.clear()
	_drift.clear()
	if room != null:
		for child in room.get_children():
			if child is Jackal:
				_jackals.append(child as Jackal)
				_start_y.append((child as Jackal).global_position.y)
				_drift.append(0.0)
	_watch_until = _tick + WATCH_TICKS


func _report() -> void:
	var name: String = ROOM_PATHS[_index].get_file().get_basename()
	var room: Room = _mgr.get_current_room()
	if room == null:
		_failures += 0 if Support.exact("%s loads" % name, false, true) else 1
		return

	_failures += 0 if Support.at_least("%s bounds width" % name,
			room.bounds.size.x, MIN_BOUNDS.x) else 1
	_failures += 0 if Support.at_least("%s bounds height" % name,
			room.bounds.size.y, MIN_BOUNDS.y) else 1

	var worst: float = 0.0
	for value in _drift:
		worst = maxf(worst, value)
	_failures += 0 if Support.at_most("%s: %d Jackal(s) stayed up" % [name, _jackals.size()],
			worst, 2.0) else 1
