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

**Looking for a worked verification example?** The tests in this repository are one Verilog testbench and two cocotb testbenches. They are enough to show what a test that can fail looks like. They are not a layered verification environment. [c4o-pyuvm](https://github.com/anlit75/c4o-pyuvm) is one: a pyuvm environment on a real UART, built from this template. It has an agent, a driver, a monitor, a scoreboard, and a register model generated from SystemRDL.

**What you make here is yours to publish.** The process is [Sky130](https://github.com/google/skywater-pdk), the PDK that SkyWater released under Apache 2.0, with no NDA. So you can put the layout, the area, the timing numbers and the GDS into a repository, a portfolio or a write-up. A foundry PDK under a confidentiality agreement permits none of that. So people who have such a PDK come here for a second set of results that they can show. It is also why people who never had one can produce results at all.

## Before you start

**On Apple Silicon, part of this runs emulated.** The c4o-core image is built for `amd64` only (one runner, no `platforms:`). So `lint`, `sim`, `cocotb`, `synth` and `gatesim` run through emulation on an `arm64` machine. `make gds` does not. Its heavy step runs LibreLane's own image, which is also published for `arm64`, so that step runs native.

This guide has no measurement of how much slower the emulated commands are. A Codespace is `amd64` throughout.

**One prerequisite is not a download: some Verilog.** You do not need much. It is enough to read an `always @(posedge clk)` block, a `<=` assignment and a `$fatal`. On [HDLBits](https://hdlbits.01xz.net/), that is the *Verilog Language* section, not the full site.

**SystemVerilog is read too.** `logic`, `always_ff` and the synthesisable subset work in every command since c4o-core 2.8.3. Every version that this repository has pinned since then includes this support. Before 2.8.3, the same file passed `make cocotb` and `make gds` but failed `make sim` and `make synth`. An `interface` as a module boundary still does not work: yosys parses the declaration and then fails at `hierarchy`. Keep interfaces in the testbench, not between synthesisable modules.

You do not need Verilog to start. `make gds` runs the example unchanged and prints real area, timing and power. `make all` shows you tests that pass. Do these first, because they tell you that the toolchain works on your machine. You need Verilog for the next step: to change `src/blinky.v`, to judge whether a passed test proves something, or to write your own test. Run the example first, learn Verilog, then come back for that step.

## Making it your design

The example is a blinky, which is a clock divider. To replace it with your own design, five things must agree, and only these five:

| Change | Where |
|---|---|
| Your RTL | `src/`, listed under `VERILOG_FILES` in `config.yaml` |
| `DESIGN_NAME` | `config.yaml` — must match your top module's name |
| Your testbenches | `test/`, under `"//TEST_FILES"` and `"//COCOTB_TESTS"` |
| The gate-level one | `test/gate/`, under `"//GATE_TESTS"` |
| The waveform's signals | `"//WAVE_SIGNALS"`, named from your testbench's top down |

No other file names the design. The `Makefile` and the CI workflow both read `DESIGN_NAME` from `config.yaml`.

Three more things cause problems in a first design:

*   **Delete the blinky files that you replace**: `src/blinky.v`, `test/tb_blinky.v`, `test/test_blinky_*.py`, `test/gate/tb_blinky_gl.v`. As an alternative, remove them from `config.yaml`. The test keys use globs such as `test/*.v`, so a blinky test file that is still in `test/` is still picked up. `VERILOG_FILES` names each file, so replace `src/blinky.v` there by name.
*   **Start every RTL file with `` `timescale 1ns/1ps ``.** Without it, `make sim` still passes, because the Verilog testbench declares its own. But `make cocotb` fails with `Unable to accurately represent 10(ns)`.
*   **Rewrite `"//DESCRIPTION"`** in `config.yaml`. If you do not, your results page says that the design is a clock divider that blinks an LED. Also change `"//WAVE_SIGNALS"` to the signals of your testbench. If you do not, `make site` stops at the first signal that the VCD does not declare.

**Three of those keys are optional.** You can delete `"//COCOTB_TESTS"`, `"//GATE_TESTS"` or `"//WAVE_SIGNALS"` from `config.yaml`. Delete the key line *and* the indented paths below it. If you delete only the key line, the paths below it join the key above, or the file does not parse. CI then skips that type of test and does not fail. If you keep the key but it matches no files, CI fails. That is correct: you asked for tests that are not there.

**A second Verilog testbench needs one more key.** `"//TEST_FILES"` accepts a glob. Icarus elaborates every module that no other module instantiates, and each one becomes a separate root. With more than one testbench, the first `$finish` then stops the full simulation, and the other testbenches never run. When more than one file matches, name the testbench that you want with `"//SIM_TOP"`.

If more than one file matches and `"//SIM_TOP"` is not set, `make sim` stops with an error that asks for it. One `make sim` runs one top module. To run another testbench, change `"//SIM_TOP"`. Then run `make sim` again.

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
| `make all` | Runs `lint`, `sim`, `cocotb` and `synth`: all the steps that run in seconds. | `Terminal` |
| `make lint` | Checks your Verilog with Verilator. | `Terminal` |
| `make sim` | Runs the Verilog testbenches with Icarus Verilog. | `build/wave.vcd` |
| `make cocotb` | Runs the Python (cocotb) testbenches. | `build/cocotb-results.xml` |
| `make synth` | Synthesises RTL into generic gates with Yosys. It gives no area and no timing: see [Seeing the circuit](#seeing-the-circuit). The script is fixed. Use `make shell` to run Yosys yourself. | `build/synthesis.json` |
| `make pdk` | Installs the Sky130 PDK. `make gds` runs it for you. Run it alone to do the 3GB download before you need it. | `pdks/` |
| `make schematic` | Draws the circuit as an SVG that you can open anywhere. | `build/schematic.svg` |
| `make gds` | Builds the physical layout with LibreLane. It takes about three minutes, plus the PDK download on a first run. | `build/<DESIGN_NAME>.gds` |
| `make gatesim` | Runs simulation again on the synthesised netlist. Run `make gds` first. | `Terminal` |
| `make report` | Prints area, timing, power and signoff from the last `make gds`. | `Terminal` |
| `make site` | Puts `report`, the layout, the schematic and the cocotb results on one page. | `build/site/index.html` |
| `make shell` | Opens a bash shell inside the c4o-core container. | — |
| `make clean` | Removes `build/`. Keeps `runs/`, because `report` and `gatesim` read it. | — |
| `make distclean` | Removes `build/` and `runs/`. | — |

`make help` lists them in the terminal.

## Reading the result

`make gds` ends with a summary of what the flow measured, so you do not need to search for it:

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

Those are the numbers of the example design, from one PDK version. Your numbers will be different, but the lines to read are the same.

**`signoff`** tells you something that no other line does: your layout passes the manufacturability checks. The `Makefile` pins a LibreLane version (`LIBRELANE_IMAGE`). By default, that version stops with an error on each of these checks (`ERROR_ON_MAGIC_DRC` and the related variables are all `True`). `config.yaml` overrides none of them. So a run that got to this line has already passed the checks.

That is the default of that version, not a guarantee from this repository, so check it again after an upgrade. `clean` states the result and names the checks that it saw. When a check fails, the line names the failures: `2 Magic DRC, 1 LVS`.

**`layout`** is the PNG that the flow drew of your chip. Open it.

`XOR` in that line is not a process-rule check. Two tools write the same layout as GDS, and the check compares the two results, which must agree. It finds a stream-out bug in one of the two writers. It is not a cross-check of the design by tools from two vendors, because both tools read the same database. Do not read a clean XOR as a second opinion on the layout.

**Positive slack** means that the design meets the clock in `config.yaml`. Negative slack means that it does not. The flow does not stop for negative slack, so a run can finish and still report that the design missed the clock. See [When slack is negative](#when-slack-is-negative).

**Those nine lines are a summary, not a signoff report.** They come from a `metrics.json` with 300 keys, so what they omit is important. They do not show the clock uncertainty and the derating that were applied, or the skew of the clock tree. They do not show which of the nine corners (`ss`/`tt`/`ff` against `min`/`nom`/`max` interconnect) gave that slack. All of these are LibreLane defaults, because `config.yaml` sets none of them. All of them are under `runs/`, with one directory for each step.

The difference between a summary and a signoff report is practical. A flow in which you set the OCV derates yourself would not accept a `+0.11 ns` hold slack as a pass. For that level of confidence, read the per-corner reports, not these nine lines.

`make report` prints the summary again. It does not run the flow again.

## Publishing the results page

`make site` builds one page, `build/site/index.html`. The page contains those lines, the layout image, the schematic, and every cocotb test with its verdict and seed. After `make gds`, the page also shows each signoff check and the worst setup path as OpenSTA reports it. It also shows an area split (flip-flops, logic, what routing added) and a power split (sequential, combinational, clock). After `make sim`, it draws the signals that `"//WAVE_SIGNALS"` names as a waveform.

The power split uses the default switching activity of OpenSTA, not the activity of your testbench. It shows where the power goes, not what a real workload draws. Each part appears after you run its command.

The page is designed for sharing, as a portfolio piece. The layout is first, then the numbers, then the tests. Your `"//DESCRIPTION"` is below the title. Buttons let you open the chip in 3D, download the GDS and view the source. The heading gives the build time and the commit that the page shows. The heading gives them because CI does not publish a failing `main`: the page continues to show the last run that passed.

CI builds that page on every run. From `main`, it publishes the page to GitHub Pages at `https://<your-user>.github.io/<your-repo>/`. A new copy of this template has Pages off, and no workflow can turn it on for you. Turn it on once: **Settings → Pages → Source: GitHub Actions**. Until you do, CI still passes and gives a notice that it published nothing.

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

`test/tb_blinky.v` is a worked example. Below is its basic shape: the smallest testbench that can fail.

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

Three things do the work:

*   **`$fatal` makes a broken design a failed CI run.** `$display` prints and continues, and the simulator exits 0 in both cases. A test that reports a failure but does not fail is decoration. `$fatal` exits non-zero, and `make sim` and the workflow read that exit code.
*   **`#1` after the edge.** `@(posedge clk)` resumes *at* the edge, before non-blocking assignments take effect. A read at that point sees the value of the previous cycle. Relative checks still pass with that old value, so this error is easy to miss.
*   **You supply `$dumpfile`/`$dumpvars`.** The tool does not. Without them you have no waveform to examine when the assertion above fails.

Try it. Change `src/blinky.v` so that the design is wrong, run `make sim`, and see it fail. If you have never seen a testbench fail, you do not know that it works.

That is the full method, and it works on any design. Break one thing and run the tests. Make sure that the test you aimed at fails and gives a message that you can act on. Then run `git checkout -- src/blinky.v` and break the next thing.

You do not learn that "the tests pass". You learn which test catches which mistake. You also learn where no test catches anything: that is the test you have not written. This method is the only answer to "does my test really check the design", because a test that cannot fail tells you nothing.

## When a test fails: look at the waveform

`make sim` writes `build/wave.vcd`, which contains every signal on every cycle. It does this only if your testbench has the two `$dumpfile`/`$dumpvars` lines from the skeleton above. Open the file with GTKWave, or with the **WaveTrace** extension that the Dev Container installs (click the `.vcd` file). A failed assertion tells you *that* the design is wrong. The waveform shows you *why*.

`*.vcd` is in `.gitignore`. CI keeps the copy from each run in the `chipforall-build-artifacts` upload for five days. So you can still examine a test that fails only on CI.

## Writing testbenches in Python

`make cocotb` runs [cocotb](https://www.cocotb.org/) tests: Python coroutines that drive the same RTL through the same simulator. It is an alternative to `test/tb_blinky.v`, not a replacement. Use the language that fits the test.

```bash
make cocotb
```

This is the smallest test file that drives a clock and checks something. Look at `tick`. `RisingEdge` resumes *at* the edge, before the non-blocking assignment takes effect. A read immediately after it sees the value of the previous cycle. This is the same problem as `#1` in Verilog. Always wait for a `Timer` after the edge:

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

List the file under `"//COCOTB_TESTS"`. Give your RTL a `` `timescale `` (see [Making it your design](#making-it-your-design)), because the `10, units="ns"` clock needs one.

The example in `test/test_blinky_cocotb.py` uses the one thing that Python clearly does better here: it writes to a signal *inside* the design.

```python
dut.count.value = (1 << (WIDTH - 1)) - 1   # one tick below the rollover
await tick(dut)
assert dut.led.value == 1
```

With that write, the check that `led` is the top bit of the counter takes four cycles. A Verilog testbench can do the same only if it overrides `WIDTH`, which the gate-level testbench cannot do, or if it runs 2^25 cycles.

## Random stimulus and a reference model

`test/test_blinky_random.py` is the other half of verification. A directed test asserts at moments that a person chose. This test builds a model of what the design should do. It compares the design with the model on every cycle, with stimulus that nobody wrote out.

It has three parts of about ten lines each:

*   **The model** is `BlinkyModel`: the behaviour of blinky, written a second time in Python. It is deliberately not a transcription of the RTL. A model that copies the mistakes of the design agrees with it everywhere and can never catch a mistake.
*   **The stimulus** is random starting counts and random reset pulses. Two of the five windows are deliberately at places where `led` changes, so a run cannot watch a signal that never moves.
*   **The scoreboard** compares `led` with the model after every clock. A failure gives the cycle, both values and the starting count.

```bash
make cocotb                   # a new seed each run
make cocotb SEED=1789965785   # replay one exactly
```

cocotb seeds Python's `random` and logs the seed that it used. You can then reproduce a CI failure on your machine from the log line.

The test also fails when `led` never moved. 200 passed cycles that watched a constant signal prove nothing. A suite that reports PASS for that is what this repository works hardest to prevent.

It does not check reset *timing*. The stimulus moves `rst` immediately after a clock edge, so an asynchronous reset and a synchronous reset look the same here. That question belongs to static timing: recovery and removal. The nine-line summary does not show it, because its two slack rows are setup and hold, which are different checks. The per-corner reports show it in a separate path group:

```bash
grep -A12 'Path Group: asynchronous' runs/*/*-openroad-stapostpnr/*/checks.rpt
```

This was measured, not assumed. A CI run of this design gave `recovery check against rising-edge clock clk` in all nine corner reports. CI prints what it finds there on every run. A design with a synchronous reset has nothing in that path group. For that design, this is the correct answer, not a missing one.

## Simulating the gates, not just the RTL

`make sim` tells you that your Verilog behaves correctly. It tells you nothing about the netlist that the tools made from it. Latch inference, reset handling and the way a synthesiser reads an ambiguous `always` block are all between the two. You cannot see them from the RTL.

`make gatesim` closes that gap. It simulates `runs/<tag>/final/nl/`, the gate-level netlist that `make gds` wrote, with the Verilog models of the Sky130 cells. `<tag>` is the run directory: `<DESIGN_NAME>_run`, unless you name it yourself.

```bash
make gds       # produces the netlist
make gatesim   # simulates it
```

It needs its own testbench in `test/gate/`, because synthesis resolves parameters. `test/tb_blinky.v` makes the design smaller by setting `WIDTH` to 4. A netlist has no `WIDTH` to set: it is fixed at the 26 that `src/blinky.v` declares. That is where the 2^26 below comes from. So `test/gate/tb_blinky_gl.v` drives the real pins and watches `led` for a full divider period. That is all 2^26 cycles, which takes a few minutes.

Synthesis removes more than parameters. It also removes internal names. The cocotb test above writes to `dut.count` to skip 2^25 cycles, but a netlist has no `count` to write to. Anything that reaches inside the design works on the RTL and stops working at this step. This step exists partly to show you that.

**This is a functional check, not a timing check.** Nothing here back-annotates an SDF. The cells switch with zero delay, so the run cannot see a race that occurs only at real delays. It does see everything that synthesis decided: inferred latches, the implementation of reset, and the reading of an ambiguous `always` block.

Timing is the job of STA, in `make gds`, and the per-corner reports above give the answer. In some flows, gate-level simulation with SDF annotation is the last timing gate. This step is not that gate.

Because `make gatesim` takes minutes, CI runs it on pushes and on `v*` tags, but not on every pull request.

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

It is not a picture of the netlist. `make synth` runs a full synthesis and gives a hundred generic gates, and nobody learns anything about their design from those gates. `make schematic` stops earlier, where the circuit still looks like its source code.

**Generic gates, not Sky130 gates.** `make synth` maps to Yosys' own cells and stops there. For the example, `build/synthesis.json` contains 94 of them (`$_DFF_PP0_`, `$_OR_`, `$_XOR_` and others) and no `sky130_` cell, because nothing gives Yosys a liberty file here. This command answers "does it synthesise, and approximately how much logic is it". It cannot answer area or timing.

The `198 standard cells` in `make report` comes from LibreLane's own synthesis inside `make gds`, with the real library. It is a different number, and you cannot compare the two.

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

## Configuration reference

`config.yaml` is a [LibreLane](https://github.com/librelane/librelane) configuration file. Keys that LibreLane does not own have a `//` prefix. LibreLane ignores those keys completely, so one file stays valid for both tools.

| Key | What it does |
|---|---|
| `DESIGN_NAME` | Your top module's name. Everything else reads it from here. |
| `VERILOG_FILES` | Synthesisable sources. One entry for each file: LibreLane validates each entry as a literal path and does not expand `**`. |
| `"//TEST_FILES"` | Verilog testbenches for `make sim`. Globs work. |
| `"//SIM_TOP"` | Which testbench module to elaborate. Required when `"//TEST_FILES"` matches more than one file. |
| `"//COCOTB_TESTS"` | Python testbenches for `make cocotb`. Optional. |
| `"//GATE_TESTS"` / `"//GATE_TOP"` | Gate-level testbenches for `make gatesim`. Optional. |
| `"//DESCRIPTION"` | One line that tells what your design is. It appears below the title of the results page and in its link preview. Optional. |
| `"//WAVE_SIGNALS"` | Signals that `make site` draws from the VCD of `make sim`. Name them from the testbench top down (`tb_blinky.uut.count`). `make site` fails on a name that the VCD does not declare. Optional. |
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
