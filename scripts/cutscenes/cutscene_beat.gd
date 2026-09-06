class_name CutsceneBeat
extends Resource

## One step of a khan's ending: a beat name the verses file also uses, and how
## long each of its beyts holds.

## Matches the beat column of the verses file. A beat the file has nothing under
## is a pause, which is how dawn gets its two seconds with nothing said.
@export var beat: StringName = &""
## Seconds one beyt of this beat stays up, or how long the pause lasts. A pair
## holds for two of these, because it is two lines to read.
@export var hold: float = 3.0
