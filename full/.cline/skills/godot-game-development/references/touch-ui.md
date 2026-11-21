# Adaptive touch UI

## Layout ownership and geometry

- Keep game-specific art/layout policy in the game composition through the existing anchor/layout seam. Change reusable platform defaults only when their shared contract is actually wrong.
- Fit controls using actual outer bounds, radii, safe extents, and the available controls region, rather than named aspect-ratio presets or anchor centers alone. A rounded rectangle and a circular button can share a center offset while having different visible edge alignment.
- Trace the final game-specific anchor override before editing generic defaults. Reserve separate space for secondary buttons/toolbars and verify no overlap at minimum, default, and maximum supported control sizes, including portrait layouts.
- A maximum element-size scale does not limit the distance between controls anchored to opposite screen edges. Constrain the effective controls region separately when reachability is a requirement.

## State and touch-only navigation

- When hiding gameplay controls, ensure a touch-only player can resume, cancel, continue results, and navigate every modal using real GUI controls.
- Query the actual owner of online/local match and modal state. A local enum may remain in a lobby phase while a separately owned online session is active. Include relevant phase/modal transitions in layout invalidation.
- Validate the real viewport dimensions and rendered state using the [capture guidance](validation-and-resource-safety.md); requested screenshot dimensions are not evidence of the rendered aspect ratio.

## Logical and physical dimensions

Android density converts pixels and logical dp; it is not a physical millimetre measurement. Physical conversion uses reported x/y DPI independently, and that metadata can be inaccurate or unavailable. Verify the project's platform adapter and units before changing thresholds. Keep ergonomic defaults provisional until tested on representative devices and users; logical eligibility and physical reachability are different claims.
