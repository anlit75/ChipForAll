# Guide

Everything after the first run. Start with the [README](../README.md) if you have not run `make gds` yet.

*[繁體中文](guide.zh-TW.md)*

## When slack is negative

Negative slack means the design does not meet the clock in `config.yaml`. Two answers are yours to reach for from here: give the design more time — raise `CLOCK_PERIOD` and run `make gds` again — or make the slow path shorter, by pipelining it or cutting logic out of it. Which one is right depends on whether the clock speed is a requirement or a guess; in a first design it is usually a guess.

Both of those change the design or its constraints. The physical answers — placement density, clock tree targets, resizer margins, routing effort — are LibreLane's, they are real, and this guide does not cover them: `config.yaml` sets none of those keys and the [configuration reference](#configuration-reference) stops where LibreLane's own variables begin. If you came here to practise timing closure by hand, that is the part you will be reading LibreLane's documentation for.

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

The example in `test/test_blinky_cocotb.py` leans on the one thing Python is plainly better at here: writing to a signal *inside* the design.

```python
dut.count.value = (1 << (WIDTH - 1)) - 1   # one tick below the rollover
await tick(dut)
assert dut.led.value == 1
```

Checking that `led` is the counter's top bit costs four cycles that way. A Verilog testbench gets there only by overriding `WIDTH` — which the gate-level testbench cannot do — or by running 2^25 cycles.

The same edge gotcha as in Verilog applies: `RisingEdge` resumes *at* the edge, before the non-blocking assignment lands, so every read in that file waits a further `Timer` first.

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

It does not check reset *timing*: the stimulus moves `rst` just after a clock edge, so an asynchronous reset and a synchronous one look the same here. That question belongs to static timing, which `make gds` already reports.

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

That cost is why CI runs `make gatesim` on pushes to `main` and on `v*` tags, but not on every pull request.

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

It is not a picture of the netlist. `make synth` runs a full synthesis and leaves hundreds of technology cells, from which nobody has ever learned anything about their own design. `make schematic` stops earlier, where the circuit still looks like the code it came from.

Under a second, so it costs nothing to run after every change — unlike `make gds`.

## Working inside the container

The repo ships a [Dev Container](https://containers.dev/). Open it in GitHub Codespaces, or in VS Code with *Reopen in Container*, and you get the same image CI uses, with the Verilog extensions already installed. The `Makefile` notices it is already inside the container and calls the tools directly instead of nesting another one.

`make gds` works in here too: the container ships a Docker daemon of its own for the LibreLane sidecar. If `make gds` says it cannot find one, rebuild the Dev Container — that is what it is asking for.

Two things to know:

*   **It runs as `root`.** On a Linux host that means files it writes into `build/` end up owned by `root`, so `make clean` from your host may need `sudo`. Running as a normal user instead breaks Codespaces.
*   **Watch the disk in a Codespace.** The inner daemon has its own image store, so the LibreLane image is pulled again rather than shared with the host, and the Sky130 PDK is another 3GB on top. On the smallest Codespace machine that is most of the disk — pick a larger one, or run `make gds` from your own host.

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
| `CLOCK_PORT` / `CLOCK_PERIOD` | The clock to constrain, and its period in ns. |
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
