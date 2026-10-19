# Navigation compatibility backport

Upstream: Flutter go_router 17.5.0, copied from the locked pub package.
Copyright and BSD license are retained in LICENSE and each source file.

Authorized on 19 October 2026 for the retained-navigation migration. Version and
public APIs are unchanged. The fork changes only:

- `RouteConfiguration.reparse`: visit nested imperative matches, preserving page
  keys, payloads and completion futures. This matches the later upstream fix
  documented in the 18.0.2 changelog.
- `StatefulNavigationShellState.goBranch`: reparse cached match lists before
  restoration so dynamic branch definitions cannot revert to an old shell.

The app also supplies a stable shell Page key; navigator keys alone do not
prevent shell replacement during structural updates. Application regressions
live in test/core/navigation/destination_router_test.dart. All upstream tests
are retained, including their two pre-existing skips. No shared pub cache is
modified. Reassess this backport during the next deliberate router upgrade.

The vendored package has its own analysis boundary; its test options include
that boundary. It inherits application diagnostics except the style-only
`parameter_assignments` lint, used in four unchanged upstream code locations.
No analyzer correctness diagnostics or upstream tests are disabled.
