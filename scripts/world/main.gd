extends Node2D

@onready var _room: Room = $Room
@onready var _player: Node2D = $Rostam
@onready var _camera: Camera2D = $Camera2D


func _ready() -> void:
	_player.global_position = _room.get_spawn_position()
	_apply_room_bounds(_room.bounds)


func _apply_room_bounds(bounds: Rect2) -> void:
	if bounds.get_area() <= 0.0:
		push_warning("Room '%s' declares no bounds; camera limits left open." % _room.name)
		return
	_camera.limit_left = int(bounds.position.x)
	_camera.limit_top = int(bounds.position.y)
	_camera.limit_right = int(bounds.end.x)
	_camera.limit_bottom = int(bounds.end.y)
	_camera.global_position = _player.global_position
