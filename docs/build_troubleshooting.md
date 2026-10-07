# Build troubleshooting

## Repeated native build warning

The current `libavif` Rust native hook can repeatedly emit `File modified during
build. Build must be rerun.` even on an unchanged checkout. Cargo declares
`native/vendor/libavif` as a dependency directory; `native_toolchain_rust`
converts it to a file URI without a trailing slash. `hooks_runner` then treats
the directory as a missing file, records the current time, and invalidates its
cache on the next run. A verbose Flutter test log identifies this dependency.
Verify the test exit code and unchanged checkout before attributing this
message to concurrent source edits; repeating the build alone does not fix
the dependency URI classification.
