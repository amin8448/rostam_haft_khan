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
##   two air attacks          2 health to 0, and Rostam takes no damage doing it
##   contact box              trimmed contact_safe_underside off the belly
##   touching its side        still costs 1, so only the belly is inert
##
## The kill phase resets the Vulture and then zeroes hover_speed so it sits on
## its anchor. That isolates the claim section 6 actually makes, which is that a
## jump plus the air attack can reach it. Leading its horizontal swing is a
## matter of play skill and is not what this check is for.
##
## It swings from 45 px to the side, not from underneath, and the safe underside
## does not change that. Rostam's capsule is 56 tall and its top sits 22 px above
## the top of his mace box, while the Vulture is 16 px tall: by the time the mace
## reaches its underside his head is already past its top, and his capsule spans
## the whole body. No contact box inside that body can avoid him, so trimming the
## belly makes it safe to be under but not safe to attack from under.
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
var _main: Node
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
var _health_at_kill: int = 0
var _side_health_before: int = 0


func _initialize() -> void:
	var main: Node = (load("res://scenes/world/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	_player = main.get_node("Rostam") as Rostam
	_main = main


func _physics_process(_delta: float) -> bool:
	_tick += 1
	if _tick > TIMEOUT:
		printerr("test_vulture: timed out in phase ", _phase)
		quit(1)
		return true

	if _tick == 1:
		# The room only exists once main._ready has run, which is the first frame.
		_vulture = (_main.get_node("RoomManager") as RoomManager) 				.get_current_room().get_node("Vulture") as Vulture
		return false

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
		"side":
			_run_side(_tick - _phase_start)
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

	_check_contact_box()

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
		_health_at_kill = _player.health
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
		_failures += 0 if Support.exact("no damage taken killing it",
				_player.health, _health_at_kill) else 1
		_vulture.reset()
		_vulture.hover_speed = 0.0
		_phase = "side"
		_phase_start = _tick
	elif _jumps >= 4:
		_failures += 0 if Support.exact("two air attacks kill it", _vulture.health, 0) else 1
		_phase = "done"


## The belly being inert must not make the whole body inert: brushing its side
## still costs a hit, which is what keeps it a threat on the dive.
func _run_side(at: int) -> void:
	if at == 5:
		_player.respawn(Vector2(_vulture.global_position.x - 22.0, _vulture.global_position.y))
		_side_health_before = _player.health
	elif at == 40:
		_failures += 0 if Support.exact("touching its side still costs 1",
				_side_health_before - _player.health, 1) else 1
		_phase = "done"


## Geometry rather than behaviour: the belly cannot be checked by walking into
## it, because Rostam's capsule is taller than the whole Vulture.
func _check_contact_box() -> void:
	var shape: CollisionShape2D = _vulture.get_node("ContactHitbox/CollisionShape2D")
	var box: RectangleShape2D = shape.shape as RectangleShape2D
	var body_bottom: float = 8.0
	var contact_bottom: float = shape.position.y + box.size.y * 0.5
	_failures += 0 if Support.near("belly left uncovered",
			body_bottom - contact_bottom, _vulture.contact_safe_underside) else 1
	_failures += 0 if Support.near("contact box still full width",
			box.size.x, 36.0) else 1


## One air attack per jump, swung on the way up so the mace head is open near the
## apex where the Vulture sits.
func _swing(since: int) -> void:
	if since == 14:
		Input.action_press("attack")
	elif since == 15:
		Input.action_release("attack")
	elif since == 45:
		Input.action_release("jump")
