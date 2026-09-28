# ChipForAll (C4O)

![CI Status](https://github.com/anlit75/ChipForAll/actions/workflows/verify.yml/badge.svg)
![release Version](https://img.shields.io/github/v/release/anlit75/ChipForAll?label=version)
[![License](https://img.shields.io/github/license/anlit75/ChipForAll)](LICENSE)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/anlit75/ChipForAll)

*[繁體中文](README.zh-TW.md)*

**A verification and CI starter kit for open-source silicon.** Simulate your RTL, drive it from Python, simulate the gates it synthesises into, and read the signoff numbers — then hand the physical flow to LibreLane. One `make` command each, nothing to install.

The example design is Verilog. You do not need Verilog to run the whole flow and read what it measured, but you do to change the design or write a test — [Prerequisites](#prerequisites) is more specific.

## ✨ Features

*   **🧪 Testbenches that can actually fail**: `make sim` for Verilog, `make cocotb` for Python. Both exit non-zero when they should — a test that passes on a broken design is worse than no test.
*   **🔬 Gate-level simulation**: `make gatesim` re-runs your tests against the netlist synthesis actually produced. Latch inference and reset handling sit between your RTL and those gates, and none of it is visible from the RTL.
*   **📊 Signoff you can read**: `make report` pulls the handful of numbers that matter — area, timing, power, DRC/LVS/antenna — out of a 300-key `metrics.json` nobody opens.
*   **✅ CI that runs all of it**: a GitHub Actions workflow that lints, simulates, synthesises, builds the GDS and re-simulates the gates, on every push.
*   **🐳 Nothing to install**: Docker, or a Dev Container / Codespace. `make gds` works in all three.

### What this is not

The physical flow — RTL to GDSII — is [LibreLane](https://github.com/librelane/librelane)'s, and `make gds` is a thin wrapper around it. If all you want is a layout, LibreLane runs standalone with `--dockerized` and you do not need this repo.

What LibreLane does not cover is simulation and verification. That is what this starter kit adds, plus the CI and the Dev Container to run it in.

**The tools are open-source equivalents, not the commercial ones.** Yosys does the synthesis, LibreLane (OpenROAD underneath) the place and route, Icarus and Verilator the simulation and linting, Magic and KLayout the DRC — where a commercial flow would use Design Compiler, Innovus or IC Compiler, VCS or Questa, and Calibre. The flow shape is the same and the vocabulary transfers; the tools on your CV would not be the ones a job advert lists, so say which you used.

**Looking for a worked verification example?** This repository's tests are a Verilog testbench and two cocotb ones — enough to show what a test that can fail looks like, and not a layered verification environment. [c4o-pyuvm](https://github.com/anlit75/c4o-pyuvm) is that: a pyuvm environment on a real UART — agent, driver, monitor, scoreboard, and a register model generated from SystemRDL — built from this template.

**What you make here is yours to publish.** The process is [Sky130](https://github.com/google/skywater-pdk), the PDK SkyWater released under Apache 2.0, with no NDA attached — so the layout, the area, the timing numbers and the GDS can all go into a repository, a portfolio or a write-up. A foundry PDK under a confidentiality agreement does not allow any of that, which is why people who have one come here for a second set of results they are allowed to show — and why people who have never had one can produce results at all.

## 🚀 Quick Start

### Prerequisites
*   Docker (Desktop or Engine)
*   Make
*   Git

*… or none of the above: open it in a GitHub Codespace and everything is already there.*

**One prerequisite is not a download: some Verilog.** Not much — enough to read an `always @(posedge clk)` block, a `<=` assignment and a `$fatal`. On [HDLBits](https://hdlbits.01xz.net/) that is the *Verilog Language* section, not the whole site.

You do not need it to start. `make gds` runs the example as it stands and prints real area, timing and power, and `make all` shows you tests passing; that is worth doing first, because it tells you the toolchain works on your machine. What needs Verilog is the step after: changing `src/blinky.v`, judging whether a test that passed proves anything, or writing one of your own. Run it first, learn Verilog, then come back for that.

### 1. Make your own copy

This repository is a **GitHub template**. Press **Use this template → Create a new repository**, then clone your copy:

```bash
git clone https://github.com/<you>/<your-repo>.git
cd <your-repo>
```

### 2. Run the full flow

```bash
make gds
```

*The first run downloads the Sky130 PDK (~3GB) before it starts anything — around
twenty minutes on a fast link, longer on a slow one. The flow itself is about three
minutes, and that is what every run after the first one costs. `make pdk` gets the
download out of the way on its own.*

### 3. Make it your design

The example is a blinky — a clock divider. To replace it with your own, four things have to agree, and nothing else does:

| Change | Where |
|---|---|
| Your RTL | `src/`, listed under `VERILOG_FILES` in `config.yaml` |
| `DESIGN_NAME` | `config.yaml` — must match your top module's name |
| Your testbenches | `test/`, under `"//TEST_FILES"` and `"//COCOTB_TESTS"` |
| The gate-level one | `test/gate/`, under `"//GATE_TESTS"` |

Nothing else names the design: the `Makefile` and the CI workflow both read `DESIGN_NAME` from `config.yaml`.

**The last two rows are optional.** Delete `"//COCOTB_TESTS"` or `"//GATE_TESTS"` from `config.yaml` — the key line *and* the indented paths under it — and CI skips that kind of test instead of failing. Keep the key and point it at nothing and CI fails, correctly: you asked for tests that are not there.

**A second Verilog testbench needs one more key.** `"//TEST_FILES"` takes a glob, and
Icarus elaborates every module nobody instantiates as a root of its own — so the first
`$finish` would end the whole simulation and the rest would never run. Name the one you
mean with `"//SIM_TOP"` as soon as more than one file matches.

Get the first row wrong and you hear about it immediately, not three minutes into `make gds`:

```console
[ERROR] DESIGN_NAME is 'my_cpu', but no module by that name is declared in
        VERILOG_FILES. Declared there: blinky.
```

## 📖 Commands

| Command | Description | Output |
|---|---|---|
| `make all` | `lint`, `sim`, `cocotb` and `synth` — everything that runs in seconds. | `Terminal` |
| `make lint` | Checks your Verilog with Verilator. | `Terminal` |
| `make sim` | Runs the Verilog testbenches with Icarus Verilog. | `build/wave.vcd` |
| `make cocotb` | Runs the Python (cocotb) testbenches. | `build/cocotb-results.xml` |
| `make synth` | Synthesises RTL into gates with Yosys. One fixed script; `make shell` if you want to drive Yosys yourself. | `build/synthesis.json` |
| `make pdk` | Installs the Sky130 PDK. `make gds` runs it for you; run it alone to do the 3GB download ahead of time. | `pdks/` |
| `make schematic` | Draws the circuit as an SVG you can open anywhere. | `build/schematic.svg` |
| `make gds` | Builds the physical layout with LibreLane. About three minutes, plus the PDK download on a first run. | `build/<DESIGN_NAME>.gds` |
| `make gatesim` | Re-runs simulation on the synthesised netlist. Needs `make gds` first. | `Terminal` |
| `make report` | Area, timing, power and signoff from the last `make gds`. | `Terminal` |
| `make shell` | A bash shell inside the c4o-core container. | — |
| `make clean` | Removes `build/`. Keeps `runs/`, which `report` and `gatesim` read. | — |
| `make distclean` | Removes `build/` and `runs/`. | — |

`make help` lists them in the terminal.

## 📊 Reading the result

`make gds` ends by printing what the flow measured, so you do not have to go looking for it:

```
  blinky

  die              69.5 x 80.2 um  (5573 um^2)
  utilization      57.1%
  standard cells   198
  setup slack      +4.70 ns  (0 violations)
  hold slack       +0.11 ns  (0 violations)
  power            0.290 mW
  signoff          clean  (Magic DRC, KLayout DRC, LVS, antenna, XOR)
  lint warnings    0
  layout           runs/blinky_run/final/render/blinky.png
```

Those are the example design's numbers, from one PDK version. Yours will differ;
the lines are what to read.

**`signoff`** says the thing nothing else says: your layout passes the manufacturability checks. The LibreLane pinned here, 3.0.14, errors on every one of them by default (`ERROR_ON_MAGIC_DRC` and its siblings are all `True`) and `config.yaml` overrides none of them, so a run that reached this line has already passed them. That is that version's default, not a guarantee this repository makes — check it again after an upgrade. `clean` states it, and names which checks it saw. When something is wrong it names that instead: `2 Magic DRC, 1 LVS`.

**`layout`** is the PNG the flow drew of your chip. Open it.

`XOR` there is not a process-rule check: it is two tools writing the same layout out as GDS and comparing the results, which has to agree. It buys back some of the confidence you get from having two vendors' tools cross-check each other.

**Positive slack** means the design meets the clock in `config.yaml`. Negative means it does not, and the flow does not stop for it — so a run can finish and still be telling you it missed. [What to do about that](docs/guide.md#when-slack-is-negative) is in the guide.

**Those nine lines are a summary, not a signoff report.** They are pulled out of a
300-key `metrics.json`, so what they leave out matters: what clock uncertainty and
derating were applied, what the clock tree's skew came to, and which of the nine
corners (`ss`/`tt`/`ff` against `min`/`nom`/`max` interconnect) that slack came from.
All of that is LibreLane's defaults — `config.yaml` sets none of it — and all of it
is under `runs/`, one directory per step. The difference is practical: a `+0.11 ns`
hold slack is not what a flow where you filled in the OCV derates yourself would
call passing. For confidence at that level, read the per-corner reports, not these
nine lines.

`make report` prints all of it again without re-running anything.

## 📚 Next steps

The [guide](docs/guide.md) covers what comes after the first run:

*   [Writing a testbench for your own design](docs/guide.md#writing-a-testbench-for-your-own-design) — the smallest one that can actually fail
*   [Looking at the waveform](docs/guide.md#when-a-test-fails-look-at-the-waveform) when a test goes red
*   [Python testbenches](docs/guide.md#writing-testbenches-in-python) with cocotb, [random stimulus against a reference model](docs/guide.md#random-stimulus-and-a-reference-model), and [gate-level simulation](docs/guide.md#simulating-the-gates-not-just-the-rtl)
*   [Iterating](docs/guide.md#iterating-without-re-running-the-whole-flow) without re-running the whole flow, and [seeing the circuit](docs/guide.md#seeing-the-circuit)
*   [Working inside the container](docs/guide.md#working-inside-the-container), and the [full configuration reference](docs/guide.md#configuration-reference)

## 📂 Project Structure

```text
.
├── .devcontainer/     # 🐳 VS Code Dev Container definition
├── config.yaml        # ⚙️ Design name, clock, floorplan
├── Makefile           # 🎮 The command center
├── docs/              # 📚 Everything after the first run
├── src/               # ✍️ Your Verilog source code
│   └── blinky.v
├── test/              # 🧪 Your testbenches
│   ├── tb_blinky.v              # RTL simulation (make sim)
│   ├── test_blinky_cocotb.py    # Python testbenches (make cocotb)
│   ├── test_blinky_random.py    # Random stimulus vs a reference model
│   └── gate/                    # Gate-level simulation (make gatesim)
│       └── tb_blinky_gl.v
└── build/             # 📦 Generated artifacts (GDS, logs, netlists)
```

## 📝 Configuration

`config.yaml` is a [LibreLane](https://github.com/librelane/librelane) configuration file — the same file drives simulation and the physical design flow. These are the keys you normally touch:

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

The rest (`PDK`, `FP_SIZING`, `FP_CORE_UTIL`, …) configures the physical design flow; leave it alone until you need it. The die is not something you have to size — `FP_SIZING: relative` grows it to fit your design. The [configuration reference](docs/guide.md#configuration-reference) has the details.

---

Powered by the **[c4o-core](https://github.com/anlit75/c4o-core)** engine.
