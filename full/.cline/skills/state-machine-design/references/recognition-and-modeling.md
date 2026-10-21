# Recognition and modeling

Use this reference when deciding whether an implicit lifecycle deserves a machine, or choosing its representation. Examples are illustrative, not repository APIs.

## Find the hidden protocol

Search relevant types and assignments, not only names containing `state`. Follow status flags, early returns, timer callbacks, subscriptions, and error handlers. Sketch an observed sequence and a problematic sequence. Separate behavior verified in code/tests from intended behavior that still needs a product decision.

Useful evidence includes:

- `is_running`, `is_cancelled`, and `has_finished` can describe contradictory conditions because several handlers write them independently.
- The same input is accepted in one phase and rejected in another, but that rule is duplicated at callers.
- Comments such as "must call start first" describe ordering the API does not enforce.
- Reset, retry, interruption, or reconnect must undo resources acquired in an earlier phase.
- A late callback can restore an earlier mode or overwrite a newer attempt.

A long function, many enum values, or several events alone is not evidence that a new abstraction helps. Name the actual invariant and change boundary first.

## Compare plausible alternatives

| Observed problem | Candidate | Why / limit |
|---|---|---|
| Stateless parse → validate → normalize → aggregate | Pipeline/functions | Data dependency already supplies order; stage names alone do not require persistent lifecycle state. |
| Stream fragments need remembered quote/escape/header modes | Parser state machine | The next fragment's meaning depends on earlier input. General nested syntax may need a stack or parser, not a flat FSM. |
| Same processing with different limits/formats | Data/configuration | A lifecycle model does not replace configuration. |
| Different interchangeable algorithms | Strategy/functions | Selection varies by implementation, rather than events changing the entity's legal behavior. |
| Async job can wait, retry, cancel, or finish | Lifecycle state machine | Legal completion and retry depend on the current attempt and phase. The transformation inside the job can remain a pipeline. |
| A small exhaustive `match(state, event)` already owns all transitions | Keep/refine it | It may already be a complete, auditable machine. Do not replace it merely to add classes. |
| Reactive AI selects among changing goals/priorities | Behavior tree, utility selection, planner, or hybrid | A machine may own action execution/interruptions while another policy selects intent. Evaluate the actual decision problem. |

## Keep modes distinct from data

A mode matters when event handling, legal operations, or resource lifetime differs. A numeric value such as bytes processed is usually context. Do not create a state for every percentage, health value, or timer tick. Conversely, an enum placed in a `context` object is still lifecycle state if it controls legal transitions; naming it context does not resolve ownership.

Prefer state-specific data when it prevents meaningful invalid combinations: a running job has an attempt identifier; a successful job has its result. Do not retain redundant flags that independently contradict that representation. Derived flags used by existing consumers can be compatibility views of the authoritative state.

One region's mutually exclusive states do not describe every independent concern. A character may jump while reloading. Combining both dimensions into names such as `jumping_reloading` and `running_reloading` multiplies states. Separate owners or parallel regions require an explicit coordination rule for cross-cutting events such as death; parallel regions do not imply parallel threads.

## Pick the representation by ownership

| Representation | Useful when | Check before choosing |
|---|---|---|
| Enum/tagged union + exhaustive transition function | Closed lifecycle, modest behavior | State-specific payloads and unsupported events remain explicit. |
| Transition table | Many regular source/event/guard/target rules | Avoid stringly typed names, hidden priority, and scattered effects. A map to functions is valid if those handlers preserve the contract. |
| State objects/components | Substantial state-local behavior/resources | Instance data must not leak between actors or shared singleton states. Avoid forwarding-only classes. |
| Hierarchical machine | Several modes genuinely share interruption or cleanup policy | Specify child/parent event precedence and exit/entry order. No inheritance hierarchy is required. |
| Parallel regions/coordinated machines | Independent modes coexist | Identify authority for shared data and ordering of cross-region events. |
| Stack/history | A mode suspends and later resumes another | Decide what resumes, whether timers continue, and whether the saved mode is still legal. |

Self-events need precision: ignoring an event, updating data without exit, and exiting/re-entering the same state can have different effects. Automatic/eventless transitions are valid when useful; check their termination rather than banning them. A guard can also use ordered fallback rules when the priority is intentional and tested.

## Sources and semantic boundaries

Consulted 2026-10-19. These support design concepts, not claims about the target repository's behavior. Use the repository's actual library/version before applying implementation-specific semantics.

- [Game Programming Patterns — State](https://gameprogrammingpatterns.com/state.html): switch and object representations, independent machines, hierarchy, and state stacks.
- [W3C SCXML](https://www.w3.org/TR/scxml/): statechart event selection, hierarchy, and run-to-completion semantics.
- [Stately — Guards](https://stately.ai/docs/guards): pure guard evaluation and ordered alternatives.
- [Stately — Events and transitions](https://stately.ai/docs/transitions): self-transition and re-entry distinctions; these details depend on the runtime.
- [Stately — Eventless transitions](https://stately.ai/docs/eventless-transitions): useful automatic transitions and infinite-loop risks.
