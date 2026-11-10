# Agent guide

Run commands from this repository root. Application code, physics, and tests are Sun.
Use `./build.sh --test` for headless tests, `./build.sh --build` to compile the GUI,
and `./build.sh --all` to build and test with an available display. On Linux use
`xvfb-run -a dbus-run-session -- ./build.sh --all` for graphical acceptance.

Use `sun fmt src tests` for first-party source. Keep temporary files in `tmp/` and
outputs in `build/`. Limit parallel compilation to at most half the available cores.
Document every module, type, function, method, and constructor with a `/** ... */` block.
Keep allocations explicit and preserve ownership and memory safety.

Dependencies are Git packages selected in `sun-config.json` and built with the
application's compiler by `scripts/install-dependencies.sh`. Install their system
requirements first with `sun dep install --config sun-config.json --yes`.
Sun manages cached checkouts; never edit the cache or import sibling checkouts. Do not publish
upstream changes, create issues or pull requests, or change Git history without an
explicit user request. Preserve unrelated working-tree changes.
