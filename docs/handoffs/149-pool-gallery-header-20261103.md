# Issue #149: Pool Gallery Header spacing

Branch: `bug/149-pool-gallery-header`; base `02b0d60e9`.
Implementation: `60bbe997dfd68028e496a9fb4226f950202cc955`.

Removed `titleSpacing: 0` from `DanbooruPoolPage`. Kurumi supplies its normal
Header inset and retains #130's internal adaptive title fitting. No custom title
wrapper, tab/navigation change or broader #148 Header behavior was introduced.

Checks: FVM formatting, clean diff and scoped analysis passed with no issues.
Existing complete `packages/kurumi/test/app_bar_test.dart`: **33 passed**, covering
long titles, narrow widths, 1x/1.5x/2x text, RTL, semantics, actions and keyboard
insets. This one-line application change does not change the Kurumi package.

Android: current-source dev x64 build passed. Installed/local APK SHA-256 matched
`2bb1173516a95f9525eed7dcc5e4d340ffcfc2896a2dc38e9cbbe6372a66bc32`.
Maestro used leased `emulator-5554`, Android 17, 360×800 logical, gesture navigation.
Pool Gallery title now has the standard 16 dp inset; inspected normal/2x text and
tab switching. Font scale restored to 1.0. Safe profile navigation and lease
restoration are shared with the other approved UI checks. Captures/logs:
`.worktrees/_artifacts/approved-ui-149/`. Loading/no-cover content in captures is
not a decoded-media acceptance claim.

Full app regression was not needed for scoped local verification. Integration
requires the final combined candidate's complete gate. Physical devices and
exhaustive localization remain unverified. Local commits only; no push, PR, merge
or issue closure. Broader Header scrolling stays separately owned by #148.
