class_name HitFlash
extends Node

## Briefly turns a placeholder shape white when it is hit.
##
## Placeholder art is flat-coloured Polygon2D and modulate multiplies, so a red
## shape stays red however it is modulated. This swaps the colours outright and
## puts them back, which is the only thing that reads on solid colours.

@export var visuals_path: NodePath = ^"../Visuals"
@export var duration: float = 0.08
@export var flash_color: Color = Color(1, 1, 1, 1)
## Telegraphs use a lighter shade of the body rather than white, so winding up
## to swing does not read as having just been hit.
@export var telegraph_color: Color = Color(1, 0.55, 0.5, 1)

var _originals: Dictionary = {}
var _timer: float = 0.0


func _ready() -> void:
	set_physics_process(false)
	var visuals: Node = get_node_or_null(visuals_path)
	if visuals == null:
		push_warning("HitFlash '%s' has no visuals at '%s'." % [name, visuals_path])
		return
	for polygon in _polygons(visuals):
		_originals[polygon] = polygon.color


## Hit feedback: a short white blink.
func flash() -> void:
	_begin(duration, flash_color)


## Attack telegraph: held for as long as the wind-up lasts, so the moment it
## ends is the moment the attack starts. Section 9 asks for exactly this, since
## there is no animation to read instead.
func telegraph(seconds: float) -> void:
	_begin(seconds, telegraph_color)


func _begin(seconds: float, color: Color) -> void:
	if _originals.is_empty():
		return
	for polygon in _originals:
		(polygon as Polygon2D).color = color
	_timer = seconds
	set_physics_process(true)


## Puts the colours back immediately, for a respawn that must not come back
## still white from the hit that killed it.
func clear() -> void:
	_timer = 0.0
	set_physics_process(false)
	_restore()


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_restore()
	set_physics_process(false)


func _restore() -> void:
	for polygon in _originals:
		(polygon as Polygon2D).color = _originals[polygon]


func _polygons(node: Node) -> Array[Polygon2D]:
	var found: Array[Polygon2D] = []
	if node is Polygon2D:
		found.append(node as Polygon2D)
	for child in node.get_children():
		found.append_array(_polygons(child))
	return found
