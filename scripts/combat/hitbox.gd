class_name Hitbox
extends Area2D

## Deals damage to any Hurtbox it overlaps while active.
##
## The Hitbox does the detecting rather than the Hurtbox, because it is the side
## that knows the damage, the knockback and how long to freeze on a hit. It
## finds targets by duck typing, so it never needs to know what it hit.
##
## Separation between sides is done with collision layers, not runtime owner
## checks: a player hitbox masks only enemy_hurtbox and an enemy hitbox masks
## only player_hurtbox, so friendly fire cannot physically overlap.

signal hit_landed(target: Node2D)

@export var damage: int = 1
@export var knockback_speed: float = 180.0
## A little lift so knockback reads as a hit rather than a shove.
@export var knockback_lift: float = 90.0
## Both parties freeze for this long when a hit lands. Section 5 calls this the
## biggest single contributor to crunchy combat. Left at zero for contact
## hazards, which should not stop the game.
@export var hit_pause: float = 0.05
@export var size: Vector2 = Vector2(34, 24):
	set(value):
		size = value
		_apply_size()
## Where the box sits relative to the body. A mace reaches forward; a hazard
## sits centred on itself.
@export var offset: Vector2 = Vector2.ZERO:
	set(value):
		offset = value
		_apply_size()
## Contact damage. Re-arms every tick and lets the target's own invulnerability
## do the rate limiting, instead of firing once per activation.
@export var continuous: bool = false
## The node this hitbox belongs to. Reported as the source of the hit and used
## as the origin knockback pushes away from.
@export var body_path: NodePath = ^".."
## Optional child drawn only while the box is open, so the active window is
## visible on screen. Rostam's mace head uses it; a hazard names its visual
## something else and simply has none.
@export var visual_path: NodePath = ^"MaceHead"

var _body: Node2D
var _shape: CollisionShape2D
var _visual: Polygon2D
var _already_hit: Array[Node] = []


func _ready() -> void:
	_body = get_node_or_null(body_path) as Node2D
	_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	_visual = get_node_or_null(visual_path) as Polygon2D
	if _shape != null and _shape.shape is RectangleShape2D:
		# Duplicate so resizing per swing cannot mutate a shared resource.
		_shape.shape = _shape.shape.duplicate()
	_apply_size()
	if continuous:
		monitoring = true
	else:
		deactivate()


func _physics_process(_delta: float) -> void:
	if not monitoring:
		return
	if continuous:
		_already_hit.clear()
	for area in get_overlapping_areas():
		_try_hit(area)


## Opens the box for one swing. Clears the per-swing record so a box left open
## for several ticks still deals damage exactly once.
func activate() -> void:
	_already_hit.clear()
	monitoring = true
	if _visual != null:
		_visual.visible = true


func deactivate() -> void:
	monitoring = false
	_already_hit.clear()
	if _visual != null:
		_visual.visible = false


func is_active() -> bool:
	return monitoring


func _try_hit(area: Area2D) -> void:
	if _already_hit.has(area) or not area.has_method("receive_hit"):
		return
	_already_hit.append(area)

	var target: Node2D = area.get_body() if area.has_method("get_body") else area
	if not area.receive_hit(damage, _knockback_for(target), _body):
		return

	hit_landed.emit(target)
	_pause(_body)
	_pause(target)


## Knockback pushes away from the attacking body, which is right for a mace
## (the target is in front) and for a hazard (the target is standing on it)
## without either needing to know about the other.
func _knockback_for(target: Node2D) -> Vector2:
	var origin: Node2D = _body if _body != null else self
	var dx: float = target.global_position.x - origin.global_position.x
	var direction: float = signf(dx)
	if is_zero_approx(direction):
		direction = signf(global_scale.x)
	if is_zero_approx(direction):
		direction = 1.0
	return Vector2(direction * knockback_speed, -knockback_lift)


func _pause(node: Node) -> void:
	if hit_pause <= 0.0 or node == null:
		return
	if node.has_method("apply_hit_pause"):
		node.apply_hit_pause(hit_pause)


func _apply_size() -> void:
	if _shape != null and _shape.shape is RectangleShape2D:
		(_shape.shape as RectangleShape2D).size = size
		_shape.position = offset
	if _visual == null:
		return
	var half: Vector2 = size * 0.5
	_visual.polygon = PackedVector2Array([
		offset + Vector2(-half.x, -half.y),
		offset + Vector2(half.x, -half.y),
		offset + Vector2(half.x, half.y),
		offset + Vector2(-half.x, half.y),
	])
