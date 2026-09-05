class_name Door
extends Area2D

## A way out of a room. Section 7: doors tell the room manager which room to
## load and where to put Rostam in it.
##
## The manager instantiates the room, so it connects this signal itself. A door
## never has to find anything.

signal entered(door: Door)

## A path, not an exported PackedScene. Exporting the scene would make room 1
## load room 2 at load time, which loads room 1 back: two doors facing each
## other are a circular dependency Godot resolves badly.
@export_file("*.tscn") var target_room: String = ""
## Name of the Marker2D to arrive on in the target room.
@export var target_entry: StringName = &"EntryWest"
## The far door of the den. It ends the slice rather than loading a room, so it
## is the one door with no target.
@export var ends_slice: bool = false
## A locked door does nothing and draws darker. The den's doors are unlocked by
## the arena when the fight is over.
@export var locked: bool = false:
	set(value):
		locked = value
		_apply_locked()
@export var open_color: Color = Color(0.85, 0.72, 0.25, 1)
@export var locked_color: Color = Color(0.3, 0.26, 0.14, 1)

@onready var _panel: Polygon2D = get_node_or_null("Panel") as Polygon2D


func _ready() -> void:
	_apply_locked()
	body_entered.connect(_on_body_entered)


func is_usable() -> bool:
	return not locked and (ends_slice or not target_room.is_empty())


func _on_body_entered(body: Node2D) -> void:
	if not is_usable():
		return
	if not body.is_in_group(Enemy.PLAYER_GROUP):
		return
	entered.emit(self)


func _apply_locked() -> void:
	if _panel == null:
		return
	_panel.color = locked_color if locked else open_color
