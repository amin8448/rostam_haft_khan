class_name Lion
extends Enemy

## The Lion, design doc section 8.
##
## The loop is the whole of it and there is nothing random in it: walk toward
## Rostam for a second or two, pick an attack by distance, telegraph it, do it,
## recover, repeat. A roar every fifteen seconds or so breaks the rhythm and
## hands over an opening.
##
## Swipe and pounce have their own hitboxes, open only inside their windows, so
## the danger is the attack rather than the animal. Unlike the Jackal and the
## Vulture the body deals no contact damage: with it on, the contact box won the
## race against the pounce box every time the Lion landed on Rostam, and the
## invulnerability that followed swallowed the real hit, so a pounce that landed
## squarely did 1 where a pounce that clipped him did 2. The swipe covers the
## body instead, which is what stops standing inside it being safe.
##
## Phase 2 is not run from here. This announces that it has been reached and
## that the final pounce has landed; the arena script owns the sequence, so it
## can be read in one place.

signal phase_two_reached
signal final_pounce_landed
signal defeated

enum State { ASLEEP, APPROACH, TELEGRAPH, SWIPE, POUNCE, RECOVER, ROAR, PINNED }
enum Attack { NONE, SWIPE, POUNCE }

@export var walk_speed: float = 90.0
@export_enum("Left:-1", "Right:1") var start_facing: int = -1

@export_group("Approach")
## Seconds of walking between attacks, section 8's "1 to 2 s".
@export var approach_min: float = 1.0
@export var approach_max: float = 2.0

@export_group("Swipe")
## Close range: inside this, it swipes.
@export var swipe_range: float = 150.0
@export var swipe_telegraph: float = 0.4
@export var swipe_active: float = 0.18
@export var swipe_recover: float = 0.35
@export var swipe_damage: int = 2
@export var swipe_size: Vector2 = Vector2(150, 56)
## The swipe starts at the Lion's own centre rather than at its nose, so
## standing inside it is not a safe place to stand. Section 8 asks for a wide
## short-range box and this is what makes it wide.
@export var swipe_reach: float = 0.0

@export_group("Pounce")
## Medium range: outside swipe_range and inside this, it pounces.
@export var pounce_range: float = 400.0
@export var pounce_telegraph: float = 0.5
@export var pounce_air_time: float = 0.7
@export var pounce_max_speed: float = 520.0
@export var pounce_land_active: float = 0.15
## Still and exposed after landing. Section 8's 0.8 s, and the main opening.
@export var pounce_recover: float = 0.8
@export var pounce_damage: int = 2
@export var pounce_size: Vector2 = Vector2(120, 40)
@export var pounce_shake: float = 5.0

@export_group("Roar")
@export var roar_interval: float = 15.0
@export var roar_time: float = 1.0

@export_group("Phase two")
## Below this fraction of full health the Lion stops choosing.
@export var phase_two_fraction: float = 0.25

var state: State = State.ASLEEP
var facing: int = -1

var _timer: float = 0.0
var _roar_timer: float = 0.0
var _attack: Attack = Attack.NONE
var _pounce_target: Vector2 = Vector2.ZERO
var _final_pounce: bool = false
var _phase_two: bool = false
var _airborne_ticks: int = 0

@onready var _swipe: Hitbox = $SwipeHitbox
@onready var _pounce: Hitbox = $PounceHitbox


func get_facing() -> int:
	return facing


func is_awake() -> bool:
	return state != State.ASLEEP


func in_phase_two() -> bool:
	return _phase_two


## Called by the arena when Rostam crosses the trigger line.
func wake() -> void:
	if state != State.ASLEEP:
		return
	state = State.APPROACH
	_timer = approach_max
	_roar_timer = roar_interval


## Section 8's phase 2 opener: one last pounce that always connects, aimed at
## wherever Rostam is standing when it starts.
func begin_final_pounce() -> void:
	_final_pounce = true
	_swipe.deactivate()
	_pounce.deactivate()
	_attack = Attack.POUNCE
	state = State.TELEGRAPH
	_timer = pounce_telegraph
	telegraph(pounce_telegraph)


## Beaten, but left on screen: Rakhsh throws it across the arena, so it must
## still be there to throw. Inert from here on.
func set_defeated() -> void:
	health = 0
	state = State.PINNED
	velocity = Vector2.ZERO
	_swipe.deactivate()
	_pounce.deactivate()
	if _contact != null:
		_contact.monitoring = false
	_hurtbox.monitorable = false
	defeated.emit()


func take_damage(amount: int, knockback: Vector2, source: Node2D) -> bool:
	if state == State.PINNED:
		return false
	var applied: bool = super(amount, knockback, source)
	if applied and not _phase_two and health <= int(float(max_health) * phase_two_fraction):
		_phase_two = true
		phase_two_reached.emit()
	return applied


func _on_ready() -> void:
	facing = start_facing
	_apply_facing()
	_swipe.damage = swipe_damage
	_swipe.size = swipe_size
	_pounce.damage = pounce_damage
	_pounce.size = pounce_size
	_apply_boxes()


func _on_reset() -> void:
	state = State.ASLEEP
	facing = start_facing
	_timer = 0.0
	_roar_timer = 0.0
	_attack = Attack.NONE
	_final_pounce = false
	_phase_two = false
	_airborne_ticks = 0
	_apply_facing()
	_swipe.deactivate()
	_pounce.deactivate()


func _tick(delta: float) -> void:
	if state != State.ASLEEP and state != State.PINNED:
		_roar_timer = maxf(_roar_timer - delta, 0.0)

	match state:
		State.ASLEEP, State.PINNED:
			velocity.x = 0.0
		State.APPROACH:
			_approach(delta)
		State.TELEGRAPH:
			_telegraph_tick(delta)
		State.SWIPE:
			_swipe_tick(delta)
		State.POUNCE:
			_pounce_tick(delta)
		State.RECOVER, State.ROAR:
			_wait(delta)

	_apply_gravity(delta)
	move_and_slide()


func _approach(delta: float) -> void:
	var player: Node2D = get_player()
	if player == null:
		velocity.x = 0.0
		return

	_face_toward(player.global_position.x)
	velocity.x = float(facing) * walk_speed
	_timer -= delta
	if _timer > 0.0:
		return

	if _roar_timer <= 0.0:
		_begin_roar()
		return

	var distance: float = absf(player.global_position.x - global_position.x)
	if distance <= swipe_range:
		_begin_attack(Attack.SWIPE)
	elif distance <= pounce_range:
		_begin_attack(Attack.POUNCE)
	else:
		# Too far for either: keep walking rather than committing to nothing.
		_timer = approach_min


func _begin_attack(attack: Attack) -> void:
	_attack = attack
	state = State.TELEGRAPH
	velocity.x = 0.0
	_timer = swipe_telegraph if attack == Attack.SWIPE else pounce_telegraph
	telegraph(_timer)


func _begin_roar() -> void:
	state = State.ROAR
	velocity.x = 0.0
	_timer = roar_time
	_roar_timer = roar_interval
	telegraph(roar_time)


func _telegraph_tick(delta: float) -> void:
	velocity.x = 0.0
	_timer -= delta
	if _timer > 0.0:
		return

	if _attack == Attack.SWIPE:
		state = State.SWIPE
		_timer = swipe_active
		_apply_boxes()
		_swipe.activate()
	else:
		_launch_pounce()


## The pounce commits to where Rostam was when the crouch ended, not to where he
## is. That is what makes it dodgeable.
func _launch_pounce() -> void:
	var player: Node2D = get_player()
	_pounce_target = player.global_position if player != null else global_position
	_face_toward(_pounce_target.x)

	var dx: float = _pounce_target.x - global_position.x
	velocity.x = clampf(dx / maxf(pounce_air_time, 0.01), -pounce_max_speed, pounce_max_speed)
	velocity.y = -gravity * pounce_air_time * 0.5

	state = State.POUNCE
	_airborne_ticks = 0
	_apply_boxes()


func _pounce_tick(_delta: float) -> void:
	_airborne_ticks += 1
	# A few ticks of grace so the launch frame does not count as a landing.
	if _airborne_ticks < 4 or not is_on_floor():
		return

	velocity.x = 0.0
	_pounce.activate()
	_timer = pounce_land_active
	state = State.RECOVER
	_shake_camera()
	if _final_pounce:
		final_pounce_landed.emit()


func _swipe_tick(delta: float) -> void:
	velocity.x = 0.0
	_timer -= delta
	if _timer > 0.0:
		return
	_swipe.deactivate()
	state = State.RECOVER
	_timer = swipe_recover


func _wait(delta: float) -> void:
	velocity.x = 0.0
	_timer -= delta
	if _timer > 0.0:
		return

	# The landing box closes partway through recovery, leaving the rest of it as
	# the opening section 8 asks for.
	if _pounce.is_active():
		_pounce.deactivate()
		_timer = pounce_recover
		return
	if state == State.RECOVER or state == State.ROAR:
		state = State.APPROACH
		_timer = randf_range(approach_min, approach_max)


func _face_toward(x: float) -> void:
	var wanted: int = 1 if x > global_position.x else -1
	if wanted == facing:
		return
	facing = wanted
	_apply_facing()
	_apply_boxes()


func _apply_facing() -> void:
	_visuals.scale.x = float(facing)


## The attack boxes sit outside Visuals so the telegraph flash does not recolour
## them, so their side is set here rather than by a parent's scale.
func _apply_boxes() -> void:
	_swipe.offset = Vector2(float(facing) * (swipe_reach + swipe_size.x * 0.5), 0.0)
	_pounce.offset = Vector2(0.0, pounce_size.y * 0.5)


func _shake_camera() -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera != null and camera.has_method("shake"):
		camera.shake(pounce_shake)
