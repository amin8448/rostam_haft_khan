extends Room

## Khan 1, room 5. The Lion's arena, and the controller for the fight.
##
## The fight lives here rather than in the Lion because it is about the room:
## the trigger line, the doors locking behind Rostam, the boss bar, and the
## phase 2 sequence. Section 8's scripted moment is one tween chain in this file
## so it can be read top to bottom instead of being chased across nodes.

@export var lion_path: NodePath = ^"Lion"
@export var trigger_path: NodePath = ^"FightTrigger"
@export var west_door_path: NodePath = ^"WestDoor"
@export var east_door_path: NodePath = ^"EastDoor"
@export var rakhsh_path: NodePath = ^"Rakhsh"

var _manager: Node
var _fighting: bool = false

@onready var _lion: Lion = get_node_or_null(lion_path) as Lion
@onready var _trigger: Area2D = get_node_or_null(trigger_path) as Area2D
@onready var _west_door: Door = get_node_or_null(west_door_path) as Door
@onready var _east_door: Door = get_node_or_null(east_door_path) as Door
@onready var _rakhsh: Node2D = get_node_or_null(rakhsh_path) as Node2D


func _ready() -> void:
	if _rakhsh != null:
		# He is at the camp until the sequence brings him in.
		_rakhsh.visible = false
	if _trigger != null:
		_trigger.body_entered.connect(_on_trigger)
	if _lion != null:
		_lion.phase_two_reached.connect(_on_phase_two)


## The manager hands itself over when it loads a room, so the arena can reach
## the banner and the boss bar without going looking for them.
func on_loaded(manager: Node) -> void:
	_manager = manager


func is_fighting() -> bool:
	return _fighting


func _physics_process(_delta: float) -> void:
	if not _fighting or _lion == null or _manager == null:
		return
	if _manager.has_method("set_boss_health"):
		_manager.set_boss_health(_lion.health, _lion.max_health)


func _on_trigger(body: Node2D) -> void:
	if _fighting or _lion == null or not body.is_in_group(Enemy.PLAYER_GROUP):
		return
	_fighting = true
	# Shut the way back. Both doors open again when it is over.
	if _west_door != null:
		_west_door.locked = true
	_lion.wake()
	if _manager != null and _manager.has_method("show_boss"):
		_manager.show_boss(_lion.health, _lion.max_health)


func _on_phase_two() -> void:
	pass
