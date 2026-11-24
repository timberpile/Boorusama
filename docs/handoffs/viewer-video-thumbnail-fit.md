# Viewer video thumbnail verification

The fallback for unknown video dimensions previously constrained a portrait
thumbnail to about 55 × 219 logical pixels in a 390 × 800 viewport. The widget
regression expects the decoded image to fit at 200 × 800 for that fixture. The
test also checks a landscape thumbnail, metadata and player dimensions, and
the handoff from the visible thumbnail to the first frame.

On base `d757a6eee`, the three unknown-dimension cases failed on geometry and
the known-metadata case passed. The follow-up passed 245 affected tests,
including the Realbooru first-visit autoplay regressions. The final
poster and player lifecycle file also passed all 15 cases after formatting.
Scoped Dart analysis reported five existing informational findings with no
errors or warnings.

## Android check pending

Both the connected and fresh local Maestro MCP sessions timed out while
inspecting leased `emulator-5562`. The lease was released. The follow-up
candidate was not installed or exercised on the device.

When Android inspection is available, open a portrait Realbooru video directly
and by swiping from an adjacent post. Check that the loading thumbnail uses
the available viewport and gives way to an advancing video without interaction.
