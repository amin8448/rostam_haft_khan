extends SceneTree

## The end of the slice, design doc section 8, and the verse cutscene that now
## fills it.
##
## Expected:
##   when the fight ends   the slot starts, Rostam is pinned, both doors unlock
##   left alone            all eight beyts play, in the order of the verses file
##   at the end            the title card, and control back
##   jump on that card     back to room 1's spawn on full health
##   the respawn point     reset to room 1, whatever it was before
##   room 5 afterwards     the Lion alive again, with no save system involved
##   a tap of jump         on to the next beyt without waiting out the beat
##   holding jump          straight to the title card, part-way through
##
## The fight is skipped rather than fought: what is under test here is what
## happens after it, and test_lion already covers the fight itself.

const Support = preload("res://tests/test_support.gd")

## The whole ending is about 26 seconds of verses, so this allows twice over.
const TIMEOUT: int = 4200
const DEN: String = "res://scenes/rooms/khan1_05_den.tscn"
const MARSH: String = "res://scenes/rooms/khan1_01_marsh.tscn"
const MARSH_SPAWN: Vector2 = Vector2(144, 612)
const ON_TRIGGER: Vector2 = Vector2(380, 548)
const VERSES: String = "res://assets/verses/khan1.tres"
## Long enough to count as a hold at the default half second, and then some.
const HOLD_TICKS: int = 45

var _main: Node
var _mgr: RoomManager
var _arena: Room
var _lion: Lion
var _player: Rostam
var _complete: CanvasLayer
var _ending: VerseCutscene
var _tick: int = 0
var _failures: int = 0

var _phase: String = "fight"
var _phase_start: int = 0
var _expected_order: String = ""
var _hold_start: int = -1
var _tap_at: int = -1


func _initialize() -> void:
	_main = (load("res://scenes/world/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_player = _main.get_node("Rostam") as Rostam
	_complete = _main.get_node("CompleteScreen") as CanvasLayer

	var verses: VerseSet = load(VERSES) as VerseSet
	var order: Array[int] = []
	for i in verses.size():
		order.append(i)
	_expected_order = str(order)


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
		_enter_den()
		return false

	match _phase:
		"fight":
			_run_fight()
		"verses":
			_run_verses()
		"restart":
			_run_restart()
		"relive":
			_run_relive()
		"skip":
			_run_skip()
		"done":
			quit(Support.report("test_ending", _failures))
			return true
	return false


func _run_fight() -> void:
	if _tick == _phase_start + 5:
		_player.respawn(ON_TRIGGER)
		return
	if _tick == _phase_start + 20:
		_failures += 0 if Support.exact("east door locked before the fight ends",
				(_arena.get_node("EastDoor") as Door).locked, true) else 1
		return
	# Straight to phase 2: the fight itself is test_lion's job.
	if _tick > _phase_start + 20 and not _lion.in_phase_two():
		_lion.take_damage(2, Vector2.ZERO, null)
		return
	if not _arena.is_finished():
		return

	_ending = _arena.get_ending() as VerseCutscene
	_failures += 0 if Support.exact("the ending starts when the fight does",
			_ending != null and _ending.is_playing(), true) else 1
	_failures += 0 if Support.exact("Rostam is pinned for it",
			_player.is_pinned(), true) else 1
	_failures += 0 if Support.exact("west door unlocked anyway",
			(_arena.get_node("WestDoor") as Door).locked, false) else 1
	_failures += 0 if Support.exact("east door unlocked anyway",
			(_arena.get_node("EastDoor") as Door).locked, false) else 1
	_begin("verses")


## Left alone, it plays itself out and ends on the title card.
func _run_verses() -> void:
	if _ending != null and _ending.is_playing():
		return

	_failures += 0 if Support.exact("every beyt played, in order",
			str(_ending.get_played_indices()), _expected_order) else 1
	_failures += 0 if Support.exact("it ends on the title card",
			_complete.is_showing(), true) else 1
	_failures += 0 if Support.exact("control comes back on the card",
			_player.is_pinned(), false) else 1
	_begin("restart")


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

	_failures += 0 if Support.exact("the card closes", _complete.is_showing(), false) else 1
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

	_enter_den()
	_phase = "relive"


func _run_relive() -> void:
	if _tick != _phase_start + 5:
		return
	_failures += 0 if Support.exact("the Lion is alive again", _lion.health, _lion.max_health) else 1
	_failures += 0 if Support.exact("and asleep again", _lion.is_awake(), false) else 1
	_failures += 0 if Support.exact("the den's east door is locked again",
			(_arena.get_node("EastDoor") as Door).locked, true) else 1
	_player.respawn(ON_TRIGGER)
	_begin("skip")


## Holding jump goes straight to the title card. Never trap the player in a
## cutscene, however long the khan's verses are.
func _run_skip() -> void:
	var at: int = _tick - _phase_start
	if _hold_start < 0:
		if at > 20 and not _lion.in_phase_two():
			_lion.take_damage(2, Vector2.ZERO, null)
			return
		_ending = _arena.get_ending() as VerseCutscene
		# One beyt in, so there is something left to skip past.
		if _ending == null or _ending.get_played_indices().is_empty():
			return
		if _tap_at < 0:
			Input.action_press("jump")
			_tap_at = _tick
			return
		if _tick == _tap_at + 1:
			Input.action_release("jump")
			return
		if _tick < _tap_at + 4:
			return
		# A beat holds for three seconds; the tap moved on inside four ticks.
		_failures += 0 if Support.exact("a tap advances to the next beyt",
				_ending.get_played_indices().size(), 2) else 1
		Input.action_press("jump")
		_hold_start = _tick
		return

	if _tick < _hold_start + HOLD_TICKS:
		return
	Input.action_release("jump")

	_failures += 0 if Support.exact("holding jump ends it",
			_ending.is_playing(), false) else 1
	_failures += 0 if Support.exact("holding jump reaches the title card",
			_complete.is_showing(), true) else 1
	_failures += 0 if Support.at_most("and skipped the rest",
			float(_ending.get_played_indices().size()), 7.0) else 1
	_failures += 0 if Support.exact("control comes back on the skip",
			_player.is_pinned(), false) else 1
	_phase = "done"


func _enter_den() -> void:
	_mgr.enter_room(DEN, &"EntryWest")
	_arena = _mgr.get_current_room()
	_lion = _arena.get_node("Lion") as Lion
	_begin("fight")


func _begin(next: String) -> void:
	_phase = next
	_phase_start = _tick
