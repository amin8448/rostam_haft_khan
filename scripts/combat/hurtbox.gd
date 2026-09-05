class_name Hurtbox
extends Area2D

## Receives damage on behalf of its owner.
##
## Passive on purpose: it does not monitor anything, the Hitbox finds it. All it
## does is forward the hit to the body that holds the health, so health never
## lives in the component and every owner keeps its own rules about
## invulnerability and death.

signal hit_received(damage: int, knockback: Vector2, source: Node2D)

## The node that holds the health. One hop by default rather than a get_parent()
## chain, and overridable when the hurtbox is nested deeper.
@export var body_path: NodePath = ^".."

var _body: Node2D


func _ready() -> void:
	# Nothing to detect: being detectable is the whole job.
	monitoring = false
	monitorable = true
	_body = get_node_or_null(body_path) as Node2D
	if _body == null:
		push_warning("Hurtbox '%s' has no body at '%s'." % [name, body_path])


func get_body() -> Node2D:
	return _body


## Returns true only when damage was actually applied, so the attacker can tell
## a real hit from one absorbed by invulnerability and skip the hit pause.
func receive_hit(damage: int, knockback: Vector2, source: Node2D) -> bool:
	var applied: bool = false
	if _body != null and _body.has_method("take_damage"):
		applied = _body.take_damage(damage, knockback, source)
	if applied:
		hit_received.emit(damage, knockback, source)
	return applied
