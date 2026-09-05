extends SceneTree

## The Jackal, design doc section 6.
##
## Expected:
##   patrols P6 (x 1696..1824)   stays on the platform, y never changes
##   turns at a ledge            at least twice in five seconds
##   turns at a wall             before touching it, so the raycast turned it
##                               rather than the collision shape stopping it
##   telegraph                   0.4 s from noticing him to the lunge
##   Rostam level and near       lunges
##   Rostam on the platform above  does not lunge, 112 px is not "roughly level"
##   contact                     exactly 1 damage
##   three sword hits            3 health to 0
##   Room.reset()                back at its start with full health
##
## Two phases pin the Jackal down by zeroing its own exports: the wall test sets
## detect_range to 0 so Rostam standing at the room spawn nearby cannot start a
## lunge instead, and the sword phase sets patrol_speed to 0 so it holds still
## while being hit. Both are stated where they happen.

const Support = preload("res://tests/test_support.gd")
const JACKAL_SCENE: PackedScene = preload("res://scenes/enemies/jackal.tscn")

const TIMEOUT: int = 2400
const HOME: Vector2 = Vector2(1760, 564)
## Standing on P6 with it, level.
const ON_P6: Vector2 = Vector2(1700, 548)
## Standing on P5, one platform up and 112 px above it.
const ON_P5: Vector2 = Vector2(1600, 452)
## Clear ground, well away from both the room's Jackal at x=1760 and the
## Vulture at x=1392, and away from where the wall-test Jackal walks.
const FAR_AWAY: Vector2 = Vector2(1000, 612)

var _jackal: Jackal
var _wall_jackal: Jackal
var _room: Node2D
var _player: Rostam
var _tick: int = 0
var _failures: int = 0

var _phase: String = "patrol"
var _phase_start: int = 0
var _min_x: float = 1e9
var _max_x: float = -1e9
var _y_drift: float = 0.0
var _turns: int = 0
var _last_facing: int = 0
var _wall_min_x: float = 1e9
var _wall_turned: bool = false
var _telegraph_at: int = -1
var _lunge_at: int = -1
var _health_before: int = 0
var _contact_loss: int = -1


func _initialize() -> void:
	var main: Node = (load("res://scenes/world/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	_player = main.get_node("Rostam") as Rostam
	_room = main.get_node("Room") as Node2D
	_jackal = _room.get_node("Jackal") as Jackal


func _physics_process(_delta: float) -> bool:
	_tick += 1
	if _tick > TIMEOUT:
		printerr("test_jackal: timed out in phase ", _phase)
		quit(1)
		return true

	if _tick == 3:
		_player.global_position = FAR_AWAY
		_last_facing = _jackal.get_facing()
		_phase_start = _tick
		return false

	match _phase:
		"patrol":
			_run_patrol()
		"wall":
			_run_wall()
		"above":
			_run_above()
		"telegraph":
			_run_telegraph()
		"contact":
			_run_contact()
		"sword":
			_run_sword()
		"reset":
			_run_reset()
		"done":
			quit(Support.report("test_jackal", _failures))
			return true
	return false


func _run_patrol() -> void:
	_min_x = minf(_min_x, _jackal.global_position.x)
	_max_x = maxf(_max_x, _jackal.global_position.x)
	_y_drift = maxf(_y_drift, absf(_jackal.global_position.y - HOME.y))
	if _jackal.get_facing() != _last_facing:
		_last_facing = _jackal.get_facing()
		_turns += 1

	if _tick != _phase_start + 300:
		return

	# On P6, so the body (half-width 20) must stay inside 1696..1824.
	_failures += 0 if Support.at_least("patrol stays off the left drop", _min_x, 1716.0) else 1
	_failures += 0 if Support.at_most("patrol stays off the right drop", _max_x, 1804.0) else 1
	_failures += 0 if Support.at_most("never falls: y drift", _y_drift, 2.0) else 1
	_failures += 0 if Support.at_least("ledge turns in 5 s", float(_turns), 2.0, "turns") else 1

	# A second Jackal on the open ground, walking into the room's left wall.
	# detect_range 0 so Rostam at the spawn does not make it lunge instead.
	_wall_jackal = JACKAL_SCENE.instantiate() as Jackal
	_wall_jackal.position = Vector2(200, 628)
	_wall_jackal.start_facing = -1
	_wall_jackal.detect_range = 0.0
	_wall_jackal.level_tolerance = 0.0
	_room.add_child(_wall_jackal)
	_phase = "wall"
	_phase_start = _tick


func _run_wall() -> void:
	_wall_min_x = minf(_wall_min_x, _wall_jackal.global_position.x)
	if _wall_jackal.get_facing() == 1:
		_wall_turned = true

	if _tick != _phase_start + 200:
		return

	_failures += 0 if Support.exact("turns at a wall", _wall_turned, true) else 1
	# Inner face of the left wall is x=64 and the body is 40 wide, so a Jackal
	# stopped by its collision shape would sit at 84. Turning above that means
	# the wall cast turned it before it ever touched.
	_failures += 0 if Support.at_least("turned before touching the wall", _wall_min_x, 86.0) else 1
	_wall_jackal.queue_free()

	_player.respawn(ON_P5)
	_phase = "above"
	_phase_start = _tick


func _run_above() -> void:
	# 160 px away horizontally, well inside detect_range, but 112 px above.
	if _jackal.state != Jackal.State.PATROL:
		_failures += 0 if Support.exact("no lunge at someone above", _jackal.state,
				Jackal.State.PATROL) else 1
		_phase = "telegraph"
		return
	if _tick != _phase_start + 150:
		return

	_failures += 0 if Support.exact("no lunge at someone above", _jackal.state,
			Jackal.State.PATROL) else 1
	_player.respawn(ON_P6)
	_phase = "telegraph"
	_phase_start = _tick


func _run_telegraph() -> void:
	if _telegraph_at < 0 and _jackal.state == Jackal.State.TELEGRAPH:
		_telegraph_at = _tick
	elif _telegraph_at > 0 and _lunge_at < 0 and _jackal.state == Jackal.State.LUNGE:
		_lunge_at = _tick
		_failures += 0 if Support.exact("lunges when level and near", true, true) else 1
		_failures += 0 if Support.near_time("telegraph length",
				float(_lunge_at - _telegraph_at) / 60.0, _jackal.telegraph_time) else 1

		_player.respawn(FAR_AWAY)
		_health_before = _player.health
		_phase = "contact"
		_phase_start = _tick
		return

	if _tick > _phase_start + 200:
		_failures += 0 if Support.exact("lunges when level and near", false, true) else 1
		_phase = "contact"
		_phase_start = _tick


func _run_contact() -> void:
	# Wait out any invulnerability from the lunge, then walk into it.
	if _tick == _phase_start + 60:
		_player.respawn(_jackal.global_position)
		_health_before = _player.health
	elif _tick > _phase_start + 60 and _contact_loss < 0 and _player.health < _health_before:
		_contact_loss = _health_before - _player.health
	elif _tick == _phase_start + 120:
		_failures += 0 if Support.exact("contact costs exactly 1", _contact_loss, 1) else 1

		_phase = "sword"
		_phase_start = _tick


func _run_sword() -> void:
	var at: int = _tick - _phase_start
	if at == 1:
		# Pin it. Standing on it during the contact phase left it mid-lunge, and
		# patrol_speed does not govern a lunge, so it has to be put back into
		# PATROL and stopped from noticing him again. What is under test here is
		# that three swings kill it, not whether Rostam can chase it.
		_jackal.state = Jackal.State.PATROL
		_jackal.patrol_speed = 0.0
		_jackal.detect_range = 0.0
		_jackal.level_tolerance = 0.0
		_jackal.velocity = Vector2.ZERO
		return
	if at == 5:
		# respawn() faces him right, so no movement input is needed to turn him.
		# 20 px, not 40: each hit knocks the Jackal about 22 px clear and only the
		# finisher steps after it, so from 40 px the second swing already whiffs.
		# This phase checks that three swings kill it, not the reach economics.
		_player.respawn(Vector2(_jackal.global_position.x - 20.0, 548.0))
		return
	_tap(20)
	_tap(45)
	_tap(70)
	if at != 110:
		return

	_failures += 0 if Support.exact("three sword hits kill it", _jackal.health, 0) else 1
	_failures += 0 if Support.exact("dead Jackal is gone", _jackal.is_alive(), false) else 1
	_player.respawn(FAR_AWAY)
	_room.reset()
	_phase = "reset"
	_phase_start = _tick


func _run_reset() -> void:
	if _tick != _phase_start + 10:
		return
	_failures += 0 if Support.exact("reset restores health", _jackal.health, _jackal.max_health) else 1
	_failures += 0 if Support.exact("reset restores life", _jackal.is_alive(), true) else 1
	_failures += 0 if Support.near("reset restores x", _jackal.global_position.x, HOME.x) else 1
	_failures += 0 if Support.near("reset restores y", _jackal.global_position.y, HOME.y) else 1
	_failures += 0 if Support.exact("reset restores patrol", _jackal.state,
			Jackal.State.PATROL) else 1
	_phase = "done"


func _tap(at: int) -> void:
	if _tick == _phase_start + at:
		Input.action_press("attack")
	elif _tick == _phase_start + at + 1:
		Input.action_release("attack")
