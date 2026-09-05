extends CanvasLayer

## One line of text on entering a room, section 7's "short text on entering a
## room is enough for now". Fades in, holds, fades out.

@export var hold_time: float = 2.0
@export var fade_time: float = 0.3

@onready var _label: Label = $Label


func _ready() -> void:
	_label.modulate.a = 0.0


func show_text(text: String) -> void:
	if text.is_empty():
		return
	_label.text = text
	var tween: Tween = create_tween()
	tween.tween_property(_label, "modulate:a", 1.0, fade_time)
	tween.tween_interval(hold_time)
	tween.tween_property(_label, "modulate:a", 0.0, fade_time)
