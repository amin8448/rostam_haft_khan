class_name Room
extends Node2D

## The area the camera is allowed to show, in world pixels. Every room must
## declare its own; the world reads this when the room is entered. Left empty
## on purpose so a room that forgets to set it says so instead of silently
## inheriting another room's size.
@export var bounds: Rect2 = Rect2()
## One line shown for a moment on entering. Blank means no banner.
@export var entry_text: String = ""
## future_systems.md item 4: open ground Rakhsh could be ridden through. Nothing
## reads this yet; it exists so rooms carry the flag from the start.
@export var rideable: bool = false


## Where a door drops Rostam. Falls back to the spawn marker so a room without
## a matching entry is still playable rather than putting him at the origin.
func get_entry(entry_name: StringName) -> Vector2:
	var marker: Marker2D = get_node_or_null(String(entry_name)) as Marker2D
	if marker != null:
		return marker.global_position
	return get_spawn_position()


## Where Rostam stands when he enters this room at the start of the game.
func get_spawn_position() -> Vector2:
	var spawn: Marker2D = get_node_or_null("PlayerSpawn") as Marker2D
	if spawn == null:
		push_warning("Room '%s' has no PlayerSpawn marker." % name)
		return global_position
	return spawn.global_position


## Puts the room back to its starting state after a death. Children opt in by
## having a reset() of their own, so the room does not need to know what lives
## in it.
func reset() -> void:
	for child in get_children():
		if child.has_method("reset"):
			child.reset()
