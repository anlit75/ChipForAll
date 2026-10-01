# Guide

Everything the [README](../README.md) leaves out: what this is and is not, the prerequisites in detail, making the template your design, reading the numbers, and what comes after the first run.

*[繁體中文](guide.zh-TW.md)*

## What this is, and what it is not

The physical flow — RTL to GDSII — is [LibreLane](https://github.com/librelane/librelane)'s, and `make gds` is a thin wrapper around it. If all you want is a layout, LibreLane runs standalone with `--dockerized` and you do not need this repo.

What LibreLane does not cover is simulation and verification. That is what this starter kit adds, plus the CI and the Dev Container to run it in.

**The tools are open-source equivalents, not the commercial ones.**

| Step | Here | What a commercial flow uses |
|---|---|---|
| Lint | Verilator | SpyGlass, Questa Lint |
| Simulation | Icarus Verilog, driven from Python by cocotb | VCS, Questa, Xcelium |
| Synthesis | Yosys | Design Compiler, Genus |
| Place and route | OpenROAD, wrapped by LibreLane | IC Compiler II, Innovus |
| Static timing | OpenSTA | PrimeTime, Tempus |
| DRC | Magic, KLayout | Calibre nmDRC, Pegasus |
| LVS | Netgen | Calibre nmLVS |

The flow shape is the same and the vocabulary transfers; the tools on your CV would not be the ones a job advert lists, so say which you used.

**Looking for a worked verification example?** This repository's tests are a Verilog testbench and two cocotb ones — enough to show what a test that can fail looks like, and not a layered verification environment. [c4o-pyuvm](https://github.com/anlit75/c4o-pyuvm) is that: a pyuvm environment on a real UART — agent, driver, monitor, scoreboard, and a register model generated from SystemRDL — built from this template.

**What you make here is yours to publish.** The process is [Sky130](https://github.com/google/skywater-pdk), the PDK SkyWater released under Apache 2.0, with no NDA attached — so the layout, the area, the timing numbers and the GDS can all go into a repository, a portfolio or a write-up. A foundry PDK under a confidentiality agreement does not allow any of that, which is why people who have one come here for a second set of results they are allowed to show — and why people who have never had one can produce results at all.

## Before you start

**On Apple Silicon, part of this runs emulated.** The c4o-core image is built for
`amd64` only — one runner, no `platforms:` — so `lint`, `sim`, `cocotb`, `synth`
and `gatesim` go through emulation on an `arm64` machine. `make gds` does not:
the heavy step runs LibreLane's own image, and that one is published for `arm64`
as well, so it runs native. How much the emulated commands slow down is not
measured here. A Codespace is `amd64` throughout.

**One prerequisite is not a download: some Verilog.** Not much — enough to read an `always @(posedge clk)` block, a `<=` assignment and a `$fatal`. On [HDLBits](https://hdlbits.01xz.net/) that is the *Verilog Language* section, not the whole site.

**SystemVerilog is read too.** `logic`, `always_ff` and the synthesisable subset
work in every command since c4o-core 2.8.3, which every version this repository
has pinned since then includes. Before that the same file passed `make cocotb` and `make gds` and
failed `make sim` and `make synth`. What still does not work is an `interface` as
a module boundary — yosys parses the declaration and then fails at `hierarchy` —
so keep interfaces in the testbench, not between synthesisable modules.

You do not need it to start. `make gds` runs the example as it stands and prints real area, timing and power, and `make all` shows you tests passing; that is worth doing first, because it tells you the toolchain works on your machine. What needs Verilog is the step after: changing `src/blinky.v`, judging whether a test that passed proves anything, or writing one of your own. Run it first, learn Verilog, then come back for that.

## Making it your design

The example is a blinky — a clock divider. To replace it with your own, five things have to agree, and nothing else does:

| Change | Where |
|---|---|
| Your RTL | `src/`, listed under `VERILOG_FILES` in `config.yaml` |
| `DESIGN_NAME` | `config.yaml` — must match your top module's name |
| Your testbenches | `test/`, under `"//TEST_FILES"` and `"//COCOTB_TESTS"` |
| The gate-level one | `test/gate/`, under `"//GATE_TESTS"` |
| The waveform's signals | `"//WAVE_SIGNALS"`, named from your testbench's top down |

Nothing else names the design: the `Makefile` and the CI workflow both read `DESIGN_NAME` from `config.yaml`.

Three more things trip up a first design:

*   **Delete the blinky files you replace** — `src/blinky.v`, `test/tb_blinky.v`, `test/test_blinky_*.py`, `test/gate/tb_blinky_gl.v` — or remove them from `config.yaml`. A glob like `src/**/*.v` picks up whatever is still there.
*   **Start every RTL file with `` `timescale 1ns/1ps ``.** Without it `make sim` still passes, because the Verilog testbench declares its own, but `make cocotb` fails with `Unable to accurately represent 10(ns)`.
*   **Rewrite `"//DESCRIPTION"`** in `config.yaml`, or your results page says it is a clock divider that blinks an LED. Same for `"//WAVE_SIGNALS"`: name the signals of your testbench, or `make site` stops at the first one the VCD does not declare.

**The last three rows are optional.** Delete `"//COCOTB_TESTS"`, `"//GATE_TESTS"` or `"//WAVE_SIGNALS"` from `config.yaml` — the key line *and* the indented paths under it — and CI skips that kind of test instead of failing. Keep the key and point it at nothing and CI fails, correctly: you asked for tests that are not there.

**A second Verilog testbench needs one more key.** `"//TEST_FILES"` takes a glob, and
Icarus elaborates every module nobody instantiates as a root of its own — so the first
`$finish` would end the whole simulation and the rest would never run. Name the one you
mean with `"//SIM_TOP"` as soon as more than one file matches.

Get the first row wrong and you hear about it immediately, not three minutes into `make gds`:

```console
[ERROR] DESIGN_NAME is 'my_cpu', but no module by that name is declared in
        VERILOG_FILES. Declared there: blinky.
```

**Where things live.**

```text
.
├── .devcontainer/     # Dev Container definition
├── config.yaml        # Design name, clock, floorplan
├── Makefile           # Every command
├── docs/              # This guide
├── src/               # Your Verilog
│   └── blinky.v
├── test/              # Your testbenches
│   ├── tb_blinky.v              # RTL simulation (make sim)
│   ├── test_blinky_cocotb.py    # Python testbenches (make cocotb)
│   ├── test_blinky_random.py    # Random stimulus vs a reference model
│   └── gate/                    # Gate-level simulation (make gatesim)
│       └── tb_blinky_gl.v
├── build/             # Generated: GDS, logs, netlists, results page
└── runs/              # Generated by make gds: LibreLane's run directories
```

## Commands

| Command | Description | Output |
|---|---|---|
| `make all` | `lint`, `sim`, `cocotb` and `synth` — everything that runs in seconds. | `Terminal` |
| `make lint` | Checks your Verilog with Verilator. | `Terminal` |
| `make sim` | Runs the Verilog testbenches with Icarus Verilog. | `build/wave.vcd` |
| `make cocotb` | Runs the Python (cocotb) testbenches. | `build/cocotb-results.xml` |
| `make synth` | Synthesises RTL into generic gates with Yosys — no area, no timing, see [Seeing the circuit](#seeing-the-circuit). One fixed script; `make shell` to drive Yosys yourself. | `build/synthesis.json` |
| `make pdk` | Installs the Sky130 PDK. `make gds` runs it for you; run it alone to do the 3GB download ahead of time. | `pdks/` |
| `make schematic` | Draws the circuit as an SVG you can open anywhere. | `build/schematic.svg` |
| `make gds` | Builds the physical layout with LibreLane. About three minutes, plus the PDK download on a first run. | `build/<DESIGN_NAME>.gds` |
| `make gatesim` | Re-runs simulation on the synthesised netlist. Needs `make gds` first. | `Terminal` |
| `make report` | Area, timing, power and signoff from the last `make gds`. | `Terminal` |
| `make site` | Puts `report`, the layout, the schematic and the cocotb results on one page. | `build/site/index.html` |
| `make shell` | A bash shell inside the c4o-core container. | — |
| `make clean` | Removes `build/`. Keeps `runs/`, which `report` and `gatesim` read. | — |
| `make distclean` | Removes `build/` and `runs/`. | — |

`make help` lists them in the terminal.

## Reading the result

`make gds` ends by printing what the flow measured, so you do not have to go looking for it:

```
  blinky

  die              69.5 x 80.2 um  (5573 um^2)
  utilization      57.1%
  standard cells   198
  setup slack      +4.70 ns  (0 violations)
  hold slack       +0.11 ns  (0 violations)
  power            0.248 mW  (nom_tt_025C_1v80)
  signoff          clean  (Magic DRC, KLayout DRC, LVS, antenna, XOR)
  lint warnings    0
  layout           runs/blinky_run/final/render/blinky.png
```

Those are the example design's numbers, from one PDK version. Yours will differ;
the lines are what to read.

**`signoff`** says the thing nothing else says: your layout passes the manufacturability checks. The LibreLane version the `Makefile` pins (`LIBRELANE_IMAGE`) errors on every one of them by default (`ERROR_ON_MAGIC_DRC` and its siblings are all `True`) and `config.yaml` overrides none of them, so a run that reached this line has already passed them. That is that version's default, not a guarantee this repository makes — check it again after an upgrade. `clean` states it, and names which checks it saw. When something is wrong it names that instead: `2 Magic DRC, 1 LVS`.

**`layout`** is the PNG the flow drew of your chip. Open it.

`XOR` there is not a process-rule check: it is two tools writing the same layout out as GDS and comparing the results, which has to agree. What it catches is a stream-out bug in either writer. It is not two vendors' tools cross-checking a design — both read the same database — so do not read a clean XOR as a second opinion on the layout itself.

**Positive slack** means the design meets the clock in `config.yaml`. Negative means it does not, and the flow does not stop for it — so a run can finish and still be telling you it missed. [What to do about that](#when-slack-is-negative) is below.

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

## Publishing the results page

`make site` puts those lines, the layout image, the schematic and every cocotb
test with its verdict and seed on one page, `build/site/index.html`. After
`make gds` it also shows each signoff check, the worst setup path as OpenSTA
reports it, an area split (flip-flops, logic, what routing added) and a power
split by sequential, combinational and clock. After `make sim` it draws the
signals `"//WAVE_SIGNALS"` names as a waveform. The power split uses OpenSTA's
default switching activity, not your testbench's, so it shows where power goes,
not what a real workload draws. Each part shows up once you have run the
command behind it.

The page is laid out to be shared, as a portfolio piece: the layout first, then
the numbers, then the tests, with your `"//DESCRIPTION"` under the title and
buttons to open the chip in 3D, download the GDS and view the source. The
heading says when the page was built and which commit it shows, because a
failing `main` is not published: the page keeps showing the last run that
passed.

CI builds that page on every run and publishes it from `main` to GitHub Pages,
at `https://<your-user>.github.io/<your-repo>/`. A new copy of this template
has Pages off, and no workflow can turn it on for you. Do it once: **Settings →
Pages → Source: GitHub Actions**. Until then, CI still passes and says in a
notice that nothing was published.

## When slack is negative

Negative slack means the design does not meet the clock in `config.yaml`. Two answers are yours to reach for from here: give the design more time — raise `CLOCK_PERIOD` and run `make gds` again — or make the slow path shorter, by pipelining it or cutting logic out of it. Which one is right depends on whether the clock speed is a requirement or a guess; in a first design it is usually a guess.

Both of those change the design or its constraints. The physical answers — placement density, clock tree targets, resizer margins, routing effort — are LibreLane's, they are real, and this guide does not cover them: `config.yaml` sets none of those keys and the [configuration reference](#configuration-reference) stops where LibreLane's own variables begin. If you came here to practise timing closure by hand, that is the part you will be reading LibreLane's documentation for.

A third answer is the constraint itself. If the path that fails should never have been timed, or the input delay the flow assumed is not the one your board gives you, no amount of design change fixes that — an SDC file does, and the [configuration reference](#configuration-reference) says how to supply one.

To see *what* is slow, read the timing report the flow already wrote:

```bash
cat runs/*/*-openroad-stapostpnr/*ss_*/checks.rpt
```

One file per timing corner, and hold is the opposite problem: setup fails in the
slow corner, hold in the fast one.

```bash
cat runs/*/*-openroad-stapostpnr/*ff_*/checks.rpt    # hold
ls -d runs/*/*-openroad-stapostpnr/*/                # everything that ran
```

Note that each of those globs matches more than one file. A run of this design
produced nine corner directories — three PVT points (`ss`, `tt`, `ff`) against
three interconnect corners (`min`, `nom`, `max`) — so `cat` concatenates three
reports and does not say which of them is the worst. Pick the worst yourself, the
way you would off a summary.

Either way the worst path is listed with every gate along it and how long each took,
which is where the time actually went.

## Writing a testbench for your own design

`test/tb_blinky.v` is a worked example and reads like one. This is the shape underneath it — the smallest testbench that can actually fail:

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

*   **`$fatal` is what makes a broken design a red CI run.** `$display` prints and carries on, and the simulator exits 0 either way — a test that reports a failure without failing is decoration. `$fatal` exits non-zero, which is what `make sim` and the workflow are reading.
*   **`#1` after the edge.** `@(posedge clk)` resumes *at* the edge, before non-blocking assignments land, so a read there sees the previous cycle's value. Relative checks still pass that way, which is what makes it easy to miss.
*   **`$dumpfile`/`$dumpvars` come from you**, not from the tool. Without them there is no waveform to look at when the assertion above fires.

Try it: change `src/blinky.v` so the design is wrong, run `make sim`, and watch it go red. A testbench you have never seen fail is a testbench you do not know works.

That is the whole method, and it works on any design, not just this one. Break one thing, run the tests, check that the one you aimed at fails and says something you could act on, then `git checkout -- src/blinky.v` and break the next thing. What you learn is not "the tests pass" but which test catches which mistake — and where nothing catches anything, which is the test you have not written yet. It is the only answer to "is my test actually checking the design", because a test that cannot fail cannot tell you.

## When a test fails: look at the waveform

`make sim` writes `build/wave.vcd` — every signal, every cycle — provided your testbench has the two `$dumpfile`/`$dumpvars` lines from the skeleton above. Open it with GTKWave, or with the **WaveTrace** extension the Dev Container already installs (click the `.vcd` file). A failing assertion tells you *that* the design is wrong; the waveform is how you find out *why*.

`*.vcd` is in `.gitignore`, and CI keeps each run's copy in the `chipforall-build-artifacts` upload for five days — so a test that only fails on CI can still be inspected.

## Writing testbenches in Python

`make cocotb` runs [cocotb](https://www.cocotb.org/) tests: Python coroutines driving the same RTL, through the same simulator. It is an alternative to `test/tb_blinky.v`, not a replacement — pick whichever language suits the test.

```bash
make cocotb
```

The smallest test file that drives a clock and checks something looks like this. Note `tick`: `RisingEdge` resumes *at* the edge, before the non-blocking assignment lands, so a read straight after it sees the previous cycle's value — the same gotcha as `#1` in Verilog. Wait a `Timer` after the edge, every time:

```python
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

async def tick(dut):
    await RisingEdge(dut.clk)
    await Timer(1, units="ns")     # let the non-blocking assignment land

@cocotb.test()
async def result_is_high_after_reset(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    dut.rst.value = 1
    await tick(dut)
    dut.rst.value = 0
    await tick(dut)
    assert dut.result.value == 1, f"result should be high, got {dut.result.value}"
```

List the file under `"//COCOTB_TESTS"`, and give your RTL a `` `timescale `` (see [Making it your design](#making-it-your-design)): the `10, units="ns"` clock needs one.

The example in `test/test_blinky_cocotb.py` leans on the one thing Python is plainly better at here: writing to a signal *inside* the design.

```python
dut.count.value = (1 << (WIDTH - 1)) - 1   # one tick below the rollover
await tick(dut)
assert dut.led.value == 1
```

Checking that `led` is the counter's top bit costs four cycles that way. A Verilog testbench gets there only by overriding `WIDTH` — which the gate-level testbench cannot do — or by running 2^25 cycles.

## Random stimulus and a reference model

`test/test_blinky_random.py` is the other half of verification. A directed test asserts on moments somebody chose; this one builds a model of what the design should do and compares against it on every cycle, under stimulus nobody wrote out.

Three pieces, each about ten lines:

*   **The model** — `BlinkyModel`, blinky's behaviour written a second way in Python. Deliberately not a transcription of the RTL: a model that copies the design's mistakes agrees with it everywhere, and so can never catch one.
*   **The stimulus** — random starting counts and random reset pulses, with two of the five windows placed where `led` changes so a run cannot watch a signal that never moves.
*   **The scoreboard** — `led` compared against the model after every clock, failing with the cycle, both values and the starting count.

```bash
make cocotb                   # a new seed each run
make cocotb SEED=1789965785   # replay one exactly
```

cocotb seeds Python's `random` itself and logs the seed it used, so a failure on CI is reproducible on your machine from the log line.

The test also fails when `led` never moved at all — 200 green cycles that watched a constant signal proved nothing, and a suite that reports PASS for that is the thing this repo spends most of its effort avoiding.

It does not check reset *timing*: the stimulus moves `rst` just after a clock edge, so an asynchronous reset and a synchronous one look the same here. That question belongs to static timing — recovery and removal — and the nine-line summary does not carry it: its two slack rows are setup and hold, which are different checks. The per-corner reports do carry it, in a path group of their own:

```bash
grep -A12 'Path Group: asynchronous' runs/*/*-openroad-stapostpnr/*/checks.rpt
```

Measured, not assumed: a CI run of this design produced `recovery check against rising-edge clock clk` in all nine corner reports, and CI prints what it finds there on every run. A design with a synchronous reset has nothing in that path group, which is the right answer for it rather than a missing one.

## Simulating the gates, not just the RTL

`make sim` says your Verilog behaves. It says nothing about the netlist the tools produced from it — latch inference, reset handling and how a synthesiser reads an ambiguous `always` block all sit between the two, and none of them are visible from the RTL. `make gatesim` closes that gap: it simulates `runs/<tag>/final/nl/` — `<tag>` is the run directory, `<DESIGN_NAME>_run` unless you name it yourself — the gate-level netlist `make gds` left behind, against the Sky130 cells' own Verilog models.

```bash
make gds       # produces the netlist
make gatesim   # simulates it
```

It needs its own testbench, in `test/gate/`, because synthesis resolves parameters: `test/tb_blinky.v` shrinks the design by setting `WIDTH` to 4, and a netlist has no `WIDTH` left to set — it is fixed at the 26 `src/blinky.v` declares. `test/gate/tb_blinky_gl.v` therefore drives the real pins and watches `led` over a full divider period — all 2^26 cycles of it, which takes a few minutes.

Parameters are not the only thing synthesis takes away. Internal names go too, so the trick the cocotb test uses above — writing to `dut.count` to skip 2^25 cycles — has nothing to write to here: there is no `count` in a netlist. Anything that reaches inside the design works on the RTL and stops working at this step, which is one of the things this step is for.

**This is a functional check, not a timing one.** Nothing here back-annotates an
SDF, so the cells switch with zero delay and the run cannot see a race that only
appears at real delays. What it does see is everything synthesis decided:
inferred latches, how reset was implemented, how an ambiguous `always` block was
read. Timing is STA's job, in `make gds`, and the reports that answer for it are
the per-corner ones above — if you are used to a flow where SDF-annotated
gate-level simulation is the last timing gate, that gate is not this step.

That cost is why CI runs `make gatesim` on pushes and on `v*` tags, but not on every pull request.

## Iterating without re-running the whole flow

Floorplan parameters — `FP_CORE_UTIL`, the die, the placement — do not need synthesis redone, so hand LibreLane the flags that resume the last run:

```bash
make gds LIBRELANE_ARGS="--last-run --from floorplan"
```

That reads the previous run out of `runs/`, which is why `make clean` leaves that directory alone and `make distclean` is the one that removes it.

**`CLOCK_PERIOD` is not one of them.** The clock is an input to synthesis, which
sizes cells and inserts buffers against it, so resuming from floorplan measures
the gates the *old* period produced under the new one. Timing may well close that
way and tell you nothing about the design you would actually get. Changing the
clock means a clean `make gds` — which is what [when slack is
negative](#when-slack-is-negative) says to run, and why.

## Seeing the circuit

```bash
make schematic
```

Draws `build/schematic.svg` — your design as flops, adders and muxes, carrying the names you gave them. Open it in the browser, or click it in VS Code; it is an SVG, so nothing special is needed to read it.

It is not a picture of the netlist. `make synth` runs a full synthesis and leaves a hundred generic gates, from which nobody has ever learned anything about their own design. `make schematic` stops earlier, where the circuit still looks like the code it came from.

**Generic gates, not Sky130 ones.** `make synth` maps to Yosys' own cells and no
further: `build/synthesis.json` for the example holds 94 of them — `$_DFF_PP0_`,
`$_OR_`, `$_XOR_` and friends — and not one `sky130_` cell, because nothing hands
Yosys a liberty file here. So this command answers "does it synthesise, and
roughly how much logic is it", and it cannot answer area or timing. The `198
standard cells` in `make report` comes from LibreLane's own synthesis inside
`make gds`, against the real library; it is not this number and the two do not
compare.

Under a second, so it costs nothing to run after every change — unlike `make gds`.

## Working inside the container

The repo ships a [Dev Container](https://containers.dev/). Open it in GitHub Codespaces, or in VS Code with *Reopen in Container*, and you get the same image CI uses, with the Verilog extensions already installed. The `Makefile` notices it is already inside the container and calls the tools directly instead of nesting another one.

`make gds` works in here too: the container ships a Docker daemon of its own for the LibreLane sidecar. If `make gds` says it cannot find one, rebuild the Dev Container — that is what it is asking for.

Two things to know:

*   **It runs as `root`.** On a Linux host that means files it writes into `build/` end up owned by `root`, so `make clean` from your host may need `sudo`. Running as a normal user instead breaks Codespaces.
*   **Watch the disk in a Codespace.** The inner daemon has its own image store, so the LibreLane image is pulled again rather than shared with the host, and the Sky130 PDK is another 3GB on top. On the smallest Codespace machine that is most of the disk — pick a larger one, or run `make gds` from your own host.

**One PDK can serve several checkouts.** The Sky130 install is 3GB and identical every time, so `PDK_ROOT` points both halves — the install and the LibreLane sidecar that reads it — at one directory:

```bash
make gds PDK_ROOT=/opt/sky130
```

Without it, every clone keeps its own copy under `pdks/`. A shared machine, or one where you keep more than one design, pays for those 3GB once instead of once per checkout. It needs c4o-core 2.8.2 or newer; the version the `Makefile` pins already is.

Prefer to stay in your own editor? `make shell` drops you into the same image from any terminal.

## Configuration reference

`config.yaml` is a [LibreLane](https://github.com/librelane/librelane) configuration file. Keys LibreLane does not own carry a `//` prefix, which it ignores outright — that is what keeps one file valid for both tools.

| Key | What it does |
|---|---|
| `DESIGN_NAME` | Your top module's name. Everything else reads it from here. |
| `VERILOG_FILES` | Synthesisable sources. One entry per file: LibreLane validates each as a literal path and does not expand `**`. |
| `"//TEST_FILES"` | Verilog testbenches for `make sim`. Globs work. |
| `"//SIM_TOP"` | Which testbench module to elaborate. Required once `"//TEST_FILES"` matches more than one file. |
| `"//COCOTB_TESTS"` | Python testbenches for `make cocotb`. Optional. |
| `"//GATE_TESTS"` / `"//GATE_TOP"` | Gate-level testbenches for `make gatesim`. Optional. |
| `"//DESCRIPTION"` | One line under the results page's title and in its link preview: what your design is. Optional. |
| `"//WAVE_SIGNALS"` | Signals `make site` draws from `make sim`'s VCD, named from the testbench top down (`tb_blinky.uut.count`). A name the VCD does not declare fails `make site`. Optional. |
| `CLOCK_PORT` / `CLOCK_PERIOD` | The clock to constrain, and its period in ns. |
| `PNR_SDC_FILE` / `SIGNOFF_SDC_FILE` | Your own timing constraints, when those two keys are not enough — see below. |
| `FP_SIZING` / `FP_CORE_UTIL` | How the die is sized — see below. |
| `PDK` / `STD_CELL_LIBRARY` | Sky130 and its standard cells. Leave alone. |

**The die sizes itself.** `FP_SIZING: relative` floorplans from `FP_CORE_UTIL` — how full the core should be, as a percentage, so the 40 here means 40% — so a bigger design gets a bigger die instead of "does not fit". Lower it if routing is tight, raise it for a smaller chip.

A fixed die is still available: set `FP_SIZING: absolute` and add `DIE_AREA: [0, 0, w, h]`. Do not leave `DIE_AREA` in the file under relative sizing — the flow no longer reads it, but the GDS stream-out still draws the chip boundary from it, and signoff then fails on a boundary nothing else used.

Everything else in the file belongs to LibreLane; see [its documentation](https://librelane.readthedocs.io/) for the full list, and the [c4o-core README](https://github.com/anlit75/c4o-core) for what this engine reads.

**Keys this reference does not list still work.** Nothing filters `config.yaml`:
c4o-core checks that the handful of keys it needs are present and sensible, and
`make gds` hands the whole file to LibreLane as it is. So `PL_TARGET_DENSITY`,
`CTS_*`, `GRT_*` and the rest of LibreLane's variables can go straight in, and
they take effect. This reference covers the ones this repository has a reason to
set — not the ones you are allowed to.

**Two keys are the whole timing constraint, and an SDC file can replace them.**
`CLOCK_PORT` and `CLOCK_PERIOD` are all this repository constrains. Everything
else a static timing tool needs — input and output delay, transition and fanout
limits, clock uncertainty, and every exception — comes from LibreLane's
defaults, which is fine for a design with one clock and no false paths and
nowhere near enough for anything else. Write the constraints yourself and name
the file:

```yaml
PNR_SDC_FILE: dir::constraints/pnr.sdc
SIGNOFF_SDC_FILE: dir::constraints/signoff.sdc
```

Both are LibreLane's own path variables, so they arrive by the pass-through
above and need nothing from c4o-core. Two of them rather than one is the point:
over-constrain place and route, then sign the design off against what it
actually has to meet. CI asserts that the pinned LibreLane still declares both
keys, so an upgrade cannot quietly make this paragraph wrong. It does not check
that your file was read: only a run with one in it tells you that.

**A second clock lives in that file, not in this one.** `CLOCK_PORT` and
`CLOCK_PERIOD` are single-valued and c4o-core requires both before it will start
the flow, so a design with two clocks names one of them here and creates both in
its SDC — this file's pair is what the convenience keys constrain, the SDC is
what the design is actually signed off against.

**Macros are LibreLane's, and this guide does not cover them.** A hard macro — an
SRAM, a PLL, somebody else's block — goes in through LibreLane's `MACROS`
variable, a dictionary of definitions each carrying its own GDS and LEF views,
and it brings power routing over the macro and placement blockages with it. The
pass-through means you can do it from `config.yaml` without anything here
changing. What this repository has to offer is a design small enough to read in
one sitting, which is the opposite end of that.
