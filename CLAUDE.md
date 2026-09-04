# Rostam: Haft Khan

A 2D side-scrolling action metroidvania built in Godot 4.6 with GDScript, based on the
Haft Khan e Rostam (Seven Labours of Rostam) from Ferdowsi's Shahnameh.

Exploration, mood and camera feel: Hollow Knight. Combat feel: fast and responsive, closer
to Hades. Hobby project by a solo developer with limited time. The developer reviews code and
playtests; you write the code.

Read `docs/khan1_design.md` before starting any gameplay work. It is the source of truth for
scope, controls and feel.

## Engine and tooling

- Godot 4.6 stable, GDScript only. No C#, no GDExtension, no third-party addons unless asked.
- Renderer: GL Compatibility (already set in project.godot). Keep it.
- The developer works on two machines (Ubuntu laptop, Windows desktop) and syncs through
  GitHub. Never write machine-specific paths or settings into the project.
- Godot is not guaranteed to be on PATH in your shell. If it is, validate scripts with
  `godot --headless --path . --check-only` (or `godot --headless --path . --quit` to catch
  scene load errors). If it is not, say so and do not pretend the project was validated.
- You cannot run or see the game. Playtesting is done by the developer. Every session ends
  with a "How to test" section (see Workflow).

## Project layout

The Godot project lives at the repository root (`project.godot` at root).

```
project.godot
CLAUDE.md
docs/                design documents
scenes/
  player/            rostam.tscn, rakhsh.tscn
  enemies/           one folder per enemy type
  bosses/
  rooms/             one scene per room, named khan1_01_marsh.tscn etc.
  ui/
  world/             main.tscn, room manager, transitions
scripts/             mirrors scenes/ (scripts/player/rostam.gd etc.)
autoload/            singletons (game_state.gd, room_manager.gd)
assets/
  placeholder/       colored shapes and simple tilesets only
  audio/
```

Keep a script next to its scene in the mirrored folder. One scene, one script.

## Conventions

- Static typing everywhere: `var speed: float = 300.0`, `func take_damage(amount: int) -> void`.
- snake_case for files, variables, functions and input actions. PascalCase for node names
  and class_name.
- Input actions are lowercase (`jump`, not `Jump`). Every action must be defined in
  project.godot for both keyboard and gamepad.
- Use signals for communication between scenes. Do not reach up the tree with `get_parent()`
  chains. Prefer `class_name` and duck typing (`has_method("take_damage")`) over hard
  references.
- Tunable numbers (speed, jump velocity, coyote time, damage) are `@export` variables with
  sensible defaults, so the developer can tweak them in the Inspector without touching code.
- Player and enemies use a simple state machine (enum plus match statement is fine; no
  framework).
- Physics in `_physics_process`, visuals and input polling in `_process` only when needed.
- Scenes must stay text-editable and diff-friendly. Do not embed large resources inline;
  save them as separate files.
- Never edit anything under `.godot/`. It is generated and gitignored.
- Comments explain why, not what. No decorative comments.

## Art and audio

Placeholder only until the design says otherwise. Use ColorRect, Polygon2D or a solid-color
TileSet. Consistent color code so the developer can read the screen at a glance:

- Rostam: blue
- Rakhsh: white
- Regular enemies: red
- Bosses: orange
- Hazards: purple
- Interactables: yellow
- Terrain: dark grey

Do not download asset packs or generate images unless asked.

## Workflow

- One feature per session. Finish it, make it testable, stop. Do not start the next thing.
- Before large architectural changes (new autoload, changing the room system, changing how
  the camera works), explain the plan in two or three sentences and wait for a yes.
- Keep every commit small and describe what changed and why. Do not commit `.godot/`.
- At the end of a session, print a **How to test** section: which scene to run (F5 or F6),
  what to press, what should happen, and what to look for if it feels wrong. The developer
  has limited time; make the test take under five minutes.
- If a request conflicts with `docs/khan1_design.md`, say so and ask rather than silently
  doing one or the other.
- If you are unsure how something looks in the running game, ask the developer to describe it
  or screenshot it rather than guessing.
