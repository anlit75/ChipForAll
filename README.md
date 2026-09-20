# ChipForAll (C4O)

![CI Status](https://github.com/anlit75/ChipForAll/actions/workflows/verify.yml/badge.svg)
![release Version](https://img.shields.io/github/v/release/anlit75/ChipForAll?label=version)
[![License](https://img.shields.io/github/license/anlit75/ChipForAll)](LICENSE)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/anlit75/ChipForAll)

**A Zero-Config Starter Kit for Open Source Silicon Design.** Focus on Verilog, not the environment variables.

## ✨ Features

*   **🐳 Dockerized Environment**: No need to install Yosys, Verilator, or LibreLane manually. If you have Docker, you are ready.
*   **⚡ Zero Configuration**: Just clone the repo and run. The environment is pre-configured for the Skywater 130nm PDK.
*   **🛠 Full Flow Support**: From Verilog RTL to GDSII Layout in a single command.
*   **✅ CI/CD Ready**: Includes GitHub Actions workflows to verify your design automatically on every push.

## 🚀 Quick Start

### Prerequisites
*   Docker (Desktop or Engine)
*   Make
*   Git

### 1. Clone the Repo
```bash
git clone https://github.com/anlit75/ChipForAll.git
cd ChipForAll
```

### 2. Run the Full Flow
To go from Verilog code to a final GDSII layout file:
```bash
make gds
```
*Wait for a few minutes. The system will automatically download the PDK, run synthesis, place & route, and generate the layout.*

## 📖 Usage Guide

We provide a unified `Makefile` to handle everything.

| Command | Description | Output Location |
|---|---|---|
| `make lint` | Checks your Verilog code for syntax errors using Verilator. | `Terminal Output` |
| `make sim` | Runs simulation using Icarus Verilog. | `build/sim.vvp` |
| `make synth` | Synthesizes RTL into Gates using Yosys. | `build/synthesis.json` |
| `make gatesim` | Re-runs simulation on the synthesised netlist. Needs `make gds` first. | `Terminal Output` |
| `make gds` | Generates the physical layout using LibreLane. | `build/<DESIGN_NAME>.gds` |
| `make report` | Shows area, timing and power from the last `make gds`. | `Terminal Output` |
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
  lint warnings    441
```

Positive slack means the design meets the clock in `config.yaml`. Run
`make report` on its own to see it again without repeating the flow.

### Simulating the gates, not just the RTL

`make sim` says your Verilog behaves. It says nothing about the netlist the
tools produced from it — latch inference, reset handling and how a synthesiser
reads an ambiguous `always` block all sit between the two, and none of them are
visible from the RTL. `make gatesim` closes that gap: it simulates
`build/runs/<tag>/final/nl/`, the gate-level netlist `make gds` left behind,
against the Sky130 cells' own Verilog models.

```bash
make gds       # produces the netlist
make gatesim   # simulates it
```

It needs its own testbench, in `test/gate/`, because synthesis resolves
parameters: `test/tb_blinky.v` shrinks the design by setting `WIDTH` to 4, and
a netlist has no `WIDTH` left to set. `test/gate/tb_blinky_gl.v` therefore
drives the real pins and watches `led` over a full divider period — all 2^26
cycles of it, which takes about five minutes.

That cost is why CI runs `make gatesim` on pushes to `main` and on `v*` tags,
but not on every pull request.

### Working inside the container

The repo ships a [Dev Container](https://containers.dev/). Open it in GitHub Codespaces, or in VS Code with *Reopen in Container*, and you get the same image CI uses, with the Verilog extensions already installed — no Docker commands to type. The `Makefile` notices it is already inside the container and calls the tools directly instead of nesting another one.

It runs as `root`. On a Linux host that means files it writes into `build/` end up owned by `root`, so `make clean` from your host may need `sudo`. Running as a normal user instead breaks Codespaces, so this is the side we err on.

`make gds` is the exception: it launches the LibreLane container, which needs a Docker socket the Dev Container does not have. Run that one from your host terminal; the Makefile will say so if you forget.

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
│   ├── tb_blinky.v    #    RTL simulation (make sim)
│   └── gate/          #    Gate-level simulation (make gatesim)
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

The remaining keys in the file (`PDK`, `DIE_AREA`, `FP_SIZING`, …) configure the physical design flow. Leave them alone until you need them — `make gds` will tell you if one is missing.

---

Powered by the **[c4o-core](https://github.com/anlit75/c4o-core)** engine.
