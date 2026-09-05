extends SceneTree

## The Lion, design doc section 8.
##
## Expected:
##   crossing the trigger      fight starts, west door locks, Lion wakes
##   Rostam close              swipe
##   Rostam at medium range    pounce
##   telegraph lengths         the exported ones, within a physics tick
##   the pounce                lands near where Rostam was when it launched
##   roar                      inside its interval
##   the mace                  damages it, and shoves Rostam back
##   below a quarter health    phase 2
##   the sequence              Lion at 0, Rostam alive with control back
##   afterwards                both doors unlocked
##
## The approach window is pinned to a fifth of a second and the roar pushed out
## of the way for most of this, so what is measured is the attack under test
## rather than whichever thing the loop happened to pick.

const Support = preload("res://tests/test_support.gd")

const TIMEOUT: int = 3000
const DEN: String = "res://scenes/rooms/khan1_05_den.tscn"
## On the trigger line, not past it: respawning teleports, and a body that is
## put down beyond an area never enters it.
const ON_TRIGGER: Vector2 = Vector2(380, 548)

var _main: Node
var _mgr: RoomManager
var _arena: Room
var _lion: Lion
var _player: Rostam
var _tick: int = 0
var _failures: int = 0

var _phase: String = "start"
var _phase_start: int = 0
var _state_at: int = -1
var _telegraph_at: int = -1
var _pounce_from: float = 0.0
var _lion_hp_before: int = 0
var _recoil: float = 0.0
var _roar_seen: bool = false
var _armed: bool = false


func _initialize() -> void:
	_main = (load("res://scenes/world/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_player = _main.get_node("Rostam") as Rostam


func _physics_process(_delta: float) -> bool:
	_tick += 1
	if _tick > TIMEOUT:
		printerr("test_lion: timed out in phase ", _phase)
		quit(1)
		return true

	if _tick == 1:
		_mgr = _main.get_node("RoomManager") as RoomManager
		_mgr.enter_room(DEN, &"EntryWest")
		_arena = _mgr.get_current_room()
		_lion = _arena.get_node("Lion") as Lion
		return false

	match _phase:
		"start":
			_run_start()
		"swipe":
			_run_swipe()
		"pounce":
			_run_pounce()
		"roar":
			_run_roar()
		"mace":
			_run_mace()
		"phase_two":
			_run_phase_two()
		"sequence":
			_run_sequence()
		"done":
			quit(Support.report("test_lion", _failures))
			return true
	return false


func _run_start() -> void:
	if _tick == 5:
		_failures += 0 if Support.exact("asleep before the trigger", _lion.is_awake(), false) else 1
		_player.respawn(ON_TRIGGER)
	elif _tick == 20:
		_failures += 0 if Support.exact("crossing the trigger starts the fight",
				_arena.is_fighting(), true) else 1
		_failures += 0 if Support.exact("the Lion wakes", _lion.is_awake(), true) else 1
		_failures += 0 if Support.exact("west door locks behind him",
				(_arena.get_node("WestDoor") as Door).locked, true) else 1

		# Short approach and no roar, so the loop commits to the attack under
		# test rather than to whatever came round next.
		_lion.approach_min = 0.2
		_lion.approach_max = 0.2
		_lion.roar_interval = 60.0
		_begin("swipe")


func _run_swipe() -> void:
	# Well inside swipe_range of 150.
	if _tick == _phase_start + 1:
		_player.respawn(Vector2(_lion.global_position.x - 90.0, 548.0))
		return
	if not _arm():
		return
	if _lion.state == Lion.State.TELEGRAPH and _telegraph_at < 0:
		_telegraph_at = _tick
	elif _lion.state == Lion.State.SWIPE and _telegraph_at > 0:
		_failures += 0 if Support.exact("swipes when Rostam is close", true, true) else 1
		_failures += 0 if Support.near_time("swipe telegraph",
				float(_tick - _telegraph_at) / 60.0, _lion.swipe_telegraph) else 1
		_begin("pounce")
	elif _lion.state == Lion.State.POUNCE:
		_failures += 0 if Support.exact("swipes when Rostam is close", false, true) else 1
		_begin("pounce")


func _run_pounce() -> void:
	# Outside swipe_range, inside pounce_range of 400.
	if _tick == _phase_start + 1:
		_player.respawn(Vector2(_lion.global_position.x - 300.0, 548.0))
		return
	# Wait for the previous attack to finish, or the state left over from the
	# swipe phase is read as this phase's choice.
	if not _arm():
		return
	if _lion.state == Lion.State.TELEGRAPH and _telegraph_at < 0:
		_telegraph_at = _tick
	elif _lion.state == Lion.State.POUNCE and _state_at < 0:
		_state_at = _tick
		_pounce_from = _player.global_position.x
		_failures += 0 if Support.exact("pounces at medium range", true, true) else 1
		_failures += 0 if Support.near_time("pounce telegraph",
				float(_tick - _telegraph_at) / 60.0, _lion.pounce_telegraph) else 1
	elif _state_at > 0 and _lion.state == Lion.State.RECOVER:
		# It commits to where he was, so this is measured against that, not
		# against where he has since ended up.
		_failures += 0 if Support.at_most("pounce lands near where he was",
				absf(_lion.global_position.x - _pounce_from), 80.0) else 1
		_begin("roar")
	elif _lion.state == Lion.State.SWIPE and _state_at < 0:
		_failures += 0 if Support.exact("pounces at medium range", false, true) else 1
		_begin("roar")


func _run_roar() -> void:
	if _tick == _phase_start + 1:
		# The roar timer is set when it wakes, so shortening the interval alone
		# changes nothing: it has to be woken again to pick the new one up.
		_lion.reset()
		_lion.roar_interval = 2.0
		_lion.approach_min = 0.2
		_lion.approach_max = 0.2
		_lion.wake()
		# Out of range of both attacks, so it only walks and roars.
		_player.respawn(Vector2(_lion.global_position.x - 700.0, 548.0))
		return
	if _lion.state == Lion.State.ROAR:
		_roar_seen = true
	# The interval plus an attack's worth of slack, since a roar only lands
	# between attacks rather than interrupting one.
	if _tick < _phase_start + 240:
		return
	_failures += 0 if Support.exact("roars within its interval", _roar_seen, true) else 1
	_lion.roar_interval = 60.0
	_begin("mace")


func _run_mace() -> void:
	var at: int = _tick - _phase_start
	if at == 1:
		# Standing still but still hittable. hold() would do it, but hold() is
		# the sequence's freeze and makes it invulnerable, which is right there
		# and wrong here.
		_lion.roar_interval = 600.0
		_lion.walk_speed = 0.0
		_lion.approach_min = 600.0
		_lion.approach_max = 600.0
		_player.respawn(Vector2(_lion.global_position.x - 70.0, 548.0))
		_lion_hp_before = _lion.health
		return
	if at == 10:
		Input.action_press("attack")
		return
	if at == 11:
		Input.action_release("attack")
		return
	if at > 11 and at < 40:
		_recoil = minf(_recoil, _player.velocity.x)
		return
	if at != 40:
		return

	_failures += 0 if Support.exact("the mace damages the Lion",
			_lion_hp_before - _lion.health, 1) else 1
	# Facing right, so the recoil pushes him left.
	_failures += 0 if Support.at_most("hitting a boss recoils Rostam",
			_recoil, -100.0, "px/s") else 1
	_begin("phase_two")


func _run_phase_two() -> void:
	var threshold: int = int(float(_lion.max_health) * _lion.phase_two_fraction)
	if _lion.health > threshold and not _lion.in_phase_two():
		_lion.take_damage(1, Vector2.ZERO, null)
		return
	if _tick < _phase_start + 4:
		return

	_failures += 0 if Support.exact("phase 2 below a quarter health",
			_lion.in_phase_two(), true) else 1
	_failures += 0 if Support.at_most("phase 2 threshold", float(_lion.health),
			float(_lion.max_health) * 0.25) else 1
	_begin("sequence")


func _run_sequence() -> void:
	# The chain is a pin, a charge, an impact, a line and a beat: comfortably
	# under five seconds, and this allows nine.
	if _tick < _phase_start + 540 and not _arena.is_finished():
		return

	_failures += 0 if Support.exact("the sequence finishes", _arena.is_finished(), true) else 1
	_failures += 0 if Support.exact("the Lion ends at zero", _lion.health, 0) else 1
	_failures += 0 if Support.exact("Rostam survives it", _player.is_dead(), false) else 1
	_failures += 0 if Support.exact("control comes back", _player.is_pinned(), false) else 1
	_failures += 0 if Support.exact("Rakhsh stays in the arena",
			(_arena.get_node("Rakhsh") as Node2D).visible, true) else 1
	_failures += 0 if Support.exact("west door unlocked",
			(_arena.get_node("WestDoor") as Door).locked, false) else 1
	_failures += 0 if Support.exact("east door unlocked",
			(_arena.get_node("EastDoor") as Door).locked, false) else 1
	_phase = "done"


func _begin(next: String) -> void:
	_phase = next
	_phase_start = _tick
	_telegraph_at = -1
	_state_at = -1
	_armed = false


## True once the Lion is back to walking, so a phase never reads the state its
## predecessor left behind.
func _arm() -> bool:
	if _armed:
		return true
	if _lion.state == Lion.State.APPROACH:
		_armed = true
	return false
