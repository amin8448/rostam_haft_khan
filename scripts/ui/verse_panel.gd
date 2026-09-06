class_name VersePanel
extends CanvasLayer

## One beyt at a time on the right third of the screen: the Persian as Ferdowsi
## wrote it, the English under it smaller, and a note for any term the player has
## no reason to know yet.
##
## The panel holds no timing of its own. The cutscene says show this, then that,
## then hide; this only draws. That is what lets Khan 2 reuse it with nothing but
## its own verses file.

signal verse_shown(entries: Array[VerseEntry])

@export_file("*.tres") var glossary_path: String = "res://assets/verses/glossary.tres"
@export var fade_time: float = 0.5
## The English arrives a beat after the Persian, so the eye reaches the original
## line first.
@export var english_delay: float = 0.3
## A term is explained the first time it is read and not again. Without this,
## Rostam and Rakhsh carry a note under nearly every beyt and the notes stop
## being worth reading. Turn it off and every match is always explained.
@export var notes_once: bool = true

var _glossary: Glossary
var _seen: Dictionary = {}
var _show_count: int = 0
var _tween: Tween

@onready var _root: Control = $Panel
@onready var _persian: Label = $Panel/Lines/Persian
@onready var _english: Label = $Panel/Lines/English
@onready var _notes: Label = $Panel/Lines/Notes


func _ready() -> void:
	_glossary = load(glossary_path) as Glossary
	hide_panel()


## Shows the beyt at `index`, together with the one after it when the data marks
## the two a pair. Returns how many entries went on screen, so the caller knows
## where to carry on from.
func show_from(verses: VerseSet, index: int) -> int:
	if verses == null or index < 0 or index >= verses.size():
		return 0
	var entries: Array[VerseEntry] = [verses.get_entry(index)]
	if entries[0].paired_with_next and index + 1 < verses.size():
		entries.append(verses.get_entry(index + 1))
	show_entries(entries)
	return entries.size()


## A pair is drawn as two lines in the same labels rather than as a second panel,
## because beyts 6 and 7 are one sentence and reading them apart loses it.
func show_entries(entries: Array[VerseEntry]) -> void:
	var persian: PackedStringArray = PackedStringArray()
	var english: PackedStringArray = PackedStringArray()
	var notes: PackedStringArray = PackedStringArray()
	for entry in entries:
		if entry == null:
			continue
		persian.append(entry.persian)
		english.append(entry.english)
		for note in _fresh_notes(entry.english):
			if not notes.has(note):
				notes.append(note)

	_persian.text = "\n".join(persian)
	_english.text = "\n".join(english)
	_notes.text = "\n".join(notes)
	_notes.visible = notes.size() > 0

	_show_count += 1
	_root.visible = true
	_fade_in()
	verse_shown.emit(entries)


func hide_panel() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_root.visible = false


func is_showing() -> bool:
	return _root.visible


## How many times the panel has been asked to show something. The ending test
## counts these to check every beyt played.
func get_show_count() -> int:
	return _show_count


## Back to the state a fresh run starts in: nothing on screen, nothing explained
## yet. Called when the slice restarts, or the second run through the ending
## would show no notes at all.
func reset() -> void:
	_seen.clear()
	_show_count = 0
	_persian.text = ""
	_english.text = ""
	_notes.text = ""
	hide_panel()


func get_persian_text() -> String:
	return _persian.text


func get_english_text() -> String:
	return _english.text


func get_notes_text() -> String:
	return _notes.text


func _fresh_notes(english: String) -> Array[String]:
	if _glossary == null:
		return []
	var out: Array[String] = []
	for term in _glossary.terms_in(english):
		if notes_once and _seen.has(term):
			continue
		_seen[term] = true
		out.append("%s: %s" % [term, _glossary.get_note(term)])
	return out


func _fade_in() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_root.modulate.a = 0.0
	_english.modulate.a = 0.0
	_notes.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_root, "modulate:a", 1.0, fade_time)
	_tween.tween_interval(english_delay)
	_tween.tween_property(_english, "modulate:a", 1.0, fade_time)
	_tween.parallel().tween_property(_notes, "modulate:a", 1.0, fade_time)
