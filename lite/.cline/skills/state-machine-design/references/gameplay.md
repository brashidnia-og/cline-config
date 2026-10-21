# Gameplay state machines

Read for character/combat/AI modes or game flow. These examples are engine-independent; inspect the project's engine version, update loop, pause model, input routing, and state owners before adapting them.

## Choose the modeled entity

A weapon, character action, enemy controller, round, or menu flow can each own a lifecycle. Avoid a global machine that also owns every entity's movement, equipment, camera, and UI. Continuous values such as velocity, aim, and blend weights usually remain data or simulation logic.

Locomotion and weapon use can coexist: jumping while reloading is not an impossible state. Use independent components/machines or parallel regions if both lifecycles matter, with an explicit rule for shared events such as stun or death. A hierarchy helps when several child modes share the same interrupt rule. Evaluate behavior trees, utility selection, or planning for AI intent; a smaller action machine can still enforce execution and cleanup.

## Example: interruptible attack

Suppose the verified feature spec allows death to interrupt every attack phase and permits firing only while ready. The action machine might use:

| Source | Event | Guard | Target | Effect/data rule |
|---|---|---|---|---|
| ready | attack requested | actor can attack | windup | Assign action generation; start windup. |
| windup | windup finished(generation) | current action | active | Enable the damage window. |
| active | active window finished(generation) | current action | recovery | Disable damage; start recovery. |
| recovery | recovery finished(generation) | current action | ready | Release action resources. |
| ready / windup / active / recovery | died | — | dead | Exit action; clear damage, timers, and buffered requests. |
| any | obsolete phase callback | wrong generation or phase | unchanged | No damage or transition. |

The table is a starting model, not a universal combat design. Specify when ammunition/resources are consumed, how many targets a damage window can affect, and whether inputs during windup/recovery are ignored, rejected, or buffered. If another system owns damage, request effects through its existing contract rather than duplicating those rules in every state.

## Timing and interruption contract

- **Tick authority:** Decide which simulation phase commits gameplay transitions and samples input. Coordinate frame input, fixed physics updates, animation callbacks, and network messages through that owner. A callback may request a transition without committing one midway through a physics decision.
- **Simultaneous events:** Define observable ordering or priority for relevant conflicts, such as death versus attack completion. A queued lower-priority request must be revalidated after a higher-priority transition. Do not prescribe a universal "one transition per frame" rule; intentional bounded chains may be correct.
- **Lifecycle:** Entry starts state-owned work; exit releases or hands it off. Check timers, signal subscriptions, hitboxes, root-motion ownership, movement overrides, and input buffers on every exit, including interruption and scene unload. Per-frame update must not accidentally repeat an entry-only effect.
- **Late callbacks:** Check both action generation and expected phase where needed. Reusing an actor from a pool or restarting the same animation can make a previous callback look current. Unsubscribe/cancel when possible, and reject stale events as a separate defense.
- **Pause and resume:** Decide which clocks and queues pause, whether held/buffered input survives, and whether resuming continues or restarts a phase. A state stack/history mechanism is useful only when saved context is still valid; death/despawn can invalidate it.
- **Simulation and presentation:** Identify which system decides gameplay timing. Animation events may be authored gameplay inputs when that is the design, but define their cancellation/failure behavior. Avoid two independent authorities for combat legality. An animation graph and gameplay machine can model different concerns with a defined interface.
- **Multiplayer/replay:** Identify authoritative simulation, predicted state if any, correction ordering, tick/sequence IDs, and cleanup of speculative effects. Do not ban client prediction or imply that a local machine secures server rules. Apply only the networking/replay requirements the game actually has.
- **Cost:** Keep transition chains, queues, and per-tick work bounded by expected actors/events. Share immutable definitions safely, but keep mutable per-actor context separate. Profile allocation/frame-time claims with `game-performance-profiling` when available; the pattern alone promises no speedup.

## Verify behavior in and out of the engine

Use deterministic event/tick traces for the transition contract and observable effects: rejected attack, interruption at each consequential phase, death and completion in one tick, repeated input, stale callbacks, pause/resume, and despawn/reuse. Assert damage windows and resources are cleaned up, not merely that the label changed to `dead`.

Then use the project's existing engine checks/playtests for input, physics, animation, and scene lifetime. Headless model checks cannot establish animation timing or game feel. In lite, engine-specific skills may not be installed; follow local project conventions and official version-specific docs instead of assuming an unavailable skill or plugin.

## Sources

Consulted 2026-10-19. The engine-specific implementation must be checked against the installed project version.

- [Game Programming Patterns — State](https://gameprogrammingpatterns.com/state.html): character FSMs, concurrent modes, hierarchy, and pushdown state stacks.
- [Godot — Using AnimationTree](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html): animation state-machine transitions and playback. An animation transition facility is not automatically the owner of gameplay legality.
