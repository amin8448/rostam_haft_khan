class_name TrainingDummy
extends CharacterBody2D

## TEMPORARY. A stationary target for judging combat feel: no AI, no attacks.
## Session 3 replaces it with the Jackal and the Vulture; delete this script,
## its scene, and the instance in khan1_01_marsh then.

@export var max_health: int = 3
@export var respawn_delay: float = 2.0
@export var gravity: float = 1800.0
## Knockback bleeds off at this rate, so a hit shoves it and it settles.
@export var friction: float = 900.0

var health: int = 3

var _respawn_timer: float = 0.0
var _hit_pause_timer: float = 0.0
var _home: Vector2

@onready var _visuals: Node2D = $Visuals
@onready var _flash: HitFlash = $HitFlash
@onready var _hurtbox: Area2D = $Hurtbox


func _ready() -> void:
	_home = global_position
	health = max_health


func _physics_process(delta: float) -> void:
	if _hit_pause_timer > 0.0:
		_hit_pause_timer -= delta
		return

	if health <= 0:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			reset()
		return

	velocity.y += gravity * delta
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	move_and_slide()


func take_damage(amount: int, knockback: Vector2, _source: Node2D) -> bool:
	if amount <= 0 or health <= 0:
		return false

	health -= amount
	_flash.flash()
	velocity = knockback

	if health <= 0:
		health = 0
		velocity = Vector2.ZERO
		_respawn_timer = respawn_delay
		_set_present(false)
	return true


func apply_hit_pause(duration: float) -> void:
	_hit_pause_timer = maxf(_hit_pause_timer, duration)


func is_alive() -> bool:
	return health > 0


## Called by Room.reset() when Rostam respawns, and by the respawn timer.
func reset() -> void:
	health = max_health
	global_position = _home
	velocity = Vector2.ZERO
	_respawn_timer = 0.0
	_hit_pause_timer = 0.0
	_flash.clear()
	_set_present(true)


## A dead dummy stops being hittable and stops being drawn, but stays in the
## tree so it can come back without being re-instanced.
func _set_present(present: bool) -> void:
	_visuals.visible = present
	_hurtbox.monitorable = present
