# Sun Tline

A desktop transmission-line simulator written in Sun using `sun_ui` and `sun_plot`.
It shows forward and reflected voltage/current waves and switch-on transients
on an ideal lossless line.

## Experiments

Choose **Repeated reflections**, **Matched line**, **Open end**, **Shorted end**,
**Capacitive charging**, **Inductive response**, **RLC ringing**, or **Sine standing wave**.
Press **Run**, pause at any time, or use **Single step** to advance one numerical step.
Playback speed is measured in line transits per wall-clock second; physical time
and transit time are shown below the plots.

The source defaults to an ideal voltage source (0 Ω source resistance) and supports
a step, a finite pulse, and sine excitation. Source matching presets explicitly
set their source resistance. Terminations are
open, shorted, resistive, capacitive, inductive, or series RC/RL/RLC. Settings use
SI units, including seconds, farads, and henries; scientific notation is accepted.
Edit settings and press **Apply and reset**. Invalid settings leave the current
experiment intact. **Reset** discards unapplied edits and restarts the active circuit.
Selecting a preset immediately installs it and pauses playback. Selecting a source
waveform applies the current settings and resets playback immediately; invalid
settings leave the active simulation unchanged. The active waveform is shown
beside the simulation time.

The default pulse lasts 12.5 ns, a quarter of the default line transit time, so
both edges fit on the line before reflection. Longer pulse widths are allowed;
when the width exceeds the transit time, the leading edge reaches the load
before the source switches off, initially resembling a step.

The dark studio interface uses red voltage waves and green current waves.
Voltage and current wave plots each occupy a full row. Playback targets 60 frames
per second with display-only subcell interpolation, while the numerical solver
retains its fixed step.

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
published Sun compiler first. Linux needs GTK4 development libraries, librsvg runtime,
`pkg-config`, Xvfb, xauth, D-Bus, and DejaVu fonts. macOS needs Homebrew `gtk4`,
`librsvg`, `pkgconf`, and `coreutils`.

```sh
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

The default dependency installer downloads published `dev` bundles, never sources.
`SUN_UI_RELEASE` and `SUN_GOBJECT_RELEASE` can select another published release.
Dependencies, download checksums, and producer compiler versions live in
`build/dependencies/`; the consumer compiler version is in `build/sun-version.txt`.
Build products and native acceptance SVGs are in `build/`.

### Required drawing support

This application requires `ui.Kind.Drawing`, `Element.drawing_id`, and the GTK
renderer drawing registration API, plus retained `gtk.DrawingArea`/`gtk.Widget`
ownership. These changes were prepared in the adjacent `sun_ui` and `sun_gobject`
repositories. **Published dependency releases must include these APIs before CI
and release publication can succeed.** Older bundles fail compilation; there is
no automatic source-build fallback.

For development against explicitly built local dependencies:

```sh
SUN_UI_BUILD=../sun_ui/build \
SUN_GOBJECT_BUILD=../sun_gobject/build ./build.sh --build
```

The application never builds or changes those checkouts. Follow each dependency's
own build instructions and use compatible compiler bundles.

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

CI validates both platforms, builds packages, and publishes a private numbered
prerelease only when both platform jobs succeed. No public package registry is used.

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
sampling. Simulation work is bounded per frame and slows under load without
skipping numerical steps. Long-running or overflowing experiments stop with a
message instead of displaying invalid values.

Tests cover analytical resistive and reactive responses, RLC convergence, complex
sine impedance, undamped pulse energy, dissipative decay, input validation, bounded
history, and playback independence. Native tests exercise actual controls, every
preset, document replacement, resizing, and resource cleanup.

All simulation, UI, and test logic is Sun. YAML, JSON, SVG, desktop metadata, and
small shell scripts provide configuration and packaging. There is no arbitrary
circuit editor, distributed line loss, Windows release, or Intel macOS release.
