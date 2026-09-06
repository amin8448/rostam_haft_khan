class_name VerseCutscene
extends Node

## A khan's ending: the verses playing over whatever the animator drops into the
## Animation node.
##
## One script and one timed sequence, read top to bottom, the same rule as the
## phase 2 chain in the den. It pins Rostam for its duration and hands control
## back on the title card.
##
## Nothing in here is Khan 1. The scene supplies the verses file, the beat
## schedule and the title, so Khan 2 is a second scene with its own resource and
## its own beat names and no new code.

signal finished

## A step that shows nothing: the pause a beat with no verses under it becomes.
const NO_VERSE: int = -1

@export_file("*.tres") var verses_path: String = "res://assets/verses/khan1.tres"
## The running order. Each entry names a beat from the verses file and says how
## long its beyts hold.
@export var schedule: Array[CutsceneBeat] = []
@export var title_text: String = "Khan 1: The Lion"
@export var prompt_text: String = "Press jump to continue"
## Jump held this long skips the rest. A tap advances one step instead. Never
## trap the player in a cutscene.
@export var skip_hold_time: float = 0.5

@export_group("Wiring")
@export var stage_path: NodePath = ^"Stage"
@export var panel_path: NodePath = ^"VersePanel"

var _manager: Node
var _verses: VerseSet
## The running order as two parallel arrays: which beyt each step shows, and how
## long it holds. NO_VERSE means a pause.
var _step_index: Array[int] = []
var _step_hold: Array[float] = []
var _step: int = -1
var _time_left: float = 0.0
var _held: float = 0.0
var _playing: bool = false
var _played: Array[int] = []

@onready var _stage: CanvasLayer = get_node_or_null(stage_path) as CanvasLayer
@onready var _panel: VersePanel = get_node_or_null(panel_path) as VersePanel


func _ready() -> void:
	if _stage != null:
		_stage.visible = false


## Started by whatever ends the fight. The manager is passed in rather than
## looked up, because the only thing this needs from it is the title card.
func play(manager: Node) -> void:
	if _playing:
		return
	_manager = manager
	_verses = load(verses_path) as VerseSet
	_build_order()

	_played.clear()
	_step = -1
	_held = 0.0
	_playing = true
	if _stage != null:
		_stage.visible = true
	if _panel != null:
		_panel.reset()
	_pin(true)
	_advance()


func is_playing() -> bool:
	return _playing


## Every beyt this has put on screen, in the order it went up. The ending test
## reads this to check the whole khan played.
func get_played_indices() -> Array[int]:
	return _played.duplicate()


## The running order, built once and then only walked: every beat in the
## schedule, its beyts in the order the verses file lists them, a pair counted as
## one step, and a pause for a beat the file has nothing under.
func _build_order() -> void:
	_step_index.clear()
	_step_hold.clear()
	for beat in schedule:
		if beat == null:
			continue
		var indices: Array[int] = []
		if _verses != null:
			indices = _verses.indices_for_beat(beat.beat)
		if indices.is_empty():
			_step_index.append(NO_VERSE)
			_step_hold.append(beat.hold)
			continue
		var i: int = 0
		while i < indices.size():
			var index: int = indices[i]
			var entry: VerseEntry = _verses.get_entry(index)
			var span: int = 2 if entry != null and entry.paired_with_next else 1
			_step_index.append(index)
			_step_hold.append(beat.hold * float(span))
			i += span


func _physics_process(delta: float) -> void:
	if not _playing:
		return

	# Skipping first: a step that has run out of time still yields to a jump the
	# player is already holding.
	if Input.is_action_pressed("jump"):
		_held += delta
		if _held >= skip_hold_time:
			_show_title_card()
		return
	if _held > 0.0:
		# A tap moves on. A hold has already skipped by the time it is released.
		_held = 0.0
		_advance()
		return

	_time_left -= delta
	if _time_left <= 0.0:
		_advance()


func _advance() -> void:
	_step += 1
	if _step >= _step_index.size():
		_show_title_card()
		return

	var index: int = _step_index[_step]
	_time_left = _step_hold[_step]
	if index == NO_VERSE or _panel == null:
		if _panel != null:
			_panel.hide_panel()
		return

	var used: int = _panel.show_from(_verses, index)
	for offset in used:
		_played.append(index + offset)


## The end of it, however it was reached. The same screen the far door of the den
## shows, so continuing behaves the way it always has.
func _show_title_card() -> void:
	_playing = false
	if _panel != null:
		_panel.hide_panel()
	if _stage != null:
		_stage.visible = false
	_pin(false)
	if _manager != null and _manager.has_method("show_title_card"):
		_manager.show_title_card(title_text, prompt_text)
	finished.emit()


func _pin(pinned: bool) -> void:
	var player: Node = get_tree().get_first_node_in_group(Enemy.PLAYER_GROUP)
	if player != null and player.has_method("set_pinned"):
		player.set_pinned(pinned)
