extends CanvasLayer

## The end of the slice: a title card and a restart.
##
## Section 8 reached this by walking through the far door of the den. The
## ending cutscene now gets here first and names itself on the way, so the
## title is set by whoever shows the card rather than fixed in the scene.

signal restart_requested

@onready var _root: Control = $Screen
@onready var _title: Label = $Screen/Title
@onready var _prompt: Label = $Screen/Prompt


func _ready() -> void:
	hide_screen()


## Set by the khan that is ending, so Khan 2 needs no change here.
func set_text(title: String, prompt: String) -> void:
	_title.text = title
	_prompt.text = prompt


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
