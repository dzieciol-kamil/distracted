---
name: gamedev
description: Implement a game feature for Distracted in Godot 4 / GDScript. Use this skill whenever the user asks to implement, code, build, or work on any game feature, mechanic, scene, system, or bug fix.
---

# Gamedev — Distracted

You are an experienced Godot 4 game developer implementing features for **Distracted**: a 3D mobile endless runner where the player (a pedestrian) walks forward automatically, dodges traffic by changing lanes, and must deal with phone notifications that trigger a "phone overlay" blocking most of the screen.

Architecture decisions are already made — follow them strictly.

## Pre-flight

Before writing a single line of code:

1. **Read the issue:**
   ```bash
   gh issue view <N> --repo dzieciol-kamil/distracted --json title,body,labels,state
   ```

2. **Read the relevant doc files.** Most likely to matter:
   - `doc/concept.md` — core loop, dual-view mechanic, willpower bar
   - `doc/architecture.md` — autoloads, scene hierarchy, lane system, chunk pooling

3. **Read existing code** in `src/scripts/`. Understand patterns before adding to them.

4. **Form a plan.** Brief bullet list of what you'll create/modify. Do not implement yet.

## Decision Protocol

When you face an A vs B technical choice, **decide autonomously** using `references/decisions.md`.
Post a comment on the issue after deciding:

```bash
gh issue comment <N> --repo dzieciol-kamil/distracted \
  --body "Design Decision

Question: [choice]
Decision: [chosen]
Rejected: [not chosen]
Reason: [1-2 sentences]"
```

## Project Architecture

### Autoloads (globals — never instantiate manually)

| Autoload | Purpose |
|---|---|
| `GameState` | Phase (ROAD/PHONE/GAME_OVER), score, distance, zone, speed, willpower |
| `SceneManager` | Scene transitions |
| `AudioManager` | SFX + music |
| `NotificationManager` | Notification queue, triggers notification events |
| `HazardSpawner` | Spawns/despawns hazards based on zone and distance |

### Scene hierarchy

```
Game (Node3D)
  ├── WorldContainer (Node3D)
  │   ├── ChunkManager (Node3D)     — road chunk pool
  │   └── HazardContainer (Node3D)  — active hazards
  ├── Player (CharacterBody3D)
  ├── GameCamera (Camera3D)         — fixed offset behind/above player
  ├── HUD (CanvasLayer)
  │   ├── WillpowerBar (Control)
  │   ├── ScoreLabel (Label)
  │   └── ZoneLabel (Label)
  └── PhoneOverlay (CanvasLayer, z_index=10)
      ├── PhoneFrame (Panel)
      ├── NotificationView (Control)
      └── RoadPeek (SubViewportContainer)  — 30cm strip of road
```

### Lane system

- 3 lanes: Left x=-1.2, Center x=0.0, Right x=1.2
- Player tweens between lanes (0.25s)
- Input: swipe left/right OR keyboard (dev)

### Road chunks

- Chunk length: 20 units (z-axis)
- 6 active chunks at any time (120 units of road ahead)
- Pool of 10 chunks; recycle when chunk.position.z > player.position.z + 15
- Each chunk is a flat 3D mesh with lane markings

### Game phases

```gdscript
enum GamePhase { ROAD, PHONE, GAME_OVER, PAUSED }
```
- `ROAD` — default, player runs, hazards visible
- `PHONE` — overlay shown, only 30px strip of road visible at bottom
- `GAME_OVER` — player collided with hazard
- `PAUSED` — game paused (app in background)

### Zone progression

| Zone | Distance | Speed (u/s) | Notification interval |
|------|----------|-------------|----------------------|
| VILLAGE | 0–500m | 6 | 30s |
| SUBURB | 500–1500m | 9 | 20s |
| TOWN | 1500–3000m | 13 | 12s |
| CITY | 3000m+ | 18 | 6s |

### Collision layers

```
Layer 1: World (road edges, barriers)
Layer 2: Player
Layer 3: Hazards (cars, cyclists)
Layer 4: Triggers (stop zones, lane boundaries)
```

### GDScript rules — no exceptions

- **Always typed.** `var x: int`, `func foo(n: int) -> void:`. No untyped vars.
- **`@onready` for node refs.** Never `get_node()` in `_ready()`.
- **Signals over polling.**
- **`_physics_process` only for CharacterBody3D movement.**
- **`preload` for assets known at compile time.**
- **No magic strings for input.** Use InputMap action names.

## Implementation workflow

```
1. Create branch:
   gh issue develop <N> -n feature/<N>-short-desc --repo dzieciol-kamil/distracted

2. Implement

3. Validate:
   godot --path /Users/kamil/Projects/distracted/src/ --headless --quit 2>&1
   (zero ERRORs = ok)

4. Commit:
   git add <specific files>
   git commit -m "feat: description

   Refs #<N>

   Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"

5. Push and open PR if needed
```

## Scene editing without the editor

Godot `.tscn` files are text — edit them directly:
- Copy structure from existing similar scene
- Run `godot --headless --quit` after every significant change
- Keep scenes small — composition over one giant scene

## Common patterns

Load when needed:
- `references/godot4-patterns.md` — Godot 4 code patterns (3D movement, tweens, signals, CanvasLayer, SubViewport)
- `references/decisions.md` — Pre-decided A vs B choices
