# Khan 1: The Lion. Vertical slice design

## 1. What we are building

A short, complete, playable slice: Rostam travels through the reed marshes toward the lion's
den, fights two enemy types along the way, and faces the Lion. Everything is placeholder art.
The goal is that movement, combat and the camera feel good. If this slice is fun with
rectangles, the other six khans reuse its systems.

Length target: 5 to 8 minutes for a first playthrough.

## 2. The source and the twist

In the Shahnameh, Rostam and his horse Rakhsh camp in a reed bed. A lion attacks at night while
Rostam sleeps. Rakhsh fights and kills it alone. Rostam wakes, scolds Rakhsh for taking the
risk, and they move on.

In the game, the player fights the Lion. When the Lion drops to about 25 percent health it
enters a rage phase, pounces and pins Rostam (short scripted moment, controls locked). Rakhsh
charges in from off-screen and finishes the fight. This keeps the original story beat, gives
the player a real fight, and introduces Rakhsh as a character the game will later turn into a
mechanic (a callable ally in Khans 2 and 3, where the story has him save Rostam again).

Tone: lonely, ancient, quiet. Reeds, wind, dusk. No dialogue trees. Short text on entering a
room is enough for now.

## 3. Controls

Both must work from day one. Use Godot's input map with a keyboard event and a joypad event
on every action.

| Action    | Keyboard          | Gamepad (Xbox layout)     |
|-----------|-------------------|---------------------------|
| move_left | Left arrow, A     | Left stick, D-pad left    |
| move_right| Right arrow, D    | Left stick, D-pad right   |
| jump      | Space             | A (bottom face button)    |
| attack    | Z, J              | X (left face button)      |
| dash      | Shift, K          | RT or B                   |
| interact  | E, Up arrow       | Y (top face button)       |
| pause     | Escape            | Start                     |

Dash is defined in the input map now but implemented in a later session.

## 4. Movement feel

Starting values were tuned by playtesting. Session 1 confirmed these on keyboard and
controller; they are the baseline the headless tests in `tests/` now guard. All remain
`@export` variables.

- Run speed: 320 px/s. Acceleration to full speed in about 0.1 s, deceleration in about
  0.08 s. Movement should feel immediate, not floaty.
- Jump: variable height. Holding the button gives full height; releasing early cuts upward
  velocity (multiply velocity.y by 0.4 on release while rising). Full jump height about 3.7
  tiles, tap jump about 0.9 tiles.
- Gravity: heavier when falling than when rising (fall gravity about 1.6x rise gravity).
  Cap fall speed at 900 px/s.
- Coyote time: 0.1 s after walking off a ledge, jump still works.
- Jump buffer: 0.1 s. Pressing jump just before landing triggers a jump on landing.
- Full air control.
- Sprite flips to face movement direction. Attacks face the sprite direction.
- Tile size: 32 px. Rostam collision capsule about 24 x 56 px.

## 5. Combat feel

- Rostam fights with the gorz, the ox-headed mace of the Shahnameh, not a sword.
- Three-hit ground combo on repeated `attack` presses. Each swing is a separate hitbox
  (Area2D) enabled for a short window. Rough timings: swing 1 and 2 about 0.25 s each, swing 3
  about 0.35 s with a bigger hitbox and more knockback. Combo resets if no input within 0.4 s
  after a swing.
- The two quick swings do not move Rostam. He plants and movement input is ignored until the
  swing ends; being rooted is what makes them feel committed. The finisher lunges about 20 px
  forward, so the third hit reads as heavier in movement as well as in reach, knockback and
  duration. A 12 px step on every swing was tried first and cut: stepping on the quick swings
  suits a Hades-like game and fights the grounded feel this one wants.
- One air attack (single swing, no combo). Its box is bigger than the ground swings and
  sits above Rostam's head rather than in front of him, so it sweeps the space overhead.
- Hit pause: freeze both attacker and target for 0.05 s on a successful hit. This is the single
  biggest contributor to "crunchy" combat; do not skip it.
- Knockback on hit for enemies (and a small self recoil for Rostam on hitting a boss).
- Rostam health: 5 hits. On taking damage: 0.8 s of invulnerability with a flicker,
  small knockback away from the source, brief control loss (0.15 s).
- Death: fade to black, respawn at the room entrance of the current room, enemies reset.
  No death penalty in this slice.
- Simple HUD: five health pips top-left. Nothing else yet.

## 6. Enemies

Two types, both dumb on purpose. Patterns matter more than intelligence.

**Jackal** (ground)
- Patrols a platform edge to edge. Turns at walls and ledges.
- When Rostam is within about 200 px and roughly level, it pauses (0.4 s telegraph), then
  lunges forward. Vulnerable during and after the lunge.
- 3 health, 1 damage.

**Vulture** (air)
- Hovers in a slow figure-eight above a fixed anchor point.
- When Rostam passes underneath, it dives in a straight line toward his last position, then
  returns to the anchor.
- 2 health, 1 damage. Killed with the air attack from directly beneath: the air swing
  reaches above Rostam's head, and a Vulture is anchored above the top of his jump, so he
  can hit it without ever reaching it himself. Its underside is safe anyway, the contact
  damage covering the top and sides only, so the dive is the threat rather than the body.

## 7. Rooms and camera

### Rooms
Five rooms, left to right. Each is its own scene. A room has: a TileMapLayer for terrain,
enemy spawns, and Door areas (Area2D) that tell the room manager to load the next room and
where to place Rostam.

1. `khan1_01_marsh`: flat, teaches run and jump. One Jackal at the end.
2. `khan1_02_reeds`: vertical space, small platforms, two Vultures. Teaches air attack.
3. `khan1_03_cliffs`: longer, mixed Jackals and Vultures, a couple of small drops.
   Teaches coyote time and jump buffering without saying so.
4. `khan1_04_camp`: quiet room. Rakhsh is standing here. Interact to "rest" (sets respawn
   point). Short text: the reed bed at dusk.
5. `khan1_05_den`: boss arena. Flat floor, walls on both sides, two low platforms.

Room transitions: brief fade (0.2 s out, 0.2 s in). Rostam keeps his velocity through doors.

### Camera (Hollow Knight style)
- One Camera2D that belongs to the world, not to Rostam. It follows a target position.
- Smooth follow: position smoothing enabled, speed around 6 to 8. It should lag slightly
  behind Rostam and never snap.
- Look-ahead: the camera target sits about 60 px ahead of Rostam in his facing direction,
  interpolated, so the player sees where they are going.
- Vertical: a small dead zone (about 40 px) so small jumps do not bob the camera. Big drops
  catch up quickly.
- Per-room limits: every room scene declares its bounds (a Rect2 export or a bounds node).
  On entering a room the camera limits are set to those bounds so it never shows outside the
  room. On room change, snap the camera instantly to the new position (no smoothing across
  the transition), then resume smoothing.
- No screen shake in this slice except a light one on the Lion's pounce landing.

## 8. The Lion (boss)

Arena: `khan1_05_den`. The Lion is large (about 3 tiles wide, 2 tall). 30 health.

Attacks, each with a clear telegraph:
- **Swipe**: when Rostam is close. 0.4 s wind-up (leans back), then a wide short-range hitbox.
  2 damage.
- **Pounce**: when Rostam is at medium range. Crouches 0.5 s, then jumps in an arc to
  Rostam's position at the start of the pounce. Landing has a small hitbox and light screen
  shake. 2 damage. Vulnerable for 0.8 s after landing.
- **Roar**: every 15 s or so. 1 s of standing still (no damage). Purely a rhythm break and
  an opening.

Behaviour loop: pick an attack based on distance, do it, walk toward Rostam for 1 to 2 s,
repeat. Nothing random beyond that.

Phase 2 (below 25 percent health): the Lion stops choosing attacks and does one final pounce
that always connects. Scripted sequence:
1. Rostam is pinned, controls locked, small struggle animation (shake in place).
2. Rakhsh enters from the left at high speed, collides with the Lion, Lion is thrown to the
   right and its health goes to zero.
3. Short text. Rostam stands. Controls return.
4. Door on the right opens. Walking through it ends the slice with a "Khan 1 complete"
   screen and a restart option.

## 9. Placeholder art

Colored shapes only, per the color code in CLAUDE.md. Terrain is a single solid tile. Rostam
is a blue capsule with a small lighter rectangle for the gorz head during swings, so the
player can see the hitbox. Enemies are red rectangles. The Lion is an orange rectangle. Rakhsh is a
white rectangle. Telegraphs are shown by a quick color flash (lighter shade) before the
attack, so timing is readable without animation.

## 10. Out of scope for this slice

Real art, animation, music, save system, map, upgrades, currency, dialogue, second controller
scheme customisation, dash implementation, any of Khans 2 to 7.

## 11. Playtest checklist

After each session the developer checks whatever applies:

- Does running start and stop instantly? Any sliding?
- Can I do a short hop and a full jump reliably?
- Does jumping right after leaving a ledge still work?
- Does the third hit of the combo feel heavier than the first two?
- When I hit something, is there a tiny freeze? Does it feel crunchy or mushy?
- Does the camera ever snap, jitter, or show outside the room?
- Can I read every enemy attack before it happens?
- Did I die to something that felt unfair?
- Did anything take more than five minutes to test?
