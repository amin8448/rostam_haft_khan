extends Enemy

## Test fixture. A stationary target for the combat tests: no AI, no attacks and
## no contact damage, so it can be stood next to safely and the only thing under
## measurement is Rostam's mace.
##
## No class_name on purpose: fixtures must not register globals into the shipped
## game. Tests reach it by instantiating this scene.
##
## Everything it used to do itself lives in Enemy now; all that is left is
## falling and bleeding off knockback.

func _tick(delta: float) -> void:
	_apply_gravity(delta)
	_apply_knockback_friction(delta)
	move_and_slide()
