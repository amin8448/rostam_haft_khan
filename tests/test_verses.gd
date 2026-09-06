extends SceneTree

## The Khan 1 verse data and the font that draws it.
##
## Expected:
##   khan1.tres            8 entries, in the order of the verses file
##   beats                 fight, fight, fight, wake, scold, scold, scold, scold
##   beats_in_order        fight, wake, scold
##   beyt 6                marked as paired with the next, and nothing else is
##   every entry           has both a Persian line and an English one
##   Vazirmatn             loads, has Persian glyphs, and shapes beyt 1
##                         right-to-left at a non-zero width
##
## The data is checked rather than the wording: the verses file is the record of
## the text, and this only guards that it survived into the resource intact and
## in order.

const Support = preload("res://tests/test_support.gd")

const VERSES: String = "res://assets/verses/khan1.tres"
const FONT: String = "res://assets/fonts/vazirmatn/Vazirmatn-Regular.ttf"
const EXPECTED_BEATS: Array[StringName] = [
	&"fight", &"fight", &"fight", &"wake", &"scold", &"scold", &"scold", &"scold",
]
## Beyt 6 is the only pair in Khan 1, and it is index 5.
const PAIRED_INDEX: int = 5

var _failures: int = 0


func _physics_process(_delta: float) -> bool:
	_check_verses()
	_check_font()
	quit(Support.report("test_verses", _failures))
	return true


func _check_verses() -> void:
	var verses: VerseSet = load(VERSES) as VerseSet
	if verses == null:
		_failures += 0 if Support.exact("khan1.tres loads as a VerseSet", false, true) else 1
		return

	_failures += 0 if Support.exact("entry count", verses.size(), EXPECTED_BEATS.size()) else 1

	var beats: Array[StringName] = []
	var missing_text: int = 0
	var pairs: Array[int] = []
	for i in verses.size():
		var entry: VerseEntry = verses.get_entry(i)
		beats.append(entry.beat)
		if entry.persian.strip_edges().is_empty() or entry.english.strip_edges().is_empty():
			missing_text += 1
		if entry.paired_with_next:
			pairs.append(i)

	_failures += 0 if Support.exact("beats, in order", str(beats), str(EXPECTED_BEATS)) else 1
	_failures += 0 if Support.exact("entries missing text", missing_text, 0) else 1
	_failures += 0 if Support.exact("the only pair is beyt 6", str(pairs), str([PAIRED_INDEX])) else 1
	_failures += 0 if Support.exact("beats in order of first use",
			str(verses.beats_in_order()), str([&"fight", &"wake", &"scold"])) else 1


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

	var verses: VerseSet = load(VERSES) as VerseSet
	var beyt: String = verses.get_entry(0).persian if verses != null else ""
	var width: float = font.get_string_size(beyt, HORIZONTAL_ALIGNMENT_RIGHT, -1, 28).x
	_failures += 0 if Support.at_least("beyt 1 laid out at 28 px", width, 100.0) else 1

	var server: TextServer = TextServerManager.get_primary_interface()
	var shaped: RID = server.create_shaped_text(
			TextServer.DIRECTION_AUTO, TextServer.ORIENTATION_HORIZONTAL)
	server.shaped_text_add_string(shaped, beyt, font.get_rids(), 28)
	server.shaped_text_shape(shaped)
	_failures += 0 if Support.exact("shaped right to left",
			server.shaped_text_get_inferred_direction(shaped), TextServer.DIRECTION_RTL) else 1
