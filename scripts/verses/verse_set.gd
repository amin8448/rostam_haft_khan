class_name VerseSet
extends Resource

## Every beyt of one khan, in order.
##
## Nothing here is specific to Khan 1: another khan needs only its own resource
## and its own beat names, and the cutscene reads it through the same interface.

@export var entries: Array[VerseEntry] = []


func size() -> int:
	return entries.size()


func get_entry(index: int) -> VerseEntry:
	if index < 0 or index >= entries.size():
		return null
	return entries[index]


## The indices belonging to one beat, in order.
func indices_for_beat(beat: StringName) -> Array[int]:
	var found: Array[int] = []
	for i in entries.size():
		if entries[i] != null and entries[i].beat == beat:
			found.append(i)
	return found


## Every beat name in the order it first appears, so a cutscene can walk the
## khan without being told what its beats are called.
func beats_in_order() -> Array[StringName]:
	var order: Array[StringName] = []
	for entry in entries:
		if entry != null and not order.has(entry.beat):
			order.append(entry.beat)
	return order
