<div align="center">

# ChipForAll

**A template for chip designs that prove they work. Open-source tools, one command.**

Write Verilog. Prove that it works with tests that can fail. Get a real chip layout and a results page on every commit. One Docker image contains every EDA tool, and you install none of them.

[![CI Status](https://github.com/anlit75/ChipForAll/actions/workflows/verify.yml/badge.svg)](https://github.com/anlit75/ChipForAll/actions/workflows/verify.yml)
[![release Version](https://img.shields.io/github/v/release/anlit75/ChipForAll?label=version)](https://github.com/anlit75/ChipForAll/releases)
[![License](https://img.shields.io/github/license/anlit75/ChipForAll)](LICENSE)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/anlit75/ChipForAll)

[**Live results page**](https://anlit75.github.io/ChipForAll/) · [Quick start](#-quick-start) · [Guide](docs/guide.md) · [繁體中文](README.zh-TW.md)

[![make all passes, one changed line fails four tests, make gds builds the layout step by step, and CI publishes a results page](https://github.com/user-attachments/assets/61a9f618-7ba2-47b4-89ff-8f3753533a6b)](https://github.com/user-attachments/assets/29de6553-4d02-4779-996a-2966028d2e6d)

</div>

---

## Why ChipForAll

An open-source flow can already make a layout: [LibreLane](https://github.com/librelane/librelane) does it. To know whether that layout is *correct* is a different problem, and it is not solved. ChipForAll adds the missing part: the tests, the checks and the CI around the flow.

| | |
|---|---|
| 🧪 **Tests that can fail** | Verilog and Python (cocotb) testbenches exit non-zero when the design is broken. |
| 🔬 **Gate-level simulation** | Runs your tests again on the netlist that synthesis made. Latch bugs and reset bugs hide there. |
| 📊 **Signoff you can read** | A short summary shows area, timing, power and DRC/LVS. You do not need to read a JSON file with hundreds of keys. |
| 🌐 **A results page per commit** | CI publishes the layout, tests, timing, area, power and signoff to GitHub Pages. |
| 🐳 **No EDA tools to install** | One Docker image contains them all. Run it from Docker, a Dev Container or a Codespace. The commands are the same in all three. |
| 🔓 **Yours to publish** | Sky130 is Apache 2.0 and has no NDA. Put the GDS in your portfolio. |

## 🚀 Quick start

You need Docker, Make and Git. A Codespace has all three:

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/anlit75/ChipForAll)

The button always opens the original repository, `anlit75/ChipForAll`, even from your copy of this README. That is enough to try steps 2 and 3. To keep your work and get your own CI and results page, do step 1 first. Then open the Codespace from your copy (**Code → Codespaces**). In both cases, select a machine larger than the smallest one, because `make gds` needs the disk space. [Why →](docs/guide.md#working-inside-the-container)

Apple Silicon works too, but some commands run emulated. [Which ones →](docs/guide.md#before-you-start)

**1. Make your copy.** Press **Use this template → Create a new repository**. Then clone it:

```bash
git clone https://github.com/<you>/<your-repo>.git && cd <your-repo>
```

In a Codespace the repository is already there. Skip the clone.

**2. Check that the tests pass** (seconds):

```bash
make all
```

**Now break it on purpose.** A layout tool cannot do this part for you. In `rtl/blinky.v`, change `count[WIDTH-1]` to `count[WIDTH-2]`. The LED now blinks twice as fast. Run `make all` again:

```
[ERROR] cocotb tests failed: led_rises_half_a_period_after_reset, led_toggles_with_a_full_period, reset_in_the_middle_restarts_the_count, random_resets_match_the_model
```

The last line names the failing tests. Above it, each failing test prints its message. `make` exits non-zero, so CI also fails. Undo the change with `git checkout -- rtl/blinky.v`. [Writing tests like this for your design →](docs/guide.md#writing-a-testbench-for-your-own-design)

**3. Build the layout** (a few minutes, plus a multi-GB PDK download on a first run):

```bash
make gds
```

At the end, it tells you what it built:

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

`signoff clean` and positive slack tell you that the layout passed the manufacturing checks and meets the clock. The flow stops at this GDS file: fabrication is not part of this repository. [How to read each line →](docs/guide.md#reading-the-result)

## 🌐 Your results, online

Each CI run on `main` publishes a results page to `https://<you>.github.io/<your-repo>/`. The page shows the layout of your design first, and you can open it in 3D or download the GDS. Next are the verdicts and the tests, then code coverage, timing, area and instances, power, and signoff last. The page gives the time of the build and the commit. Each section can open a History fold with charts of the earlier commits on `main`. Each section also ends with the files behind it, to download.

Turn it on once: **Settings → Pages → Source: GitHub Actions**. Build the page locally with `make site`. [More →](docs/guide.md#publishing-the-results-page)

## 🎮 Commands

| Command | What it does |
|---|---|
| `make all` | Lint, your tests and synthesis: all the steps that take seconds |
| `make gds` | Full RTL-to-GDSII flow, then the summary above |
| `make regress` | Your test list over many seeds. [More →](docs/guide.md#many-seeds) |
| `make coverage` | How much of your RTL the Python tests run |
| `make gatesim` | Your tests again, on the gates (after `make gds`) |
| `make report` | The summary again, with no new run |
| `make site` | The results page, in `build/site/` |
| `make shell` | A shell inside the toolchain container |

`make help` lists all the commands. The [full table](docs/guide.md#commands) shows what each command writes.

## ✍️ Make it your design

Delete the blinky files. Put your Verilog in `rtl/` and your tests in `tb/`. List them in `config.yaml`. Set `DESIGN_NAME` to your top module. The `Makefile` and CI read all other data from `config.yaml`. [The three things that must agree →](docs/guide.md#making-it-your-design)

## Who it is for

- **Students and self-learners** who want a first chip to show, with tests that prove it works. You need [some Verilog](docs/guide.md#before-you-start) to change the design.
- **Engineers under a foundry NDA** who want a second set of results that they can publish.
- **Anyone learning verification.** For a full UVM-style environment, see [c4o-pyuvm](https://github.com/anlit75/c4o-pyuvm), built from this template.

**Good to know:** the tools are the open-source equivalents of the commercial tools. Icarus replaces VCS, Yosys replaces Design Compiler, and OpenSTA replaces PrimeTime. The flow and the vocabulary transfer. The tool names do not. [Full mapping →](docs/guide.md#what-this-is-and-what-it-is-not)

## 📚 Learn more

- [Guide](docs/guide.md): prerequisites, writing testbenches, the debug waveform, gate-level simulation, negative slack, configuration reference
- [c4o-core](https://github.com/anlit75/c4o-core): the toolchain engine behind every command
- [c4o-pyuvm](https://github.com/anlit75/c4o-pyuvm): a pyuvm verification environment on a real UART

---

<div align="center">

[MIT License](LICENSE) · Powered by [c4o-core](https://github.com/anlit75/c4o-core)

</div>
