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

@export_group("Phase two")
## How long Rostam is held before Rakhsh arrives.
@export var pin_time: float = 1.0
@export var rakhsh_start_x: float = -140.0
@export var rakhsh_speed: float = 1100.0
## How far past the Lion Rakhsh carries before stopping.
@export var rakhsh_overrun: float = 90.0
@export var throw_distance: float = 280.0
@export var throw_time: float = 0.45
@export var impact_shake: float = 9.0
@export var victory_text: String = "Rakhsh did not wait to be asked."
@export var settle_time: float = 1.6

var _manager: Node
var _fighting: bool = false
var _sequence_running: bool = false
var _finished: bool = false

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
		_lion.final_pounce_landed.connect(_on_final_pounce_landed)


## The manager hands itself over when it loads a room, so the arena can reach
## the banner and the boss bar without going looking for them.
func on_loaded(manager: Node) -> void:
	_manager = manager


func is_fighting() -> bool:
	return _fighting


func is_finished() -> bool:
	return _finished


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


## Section 8: below a quarter health the Lion stops choosing and commits to one
## last pounce that always connects.
func _on_phase_two() -> void:
	if _sequence_running or _lion == null:
		return
	_sequence_running = true
	_lion.begin_final_pounce()


## The whole scripted moment, in order, in one place. Nothing here is spread
## across nodes: read it top to bottom and that is what happens on screen.
func _on_final_pounce_landed() -> void:
	var player: Node2D = _find_player()
	if player != null and player.has_method("set_pinned"):
		player.set_pinned(true)
	if _lion != null:
		_lion.hold()

	var lion_x: float = _lion.position.x if _lion != null else 0.0
	var charge_time: float = absf(lion_x - rakhsh_start_x) / maxf(rakhsh_speed, 1.0)

	var tween: Tween = create_tween()
	# 1. Pinned. Rostam shakes in place; set_pinned does that himself.
	tween.tween_interval(pin_time)
	# 2. Rakhsh comes in from the left, off screen, at speed.
	tween.tween_callback(_send_rakhsh)
	tween.tween_property(_rakhsh, "position:x", lion_x, charge_time)
	# 3. Impact. The Lion is beaten here, not killed by damage, so it stays on
	#    screen to be thrown rather than vanishing like an ordinary enemy.
	tween.tween_callback(_impact)
	tween.tween_property(_lion, "position:x", lion_x + throw_distance, throw_time)
	tween.parallel().tween_property(_rakhsh, "position:x", lion_x + rakhsh_overrun, throw_time)
	# 4. A line, a beat, and then control comes back.
	tween.tween_callback(_say_victory)
	tween.tween_interval(settle_time)
	tween.tween_callback(_finish_fight)


func _send_rakhsh() -> void:
	if _rakhsh == null:
		return
	_rakhsh.position.x = rakhsh_start_x
	_rakhsh.visible = true


func _impact() -> void:
	if _lion != null:
		_lion.set_defeated()
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera != null and camera.has_method("shake"):
		camera.shake(impact_shake)


func _say_victory() -> void:
	if _manager != null and _manager.has_method("show_text"):
		_manager.show_text(victory_text)


func _finish_fight() -> void:
	_fighting = false
	_finished = true
	var player: Node2D = _find_player()
	if player != null and player.has_method("set_pinned"):
		player.set_pinned(false)
	# Both ways out open again, and the east one is the way on.
	if _west_door != null:
		_west_door.locked = false
	if _east_door != null:
		_east_door.locked = false
	if _manager != null and _manager.has_method("hide_boss"):
		_manager.hide_boss()


func _find_player() -> Node2D:
	return get_tree().get_first_node_in_group(Enemy.PLAYER_GROUP) as Node2D
