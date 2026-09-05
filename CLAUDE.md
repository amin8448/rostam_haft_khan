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
- Godot is on PATH as `godot` (main build; `godot_console` is the console wrapper, only
  needed for interactive use). Both pipe output correctly for scripted validation. If
  `godot` is not found, say so and stop claiming anything is validated. Never write the path
  to the Godot binary into the project.
- You cannot see the game. Playtesting is done by the developer. What you can do is drive
  it headless and measure it (see Validation and Tests). Every session ends with a "How to
  test" section (see Workflow).

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
tests/               headless simulation scripts, committed (see Tests)
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

## Validation

Run from the repository root, in this order, before every commit that touches scripts,
scenes or assets:

1. `godot --headless --path . --import` rebuilds `.godot/`, writes `.import` sidecars,
   registers `class_name` globals and reports parse errors. Always first: without it a new
   texture has no loader and a new `class_name` does not resolve.
2. `godot --headless --path . --check-only --script res://path/to/file.gd` parses one
   script. `--check-only` without `--script` checks nothing and runs the game forever.
3. `godot --headless --path . --quit` loads the main scene and exits.
4. `godot --headless --path . --script res://tests/<name>.gd` runs a simulation test.

If a command times out, a Godot process is probably still running. Kill it before
continuing. `.import` files are committed; `.godot/` and `.claude/` never are.

## Tests

`tests/` holds headless simulation scripts (`extends SceneTree`). Each instantiates
`main.tscn`, drives `Input.action_press` / `action_release` over physics ticks, and prints
measured values next to the design targets. They are the only way this project can check
feel without a human, so they are committed, kept current, and re-run whenever movement,
combat or the camera changes. State the expected values at the top of each script.

Headless quirks: the dummy viewport is 64x64 and ignores `root.size` and `--resolution`, so
never assert on screen size. Probe camera limits by pushing the target past the bounds and
comparing `get_screen_center_position()` with limit plus half of 64. Release an action once,
not every tick, or `is_action_just_released` fires repeatedly. RID and ObjectDB leak
warnings at exit are noise.

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
- Keep every commit small and describe what changed and why. Push at the end of every
  session; the developer works on two machines and an unpushed session is invisible.
- At the end of a session, print a **How to test** section: which scene to run (F5 or F6),
  what to press, what should happen, and what to look for if it feels wrong. The developer
  has limited time; make the test take under five minutes.
- If a request conflicts with `docs/khan1_design.md`, say so and ask rather than silently
  doing one or the other.
- If you are unsure how something looks in the running game, ask the developer to describe it
  or screenshot it rather than guessing.