class_name Vulture
extends Enemy

## Air enemy, design doc section 6. Hovers in a slow figure-eight around a fixed
## anchor. When Rostam passes underneath it telegraphs, dives in a straight line
## at where he was when the dive started, then flies back and resumes hovering.
##
## Diving at where he was, not where he is, is what makes it dodgeable: the dive
## is committed the moment the telegraph ends.

enum State { HOVER, TELEGRAPH, DIVE, RETURN }

@export_group("Hover")
## Half-width and half-height of the figure-eight around the anchor. The width
## is kept under 30 so the Vulture never drifts out of the air swing's box while
## Rostam is directly beneath its anchor.
@export var hover_width: float = 28.0
@export var hover_height: float = 20.0
## Radians per second along the curve. One lap takes about 5 s at 1.2.
@export var hover_speed: float = 1.2

@export_group("Body")
## The contact box is trimmed by this much off the bottom, so the Vulture's
## belly is safe to be under while its top and sides still hurt. The hurtbox
## stays the full body, so the mace can hit it from any side.
@export var contact_safe_underside: float = 10.0:
	set(value):
		contact_safe_underside = value
		_shape_contact()

@export_group("Attack")
## Horizontal band within which Rostam counts as underneath.
@export var detect_width: float = 90.0
## He must be at least this far below, so it does not dive at someone level with
## it on a platform.
@export var detect_min_below: float = 40.0
@export var telegraph_time: float = 0.35
@export var dive_speed: float = 420.0
## Backstop, in case the target is never quite reached.
@export var dive_max_time: float = 1.2
@export var return_speed: float = 170.0
## Hovering time owed after a dive before it may commit to another.
@export var dive_cooldown: float = 1.2

var state: State = State.HOVER

var _phase: float = 0.0
var _timer: float = 0.0
var _cooldown: float = 0.0
var _dive_target: Vector2 = Vector2.ZERO
var _facing: int = 1


func get_facing() -> int:
	return _facing


func get_anchor() -> Vector2:
	return _home


func _on_ready() -> void:
	_phase = 0.0
	global_position = _home
	_shape_contact()


## Trims the contact box up off the belly. Driven from the hurtbox's shape so
## the two cannot drift apart, and the drawn body is left alone: this changes
## where it hurts, not what it looks like.
func _shape_contact() -> void:
	if _contact == null:
		return
	var full: Vector2 = _body_size()
	var height: float = maxf(full.y - contact_safe_underside, 2.0)
	_contact.size = Vector2(full.x, height)
	_contact.offset = Vector2(0.0, -(full.y - height) * 0.5)


func _body_size() -> Vector2:
	var shape: CollisionShape2D = _hurtbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null and shape.shape is RectangleShape2D:
		return (shape.shape as RectangleShape2D).size
	return Vector2(36, 16)


func _on_reset() -> void:
	state = State.HOVER
	_phase = 0.0
	_timer = 0.0
	_cooldown = 0.0
	velocity = Vector2.ZERO


## A hit sends it home rather than back into the figure-eight, so it eases back
## to the anchor instead of snapping to wherever the curve had got to.
func take_damage(amount: int, knockback: Vector2, source: Node2D) -> bool:
	var applied: bool = super(amount, knockback, source)
	if applied and is_alive():
		state = State.RETURN
	return applied


func _tick(delta: float) -> void:
	match state:
		State.HOVER:
			_hover(delta)
		State.TELEGRAPH:
			_telegraph(delta)
		State.DIVE:
			_dive(delta)
		State.RETURN:
			_return(delta)


## Flies rather than falls, so knockback bleeds off in both axes and no gravity
## is applied.
func _drift(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, knockback_friction * delta)
	velocity.y = move_toward(velocity.y, 0.0, knockback_friction * delta)
	move_and_slide()


## Lemniscate of Gerono: a figure-eight, driven by position rather than velocity
## so the path is exact and does not drift over time.
func _hover(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_phase += hover_speed * delta

	var previous_x: float = global_position.x
	global_position = _home + Vector2(
		hover_width * sin(_phase),
		hover_height * sin(_phase) * cos(_phase))
	_face(global_position.x - previous_x)

	if _cooldown <= 0.0 and _is_player_underneath():
		state = State.TELEGRAPH
		_timer = telegraph_time
		telegraph(telegraph_time)


func _telegraph(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return

	var player: Node2D = get_player()
	_dive_target = player.global_position if player != null else global_position + Vector2.DOWN * 100.0
	state = State.DIVE
	_timer = dive_max_time


func _dive(delta: float) -> void:
	var to_target: Vector2 = _dive_target - global_position
	_timer -= delta
	if _timer <= 0.0 or to_target.length() <= dive_speed * delta:
		_enter_return()
		return

	velocity = to_target.normalized() * dive_speed
	_face(velocity.x)
	move_and_slide()


func _return(delta: float) -> void:
	var to_home: Vector2 = _home - global_position
	if to_home.length() <= return_speed * delta:
		global_position = _home
		velocity = Vector2.ZERO
		_phase = 0.0
		_cooldown = dive_cooldown
		state = State.HOVER
		return

	velocity = to_home.normalized() * return_speed
	_face(velocity.x)
	move_and_slide()


func _enter_return() -> void:
	state = State.RETURN
	velocity = Vector2.ZERO


func _is_player_underneath() -> bool:
	var player: Node2D = get_player()
	if player == null:
		return false
	if player.has_method("is_dead") and player.is_dead():
		return false
	var offset: Vector2 = player.global_position - global_position
	return absf(offset.x) <= detect_width and offset.y >= detect_min_below


func _face(dx: float) -> void:
	if absf(dx) < 0.5:
		return
	var wanted: int = 1 if dx > 0.0 else -1
	if wanted == _facing:
		return
	_facing = wanted
	_visuals.scale.x = float(_facing)
