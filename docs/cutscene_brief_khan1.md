# Khan 1 ending cutscene: brief for the animator

## What it is

The closing scene of the first chapter of a 2D side-scrolling action game based on the
Shahnameh's Haft Khan-e Rostam. The scene is Ferdowsi's: Rostam has slept through the night
in a reed bed; a lion attacked; his horse Rakhsh killed it alone. Rostam wakes to the dead
lion and, instead of thanking Rakhsh, scolds him for risking his life without waking him.

Ferdowsi's own verses play over the scene, in Persian with English beneath, one beyt at a
time, on the right third of the screen. The animation fills the rest. See
`docs/verses/khan1.md` for the exact lines and their English.

## Tone

Lonely, ancient, quiet. Dawn over a reed bed. No dialogue is spoken; the verses carry it.
The scolding should read as love expressed as anger, and Rakhsh should read as unbothered.

## Two scenes

There are two cutscenes in Khan 1, and the brief covers both.

**Scene 1, the approach (before the fight).** Night in the reed bed. Rostam asleep, Rakhsh
standing. The lion comes through the reeds toward the sleeping man; Rakhsh sees it first.
About 8 to 10 seconds, no verses, ending on the lion springing. The game then cuts to the
fight. The lion's roar and its charge carry this scene, so sound matters here more than
in scene 2.

**Scene 2, the ending (after the fight).** Described in full below.

## Beats and timings (scene 2)

The game plays the verses on a schedule the animator can match. Timings below are the
defaults and can change to fit the animation; tell us the final ones and we set them.

| Beat | Duration | Verses shown | What is on screen |
|------|----------|--------------|-------------------|
| fight | 9 s (3 per beyt) | 1, 2, 3 | Night. Rakhsh and the lion: hooves to the head, teeth in the back, beaten against the ground. Rostam asleep at the edge. Can be stylised or partly implied; the verses describe it. |
| dawn | 2 s | none | Light rises over the reeds. The lion lies dead. |
| wake | 3 s | 4 | Rostam wakes, sees the lion, understands. |
| scold | 12 s (3 per beyt, 6 and 7 together) | 5, 6 and 7, 8 | Rostam on his feet before Rakhsh. On 6 and 7 he means the gorz (his ox-headed mace) and his helm; on 8, "why did you not cry out". Rakhsh's reaction closes it. |
| title | held | none | Cut to black. The game draws the title card. |

Total about 26 s. Shorter is fine; longer only if it earns it.

## Characters

- **Rostam**: the hero. Big, bearded, the tiger-skin coat (babr-e bayan) and the ox-headed
  mace (gorz) are his signature items in the text.
- **Rakhsh**: his horse. Dappled or roan in the text ("Rakhsh" means radiant). Loyal,
  fierce, and in this scene, the one who did the work.
- **The lion**: dead by the time the scene starts in earnest.

The game's own art is not finished; the cutscene need not match anything yet. Whatever
style the animator chooses will inform the game's style, not the other way round.

## Technical

- Game engine: Godot 4. Target 1152 x 648 game resolution; the cutscene can be 1920 x 1080
  and will be scaled.
- Delivery formats we can use directly, in order of preference:
  1. A PNG image sequence (frame-numbered) or a sprite sheet per beat, 24 fps.
  2. A video file in Ogg Theora (.ogv), which Godot plays natively. Other codecs need
     converting.
  3. A Godot scene with an AnimationPlayer, if the animator works in Godot.
- The verses are drawn by the game on top, on the right third of the screen. Keep that
  region visually quiet (sky, reeds, negative space) so the text reads.
- No audio yet. If the animator wants to propose sound, we are listening.

## Where it goes

`scenes/cutscenes/khan1_ending.tscn` has an empty node named `Animation`, at `Stage/Animation`,
placed at the centre of a 1152 x 648 screen. The delivered animation is dropped in there; the
dark `Backdrop` beside it is a placeholder and can be removed once there is something to show.
The beat schedule is an exported array on the same scene: one entry per beat, each naming a
beat from the verses file and how long one of its beyts holds.
