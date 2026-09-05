class_name GrazingGround
extends Area2D

## Open ground where Rakhsh waits. future_systems.md item 1: one node type that
## rests, saves, and later travels. This is the first of them, and nothing about
## it is specific to the camp, so a second one anywhere works unchanged.
##
## It only announces that Rostam rested. The RoomManager decides what resting
## means, because it is the thing that knows which room this is.

signal rested(ground: GrazingGround)

var _player_inside: bool = false

@onready var _rest_point: Marker2D = get_node_or_null("RestPoint") as Marker2D


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(_delta: float) -> void:
	if not _player_inside:
		return
	if Input.is_action_just_pressed("interact"):
		rested.emit(self)


## Where Rostam stands when he respawns here.
func get_rest_position() -> Vector2:
	return _rest_point.global_position if _rest_point != null else global_position


func is_player_inside() -> bool:
	return _player_inside


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(Enemy.PLAYER_GROUP):
		_player_inside = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group(Enemy.PLAYER_GROUP):
		_player_inside = false
