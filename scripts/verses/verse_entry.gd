class_name VerseEntry
extends Resource

## One beyt: a line of Ferdowsi in two hemistichs, its English, and the beat of
## the cutscene it belongs to.

@export_multiline var persian: String = ""
@export_multiline var english: String = ""
## Which stretch of the cutscene this line plays over. The data carries the beat
## and never the seconds, so the cutscene decides pacing and the verses file
## stays a record of the text.
@export var beat: StringName = &""
## Beyts 6 and 7 of Khan 1 are one sentence and are always shown together. Any
## khan can mark a pair the same way.
@export var paired_with_next: bool = false
