# Guide

This guide contains what the [README](../README.md) does not. It tells you what this repository is and is not, and gives the prerequisites in detail. It also tells you how to make the template your design, how to read the numbers, and what to do after the first run.

*[繁體中文](guide.zh-TW.md)*

## What this is, and what it is not

The physical flow, RTL to GDSII, belongs to [LibreLane](https://github.com/librelane/librelane). `make gds` is a thin wrapper around it. If you only want a layout, LibreLane runs standalone with `--dockerized`, and you do not need this repository.

LibreLane does not do simulation and verification. This starter kit adds them, together with the CI and the Dev Container in which they run.

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

The shape of the flow is the same, and the vocabulary transfers. But the tools on your CV are not the tools that a job advert lists, so say which tools you used.

**Looking for a worked verification example?** The tests in this repository are two cocotb testbenches. They are enough to show what a test that can fail looks like. They are not a layered verification environment. [c4o-pyuvm](https://github.com/anlit75/c4o-pyuvm) is one: a pyuvm environment on a real UART, built from this template. It has an agent, a driver, a monitor, a scoreboard, and a register model generated from SystemRDL.

**What you make here is yours to publish.** The process is [Sky130](https://github.com/google/skywater-pdk), the PDK that SkyWater released under Apache 2.0, with no NDA. So you can put the layout, the area, the timing numbers and the GDS into a repository, a portfolio or a write-up. A foundry PDK under a confidentiality agreement permits none of that. So people who have such a PDK come here for a second set of results that they can show. It is also why people who never had one can produce results at all.

## Before you start

**On Apple Silicon, part of this runs emulated.** The c4o-core image is built for `amd64` only (one runner, no `platforms:`). So `lint`, `cocotb`, `gatesim` and `synth` run through emulation on an `arm64` machine. So does `sim`, once you add a Verilog testbench. `make gds` does not. Its heavy step runs LibreLane's own image, which is also published for `arm64`, so that step runs native.

This guide has no measurement of how much slower the emulated commands are. A Codespace is `amd64` throughout.

**One prerequisite is not a download: some Verilog.** You do not need much. It is enough to read an `always @(posedge clk)` block and a `<=` assignment. The tests are Python, so you also read an `assert`. On [HDLBits](https://hdlbits.01xz.net/), that is the *Verilog Language* section, not the full site.

**SystemVerilog is read too.** `logic`, `always_ff` and the synthesisable subset work in every command since c4o-core 2.8.3. Every version that this repository has pinned since then includes this support. Before 2.8.3, the same file passed `make cocotb` and `make gds` but failed `make sim` and `make synth`. An `interface` as a module boundary still does not work: yosys parses the declaration and then fails at `hierarchy`. Keep interfaces in the testbench, not between synthesisable modules.

You do not need Verilog to start. `make gds` runs the example unchanged and prints real area, timing and power. `make all` shows you tests that pass. Do these first, because they tell you that the toolchain works on your machine. You need Verilog for the next step: to change `rtl/blinky.v`, to judge whether a passed test proves something, or to write your own test. Run the example first, learn Verilog, then come back for that step.

## Making it your design

The example is a blinky, which is a clock divider. To replace it with your own design, three things must agree, and only these three:

| Change | Where |
|---|---|
| Your RTL | `rtl/`, listed under `VERILOG_FILES` in `config.yaml` |
| `DESIGN_NAME` | `config.yaml` — must match your top module's name |
| Your testbenches | `tb/`, under `"//COCOTB_TESTS"` |

No other file names the design. The `Makefile` and the CI workflow both read `DESIGN_NAME` from `config.yaml`.

Four more things cause problems in a first design:

*   **Delete the blinky files that you replace**: `rtl/blinky.v` and `tb/test_blinky_*.py`. As an alternative, remove them from `config.yaml`. The test key uses the glob `tb/*.py`, so a blinky test file that is still in `tb/` is still included. `VERILOG_FILES` names each file, so replace `rtl/blinky.v` there by name.
*   **Rewrite `tb/regression.yaml`** for your tests. An entry that names a test file that you deleted stops `make regress`, and so CI. To use no list, delete the file and the `"//REGRESSION"` key.
*   **Start every RTL file with `` `timescale 1ns/1ps ``.** Without it, `make cocotb` fails with `Unable to accurately represent 10(ns)`. `make sim` still passes, because a Verilog testbench declares its own.
*   **Rewrite `"//DESCRIPTION"`** in `config.yaml`. If you do not, your results page says that the design is a clock divider that blinks an LED.

**A repository needs tests of at least one kind.** `make all` runs `cocotb` when `"//COCOTB_TESTS"` is set and `sim` when `"//TEST_FILES"` is set. It prints a skip line for a kind whose key is not set. With neither key set, `make all` fails. CI follows the same rules. If you keep a key but it matches no files, CI fails. That is correct: you asked for tests that are not there.

If the first row is wrong, you get an error immediately, not three minutes into `make gds`:

```console
[ERROR] DESIGN_NAME is 'my_cpu', but no module by that name is declared in
        VERILOG_FILES. Declared there: blinky.
```

**Where things live.**

```text
.
├── .devcontainer/     # Dev Container definition
├── config.yaml        # Design name, clock, floorplan
├── Makefile           # Image names. Commands come from the image
├── docs/              # This guide
├── rtl/               # Your Verilog
│   └── blinky.v
├── tb/                # Your testbenches
│   ├── test_blinky_cocotb.py    # Directed tests (make cocotb, make gatesim)
│   ├── test_blinky_random.py    # Random stimulus vs a reference model
│   └── regression.yaml          # Test list for make regress
├── build/             # Generated: GDS, logs, netlists, results page
└── runs/              # Generated by make gds: LibreLane's run directories
```

## Commands

| Command | Description | Output |
|---|---|---|
| `make all` | Runs `lint`, `cocotb` and `synth`, and `sim` when `"//TEST_FILES"` is set: all the steps that run in seconds. | `Terminal` |
| `make lint` | Checks your Verilog with Verilator. | `Terminal` |
| `make sim` | Runs a Verilog testbench with Icarus Verilog. It needs `"//TEST_FILES"`: see [Adding a Verilog testbench](#adding-a-verilog-testbench). | `build/wave.vcd` |
| `make cocotb` | Runs the Python (cocotb) testbenches on the RTL. With `WAVES=1`, it also writes a VCD into `build/`. | `build/cocotb-results.xml` |
| `make regress` | Runs the tests of `tb/regression.yaml`, each over its seeds. See [Many seeds](#many-seeds). | `build/regress/` |
| `make coverage` | Runs the Python tests again on Verilator and counts the RTL that they run. It does not decide pass or fail. See [Code coverage](#code-coverage). | `build/coverage/` |
| `make synth` | Synthesises RTL into generic gates with Yosys. It gives no area and no timing: see [Seeing the circuit](#seeing-the-circuit). The script is fixed. Use `make shell` to run Yosys yourself. | `build/synthesis.json` |
| `make pdk` | Installs the Sky130 PDK. `make gds` runs it for you. Run it alone to do the 3GB download before you need it. | `pdks/` |
| `make schematic` | Draws the circuit as an SVG that you can open anywhere. | `build/schematic.svg` |
| `make gds` | Builds the physical layout with LibreLane. It takes about three minutes, plus the PDK download on a first run. | `build/<DESIGN_NAME>.gds` |
| `make gatesim` | Runs the cocotb testbenches again on the synthesised netlist. With `"//GATE_TESTS"` set, it runs that Verilog testbench instead. Run `make gds` first. | `build/cocotb-gl-results.xml` |
| `make report` | Prints area, timing, power and signoff from the last `make gds`. | `Terminal` |
| `make site` | Puts `report`, the layout and the cocotb results on one page. | `build/site/index.html` |
| `make shell` | Opens a bash shell inside the c4o-core container. | — |
| `make clean` | Removes `build/`. Keeps `runs/`, because `report` and `gatesim` read it. | — |
| `make distclean` | Removes `build/` and `runs/`. | — |

`make help` lists them in the terminal.

## Reading the result

`make gds` ends with a summary of what the flow measured, so you do not need to search for it:

```
  blinky

  die                56.375 x 67.095 um  (3782.48 um^2)
  utilization        56.6%
  instances          65 after synthesis, 113 after routing
  instance classes   32 logic, 27 well taps, 18 timing-repair buffers, 17 inverters, 16 sequential, 3 clock buffers
  drive strength     X1 0->18, X2 65->65, X16 0->3  (synthesis->routing)
  setup slack        +5.52 ns  (0 violations)
  hold slack         +0.11 ns  (0 violations)
  power              0.143 mW  (nom_tt_025C_1v80)
  signoff            clean  (DRC, LVS, antenna, XOR)
  lint warnings      0
  layout             runs/blinky_run/final/render/blinky.png
```

Those are the numbers of the example design, from one PDK version. Your numbers will be different, but the lines to read are the same.

**`signoff`** tells you something that no other line does: your layout passes the manufacturability checks. The `Makefile` pins a LibreLane version (`LIBRELANE_IMAGE`). By default, that version stops with an error on each of these checks (`ERROR_ON_MAGIC_DRC` and the related variables are all `True`). `config.yaml` overrides none of them. So a run that got to this line has already passed the checks.

That is the default of that version, not a guarantee from this repository, so check it again after an upgrade. `clean` states the result and names the checks that it saw. When a check fails, the line names the failures: `2 Magic DRC, 1 LVS`.

**`instances`** counts the cells of the design, once after synthesis and once after routing. The difference is what place and route added, such as well taps, clock buffers and timing-repair buffers. `instance classes` splits the count after routing. `drive strength` counts the same instances by the `_N` suffix of the Sky130 cell name, from synthesis to routing. `X1 0->18` means that synthesis made no X1 instances and the flow has 18 after routing. Physical-only cells, such as well taps, are not in that line.

**`layout`** is the PNG that the flow drew of your chip. Open it.

`XOR` in that line is not a process-rule check. Two tools write the same layout as GDS, and the check compares the two results, which must agree. It finds a stream-out bug in one of the two writers. It is not a cross-check of the design by tools from two vendors, because both tools read the same database. Do not read a clean XOR as a second opinion on the layout.

**Positive slack** means that the design meets the clock in `config.yaml`. Negative slack means that it does not. The flow does not stop for negative slack, so a run can finish and still report that the design missed the clock. See [When slack is negative](#when-slack-is-negative).

**Those lines are a summary, not a signoff report.** They come from a `metrics.json` with 300 keys, so what they omit is important. They do not show the clock uncertainty and the derating that were applied, or the skew of the clock tree. They do not show which of the nine corners (`ss`/`tt`/`ff` against `min`/`nom`/`max` interconnect) gave that slack. All of these are LibreLane defaults, because `config.yaml` sets none of them. All of them are under `runs/`, with one directory for each step.

The difference between a summary and a signoff report is practical. A flow in which you set the OCV derates yourself would not accept a `+0.11 ns` hold slack as a pass. For that level of confidence, read the per-corner reports, not these lines.

`make report` prints the summary again. It does not run the flow again.

## Publishing the results page

`make site` builds one page, `build/site/index.html`. The page starts with the layout image and the verdicts. It lists every cocotb test with its verdict and seed. After `make coverage`, the page shows a Coverage section. After `make gds`, the page also shows four sections in this order: timing, area and instances, power, and signoff checks.

Timing says whether the design meets the clock, and gives the worst setup and hold slack. It then lists the constraints that the run used. Each one says whether `config.yaml` set it or the flow used its default. Area and instances count the instances after synthesis and after routing, by class and by drive strength. They also name the standard cell library and say that it has a single threshold voltage.

Power gives the corner, the clock frequency and the activity. The activity is the default switching activity of OpenSTA, not the activity of your testbench. It shows where the power goes, not what a real workload draws. Signoff checks come last: one DRC row for Magic and KLayout, LVS, antenna, XOR and the static IR drop. The page says that electromigration, crosstalk and dynamic IR drop are not analysed. Each part appears after you run its command.

The page is designed for sharing, as a portfolio piece. The layout is first, then the numbers, then the tests. Your `"//DESCRIPTION"` is below the title. Buttons let you open the chip in 3D, download the GDS and view the source. The heading gives the build time and the commit that the page shows. The heading gives them because CI does not publish a failing `main`: the page continues to show the last run that passed.

CI builds that page on every run. From `main`, it publishes the page to GitHub Pages at `https://<your-user>.github.io/<your-repo>/`. A manual run of the workflow on `main` publishes the page again. Use it to refresh the page without a commit. A new copy of this template has Pages off, and no workflow can turn it on for you. Turn it on once: **Settings → Pages → Source: GitHub Actions**. Until you do, CI still passes and gives a notice that it published nothing.

## Code coverage

`make coverage` shows how much of your RTL the Python tests run. It runs the `"//COCOTB_TESTS"` again on Verilator, which has the coverage counters. Icarus has none. `make all` does not run it, but CI does.

It counts three kinds of points. A block is a piece of code that ran. A branch is one side of an `if` or a `case`. A toggle is a signal bit that changed value. The results page shows each kind with the points hit and the total. A card in the summary at the top of the page shows them too.

Pass and fail stay with `make cocotb`, which runs on Icarus. Verilator is 2-state, so a signal that is `x` before reset reads 0 there. A test can pass on one simulator and fail on the other. A failing Verilator run does not fail `make coverage`. A design that Verilator cannot build does.

`make coverage SEED=<n>` sets the seed. The page says which seed the run used. With `"//REGRESSION"` set, it measures the runs of that list and merges them, so the numbers cover every seed. [All the details →](https://github.com/anlit75/c4o-core/blob/main/docs/commands.md#code-coverage-coverage)

## When slack is negative

Negative slack means that the design does not meet the clock in `config.yaml`. You have two answers. Give the design more time: increase `CLOCK_PERIOD` and run `make gds` again. Or make the slow path shorter: pipeline it or remove logic from it. The correct answer depends on whether the clock speed is a requirement or a guess. In a first design it is usually a guess.

Both answers change the design or its constraints. The physical answers are placement density, clock tree targets, resizer margins and routing effort. They belong to LibreLane and they are real, but this guide does not cover them. `config.yaml` sets none of those keys, and the [configuration reference](#configuration-reference) stops where LibreLane's own variables start. If you came here to practise manual timing closure, read LibreLane's documentation for that part.

A third answer is the constraint itself. Maybe the flow should not time the path that fails. Or the input delay that the flow assumed is not the delay that your board gives. In those cases, no design change corrects the problem. An SDC file does, and the [configuration reference](#configuration-reference) tells you how to supply one.

To see *what* is slow, read the timing report that the flow already wrote:

```bash
cat runs/*/*-openroad-stapostpnr/*ss_*/checks.rpt
```

There is one file for each timing corner. Hold is the opposite problem: setup fails in the slow corner, and hold fails in the fast corner.

```bash
cat runs/*/*-openroad-stapostpnr/*ff_*/checks.rpt    # hold
ls -d runs/*/*-openroad-stapostpnr/*/                # everything that ran
```

Each of those globs matches more than one file. One run of this design made nine corner directories: three PVT points (`ss`, `tt`, `ff`) for each of three interconnect corners (`min`, `nom`, `max`). So `cat` joins three reports and does not tell you which is the worst. Find the worst one yourself, as you would from a summary.

In each report, the worst path shows every gate along it and the delay of each gate. That shows you where the time went.

## Writing a testbench for your own design

`tb/test_blinky_cocotb.py` is a worked example. Below is its basic shape: the smallest testbench that can fail.

```python
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer

@cocotb.test()
async def result_is_high_after_reset(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())   # a 100 MHz clock
    dut.rst.value = 1
    await ClockCycles(dut.clk, 2)
    dut.rst.value = 0

    await ClockCycles(dut.clk, 1)
    await Timer(3, units="ns")     # let the outputs settle
    assert dut.result.value == 1, f"result should be high after reset, got {dut.result.value}"
```

List the file under `"//COCOTB_TESTS"`. Give your RTL a `` `timescale `` (see [Making it your design](#making-it-your-design)), because the `10, units="ns"` clock needs one.

Three things do the work:

*   **`assert` makes a broken design a failed CI run.** The simulator exits 0 even when a test failed. `make cocotb` reads the results file that cocotb writes, and exits non-zero when a test failed there. A test that prints a failure but does not assert is decoration.
*   **A `Timer` after the edge.** `ClockCycles` resumes *at* the edge, before the outputs of the design change. A read at that point sees the value of the previous cycle. On the gates the outputs change a few ns later still. Relative checks still pass with that old value, so this error is easy to miss. Keep the wait below half a clock period.
*   **`make cocotb WAVES=1` makes the waveform.** Without `WAVES=1`, `make cocotb` dumps nothing. Run it again with `WAVES=1` when the assertion above fails.

Try it. Change `rtl/blinky.v` so that the design is wrong, run `make cocotb`, and see it fail. If you have never seen a testbench fail, you do not know that it works.

That is the full method, and it works on any design. Break one thing and run the tests. Make sure that the test you aimed at fails and gives a message that you can act on. Then run `git checkout -- rtl/blinky.v` and break the next thing.

You do not learn that "the tests pass". You learn which test catches which mistake. You also learn where no test catches anything: that is the test you have not written. This method is the only answer to "does my test really check the design", because a test that cannot fail tells you nothing.

## When a test fails: look at the waveform

`make cocotb WAVES=1` writes `build/<DESIGN_NAME>.vcd`, which contains every signal of your design on every cycle. Without `WAVES=1`, `make cocotb` writes no VCD. The names in the file start at the design top, for example `blinky.count`. Open the file with GTKWave, or with the **WaveTrace** extension that the Dev Container installs (click the `.vcd` file). A failed assertion tells you *that* the design is wrong. The waveform shows you *why*.

`*.vcd` is in `.gitignore`. CI does not write a VCD. To examine a test that fails only on CI, run `make cocotb WAVES=1 SEED=<seed>` with the seed from the CI log.

## Writing testbenches in Python

`make cocotb` runs [cocotb](https://www.cocotb.org/) tests: Python coroutines that drive the design through the simulator. `make gatesim` runs the same files on the gates.

```bash
make cocotb
```

The two files in `tb/` touch only `dut.clk`, `dut.rst` and `dut.led`. They do not read `dut.count` and they do not force it. Keep your tests to the ports of your design, so that they run on the gates too. [Why →](#simulating-the-gates-not-just-the-rtl)

Without the counter, a test can only wait for `led` to change. After a reset, `led` rises once 2^(`WIDTH`-1) clock cycles have passed. Each cycle costs simulator time, which is why `rtl/blinky.v` has a small `WIDTH`. A board clock needs a wider counter, and the comment in that file says how wide. A test would take far too long to wait for that.

`tb/test_blinky_cocotb.py` has four directed tests. One checks that reset holds `led` low. One checks that `led` rises exactly 2^(`WIDTH`-1) cycles after reset is released, and not a cycle either side. One checks a full period. One checks a reset in the middle of a period. `led` must fall without a clock edge, and the count must start again.

Both test files repeat `WIDTH`, because a netlist has no parameter to read. Keep that constant equal to `WIDTH` in `rtl/blinky.v`.

## Random stimulus and a reference model

`tb/test_blinky_random.py` is the other half of verification. A directed test asserts at moments that a person chose. This test builds a model of what the design should do. It compares the design with the model on every cycle, with stimulus that nobody wrote out.

It has three parts of about ten lines each:

*   **The model** is `BlinkyModel`: the behaviour of blinky, written a second time in Python. It is deliberately not a transcription of the RTL. A model that copies the mistakes of the design agrees with it everywhere and can never catch a mistake.
*   **The stimulus** is a first stretch that reaches the rise of `led`, a second rise after a reset, then random reset pulses. The first stretch makes sure that a run cannot watch a signal that never moves.
*   **The scoreboard** compares `led` with the model after every clock. A failure gives the cycle, both values and the count of the model.

```bash
make cocotb                   # a new seed each run
make cocotb SEED=1789965785   # replay one exactly
```

cocotb seeds Python's `random` and logs the seed that it used. You can then reproduce a CI failure on your machine from the log line. `make gatesim SEED=1789965785` replays a gate run the same way.

The test also fails when `led` never moved. Passed cycles that watched a constant signal prove nothing. A suite that reports PASS for that is what this repository works hardest to prevent.

It does not check that reset acts without a clock edge. The stimulus moves `rst` at a falling edge and reads `led` at the next one. So an asynchronous reset and a synchronous reset look the same here. The directed test `reset_in_the_middle_restarts_the_count` checks that. Reset *timing* belongs to static timing: recovery and removal. The nine-line summary does not show it, because its two slack rows are setup and hold, which are different checks. The per-corner reports show it in a separate path group:

```bash
grep -A12 'Path Group: asynchronous' runs/*/*-openroad-stapostpnr/*/checks.rpt
```

This was measured, not assumed. A CI run of this design gave `recovery check against rising-edge clock clk` in all nine corner reports. CI prints what it finds there on every run. A design with a synchronous reset has nothing in that path group. For that design, this is the correct answer, not a missing one.

## Many seeds

One seed is one random run. `make regress` runs a list of tests, each over several seeds. The list is `tb/regression.yaml`, and `"//REGRESSION"` in `config.yaml` names it. Each entry has a `test`, which is a module of `"//COCOTB_TESTS"` or one test as `<module>.<function>`, and an optional `seeds`. The RTL is compiled once.

```bash
make regress                  # the whole list, from a new base seed
make regress SEED=1789965785  # the whole list again, with the same seeds
```

The command prints the base seed and a table of runs passed for each entry. A failed run does not stop the others, and the exit code is 1. For each failed run, the command prints how to replay it:

```text
make cocotb SEED=910098751 TEST=test_blinky_random
```

CI runs the list on every pull request. Add an entry to put a new test on it. [All the details →](https://github.com/anlit75/c4o-core/blob/main/docs/commands.md#many-seeds-regress)

## Adding a Verilog testbench

The template ships no Verilog testbench, but the path stays open. Put the file in `tb/` and list it:

```yaml
"//TEST_FILES":
  - dir::tb/tb_my_design.v
```

`make sim` runs it, and `make all` and CI run it too. A failed check must call `$fatal`. `$display` prints and the simulator exits 0, but `$fatal` exits non-zero, and `make sim` reads that exit code. You supply `$dumpfile` and `$dumpvars` yourself.

`"//TEST_FILES"` accepts a glob. Icarus elaborates every module that no other module instantiates, and each one becomes a separate root. With more than one testbench, the first `$finish` stops the full simulation, and the other testbenches never run. When more than one file matches, name the testbench that you want with `"//SIM_TOP"`. Without it, `make sim` stops with an error that asks for it. One `make sim` runs one top module.

To run a Verilog testbench on the gates, list it under `"//GATE_TESTS"`. Then `make gatesim` runs it and not the cocotb tests. `"//GATE_TOP"` names its top module, as `"//SIM_TOP"` does. Synthesis resolves parameters, so a gate-level testbench cannot shrink the design the way an RTL one can.

## Simulating the gates, not just the RTL

`make cocotb` tells you that your Verilog behaves correctly. It tells you nothing about the netlist that the tools made from it. Latch inference, reset handling and the way a synthesiser reads an ambiguous `always` block are all between the two. You cannot see them from the RTL.

`make gatesim` closes that gap. It runs the same cocotb tests on `runs/<tag>/final/nl/`, the gate-level netlist that `make gds` wrote, with the Verilog models of the Sky130 cells. `<tag>` is the run directory: `<DESIGN_NAME>_run`, unless you name it yourself. The verdicts go to `build/cocotb-gl-results.xml`.

```bash
make gds       # produces the netlist
make gatesim   # runs the tests on it
```

The same files work because they touch only the ports. Synthesis resolves parameters, and it removes internal names. A netlist has no `WIDTH` to read and no `count` to write to. Anything that reaches inside the design works on the RTL and stops working at this step. This step exists partly to show you that.

That is also why `WIDTH` is 16 in `rtl/blinky.v`. A test that sees only the ports must wait for `led` to rise, and the gates run slower than the RTL. With a small `WIDTH`, the wait is short enough that CI runs these tests on every pull request.

**This is a functional check, not a timing check.** Nothing here back-annotates an SDF. The cells switch with zero delay, so the run cannot see a race that occurs only at real delays. It does see everything that synthesis decided: inferred latches, the implementation of reset, and the reading of an ambiguous `always` block.

Timing is the job of STA, in `make gds`, and the per-corner reports above give the answer. In some flows, gate-level simulation with SDF annotation is the last timing gate. This step is not that gate.

CI runs the cocotb tests on the gates on every event, pull requests included. It then compares the pass, fail and skip counts of that run with those of the RTL run, and fails when they differ. A Verilog gate testbench keeps the older rule: CI runs it on pushes and on `v*` tags, but not on every pull request.

## Iterating without re-running the whole flow

Floorplan parameters (`FP_CORE_UTIL`, the die, the placement) do not need a new synthesis. Resume the last run from floorplan with LibreLane's own flags:

```bash
make gds LIBRELANE_ARGS="--from OpenROAD.Floorplan --with-initial-state runs/blinky_run/13-openroad-floorplan/state_in.json"
```

`--from` takes the id of a LibreLane step. `--with-initial-state` takes the state that the step received in the last run: the `state_in.json` in the directory of that step. Without that file, LibreLane starts from the finished design, and the flow fails. The directory names in `runs/<tag>/` are the step ids in lower case, so you can resume from any step.

That command reads the previous run from `runs/`. For this reason `make clean` keeps `runs/`, and only `make distclean` removes it.

LibreLane adds the resumed steps after the old steps and continues the numbers. After a resume, the run directory has two directories for each resumed step, and the globs in this guide match both. The directory with the larger number is the new one.

`make gds` without `--from` is a full run. It deletes the previous run first.

You must know which steps your change affects. A step that is before your `--from` step does not run again, so it does not see the change.

**`CLOCK_PERIOD` is not one of them.** The clock is an input to synthesis, which sizes cells and inserts buffers for it. So if you resume from floorplan, the flow measures the gates that the *old* period produced against the new period. Timing can easily close that way and tell you nothing about the design that you would really get. A clock change needs a full `make gds`, without `--from`. [When slack is negative](#when-slack-is-negative) tells you to run that, and this is the reason.

## Seeing the circuit

```bash
make schematic
```

This command draws `build/schematic.svg`: your design as flops, adders and muxes, with the names that you gave them. Open it in the browser or click it in VS Code. It is an SVG, so you need no special tool to read it.

It is not a picture of the netlist. `make synth` runs a full synthesis and gives a long list of generic gates, and nobody learns anything about their design from those gates. `make schematic` stops earlier, where the circuit still looks like its source code.

**Generic gates, not Sky130 gates.** `make synth` maps to Yosys' own cells and stops there. For the example, `build/synthesis.json` contains only such cells (`$_DFF_PP0_`, `$_OR_`, `$_XOR_` and others) and no `sky130_` cell, because nothing gives Yosys a liberty file here. This command answers "does it synthesise, and approximately how much logic is it". It cannot answer area or timing.

The instance count after synthesis in `make report` comes from LibreLane's own synthesis inside `make gds`, with the real library. It is a different number, and you cannot compare the two.

This takes less than a second, so you can run it after every change, unlike `make gds`.

## Working inside the container

The repository includes a [Dev Container](https://containers.dev/). Open it in GitHub Codespaces, or in VS Code with *Reopen in Container*. You get the same image that CI uses, with the Verilog extensions installed. The `Makefile` detects that it is inside the container. It then calls the tools directly and does not start a nested container.

`make gds` also works here, because the container has its own Docker daemon for the LibreLane sidecar. If `make gds` says that it cannot find a daemon, rebuild the Dev Container. That is what the message asks for.

Two things to know:

*   **It runs as `root`.** On a Linux host, the files that it writes into `build/` are then owned by `root`, so `make clean` from your host can need `sudo`. Running as a normal user breaks Codespaces.
*   **Monitor the disk in a Codespace.** The inner daemon has its own image store. It pulls the LibreLane image again and does not share it with the host. The Sky130 PDK adds 3GB more. On the smallest Codespace machine, that is most of the disk. Select a larger machine, or run `make gds` from your own host.

**One PDK can serve several checkouts.** The Sky130 install is 3GB and is always the same. `PDK_ROOT` points the install, and the LibreLane sidecar that reads it, at one directory.

```bash
make gds PDK_ROOT=/opt/sky130
```

Without it, every clone keeps its own copy under `pdks/`. With it, a shared machine, or a machine with more than one design, stores those 3GB only once. This needs c4o-core 2.8.2 or newer, and the version that the `Makefile` pins is new enough.

Prefer to stay in your own editor? `make shell` opens the same image from any terminal.

## Getting fixes after you copy the template

A repository that you make from this template has no git history in common with it. GitHub does not change your repository when the template changes. Three parts get fixes without a change from you:

| Part | How a fix reaches you |
|---|---|
| The tools | The `Makefile` and `.devcontainer/devcontainer.json` name the image `ghcr.io/anlit75/c4o-core:2.22`. A fix to 2.22 arrives the next time the image is pulled. When 2.23 is released, change the two lines to get its fixes. CI fails if the two lines are different. |
| The make commands | The `Makefile` includes its rules from the image. A fix to a command such as `make gds` arrives with the image. See [what your own targets can use](https://github.com/anlit75/c4o-core/blob/main/docs/makefile.md). |
| The CI steps | `.github/workflows/verify.yml` calls actions from c4o-core at `@v2`. A fix to an action arrives on the next run. See [what each action does](https://github.com/anlit75/c4o-core/blob/main/docs/actions.md). |

The other parts do not change after you copy them. They are the image names and the stub text in the `Makefile`, the triggers and jobs of the workflow, `devcontainer.json`, and the docs.

Put targets of your own at the end of the `Makefile`, below the `include` line.

Put steps of your own between the actions in `verify.yml`. They run in the same job, so they can read `runs/` and `build/`.

Some steps in `verify.yml` have the comment `Template only`. They check sentences in this template's README and guide. They run in the template repository and are skipped in yours. You can delete them.

## Configuration reference

`config.yaml` is a [LibreLane](https://github.com/librelane/librelane) configuration file. Keys that LibreLane does not own have a `//` prefix. LibreLane ignores those keys completely, so one file stays valid for both tools.

| Key | What it does |
|---|---|
| `DESIGN_NAME` | Your top module's name. Everything else reads it from here. |
| `VERILOG_FILES` | Synthesisable sources. One entry for each file: LibreLane validates each entry as a literal path and does not expand `**`. |
| `"//COCOTB_TESTS"` | Python testbenches for `make cocotb` and `make gatesim`. Globs work. |
| `"//REGRESSION"` | The test list for `make regress`: a YAML file of `test` and `seeds`. Optional. |
| `"//TEST_FILES"` | Verilog testbenches for `make sim`. Optional. Globs work. |
| `"//SIM_TOP"` | Which Verilog testbench module to elaborate. Required when `"//TEST_FILES"` matches more than one file. |
| `"//GATE_TESTS"` / `"//GATE_TOP"` | Verilog gate-level testbenches for `make gatesim`. Optional. When set, `make gatesim` runs them and not the cocotb tests. |
| `"//DESCRIPTION"` | One line that tells what your design is. It appears below the title of the results page and in its link preview. Optional. |
| `CLOCK_PORT` / `CLOCK_PERIOD` | The clock to constrain, and its period in ns. |
| `PNR_SDC_FILE` / `SIGNOFF_SDC_FILE` | Your own timing constraints, when those two keys are not sufficient. See below. |
| `FP_SIZING` / `FP_CORE_UTIL` | How the die is sized. See below. |
| `PDK` / `STD_CELL_LIBRARY` | Sky130 and its standard cells. Do not change them. |

**The die sizes itself.** `FP_SIZING: relative` makes the floorplan from `FP_CORE_UTIL`. That key is how full the core should be, as a percentage: the 40 here means 40%. A larger design then gets a larger die and not a "does not fit" error. Decrease `FP_CORE_UTIL` if routing is tight. Increase it for a smaller chip.

A fixed die is still available. Set `FP_SIZING: absolute` and add `DIE_AREA: [0, 0, w, h]`. Do not keep `DIE_AREA` in the file with relative sizing. The flow no longer reads it, but the GDS stream-out still draws the chip boundary from it. Signoff then fails on a boundary that nothing else used.

All other keys in the file belong to LibreLane. See [its documentation](https://librelane.readthedocs.io/) for the full list. See the [c4o-core README](https://github.com/anlit75/c4o-core) for what this engine reads.

**Keys that this reference does not list still work.** Nothing filters `config.yaml`. c4o-core checks that the few keys it needs are present and sensible. `make gds` then gives the full file to LibreLane unchanged. You can add `PL_TARGET_DENSITY`, `CTS_*`, `GRT_*` and the other LibreLane variables directly, and they take effect. This reference covers the keys that this repository has a reason to set, not all the keys that you are permitted to set.

**Two keys are the full timing constraint, and an SDC file can replace them.** This repository constrains only `CLOCK_PORT` and `CLOCK_PERIOD`. A static timing tool needs more: input and output delay, transition and fanout limits, clock uncertainty, and every exception. All of that comes from LibreLane's defaults. The defaults are sufficient for a design with one clock and no false paths, and far from sufficient for any other design. Write the constraints yourself and name the file:

```yaml
PNR_SDC_FILE: dir::constraints/pnr.sdc
SIGNOFF_SDC_FILE: dir::constraints/signoff.sdc
```

Both are LibreLane's own path variables, so they arrive through the pass-through above and need nothing from c4o-core. There are two keys for a reason. You can over-constrain place and route, then sign off the design against what it must really meet. CI asserts that the pinned LibreLane still declares both keys, so an upgrade cannot silently make this paragraph wrong. CI does not check that the flow read your file. Only a run that uses the file tells you that.

**A second clock goes in that file, not in this one.** `CLOCK_PORT` and `CLOCK_PERIOD` each have one value, and c4o-core requires both before it starts the flow. A design with two clocks names one of them here and creates both in its SDC. The convenience keys constrain only the pair in this file. The design is signed off against the SDC.

**Macros belong to LibreLane, and this guide does not cover them.** A hard macro (an SRAM, a PLL, a block from another person) goes in through LibreLane's `MACROS` variable. That variable is a dictionary of definitions, each with its own GDS and LEF views. A macro also brings power routing over the macro and placement blockages. Because of the pass-through, you can do this from `config.yaml` with no change here. This repository offers a design small enough to read in one sitting, which is the opposite of that.
