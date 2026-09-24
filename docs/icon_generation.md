# App icon generation

The editable artwork sources are:

- `assets/images/logo.svg` for production and default builds
- `assets/images/logo-dev.svg` for development builds

Both contain the complete box-and-T mark, including the perspective-aligned T
printed on the left face. The development source additionally has `Dev`
printed on the right face.

The generator intentionally does not rasterize SVG. After editing either SVG,
manually export it as a transparent 512-by-512 PNG beside the source:

- `assets/images/logo.png`
- `assets/images/logo-dev.png`

Run `./scripts/generate_icons.sh` after exporting either PNG or changing a
platform layout. The repository-owned compositor derives the production and
development inputs under `assets/icon/`. `flutter_launcher_icons` generates
the flavor-specific Android and iOS assets. A final repository-owned step
generates both flavors for macOS, Windows, and web, where
`flutter_launcher_icons` cannot emit separate flavor assets.

Default and production builds use the production artwork. Development builds
select the Dev artwork. For web, use `./scripts/build_web_dev.sh` to replace the
default icon links with the generated Dev assets at build time.

The files under `assets/icon/`, native platform icon directories, and web icon
directories are generated outputs; do not edit them directly.
