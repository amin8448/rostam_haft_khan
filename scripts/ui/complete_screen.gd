extends CanvasLayer

## The end of the slice. Section 8: walking through the far door of the den ends
## it with a title and a restart.

signal restart_requested

@onready var _root: Control = $Screen


func _ready() -> void:
	hide_screen()


func show_screen() -> void:
	_root.visible = true


func hide_screen() -> void:
	_root.visible = false


func is_showing() -> bool:
	return _root.visible


## Polled rather than driven by _unhandled_input, so it behaves the same whether
## the press comes from a pad, a key, or a test.
func _process(_delta: float) -> void:
	if _root.visible and Input.is_action_just_pressed("jump"):
		restart_requested.emit()
