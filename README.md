# ChipForAll (C4O)

![CI Status](https://github.com/anlit75/ChipForAll/actions/workflows/verify.yml/badge.svg)
![release Version](https://img.shields.io/github/v/release/anlit75/ChipForAll?label=version)
[![License](https://img.shields.io/github/license/anlit75/ChipForAll)](LICENSE)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/anlit75/ChipForAll)

**A verification and CI starter kit for open-source silicon.** Simulate your RTL, drive it from Python, simulate the gates it synthesises into, and read the signoff numbers — then hand the physical flow to LibreLane. One `make` command each, nothing to install.

## ✨ Features

*   **🧪 Testbenches that can actually fail**: `make sim` for Verilog, `make cocotb` for Python. A test that passes on a broken design is worse than no test, so both exit non-zero when they should — which is less obvious than it sounds, and is where most of this repo's bug fixes have gone.
*   **🔬 Gate-level simulation**: `make gatesim` re-runs your tests against the netlist synthesis actually produced. Latch inference and reset handling sit between your RTL and those gates, and none of it is visible from the RTL.
*   **📊 Signoff you can read**: `make report` pulls the handful of numbers that matter — area, timing, power, DRC/LVS/antenna — out of a 300-key `metrics.json` nobody opens.
*   **✅ CI that runs all of it**: a GitHub Actions workflow that lints, simulates, synthesises, builds the GDS and re-simulates the gates, on every push.
*   **🐳 Nothing to install**: Docker, or a Dev Container / Codespace. `make gds` works in all three.

### What this is not

The physical flow — RTL to GDSII — is [LibreLane](https://github.com/librelane/librelane)'s, and `make gds` is a thin wrapper around it. If all you want is a layout, LibreLane runs standalone with `--dockerized` and you do not need this repo.

What LibreLane does not cover is simulation and verification. That is what this starter kit adds, plus the CI and the Dev Container to run it in.

## 🚀 Quick Start

### Prerequisites
*   Docker (Desktop or Engine)
*   Make
*   Git

*… or none of the above: open it in a GitHub Codespace and everything is already there.*

### 1. Make your own copy

This repository is a **GitHub template**. Press **Use this template → Create a new repository**, then clone your copy:

```bash
git clone https://github.com/<you>/<your-repo>.git
cd <your-repo>
```

Cloning this repository directly also works, but you get its git history and no place to push.

### 2. Run the Full Flow
To go from Verilog code to a final GDSII layout file:
```bash
make gds
```
*Wait for a few minutes. The system will automatically download the PDK, run synthesis, place & route, and generate the layout.*

### 3. Make it your design

The example is a blinky — a clock divider. To replace it with your own, four things have to agree, and nothing else does:

| Change | Where |
|---|---|
| Your RTL | `src/`, listed under `VERILOG_FILES` in `config.yaml` |
| `DESIGN_NAME` | `config.yaml` — must match your top module's name |
| Your testbenches | `test/`, under `"//TEST_FILES"` and `"//COCOTB_TESTS"` |
| The gate-level one | `test/gate/`, under `"//GATE_TESTS"` — see below for why it is separate |

Nothing else names the design. The `Makefile` and the CI workflow both read `DESIGN_NAME` from `config.yaml`, so renaming it is enough.

**The last two rows are optional.** Delete `"//COCOTB_TESTS"` or `"//GATE_TESTS"` from `config.yaml` and CI skips that kind of test instead of failing. A Verilog testbench is the one thing worth insisting on; a Python one is a second way to write the same test, and a gate-level one is the hardest file here to write — it cannot shrink the design through a parameter the way `test/tb_blinky.v` does, so it has to drive the real ports at their real width.

Keep the key and point it at nothing, though, and CI fails — correctly. You asked for tests that are not there.


Get the first row wrong and you hear about it immediately, not three minutes into `make gds`:

```console
[ERROR] DESIGN_NAME is 'my_cpu', but no module by that name is declared in
        VERILOG_FILES. Declared there: blinky.
```

## 📖 Usage Guide

We provide a unified `Makefile` to handle everything.

| Command | Description | Output Location |
|---|---|---|
| `make lint` | Checks your Verilog code for syntax errors using Verilator. | `Terminal Output` |
| `make sim` | Runs simulation using Icarus Verilog. | `build/sim.vvp` |
| `make cocotb` | Runs the Python (cocotb) testbenches. | `build/cocotb-results.xml` |
| `make synth` | Synthesizes RTL into Gates using Yosys. | `build/synthesis.json` |
| `make schematic` | Draws the circuit as an SVG you can open anywhere. | `build/schematic.svg` |
| `make gatesim` | Re-runs simulation on the synthesised netlist. Needs `make gds` first. | `Terminal Output` |
| `make gds` | Generates the physical layout using LibreLane. | `build/<DESIGN_NAME>.gds` |
| `make report` | Shows area, timing, power and the DRC/LVS/antenna signoff from the last `make gds`. | `Terminal Output` |
| `make shell` | Opens a bash shell inside the c4o-core container. | `N/A` |
| `make clean` | Removes all generated artifacts. | `N/A` |

> **💡 Note:** The first time you run `make gds`, it will automatically download and install the Sky130 PDK (approx. 3GB). Please be patient!

### Reading the result

`make gds` ends by printing what the flow measured, so you do not have to go
looking for it:

```
  blinky

  die              100 x 100 um  (10000 um^2)
  utilization      29.2%
  standard cells   243
  setup slack      +4.69 ns  (0 violations)
  hold slack       +0.11 ns  (0 violations)
  power            0.292 mW
  signoff          clean  (Magic DRC, KLayout DRC, LVS, antenna, XOR)
  lint warnings    0
  layout           runs/blinky_run/final/render/blinky.png
```

**`signoff`** is the row that says the thing nobody else says: your layout
passes the manufacturability checks. LibreLane errors on every one of them by
default, so a run that reached this line has already passed them — `clean`
just states it, and names which checks it saw. When something is wrong it
names that instead: `2 Magic DRC, 1 LVS`.

**`layout`** is the PNG the flow drew of your chip. It renders one on every
run and then leaves it in the run directory; open it.

Positive slack means the design meets the clock in `config.yaml`. Run
`make report` on its own to see it again without repeating the flow.

**Negative slack means it does not**, and there are only two answers. Give the
design more time — raise `CLOCK_PERIOD` in `config.yaml` and run `make gds`
again — or make the slow path shorter, by pipelining it or cutting logic out
of it. Which one is right depends on whether the clock speed is a requirement
or a guess; in a first design it is usually a guess.

To see *what* is slow, read the timing report the flow already wrote:

```bash
cat runs/*/final/*.rpt          # or look under runs/<tag>/ for the STA steps
```

The worst path is listed with every gate along it, which is where the time
actually went. The flow does not stop for negative slack, so a run can finish
and still be telling you it missed.

### Iterating without re-running the whole flow

The first `make gds` is about three minutes. Most of what you change after it
— `FP_CORE_UTIL`, `CLOCK_PERIOD`, the floorplan — does not need synthesis redone,
so hand LibreLane the flags that resume the last run:

```bash
make gds LIBRELANE_ARGS="--last-run --from floorplan"
```

`runs/` stays where LibreLane puts it, which is what makes that work. It used
to be moved into `build/` after each run, which looked tidier and silently
broke `--last-run`: LibreLane looks for a previous run in `runs/`, and there
was never one there. `make clean` removes both.

### Seeing the circuit

```bash
make schematic
```

Draws `build/schematic.svg` — your design as flops, adders and muxes, carrying
the names you gave them. Open it in the browser, or click it in VS Code; it is
an SVG, so nothing special is needed to read it.

It is not a picture of the netlist. `make synth` runs a full synthesis and
leaves hundreds of technology cells, from which nobody has ever learned
anything about their own design. `make schematic` stops earlier, where the
circuit still looks like the code it came from.

Under a second, so it costs nothing to run after every change — unlike
`make gds`.

### Writing a testbench for your own design

`test/tb_blinky.v` is a worked example and reads like one. This is the shape
underneath it — the smallest testbench that can actually fail:

```verilog
`timescale 1ns/1ps

module tb_my_design;

    reg clk = 0;
    reg rst = 1;
    wire result;

    my_design uut (.clk(clk), .rst(rst), .result(result));

    always #5 clk = ~clk;          // a 100 MHz clock

    initial begin
        $dumpfile("build/wave.vcd");
        $dumpvars(0, tb_my_design);

        repeat (2) @(posedge clk);
        rst = 0;

        @(posedge clk);
        #1;                        // let the non-blocking assignment land
        if (result !== 1'b1)
            $fatal(1, "result should be high after reset, got %b", result);

        $display("tb_my_design: PASS");
        $finish;
    end

endmodule
```

Three things are doing the work:

*   **`$fatal` is what makes a broken design a red CI run.** `$display` prints
    and carries on, and the simulator exits 0 either way — a test that reports
    a failure without failing is decoration. `$fatal` exits non-zero, which is
    what `make sim` and the workflow are reading.
*   **`#1` after the edge.** `@(posedge clk)` resumes *at* the edge, before
    non-blocking assignments land, so a read there sees the previous cycle's
    value. Relative checks still pass that way, which is what makes it easy to
    miss.
*   **`$dumpfile`/`$dumpvars` come from you**, not from the tool. Without them
    there is no waveform to look at when the assertion above fires.

Try it: change `src/blinky.v` so the design is wrong, run `make sim`, and
watch it go red. A testbench you have never seen fail is a testbench you do
not know works.

### When a test fails: look at the waveform

`make sim` writes `build/wave.vcd` — every signal, every cycle. Open it with
GTKWave, or with the **WaveTrace** extension the Dev Container already
installs (click the `.vcd` file). A failing assertion tells you *that* the
design is wrong; the waveform is how you find out *why*.

It comes from the testbench, not from the tool, so your own testbenches need
these two lines to produce one:

```verilog
initial begin
    $dumpfile("build/wave.vcd");
    $dumpvars(0, tb_your_design);
end
```

`test/tb_blinky.v` has them already. `*.vcd` is in `.gitignore`, and CI keeps
each run's copy in the `chipforall-build-artifacts` upload for five days — so
a test that only fails on CI can still be inspected.

### Writing testbenches in Python

`make cocotb` runs [cocotb](https://www.cocotb.org/) tests: Python coroutines
driving the same RTL, through the same simulator. It is an alternative to
`test/tb_blinky.v`, not a replacement — pick whichever language suits the test.

```bash
make cocotb
```

The example in `test/test_blinky_cocotb.py` leans on the one thing Python is
plainly better at here: writing to a signal *inside* the design.

```python
dut.count.value = (1 << (WIDTH - 1)) - 1   # one tick below the rollover
await tick(dut)
assert dut.led.value == 1
```

Checking that `led` is the counter's top bit costs four cycles that way. A
Verilog testbench gets there only by overriding `WIDTH` — which the gate-level
testbench cannot do — or by running 2^25 cycles, which is what `make gatesim`
spends four minutes on below.

One gotcha the example encodes: `RisingEdge` resumes *at* the edge, before the
non-blocking assignment lands. Every read in that file waits a further `Timer`
first, or it would see the previous cycle's value.

### Simulating the gates, not just the RTL

`make sim` says your Verilog behaves. It says nothing about the netlist the
tools produced from it — latch inference, reset handling and how a synthesiser
reads an ambiguous `always` block all sit between the two, and none of them are
visible from the RTL. `make gatesim` closes that gap: it simulates
`runs/<tag>/final/nl/`, the gate-level netlist `make gds` left behind,
against the Sky130 cells' own Verilog models.

```bash
make gds       # produces the netlist
make gatesim   # simulates it
```

It needs its own testbench, in `test/gate/`, because synthesis resolves
parameters: `test/tb_blinky.v` shrinks the design by setting `WIDTH` to 4, and
a netlist has no `WIDTH` left to set. `test/gate/tb_blinky_gl.v` therefore
drives the real pins and watches `led` over a full divider period — all 2^26
cycles of it, which takes about four minutes (3:36 on a CI runner).

That cost is why CI runs `make gatesim` on pushes to `main` and on `v*` tags,
but not on every pull request.

### Working inside the container

The repo ships a [Dev Container](https://containers.dev/). Open it in GitHub Codespaces, or in VS Code with *Reopen in Container*, and you get the same image CI uses, with the Verilog extensions already installed — no Docker commands to type. The `Makefile` notices it is already inside the container and calls the tools directly instead of nesting another one.

It runs as `root`. On a Linux host that means files it writes into `build/` end up owned by `root`, so `make clean` from your host may need `sudo`. Running as a normal user instead breaks Codespaces, so this is the side we err on.

`make gds` works in here too. It launches the LibreLane container as a sidecar, so the Dev Container ships a Docker daemon of its own for it to talk to — you no longer have to leave for your host terminal, which in Codespaces meant you could not run the headline command at all.

That is docker-*in*-docker rather than docker-outside-of-docker, and the difference is not a preference. `make gds` bind-mounts the working directory, which is `/workspace` in here. An outside daemon would resolve that path on your host, where `/workspace` does not exist, so Docker would create an empty directory and LibreLane would run against nothing — no error, just a confusing failure deep in the flow. An inside daemon resolves it against this filesystem, where it is the repo.

The cost is a first run that pulls the LibreLane image inside the container, and a Dev Container that has to be rebuilt once for the feature to install. If `make gds` says it cannot find a Docker daemon, a rebuild is what it is asking for.

**Watch the disk in a Codespace.** That inner daemon has its own image store, so the LibreLane image is pulled again rather than shared with the host, and the Sky130 PDK is another 3GB on top. On the smallest Codespace machine that is most of the disk. Pick a larger one, or run `make gds` from your own host if the Codespace runs out.

Prefer to stay in your own editor? `make shell` drops you into the same image from any terminal.

## 📂 Project Structure

```text
.
├── .devcontainer/     # 🐳 VS Code Dev Container definition
├── config.yaml        # ⚙️ Project configuration (Design Name, Clock, Area)
├── Makefile           # 🎮 The command center
├── src/               # ✍️ Your Verilog Source Code
│   └── blinky.v
├── test/              # 🧪 Your Testbenches
│   ├── tb_blinky.v              # RTL simulation (make sim)
│   ├── test_blinky_cocotb.py    # Python testbenches (make cocotb)
│   └── gate/                    # Gate-level simulation (make gatesim)
│       └── tb_blinky_gl.v
└── build/             # 📦 All generated artifacts (GDS, Logs, Netlists)
```

## 📝 Configuration

Modify `config.yaml` in the root directory to change your design settings. It is a [LibreLane](https://github.com/librelane/librelane) configuration file — the same file drives simulation and the physical design flow, and the comments in it mark which settings you normally touch:

```yaml
DESIGN_NAME: my_design

VERILOG_FILES:
  - dir::src/my_design.v

# Simulation only. LibreLane ignores keys starting with '//'.
"//TEST_FILES":
  - dir::test/*.v

CLOCK_PORT: clk
CLOCK_PERIOD: 10.0
```

The remaining keys in the file (`PDK`, `FP_SIZING`, `FP_CORE_UTIL`, …) configure the physical design flow. Leave them alone until you need them — `make gds` will tell you if one is missing.

The die is not one of the things you have to size. `FP_SIZING: relative` floorplans from `FP_CORE_UTIL` — how full the core should be, 40% here — so a bigger design gets a bigger die instead of "does not fit". Lower it if routing is tight, raise it for a smaller chip. A fixed die is still available: set `FP_SIZING: absolute` and add `DIE_AREA: [0, 0, w, h]`.

---

Powered by the **[c4o-core](https://github.com/anlit75/c4o-core)** engine.
