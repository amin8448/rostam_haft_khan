extends SceneTree

## The Khan 1 verse data, the glossary, the font that draws them, and the panel
## that puts them on screen.
##
## Expected:
##   khan1.tres            8 entries, in the order of the verses file
##   beats                 fight, fight, fight, wake, scold, scold, scold, scold
##   beats_in_order        fight, wake, scold
##   beyt 6                marked as paired with the next, and nothing else is
##   every entry           has both a Persian line and an English one
##   Vazirmatn             loads, has Persian glyphs, and shapes beyt 1
##                         right-to-left at a non-zero width
##   glossary.tres         has the terms from docs/glossary.md, matched as whole
##                         words: "div" is not found inside "divide"
##   the panel             holds the exact Persian and English of what it was
##                         shown, draws the Persian right to left in Vazirmatn,
##                         shows beyts 6 and 7 together as the pair they are,
##                         puts the Kayanid and Mazandaran notes under beyt 7,
##                         and hides on request
##
## The data is checked rather than the wording: the verses file is the record of
## the text, and this only guards that it survived into the resource intact and
## in order.

const Support = preload("res://tests/test_support.gd")

const VERSES: String = "res://assets/verses/khan1.tres"
const GLOSSARY: String = "res://assets/verses/glossary.tres"
const FONT: String = "res://assets/fonts/vazirmatn/Vazirmatn-Regular.ttf"
const PANEL: String = "res://scenes/ui/verse_panel.tscn"
const EXPECTED_BEATS: Array[StringName] = [
	&"fight", &"fight", &"fight", &"wake", &"scold", &"scold", &"scold", &"scold",
]
## Beyt 6 is the only pair in Khan 1, and it is index 5.
const PAIRED_INDEX: int = 5

var _verses: VerseSet
var _panel: VersePanel
var _failures: int = 0


func _initialize() -> void:
	_verses = load(VERSES) as VerseSet
	_panel = (load(PANEL) as PackedScene).instantiate() as VersePanel
	root.add_child(_panel)


func _physics_process(_delta: float) -> bool:
	# _ready has not run at _initialize time, so the panel is only usable here.
	_check_verses()
	_check_font()
	_check_glossary()
	_check_panel()
	quit(Support.report("test_verses", _failures))
	return true


func _check_verses() -> void:
	if _verses == null:
		_failures += 0 if Support.exact("khan1.tres loads as a VerseSet", false, true) else 1
		return

	_failures += 0 if Support.exact("entry count", _verses.size(), EXPECTED_BEATS.size()) else 1

	var beats: Array[StringName] = []
	var missing_text: int = 0
	var pairs: Array[int] = []
	for i in _verses.size():
		var entry: VerseEntry = _verses.get_entry(i)
		beats.append(entry.beat)
		if entry.persian.strip_edges().is_empty() or entry.english.strip_edges().is_empty():
			missing_text += 1
		if entry.paired_with_next:
			pairs.append(i)

	_failures += 0 if Support.exact("beats, in order", str(beats), str(EXPECTED_BEATS)) else 1
	_failures += 0 if Support.exact("entries missing text", missing_text, 0) else 1
	_failures += 0 if Support.exact("the only pair is beyt 6", str(pairs), str([PAIRED_INDEX])) else 1
	_failures += 0 if Support.exact("beats in order of first use",
			str(_verses.beats_in_order()), str([&"fight", &"wake", &"scold"])) else 1


## Guards the font being present and usable, since it is a downloaded asset that
## the whole ending depends on and a missing one would only show at runtime.
func _check_font() -> void:
	var font: FontFile = load(FONT) as FontFile
	if font == null:
		_failures += 0 if Support.exact("Vazirmatn loads", false, true) else 1
		return

	# Three Persian letters from beyt 1: seen, kheh, sheen.
	var glyphs: int = 0
	for letter in ["س", "خ", "ش"]:
		if font.has_char(letter.unicode_at(0)):
			glyphs += 1
	_failures += 0 if Support.exact("has Persian glyphs", glyphs, 3) else 1

	var beyt: String = _verses.get_entry(0).persian if _verses != null else ""
	var width: float = font.get_string_size(beyt, HORIZONTAL_ALIGNMENT_RIGHT, -1, 28).x
	_failures += 0 if Support.at_least("beyt 1 laid out at 28 px", width, 100.0) else 1

	var server: TextServer = TextServerManager.get_primary_interface()
	var shaped: RID = server.create_shaped_text(
			TextServer.DIRECTION_AUTO, TextServer.ORIENTATION_HORIZONTAL)
	server.shaped_text_add_string(shaped, beyt, font.get_rids(), 28)
	server.shaped_text_shape(shaped)
	_failures += 0 if Support.exact("shaped right to left",
			server.shaped_text_get_inferred_direction(shaped), TextServer.DIRECTION_RTL) else 1


func _check_glossary() -> void:
	var book: Glossary = load(GLOSSARY) as Glossary
	if book == null:
		_failures += 0 if Support.exact("glossary.tres loads as a Glossary", false, true) else 1
		return

	_failures += 0 if Support.at_least("glossary terms", float(book.entries.size()), 8.0) else 1
	_failures += 0 if Support.exact("case is ignored",
			book.contains_term("this gorz and this helm", "Gorz"), true) else 1
	# Whole words only: without that, "div" is in "divide" and half the English
	# picks up notes it should not have.
	_failures += 0 if Support.exact("a term is not found inside a longer word",
			book.contains_term("he divided the spoils", "div"), false) else 1
	_failures += 0 if Support.exact("a term with a space and a hyphen is found",
			book.contains_term("wearing the babr-e bayan", "babr-e bayan"), true) else 1


func _check_panel() -> void:
	if _panel == null or _verses == null:
		_failures += 0 if Support.exact("the panel instantiates", false, true) else 1
		return

	_failures += 0 if Support.exact("hidden until it is shown something",
			_panel.is_showing(), false) else 1

	var first: VerseEntry = _verses.get_entry(0)
	var used: int = _panel.show_from(_verses, 0)
	_failures += 0 if Support.exact("beyt 1 is shown on its own", used, 1) else 1
	_failures += 0 if Support.exact("the panel is up", _panel.is_showing(), true) else 1
	_failures += 0 if Support.exact("the Persian label holds beyt 1",
			_panel.get_persian_text(), first.persian) else 1
	_failures += 0 if Support.exact("the English label holds beyt 1",
			_panel.get_english_text(), first.english) else 1
	_failures += 0 if Support.exact("beyt 1 explains Rakhsh",
			_panel.get_notes_text().begins_with("Rakhsh:"), true) else 1

	# Rakhsh is named again in beyt 5 and must not be explained twice.
	_panel.show_from(_verses, 4)
	_failures += 0 if Support.exact("a term is only explained once",
			_panel.get_notes_text().contains("Rakhsh:"), false) else 1

	# The pair. Beyts 6 and 7 are one sentence, so they go up together.
	var sixth: VerseEntry = _verses.get_entry(PAIRED_INDEX)
	var seventh: VerseEntry = _verses.get_entry(PAIRED_INDEX + 1)
	used = _panel.show_from(_verses, PAIRED_INDEX)
	_failures += 0 if Support.exact("beyts 6 and 7 are shown together", used, 2) else 1
	_failures += 0 if Support.exact("both Persian lines are up",
			_panel.get_persian_text(), "%s\n%s" % [sixth.persian, seventh.persian]) else 1
	_failures += 0 if Support.exact("both English lines are up",
			_panel.get_english_text(), "%s\n%s" % [sixth.english, seventh.english]) else 1
	var notes: String = _panel.get_notes_text()
	_failures += 0 if Support.exact("beyt 7 explains Kayanid",
			notes.contains("Kayanid:"), true) else 1
	_failures += 0 if Support.exact("beyt 7 explains Mazandaran",
			notes.contains("Mazandaran:"), true) else 1

	var persian_label: Label = _panel.get_node("Panel/Lines/Persian") as Label
	_failures += 0 if Support.exact("the Persian is drawn right to left",
			persian_label.text_direction, Control.TEXT_DIRECTION_RTL) else 1
	_failures += 0 if Support.exact("the Persian is drawn in Vazirmatn",
			persian_label.get_theme_font("font").resource_path, FONT) else 1
	_failures += 0 if Support.at_least("the Persian is larger than the English",
			float(persian_label.get_theme_font_size("font_size")),
			float((_panel.get_node("Panel/Lines/English") as Label)
					.get_theme_font_size("font_size")) + 1.0) else 1

	_failures += 0 if Support.exact("show calls counted", _panel.get_show_count(), 3) else 1
	_panel.hide_panel()
	_failures += 0 if Support.exact("hides on request", _panel.is_showing(), false) else 1

	_panel.reset()
	_panel.show_from(_verses, 0)
	_failures += 0 if Support.exact("a reset run explains Rakhsh again",
			_panel.get_notes_text().begins_with("Rakhsh:"), true) else 1
	_panel.hide_panel()
