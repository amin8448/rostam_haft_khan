class_name Enemy
extends CharacterBody2D

## Shared base for the Jackal, the Vulture and later the Lion. Promoted from the
## training dummy, which had a working version of all of this already.
##
## Holds health, damage, hit pause, knockback, the white flash, death and the
## reset() that Room.reset() calls. Subclasses add only their own state machine
## and attack, through _tick() and _on_reset(). A plain class, no framework.
##
## Contact damage is a continuous Hitbox on the body at hit_pause 0, always on.
## Section 6 gives one damage number per enemy with no separate attack damage,
## and section 5's response to a hit (0.8 s invulnerability, knockback, control
## loss) is the classic contact-damage model, so the telegraph rather than the
## hitbox is what makes an enemy fair to approach.

signal died

const PLAYER_GROUP: StringName = &"player"

@export var max_health: int = 3
## Seconds before coming back unaided. Zero means stay dead until Room.reset(),
## which is what real enemies do; only the test dummy sets it.
@export var respawn_delay: float = 0.0
@export var gravity: float = 1800.0
## Knockback bleeds off at this rate, so a hit shoves and it settles.
@export var knockback_friction: float = 900.0
## Time after a hit during which the enemy drifts on the knockback instead of
## driving its own movement. Without it the AI overwrites velocity on the very
## next tick and the knockback never reads at all.
@export var stagger_time: float = 0.18

var health: int = 0

var _hit_pause_timer: float = 0.0
var _respawn_timer: float = 0.0
var _stagger_timer: float = 0.0
var _home: Vector2
var _player_ref: Node2D

@onready var _visuals: Node2D = $Visuals
@onready var _flash: HitFlash = $HitFlash
@onready var _hurtbox: Area2D = $Hurtbox
## Optional: a passive target such as the test dummy has no contact damage.
@onready var _contact: Hitbox = get_node_or_null("ContactHitbox") as Hitbox


func _ready() -> void:
	_home = global_position
	health = max_health
	_on_ready()


func _physics_process(delta: float) -> void:
	# A frozen enemy freezes whole: the AI stops along with the movement, so a
	# telegraph cannot tick away while the screen is held on the hit.
	if _hit_pause_timer > 0.0:
		_hit_pause_timer -= delta
		return

	if health <= 0:
		if respawn_delay > 0.0:
			_respawn_timer -= delta
			if _respawn_timer <= 0.0:
				reset()
		return

	if _stagger_timer > 0.0:
		_stagger_timer -= delta
		_drift(delta)
		return

	_tick(delta)


## Returns true only when damage was actually applied, so the attacker can tell
## a real hit from one that landed on something already dead.
func take_damage(amount: int, knockback: Vector2, _source: Node2D) -> bool:
	if amount <= 0 or health <= 0:
		return false

	health -= amount
	_flash.flash()
	velocity = knockback
	_stagger_timer = stagger_time

	if health <= 0:
		health = 0
		velocity = Vector2.ZERO
		_respawn_timer = respawn_delay
		_set_present(false)
		died.emit()
	return true


func apply_hit_pause(duration: float) -> void:
	_hit_pause_timer = maxf(_hit_pause_timer, duration)


func is_hit_paused() -> bool:
	return _hit_pause_timer > 0.0


func is_alive() -> bool:
	return health > 0


func is_staggered() -> bool:
	return _stagger_timer > 0.0


func get_home() -> Vector2:
	return _home


## A short white blink, for being hit.
func flash() -> void:
	_flash.flash()


## A lighter shade held for the length of a wind-up, for telegraphing an attack.
func telegraph(seconds: float) -> void:
	_flash.telegraph(seconds)


## The player, found by group rather than by a hard reference or a path up the
## tree. Looked up lazily so enemies do not depend on _ready ordering.
func get_player() -> Node2D:
	if _player_ref == null or not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D
	return _player_ref


## Called by Room.reset() when Rostam respawns, and by respawn_delay.
func reset() -> void:
	health = max_health
	global_position = _home
	velocity = Vector2.ZERO
	_respawn_timer = 0.0
	_hit_pause_timer = 0.0
	_stagger_timer = 0.0
	_flash.clear()
	_set_present(true)
	_on_reset()


func _apply_gravity(delta: float) -> void:
	velocity.y += gravity * delta


func _apply_knockback_friction(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, knockback_friction * delta)


## Subclass hooks. _tick runs only while alive and unfrozen, so a subclass never
## has to check either.
func _on_ready() -> void:
	pass


func _tick(_delta: float) -> void:
	pass


func _on_reset() -> void:
	pass


## How the body moves while riding out knockback. Ground enemies fall; the
## Vulture overrides this to stay airborne.
func _drift(delta: float) -> void:
	_apply_gravity(delta)
	_apply_knockback_friction(delta)
	move_and_slide()


## A dead enemy stops being drawn, stops being hittable and stops dealing
## contact damage, but stays in the tree so reset() can bring it back without
## re-instancing it.
func _set_present(present: bool) -> void:
	_visuals.visible = present
	if present:
		# The broadphase does not know it moved back to its home until the next
		# step, so push the transform through before it can be hit or hit back.
		force_update_transform()
		_hurtbox.force_update_transform()
		if _contact != null:
			_contact.force_update_transform()
	_hurtbox.monitorable = present
	if _contact != null:
		_contact.monitoring = present and _contact.continuous
