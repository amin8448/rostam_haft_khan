class_name RoomManager
extends Node

## Loads rooms, moves Rostam between them, and owns the respawn point.
##
## A node in main.tscn rather than an autoload. The usual reason to make this
## global is so a Door buried in a room can reach it, but the manager is what
## instantiates the room, so it connects the doors itself and nothing has to go
## looking. Everything else it needs is a sibling.

signal room_entered(room: Room)

## Section 7: 0.2 s out, 0.2 s in. The swap and the camera snap both happen
## while the screen is fully black.
@export var fade_time: float = 0.2
@export_file("*.tscn") var starting_room: String = "res://scenes/rooms/khan1_01_marsh.tscn"
@export var starting_entry: StringName = &"PlayerSpawn"
## Shown when Rostam rests, so it is visible that it worked.
@export var rest_text: String = "Rested."

@export_group("Wiring")
@export var rooms_parent_path: NodePath = ^"../Rooms"
@export var player_path: NodePath = ^"../Rostam"
@export var camera_path: NodePath = ^"../GameCamera"
@export var fade_path: NodePath = ^"../FadeLayer/Fade"
@export var banner_path: NodePath = ^"../RoomBanner"

var _room: Room
var _room_path: String = ""
var _busy: bool = false

## The respawn point is a room and a position, never "the camp". A second
## grazing ground anywhere in the game works with no change here
## (future_systems.md item 2).
var _respawn_room: String = ""
var _respawn_position: Vector2 = Vector2.ZERO

@onready var _rooms: Node = get_node(rooms_parent_path)
@onready var _player: Rostam = get_node(player_path) as Rostam
@onready var _camera: GameCamera = get_node(camera_path) as GameCamera
@onready var _fade: ColorRect = get_node_or_null(fade_path) as ColorRect
@onready var _banner: CanvasLayer = get_node_or_null(banner_path) as CanvasLayer


## Called by main once the player's signals are wired.
func start() -> void:
	enter_room(starting_room, starting_entry)
	_respawn_room = starting_room
	_respawn_position = _room.get_entry(starting_entry)


func get_current_room() -> Room:
	return _room


func get_current_room_path() -> String:
	return _room_path


func get_respawn_room() -> String:
	return _respawn_room


func get_respawn_position() -> Vector2:
	return _respawn_position


func is_busy() -> bool:
	return _busy


## Resting: health back to full, and this ground becomes the respawn point. The
## ground itself decides nothing; this is the only thing that knows which room
## it is in.
func on_rested(ground: GrazingGround) -> void:
	set_respawn(_room_path, ground.get_rest_position())
	if _player.has_method("heal_full"):
		_player.heal_full()
	if _banner != null and _banner.has_method("show_text"):
		_banner.show_text(rest_text)


## Called by a grazing ground when Rostam rests. Stores where, not what.
func set_respawn(room_path: String, position: Vector2) -> void:
	_respawn_room = room_path
	_respawn_position = position


func on_door_entered(door: Door) -> void:
	if _busy or not door.is_usable():
		return
	_busy = true

	# Section 7: Rostam keeps his velocity through a door.
	var carried: Vector2 = _player.velocity
	var path: String = door.target_room
	var entry: StringName = door.target_entry

	var tween: Tween = create_tween()
	tween.tween_property(_fade, "color:a", 1.0, fade_time)
	tween.tween_callback(func() -> void:
		enter_room(path, entry)
		_player.velocity = carried)
	tween.tween_property(_fade, "color:a", 0.0, fade_time)
	tween.tween_callback(func() -> void: _busy = false)


func on_player_died() -> void:
	if _busy:
		return
	_busy = true
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "color:a", 1.0, fade_time)
	tween.tween_callback(_respawn)
	tween.tween_property(_fade, "color:a", 0.0, fade_time)
	tween.tween_callback(func() -> void: _busy = false)


func _respawn() -> void:
	if _respawn_room != _room_path:
		# A freshly loaded room is already in its starting state.
		_load(_respawn_room)
	else:
		_room.reset()
	_player.respawn(_respawn_position)
	_camera.set_bounds(_room.bounds)
	_camera.set_target(_player)


## Instant, no fade. The door path wraps this in one; a debug warp or a test
## calls it directly.
func enter_room(path: String, entry: StringName) -> void:
	_load(path)
	_player.global_position = _room.get_entry(entry)
	# Teleporting leaves the hurtbox behind in the broadphase for a step, which
	# is how a hazard in the last room could land a free hit in this one.
	_player.force_update_transform()

	_camera.set_bounds(_room.bounds)
	# set_target snaps and resets smoothing, so the camera does not sweep across
	# the level behind the fade.
	_camera.set_target(_player)

	if _banner != null and _banner.has_method("show_text"):
		_banner.show_text(_room.entry_text)
	room_entered.emit(_room)


func _load(path: String) -> void:
	for child in _rooms.get_children():
		# Removed as well as freed: queue_free is deferred, and a room still in
		# the tree would have Rostam standing in the old terrain for a frame.
		_rooms.remove_child(child)
		child.queue_free()

	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		push_error("RoomManager could not load room '%s'." % path)
		return
	_room = scene.instantiate() as Room
	_room_path = path
	_rooms.add_child(_room)

	for door in _find_nodes(_room, "Door"):
		(door as Door).entered.connect(on_door_entered)
	for ground in _find_nodes(_room, "GrazingGround"):
		(ground as GrazingGround).rested.connect(on_rested)


## The manager instantiates the room, so it connects what is in it rather than
## anything in the room having to find the manager.
func _find_nodes(node: Node, type: String) -> Array[Node]:
	var found: Array[Node] = []
	if node.is_class(type) or (node.get_script() != null and _is_type(node, type)):
		found.append(node)
	for child in node.get_children():
		found.append_array(_find_nodes(child, type))
	return found


func _is_type(node: Node, type: String) -> bool:
	match type:
		"Door":
			return node is Door
		"GrazingGround":
			return node is GrazingGround
	return false
