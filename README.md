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
| `make gds` | Generates the physical layout using LibreLane. | `build/<DESIGN_NAME>.gds` |
| `make clean` | Removes all generated artifacts. | `N/A` |

> **💡 Note:** The first time you run `make gds`, it will automatically download and install the Sky130 PDK (approx. 3GB). Please be patient!

## 📂 Project Structure

```text
.
├── config.yaml        # ⚙️ Project configuration (Design Name, Clock, Area)
├── Makefile           # 🎮 The command center
├── src/               # ✍️ Your Verilog Source Code
│   └── blinky.v
├── test/              # 🧪 Your Testbenches
│   └── tb_blinky.v
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
