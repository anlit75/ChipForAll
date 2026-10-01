<div align="center">

# ChipForAll

**Verify your chip design like a professional team — with open-source tools, in one command.**

Simulate your RTL, test it from Python, re-run the tests on the synthesised gates, build a real Sky130 layout, and publish the results as a web page. Nothing to install.

[![CI Status](https://github.com/anlit75/ChipForAll/actions/workflows/verify.yml/badge.svg)](https://github.com/anlit75/ChipForAll/actions/workflows/verify.yml)
[![release Version](https://img.shields.io/github/v/release/anlit75/ChipForAll?label=version)](https://github.com/anlit75/ChipForAll/releases)
[![License](https://img.shields.io/github/license/anlit75/ChipForAll)](LICENSE)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/anlit75/ChipForAll)

[**Live results page**](https://anlit75.github.io/ChipForAll/) · [Quick start](#-quick-start) · [Guide](docs/guide.md) · [繁體中文](README.zh-TW.md)

</div>

---

## Why ChipForAll

Getting a layout out of an open-source flow is solved — [LibreLane](https://github.com/librelane/librelane) does it. Knowing whether that layout is *right* is not. ChipForAll adds the part that is missing: the tests, the checks and the CI around the flow.

| | |
|---|---|
| 🧪 **Tests that can fail** | Verilog and Python (cocotb) testbenches that exit non-zero on a broken design. |
| 🔬 **Gate-level simulation** | Re-runs your tests on the netlist synthesis produced, where latches and reset bugs hide. |
| 📊 **Signoff you can read** | Area, timing, power and DRC/LVS in nine lines, not a 300-key JSON. |
| 🌐 **A results page per commit** | CI publishes tests, signoff, layout and waveform to GitHub Pages. |
| 🐳 **Nothing to install** | Docker, a Dev Container or a Codespace. Same commands in all three. |
| 🔓 **Yours to publish** | Sky130 is Apache 2.0, no NDA. Put the GDS in your portfolio. |

## 🚀 Quick start

You need Docker, Make and Git — or a Codespace, which has all three:

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/anlit75/ChipForAll)

The button opens this repository, which is enough to try steps 2 and 3. To keep your work and get your own CI and results page, do step 1 first and open the Codespace from your copy (**Code → Codespaces**). Either way, pick a machine larger than the smallest: `make gds` needs the disk. [Why →](docs/guide.md#working-inside-the-container)

**1. Make your copy.** Press **Use this template → Create a new repository**, then:

```bash
git clone https://github.com/<you>/<your-repo>.git && cd <your-repo>
```

In a Codespace the repository is already there; skip the clone.

**2. Check that the tests pass** (seconds):

```bash
make all
```

**3. Build the chip** (about 3 minutes; the first run also downloads the 3 GB PDK, around 20 minutes):

```bash
make gds
```

It ends by telling you what it built:

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

`signoff clean` and positive slack mean the layout passed the manufacturing checks and meets the clock. [How to read each line →](docs/guide.md#reading-the-result)

## 🌐 Your results, online

Every CI run on `main` publishes a results page to `https://<you>.github.io/<your-repo>/`: pass/fail at the top, then tests, signoff checks, the layout (with a 3D viewer), the waveform, timing, area and power.

Turn it on once: **Settings → Pages → Source: GitHub Actions**. Build it locally with `make site`. [More →](docs/guide.md#publishing-the-results-page)

## 🎮 Commands

| Command | What it does |
|---|---|
| `make all` | Lint, simulate, cocotb, synthesise — everything that takes seconds |
| `make gds` | Full RTL-to-GDSII flow, then the summary above |
| `make gatesim` | Your tests again, on the gates (after `make gds`) |
| `make report` | The summary again, without re-running |
| `make site` | The results page, in `build/site/` |
| `make shell` | A shell inside the toolchain container |

`make help` lists them all; the [full table](docs/guide.md#commands) says what each writes.

## ✍️ Make it your design

Put your Verilog in `src/`, your tests in `test/`, and set `DESIGN_NAME` in `config.yaml` to your top module. The `Makefile` and CI read everything else from there. [The five things that must agree →](docs/guide.md#making-it-your-design)

## Who it is for

- **Students and self-learners** who want a first chip they can show, with tests that prove it works. You will need [some Verilog](docs/guide.md#before-you-start) to change the design.
- **Engineers under a foundry NDA** who want a second set of results they are allowed to publish.
- **Anyone learning verification.** For a full UVM-style environment, see [c4o-pyuvm](https://github.com/anlit75/c4o-pyuvm), built from this template.

**Good to know:** the tools are the open-source equivalents of the commercial ones — Icarus instead of VCS, Yosys instead of Design Compiler, OpenSTA instead of PrimeTime. The flow and vocabulary transfer; the tool names do not. [Full mapping →](docs/guide.md#what-this-is-and-what-it-is-not)

## 📚 Learn more

- [Guide](docs/guide.md) — prerequisites, writing testbenches, waveforms, gate-level simulation, negative slack, configuration reference
- [c4o-core](https://github.com/anlit75/c4o-core) — the toolchain engine behind every command
- [c4o-pyuvm](https://github.com/anlit75/c4o-pyuvm) — a pyuvm verification environment on a real UART

<details>
<summary>Project structure</summary>

```text
.
├── .devcontainer/     # Dev Container definition
├── config.yaml        # Design name, clock, floorplan
├── Makefile           # Every command
├── docs/              # The guide
├── src/               # Your Verilog
│   └── blinky.v
├── test/              # Your testbenches
│   ├── tb_blinky.v              # RTL simulation (make sim)
│   ├── test_blinky_cocotb.py    # Python testbenches (make cocotb)
│   ├── test_blinky_random.py    # Random stimulus vs a reference model
│   └── gate/                    # Gate-level simulation (make gatesim)
│       └── tb_blinky_gl.v
└── build/             # Generated: GDS, logs, netlists, results page
```

</details>

---

<div align="center">

[MIT License](LICENSE) · Powered by [c4o-core](https://github.com/anlit75/c4o-core)

</div>
