extends SceneTree

## Rostam taking damage, dying and respawning, design doc section 5.
##
## Expected:
##   first contact with the hazard   1 damage, 5 health to 4
##   again inside 0.8 s              0 damage, absorbed by invulnerability
##   gap between successive hits     0.8 s, set by invulnerable_time
##   contacts needed to kill         5
##   after respawn                   spawn point (144, 612), 5 health, IDLE
##
## Rostam is stood on the hazard patch and left there. The patch is a Hitbox in
## continuous mode, so it re-arms every tick and his own invulnerability is what
## paces the damage; that is the behaviour under test, not a convenience.
##
## The knockback is small enough (200 px/s sideways, 150 lift, and control loss
## brakes it within about 5 px) that he stays on the 96 px patch between hits.

const Support = preload("res://tests/test_support.gd")

const TIMEOUT: int = 1200
## Centre of the HazardPatch in khan1_01_marsh, standing height.
const ON_HAZARD: Vector2 = Vector2(1632, 612)
const SPAWN: Vector2 = Vector2(144, 612)

var _player: Rostam
var _tick: int = 0
var _failures: int = 0

var _health: int = 5
var _hit_ticks: Array[int] = []
var _first_hit_checked: bool = false
var _died_at: int = -1
var _died_signal: bool = false
var _reported: bool = false


func _initialize() -> void:
	var main: Node = (load("res://scenes/world/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	_player = main.get_node("Rostam") as Rostam
	_player.died.connect(func() -> void: _died_signal = true)


func _physics_process(_delta: float) -> bool:
	_tick += 1
	if _tick > TIMEOUT:
		printerr("test_health: timed out after %d hits" % _hit_ticks.size())
		quit(1)
		return true

	# main.gd puts Rostam on the room spawn in _ready, so move him after that.
	if _tick == 3:
		_player.global_position = ON_HAZARD
		return false

	if _player.health < _health:
		var lost: int = _health - _player.health
		_health = _player.health
		_hit_ticks.append(_tick)
		if _hit_ticks.size() == 1:
			_failures += 0 if Support.exact("first contact costs 1", lost, 1) else 1
			_failures += 0 if Support.exact("health after first contact", _health, 4) else 1
			_failures += 0 if Support.exact("invulnerable after a hit",
					_player.is_invulnerable(), true) else 1

	# 0.4 s after the first hit, still inside the 0.8 s window and still stood
	# on the hazard, so this is a genuine second contact that must cost nothing.
	if not _first_hit_checked and _hit_ticks.size() == 1 and _tick == _hit_ticks[0] + 24:
		_first_hit_checked = true
		_failures += 0 if Support.exact("second contact inside 0.8 s costs 0",
				_player.health, 4) else 1
		_failures += 0 if Support.exact("still invulnerable at 0.4 s",
				_player.is_invulnerable(), true) else 1

	if _player.is_dead() and _died_at < 0:
		_died_at = _tick
		_failures += 0 if Support.exact("contacts needed to kill", _hit_ticks.size(), 5) else 1
		_failures += 0 if Support.exact("health at death", _player.health, 0) else 1
		_failures += 0 if Support.exact("died signal fired", _died_signal, true) else 1
		var gaps: float = 0.0
		for i in range(1, _hit_ticks.size()):
			gaps += float(_hit_ticks[i] - _hit_ticks[i - 1]) / 60.0
		_failures += 0 if Support.near_time("gap between hits",
				gaps / float(_hit_ticks.size() - 1), _player.invulnerable_time) else 1

	# main.gd fades out, respawns, fades back in. 60 ticks is a full second,
	# comfortably past the respawn callback partway through that.
	if _died_at > 0 and _tick == _died_at + 60 and not _reported:
		_reported = true
		_failures += 0 if Support.near("respawn x", _player.global_position.x, SPAWN.x) else 1
		_failures += 0 if Support.near("respawn y", _player.global_position.y, SPAWN.y) else 1
		_failures += 0 if Support.exact("respawn health", _player.health, _player.max_health) else 1
		_failures += 0 if Support.exact("respawn state is IDLE",
				_player.state, Rostam.State.IDLE) else 1
		_failures += 0 if Support.exact("respawn clears death", _player.is_dead(), false) else 1
		_failures += 0 if Support.exact("respawn clears invulnerability",
				_player.is_invulnerable(), false) else 1
		_failures += 0 if Support.exact("respawn clears attacking",
				_player.is_attacking(), false) else 1
		_failures += 0 if Support.near("respawn clears velocity",
				_player.velocity.length(), 0.0) else 1
		quit(Support.report("test_health", _failures))
		return true
	return false
