<div align="center">

# ChipForAll

**Write Verilog. Prove that it works. Get a real chip layout.**

A template with tests that can fail, a full RTL-to-GDSII flow and a results page on every commit. It runs in your browser in a GitHub Codespace. You install no EDA tools.

[**Use this template**](https://github.com/anlit75/ChipForAll/generate) · [See a results page](https://anlit75.github.io/ChipForAll/) · [Guide](docs/guide.md) · [繁體中文](README.zh-TW.md)

![the tests pass, one changed line fails four tests, make gds builds the layout step by step, and CI publishes a results page](https://raw.githubusercontent.com/anlit75/c4o-core/assets/demo/demo.gif)

[![CI Status](https://github.com/anlit75/ChipForAll/actions/workflows/verify.yml/badge.svg)](https://github.com/anlit75/ChipForAll/actions/workflows/verify.yml)
[![release Version](https://img.shields.io/github/v/release/anlit75/ChipForAll?label=version)](https://github.com/anlit75/ChipForAll/releases)
[![License](https://img.shields.io/github/license/anlit75/ChipForAll)](LICENSE)

</div>

## Quick Start

You need a GitHub account. Everything else runs in a Codespace.

**1. Make your copy.** Press [**Use this template → Create a new repository**](https://github.com/anlit75/ChipForAll/generate). Give it a name and press **Create repository**.

**2. Open a Codespace on your copy.** In your new repository, press **Code → Codespaces → Create codespace on main**. The first start takes a few minutes. Wait until a terminal opens.

**3. Check that the tests pass** (seconds). In the terminal, type:

```bash
make sim
```

`make sim` checks the RTL, then runs every test that `config.yaml` lists. A bare `make` only checks the config.

**4. Break it on purpose.** A layout tool cannot do this part for you. In `rtl/blinky.v`, change `count[WIDTH-1]` to `count[WIDTH-2]`. The LED now blinks twice as fast. Run `make sim` again:

```
  FAIL cocotb  1 passed, 4 failed, seed 1791638899, 10.0 s
[ERROR] cocotb tests failed: led_rises_half_a_period_after_reset, led_toggles_with_a_full_period, reset_in_the_middle_restarts_the_count, random_resets_match_the_model

led_rises_half_a_period_after_reset  tb/test_blinky_cocotb.py:64
AssertionError: led rose before cycle 32768
assert 1 == 0
make cocotb SEED=1791638899 TEST=test_blinky_cocotb.led_rises_half_a_period_after_reset
```

The `[ERROR]` line names the failing tests. Below it, each failing test prints its message and a command that runs it again. The block shows the first of the four. `make` exits non-zero, so CI also fails. Undo the change with `git checkout -- rtl/blinky.v`. [Writing tests like this for your design →](docs/guide.md#writing-a-testbench-for-your-own-design)

**5. Build the layout** (a few minutes, plus a multi-GB PDK download on a first run):

```bash
make gds
```

At the end, it tells you what it built:

```
  blinky

  die                56.375 x 67.095 um  (3782.48 um^2)
  utilization        51.7%
  instances          65 after synthesis, 116 after routing
  instance classes   32 logic, 27 well taps, 21 timing-repair buffers, 17 inverters, 16 sequential, 3 clock buffers
  drive strength     X1 0->17, X2 65->69, X16 0->3  (synthesis->routing)
  setup slack        +5.96 ns  (0 violations)
  hold slack         +0.11 ns  (0 violations)
  limit violations   0 max slew, 0 max capacitance, 0 max fanout
  power              0.143 mW  (nom_tt_025C_1v80)
  signoff            clean  (DRC, LVS, antenna, XOR)
  lint warnings      0
  layout             runs/blinky_run/final/render/blinky.png

  GDS         build/blinky.gds
  Stages      build/stages/ (6 renders)
```

`signoff clean` and positive slack tell you that the layout passed the manufacturing checks and meets the clock. The flow stops at this GDS file: fabrication is not part of this repository. [How to read each line →](docs/guide.md#reading-the-result)

Prefer your own machine? [Run it with Docker →](docs/guide.md#running-it-on-your-own-machine)

## Your Online Results

Each CI run on `main` publishes a results page to `https://<you>.github.io/<your-repo>/`. [Here is the page of this template.](https://anlit75.github.io/ChipForAll/)

The page shows your layout first. You can open it in 3D or download the GDS. Next are the tests, coverage, timing, area, power and signoff. Each of these sections has a History fold with charts of the earlier commits on `main`. The last section, How it was built, shows a real picture of each stage.

Turn it on once: **Settings → Pages → Source: GitHub Actions**. Build the page locally with `make site`. [More →](docs/guide.md#publishing-the-results-page)

## Make it Yours

Delete the blinky files. Put your Verilog in `rtl/` and your tests in `tb/`. List them in `config.yaml`. Set `DESIGN_NAME` to your top module. The `Makefile` and CI read all other data from `config.yaml`. [The three things that must agree →](docs/guide.md#making-it-your-design)

You need [some Verilog](docs/guide.md#before-you-start) to change the design. When your design works, replace this README with one about your design.

## Commands

| Command | What it does |
|---|---|
| `make` | Checks `config.yaml` and the files it names. It runs no tool |
| `make rtl` | Compiles, lints and synthesises your RTL: the steps that take seconds |
| `make sim` | `make rtl`, then every test: Verilog and Python (cocotb). `WAVES=1` also writes a waveform |
| `make regress` | Your test list over many seeds, then code coverage. `COVERAGE=0` skips the coverage. [More →](docs/guide.md#many-seeds) |
| `make gds` | Full RTL-to-GDSII flow, then the summary above. It skips the flow when nothing changed, and `FORCE=1` runs it anyway |
| `make gatesim` | Your tests again, on the gates (after `make gds`) |
| `make report` | The summary again, with no new run (after `make gds`) |
| `make site` | The results page, in `build/site/` |
| `make shell` | A shell inside the toolchain container |

`make gatesim` and `make report` stop with an error when your RTL changed since the last `make gds`. Run `make gds` again.

`make help` lists all the commands. The [full table](docs/guide.md#commands) shows what each command writes.

## What You Get

An open-source flow can already make a layout: [LibreLane](https://github.com/librelane/librelane) does it. To know whether that layout is *correct* is a different problem, and it is not solved. ChipForAll adds the missing part: the tests, the checks and the CI around the flow.

- **Tests that can fail.** Verilog and Python (cocotb) testbenches exit non-zero when the design is broken.
- **Gate-level simulation.** Your tests run again on the netlist that synthesis made. Latch bugs and reset bugs hide there.
- **Signoff you can read.** A short summary shows area, timing, power and DRC/LVS. You do not need to read a JSON file with hundreds of keys.
- **No EDA tools to install.** One Docker image contains them all. The commands are the same in Docker, a Dev Container and a Codespace.
- **Yours to publish.** Sky130 is Apache 2.0 and has no NDA. Put the GDS in your portfolio.

The tools are the open-source equivalents of the commercial tools. Icarus replaces VCS, Yosys replaces Design Compiler, and OpenSTA replaces PrimeTime. The flow and the vocabulary transfer. The tool names do not. [Full mapping →](docs/guide.md#what-this-is-and-what-it-is-not)

## Who It Is For

- **Students and self-learners** who want a first chip to show, with tests that prove it works.
- **Engineers under a foundry NDA** who want a second set of results that they can publish.
- **Anyone learning verification.** For a full UVM-style environment, see [c4o-pyuvm](https://github.com/anlit75/c4o-pyuvm), built from this template.

## Learn More

- [Guide](docs/guide.md): running on your own machine, writing testbenches, the debug waveform, gate-level simulation, negative slack, configuration reference
- [c4o-core](https://github.com/anlit75/c4o-core): the toolchain engine behind every command
- [c4o-pyuvm](https://github.com/anlit75/c4o-pyuvm): a pyuvm verification environment on a real UART

---

<div align="center">

[MIT License](LICENSE) · Powered by [c4o-core](https://github.com/anlit75/c4o-core)

</div>
