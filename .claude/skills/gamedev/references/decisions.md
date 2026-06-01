# Pre-decided A vs B choices

These decisions are final for this project. Apply them without asking.

---

## Architecture

**2D vs 3D engine**
→ **3D (Godot 4 Node3D / CharacterBody3D)**
*Reason: Subway Surfers POV is fundamentally 3D. Camera-behind perspective and lane-changing work naturally in 3D. Art style (low-poly/voxel) maps well to 3D meshes.*

**Autoload (singleton) vs passed reference**
→ **Autoload** for global state (GameState, AudioManager, SceneManager, NotificationManager, HazardSpawner).
→ **Passed reference** for local collaborations between sibling nodes.
*Reason: Autoloads avoid prop-drilling. Local state stays local.*

**Inheritance vs Composition**
→ **Composition** by default. Inheritance only for clear is-a (e.g., `Car extends BaseHazard`).
*Reason: Godot's node tree is already a composition model.*

**One big scene vs many small scenes**
→ **Many small scenes**, composed at the root level.
*Reason: Reusability, easier headless testing, cleaner diffs.*

**Road: static level vs infinite chunk pool**
→ **Infinite chunk pool** (5–6 active chunks, recycled when behind player).
*Reason: Endless runner requires infinite road; pooling avoids GC spikes.*

---

## GDScript

**Typed vs untyped GDScript**
→ **Always typed.**

**`@onready` vs `get_node()` in `_ready()`**
→ **`@onready` annotation always.**

**`_process` vs `_physics_process` for movement**
→ **`_physics_process`** for CharacterBody3D. **`_process`** for visuals, UI, camera follow.

**Polling state vs signals**
→ **Signals always.**

**`match` vs `if/elif` chains**
→ **`match`** for enum/type dispatch (3+ cases). **`if/elif`** for conditions.

---

## Game Mechanics

**Lane change: instant vs tween**
→ **Tween** (0.25s ease-in-out).
*Reason: Instant feels jarring on mobile. Short tween gives tactile feedback.*

**Player forward movement: player moves vs world moves**
→ **Player moves forward** (z-axis negative), camera follows.
*Reason: Simpler physics; hazards can be static or move independently. Road chunks recycle based on player position.*

**Phone overlay: SubViewport vs screenshot**
→ **SubViewport** for the road peek strip.
*Reason: SubViewport shows live game content in the road strip — player can actually see hazards through the gap. Screenshot would be stale.*

**Willpower bar: separate timer node vs code-only**
→ **Separate Timer node** (child of WillpowerBar scene), driven by signal.
*Reason: Godot Timer is reliable and pausable. Code-only with delta accumulation is error-prone.*

**Notification queue: Array vs signal-only**
→ **Array queue** in NotificationManager.
*Reason: Notifications can stack; queue lets us peek, schedule, and drain without race conditions.*

**Hazard spawning: preloaded scenes vs dynamic load**
→ **Preloaded scenes** (`preload` in HazardSpawner for each hazard type).
*Reason: Mobile — no loading hitches during gameplay.*

**Collision detection for lane hazards: Area3D vs shape cast**
→ **Area3D** on each hazard, player has Area3D pickup zone.
*Reason: Hazards don't need physics sim, just overlap detection.*

---

## Data & Resources

**Notification data: JSON vs Resource**
→ **JSON** (`src/data/notifications/notifications.json`).
*Reason: Human-readable, easy to extend by non-programmers.*

**Zone config: JSON vs GDScript constants**
→ **GDScript constants** in `GameState`.
*Reason: Zone transitions are few and well-defined; JSON overhead not justified.*

**Settings: ConfigFile vs Resource**
→ **ConfigFile** for player settings (volume, etc.).

---

## Animation

**Tween vs AnimationPlayer**
→ **Tween** for one-shot property transitions (lane change, phone slide-in/out, willpower bar drain).
→ **AnimationPlayer** for character walk cycle and looping animations.

---

## UI & Mobile

**Screen resolution**
→ Viewport: **390×844** (iPhone 14 portrait baseline).
→ Stretch mode: `canvas_items`, aspect: `expand`.

**Touch input for lanes**
→ Swipe gesture: detect `InputEventScreenDrag`, threshold 40px horizontal.
→ Also expose keyboard (A/D or arrows) for dev builds.
→ Never hardcode touch positions in gameplay scripts.

---

## Audio

**AudioStreamPlayer vs AudioStreamPlayer2D**
→ **AudioStreamPlayer** for music and UI sounds.
→ **AudioStreamPlayer2D** for positional hazard sounds (car passing).
→ Always route through **AudioManager** autoload.

---

## Renderer

**Forward Plus vs Mobile vs gl_compatibility**
→ **gl_compatibility** (OpenGL ES).
*Reason: Broadest mobile device support. The low-poly art style doesn't need advanced lighting.*
