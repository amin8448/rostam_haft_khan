class_name Glossary
extends Resource

## Terms a player may not know, matched against the English of a verse.
##
## The same file feeds the Journal later (future_systems.md item 5). A term that
## has not turned up in the game yet needs no special handling: it simply never
## matches anything on screen, which is what "stays hidden until it appears"
## amounts to.

@export var entries: Array[GlossaryTerm] = []


## The notes for every term found in the text, in the order the glossary lists
## them, formatted as one line each. Matching ignores case, so a term is found
## however the verse happens to capitalise it.
func notes_for(text: String) -> Array[String]:
	var found: Array[String] = []
	for entry in entries:
		if entry != null and contains_term(text, entry.term):
			found.append("%s: %s" % [entry.term, entry.note])
	return found


## The terms found rather than their notes, for anything that wants to know what
## was matched without the wording. The Journal will want this.
func terms_in(text: String) -> Array[String]:
	var found: Array[String] = []
	for entry in entries:
		if entry != null and contains_term(text, entry.term):
			found.append(entry.term)
	return found


func get_note(term: String) -> String:
	for entry in entries:
		if entry != null and entry.term.nocasecmp_to(term) == 0:
			return entry.note
	return ""


## Whole words only, done by hand rather than with a RegEx so a term with
## punctuation in it needs no escaping. "div" must not match "divide", and
## "babr-e bayan" has to match across its hyphen and its space.
func contains_term(text: String, term: String) -> bool:
	if term.is_empty():
		return false
	var from: int = 0
	while true:
		var at: int = text.findn(term, from)
		if at < 0:
			return false
		var before: String = text[at - 1] if at > 0 else " "
		var after_at: int = at + term.length()
		var after: String = text[after_at] if after_at < text.length() else " "
		if not _is_word_char(before) and not _is_word_char(after):
			return true
		from = at + 1
	return false


func _is_word_char(glyph: String) -> bool:
	if glyph.is_valid_int():
		return true
	return glyph.to_lower() != glyph.to_upper()
