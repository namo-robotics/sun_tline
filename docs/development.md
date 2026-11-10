# Development and simulation guide

Run commands from the repository root.

## Experiments

Choose **Repeated reflections**, **Matched line**, **Open end**, **Shorted end**,
**Capacitive charging**, **Inductive response**, **RLC ringing**, or **Sine standing wave**.
Press **Run**, pause at any time, or use **Single step** to advance one numerical step.
Playback speed is measured in line transits per wall-clock second; physical time
and transit time are shown below the plots.

The source defaults to an ideal voltage source (0 Ω source resistance) and supports
a step, a rectangular pulse, a single-cycle sine pulse, and continuous sine excitation. Source matching presets explicitly
set their source resistance. Terminations are
open, shorted, resistive, capacitive, inductive, or series RC/RL/RLC. Settings use
SI units, including seconds, farads, and henries; scientific notation is accepted.
Valid settings edits apply automatically and reset playback to paused. Incomplete
or invalid input leaves the current experiment intact and displays a validation message. **Reset** discards unapplied edits and restarts the active circuit.
Selecting a preset immediately installs it and pauses playback. Selecting a source
waveform applies the current settings and resets playback immediately; invalid
settings leave the active simulation unchanged. The active waveform is shown
beside the simulation time.

**Sine pulse** emits one full sine cycle over the selected **Pulse width**, then
returns to zero. Its frequency is the inverse of its width; the separate frequency
field applies only to continuous **Sine**. The sine pulse requires at least 100
simulation steps across its width.

The default pulse lasts 12.5 ns, a quarter of the default line transit time, so
both edges fit on the line before reflection. Longer pulse widths are allowed;
when the width exceeds the transit time, the leading edge reaches the load
before the source switches off, initially resembling a step.

The dark studio interface uses red voltage waves and green current waves.
Voltage and current wave plots each occupy a full row. Playback targets 240 frames
per second with display-only subcell interpolation, while the numerical solver
retains its fixed step. Time and step readouts use stable, fixed-width fields
and refresh at 10 Hz during playback; pausing or single-stepping updates them
immediately. The event loop services native input and scrolling while waiting
for the next wave update, including when simulation playback is paused. Actual
presentation rate depends on the display refresh rate and rendering workload.
A new wave document is prepared only after GTK has painted the previous one.

**Traveling components** separates the forward/backward waves. Positive current
points toward the load, so a backward voltage wave has negative current.
Voltage limits cover at least −2× to +2× the source amplitude so reflections stay
visible. Plot limits stay fixed until **Rescale** or a circuit reset; rescale if a trace
moves outside the visible range. A new circuit begins unenergized, with its source
boundary launched at time zero.

Resistance absorbs energy. Ideal reactive circuits can oscillate indefinitely;
a resonantly driven ideal circuit can grow without settling. Sine excitation has
a periodic steady response, not a constant DC voltage. The application does not
add artificial damping or automatically declare convergence.

## Build and test

Supported release targets: Linux x86-64 and Apple Silicon macOS. Install a compatible
published Sun compiler first. Linux needs Git, Python, CMake, Ninja, Clang,
GObject introspection metadata, GStreamer development libraries, X11/Xext
development libraries, GTK4 development libraries, librsvg development libraries,
`pkg-config`, Xvfb, xauth, D-Bus, and DejaVu fonts. macOS needs Homebrew `gtk4`,
`librsvg`, `pkgconf`, `coreutils`, `cmake`, `ninja`, `python`,
`gobject-introspection`, and `gstreamer`.
`sun dep install` installs additional requirements declared by Git dependencies.

```sh
sun dep install --config sun-config.json --yes
./scripts/install-dependencies.sh
./build.sh --test                 # Sun-only physics and state tests
./build.sh --plot-test            # Curve accuracy; needs sun_ui/sun_plot, no display
./build.sh --build
./build/sun_tline
```

Run all checks with an available desktop using `./build.sh --all`. On Linux:

```sh
xvfb-run -a dbus-run-session -- ./build.sh --all
sun fmt --check src tests
```

The dependency installer resolves the Git packages in `sun-config.json` and builds
`sun_ui`, `sun_plot`, the GTK adapter, and `sun_gobject` with the application's
compiler. Sun manages source checkouts and generated bindings under `.sun/`.
Dependencies use SSH URLs and `main`; CI rewrites GitHub SSH URLs to HTTPS.
Set a dependency's `version` to a branch, tag, or commit to select another revision.
Use `sun build --refresh-sources` to refresh cached revisions explicitly.

Dependency resolution records and licenses live in `build/dependencies/`;
the compiler version is recorded in `build/sun-version.txt`. CI retains these
records with the packaged artifacts. `SUN_EXECUTABLE` selects the compiler for
both dependency setup and application builds.

`sun-config.json` declares the named products and native linking requirements.
The `build.sh` wrapper queries `sun describe` for their actual output paths and
copies the GUI executable to `build/sun_tline` for packaging and manual use.
The application requires the drawing APIs from the selected `sun_ui` revision.
Its manifest loads GTK types through `sun_ui_gtk.moon`. Do not also import the
direct `sun_gobject` Moon libraries there: the renderer's transitive build can
resolve to a different cache path, creating distinct GTK type instances.
Legacy `SUN_UI_BUILD`, `SUN_GOBJECT_BUILD`, `SUN_UI_RELEASE`, and
`SUN_GOBJECT_RELEASE` overrides are no longer used.

## Packages

After a successful build and tests:

```sh
./scripts/package-linux.sh        # Linux Debian package, extraction and launch test
./scripts/package-macos.sh        # Relocated, ad-hoc-signed app and DMG on macOS
```

For local dependency overrides, also set `SUN_UI_SOURCE` and `SUN_GOBJECT_SOURCE`
to their repository roots so packaging can include license notices. Linux packaging
requires `dpkg-dev` and native library package metadata. Install the Debian package
with `sudo apt install ./build/sun-tline_amd64.deb` and launch **Sun Tline** from the
desktop menu. The macOS DMG contains an app to drag into Applications. It is ad-hoc
signed, not notarized; macOS may require approving it in Privacy & Security.

CI validates both platforms, builds packages, and updates the same private `dev`
prerelease only when both platform jobs succeed. Each successful publication
replaces the package, checksum, and provenance assets and moves the `dev` tag
to the tested commit. Pushes to `main` and manual
runs of the **CI** workflow on `main` can publish a release. The DMG is mounted
and its app copied to a fresh path, then checked for signatures, library
relocation, and native GTK behavior with a clean environment before publication. No public package registry is used.

## Numerical model

The engine uses two fixed-size circular wave buffers with one cell transit per
step: `dt = length / (velocity * cells)`. Voltage is `V+ + V-`; current is
`(V+ - V-) / Z0`. Both terminal arrivals are evaluated before updating either
buffer. Source resistance reflects returning waves with `(Rs-Z0)/(Rs+Z0)`.

The load is driven by the arriving wave's equivalent voltage `2 V+` through `Z0`.
Resistors use their exact reflection relation. Capacitors and inductors use
trapezoidal companion equations with retained voltage/current state. This follows
wave-digital modeling principles described in Julius O. Smith's *Physical Audio
Signal Processing*, “Wave Digital Filters”.

The default is 512 cells; 32–16384 are supported. Reactive time scales and pulse
widths must span at least 20 steps, and sine periods at least 100. Double resolution
to check convergence. Abrupt step/pulse edges have the expected grid-time
quantization, and narrow spatial details can be lost in the display's reduced
sampling. Simulation work is bounded per event-loop turn. Delayed updates retain pending
physical time and catch up in batches without skipping numerical steps; sustained
overload can still make playback fall behind wall time. Long-running or overflowing experiments stop with a
message instead of displaying invalid values.

Tests cover analytical resistive and reactive responses, RLC convergence, complex
sine impedance, undamped pulse energy, dissipative decay, input validation, bounded
history, and playback independence. Native tests exercise actual controls, every
preset, document replacement, resizing, and resource cleanup.

All simulation, UI, and test logic is Sun. YAML, JSON, SVG, desktop metadata, and
small shell scripts provide configuration and packaging. There is no arbitrary
circuit editor, distributed line loss, Windows release, or Intel macOS release.
