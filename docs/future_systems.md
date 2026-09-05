# Future systems

Ideas that are settled in direction but deliberately not built during the Khan 1 slice. This
file exists so they are not re-invented later from the code alone, and so the slice does not
accidentally close a door on them. Nothing here is a task for Claude Code until a session
prompt says so.

## Principle

Rostam without Rakhsh is not Rostam. Every system in this file is a way of putting Rakhsh in
the game as a character with agency, the way Ferdowsi wrote him, rather than as a vehicle or
a mascot. Where the Shahnameh gives Rakhsh a moment, the game gives the player a mechanic
that matches it, introduced at that moment and not before.

## 1. Grazing grounds: rest and travel

**What it is.** Open, grassy places where Rakhsh waits. A grazing ground is one node type
that does three things: rest (refill health, set respawn), save, and later, travel. The camp
in Khan 1 room 4 is the first one.

**The fiction.** Rostam rides Rakhsh between labours, but the labours themselves happen where
a horse cannot go: the lion's den, the dragon's ground, the witch's garden, the dark. Rooms
are on foot. Rakhsh waits at the nearest open ground and carries Rostam between grounds he
has already found. This is the Hollow Knight stag-station structure with a reason attached.

**Unlock.** After the Lion fight in Khan 1, where Rakhsh saves Rostam. Before that, the camp
is only a rest point. After it, interacting with Rakhsh at any grazing ground offers travel to
any other discovered ground. Travel is a short scripted moment (mount, fade, arrive) rather
than a menu on a black screen, so the horse stays visible as a character.

**Scope note.** Travel earns its place when the map is big enough to be tedious on foot.
Khan 1 is five rooms in a line, so the slice builds the rest point only. What the slice must
not do is hard-code "the camp" as a single unique object; see "Keep extensible" below.

## 2. Calling Rakhsh: the ally

**The fiction gives him agency four times.**

| Khan | What Rakhsh does in the story | Mechanic it suggests |
|------|------------------------------|----------------------|
| 1, the Lion | Kills the lion while Rostam sleeps | Scripted finish to the boss (already in the slice design) |
| 2, the Desert | Carries Rostam through the desert; a ram leads them to water | Riding traversal sequence, the one stretch on horseback |
| 3, the Dragon | Wakes Rostam three times as the dragon approaches, then bites and holds the dragon while Rostam kills it | Rakhsh as a fight ally: a call that pins or staggers a boss for a window |
| 7, the White Div | Carries Rostam into the cave; present at the climax | Culmination of whatever the call has become |

**Direction.** A "call Rakhsh" ability that gains one function per khan, in story order, so
the player learns Rakhsh the way Rostam does. Limited uses per room or a long cooldown, and
never in rooms that are fictionally horse-inaccessible. The point is that Rakhsh helps at
decisive moments, not that he is a summon to spam.

**Not decided.** Input (probably `interact` held, or a dedicated action once the map has
room for it), exact uses, whether he has his own health. Decide when Khan 3 is designed.

## 3. Riding: Rakhsh as an earned ability

**The idea.** Rostam can ride Rakhsh through open stretches of the map: faster movement,
higher jump, a charge that knocks small enemies aside. Shown on screen as Rostam mounted, a
distinct silhouette. Earned, not granted at the start, because it is the game's expression of
the bond deepening.

**Where it could be earned.** Most naturally after the Khan 2 desert crossing, since that is
where the story makes the horse the reason Rostam survives.

**Constraints.** Only in rooms flagged as rideable (open ground). Dismount is forced at room
doors into non-rideable rooms. Combat while mounted is limited or absent, so riding is
traversal and not a second combat system.

**Honest scope assessment.** This is the largest item here. It means a second movement
state machine, a second set of tuned numbers, a mounted sprite set, and room flags. It is
also the one most likely to feel great. Treat it as its own milestone after the Khan 1 slice
is playable end to end, and prototype it with rectangles before committing to it.

## 4. Smaller Shahnameh notes for later

- Rostam's signature weapon in the text is the ox-headed mace (gorz-e gavsar), not the sword.
  Settled in session 4: the gorz is the weapon, including the three-hit combo, and everything
  in the code is named for it. Nothing about it is decided beyond the name and the shape; a
  distinct heavy attack, if there ever is one, is still open.
- The tiger-skin armour (babr-e bayan) is a natural upgrade or charm slot if the game grows
  one.
- Khan 4 (the witch) and Khan 6 (Arzhang) are the two labours where Rakhsh has no role, which
  is a good rhythm: two khans where the player is alone before the finale.

## Keep extensible during the Khan 1 slice

These are the only concrete obligations this file places on sessions 4 and 5:

1. The camp's Rakhsh is a `GrazingGround` scene (or equivalently named), an interactable node
   with a rest-point behaviour, instanced in room 4. Not a one-off script in the room.
2. Respawn-point logic in the world or room manager stores "the last grazing ground used",
   not "the camp", so a second ground works without changes.
3. The Lion's phase 2 sequence is written as "Rakhsh arrives" with Rakhsh as his own scene
   (`scenes/player/rakhsh.tscn`), so the same scene can later be mounted, called, or stand at
   a grazing ground.
4. Room scenes carry an exported flag for whether they are rideable, defaulting to false.
   Nothing reads it yet.

Everything else in this document stays out of the code until it has its own session.
