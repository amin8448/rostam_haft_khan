extends SceneTree

## The Vulture, design doc section 6.
##
## Expected:
##   hover box                anchor +/- hover_width by +/- hover_height/2,
##                            since sin(t)cos(t) peaks at 0.5
##   Rostam far away          never leaves HOVER
##   Rostam underneath        telegraphs, then dives
##   the dive                 arrives within 30 px of where he was when it
##                            committed, not where he has since moved to
##   afterwards               back on the anchor, hovering again
##   two air attacks          2 health to 0, from a standing jump
##
## The kill phase resets the Vulture and then zeroes hover_speed so it sits on
## its anchor. That isolates the claim section 6 actually makes, which is that a
## jump plus the air attack can reach it. Leading its horizontal swing is a
## matter of play skill and is not what this check is for.
##
## It swings from 45 px to the side, not from underneath. Rostam's head reaches
## 22 px higher than his mace does, so jumping straight up into the Vulture
## puts his hurtbox into its contact box before the mace arrives: he takes the
## hit, the knockback replaces his rise, and the stun swallows the attack input.
## 45 px clears the two bodies (12 + 18 = 30) while leaving the mace, which
## reaches 44 px, well inside it.

const Support = preload("res://tests/test_support.gd")

const TIMEOUT: int = 2400
const ANCHOR: Vector2 = Vector2(1392, 500)
## Directly below the anchor, on the clear ground under the climb.
const UNDERNEATH: Vector2 = Vector2(1392, 612)
## Clear ground far from both the Vulture and the room's Jackal at x=1760.
const FAR_AWAY: Vector2 = Vector2(1000, 612)

var _vulture: Vulture
var _player: Rostam
var _tick: int = 0
var _failures: int = 0

var _phase: String = "hover"
var _phase_start: int = 0
var _min: Vector2 = Vector2(1e9, 1e9)
var _max: Vector2 = Vector2(-1e9, -1e9)
var _left_hover: bool = false
var _dive_from: Vector2 = Vector2.ZERO
var _dive_closest: float = 1e9
var _saw_telegraph: bool = false
var _saw_dive: bool = false
var _jumps: int = 0
var _jump_at: int = 0


func _initialize() -> void:
	var main: Node = (load("res://scenes/world/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	_player = main.get_node("Rostam") as Rostam
	_vulture = main.get_node("Room/Vulture") as Vulture


func _physics_process(_delta: float) -> bool:
	_tick += 1
	if _tick > TIMEOUT:
		printerr("test_vulture: timed out in phase ", _phase)
		quit(1)
		return true

	if _tick == 3:
		_player.respawn(FAR_AWAY)
		_phase_start = _tick
		return false

	match _phase:
		"hover":
			_run_hover()
		"dive":
			_run_dive()
		"return":
			_run_return()
		"kill":
			_run_kill()
		"done":
			quit(Support.report("test_vulture", _failures))
			return true
	return false


func _run_hover() -> void:
	var at: Vector2 = _vulture.global_position
	_min = Vector2(minf(_min.x, at.x), minf(_min.y, at.y))
	_max = Vector2(maxf(_max.x, at.x), maxf(_max.y, at.y))
	if _vulture.state != Vulture.State.HOVER:
		_left_hover = true

	if _tick != _phase_start + 300:
		return

	_failures += 0 if Support.exact("no dive while he is far", _left_hover, false) else 1
	_failures += 0 if Support.at_least("hover left edge", _min.x,
			ANCHOR.x - _vulture.hover_width - 1.0) else 1
	_failures += 0 if Support.at_most("hover right edge", _max.x,
			ANCHOR.x + _vulture.hover_width + 1.0) else 1
	_failures += 0 if Support.at_least("hover top edge", _min.y,
			ANCHOR.y - _vulture.hover_height * 0.5 - 1.0) else 1
	_failures += 0 if Support.at_most("hover bottom edge", _max.y,
			ANCHOR.y + _vulture.hover_height * 0.5 + 1.0) else 1

	_player.respawn(UNDERNEATH)
	_phase = "dive"
	_phase_start = _tick


func _run_dive() -> void:
	if _vulture.state == Vulture.State.TELEGRAPH:
		_saw_telegraph = true
	if _vulture.state == Vulture.State.DIVE:
		if not _saw_dive:
			_saw_dive = true
			# Where he was when it committed. It should come here even if he
			# moves, which is what makes the dive dodgeable.
			_dive_from = _player.global_position
		_dive_closest = minf(_dive_closest, _vulture.global_position.distance_to(_dive_from))

	if not _saw_dive and _tick < _phase_start + 400:
		return
	if _saw_dive and _vulture.state != Vulture.State.RETURN and _tick < _phase_start + 400:
		return

	_failures += 0 if Support.exact("telegraphs before diving", _saw_telegraph, true) else 1
	_failures += 0 if Support.exact("dives when he is underneath", _saw_dive, true) else 1
	_failures += 0 if Support.at_most("dive reaches his position", _dive_closest, 30.0) else 1

	_player.respawn(FAR_AWAY)
	_phase = "return"
	_phase_start = _tick


func _run_return() -> void:
	if _vulture.state != Vulture.State.HOVER and _tick < _phase_start + 400:
		return

	_failures += 0 if Support.exact("hovers again afterwards", _vulture.state,
			Vulture.State.HOVER) else 1
	_failures += 0 if Support.near("returns to the anchor x",
			_vulture.global_position.x, ANCHOR.x) else 1
	_failures += 0 if Support.near("returns to the anchor y",
			_vulture.global_position.y, ANCHOR.y) else 1

	# Park it on its anchor for the reach test.
	_vulture.reset()
	_vulture.hover_speed = 0.0
	_vulture.detect_width = 0.0
	_phase = "kill"
	_phase_start = _tick


func _run_kill() -> void:
	var at: int = _tick - _phase_start
	if at == 5:
		_player.respawn(Vector2(_vulture.global_position.x - 45.0, UNDERNEATH.y))
		return
	# respawn() drops him from exactly resting height and he settles over a few
	# ticks, so jumping on a fixed offset launches him mid-fall and cuts the arc
	# short. Wait for the floor instead.
	if at < 25 or not _player.is_on_floor():
		if _jump_at > 0 and _tick - _jump_at <= 60:
			_swing(_tick - _jump_at)
		return

	if _jump_at == 0 or _tick - _jump_at > 90:
		_jumps += 1
		_jump_at = _tick
		Input.action_press("jump")
		return
	_swing(_tick - _jump_at)

	if not _vulture.is_alive():
		_failures += 0 if Support.exact("two air attacks kill it", _vulture.health, 0) else 1
		_failures += 0 if Support.at_most("jumps needed", float(_jumps), 2.0, "jumps") else 1
		_phase = "done"
	elif _jumps >= 4:
		_failures += 0 if Support.exact("two air attacks kill it", _vulture.health, 0) else 1
		_phase = "done"


## One air attack per jump, swung on the way up so the mace head is open near the
## apex where the Vulture sits.
func _swing(since: int) -> void:
	if since == 14:
		Input.action_press("attack")
	elif since == 15:
		Input.action_release("attack")
	elif since == 45:
		Input.action_release("jump")
