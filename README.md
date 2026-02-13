# ⚡ ChipForAll (C4O) - v1.1.1

![CI Status](https://github.com/anlit75/ChipForAll/actions/workflows/verify.yml/badge.svg)
![License](https://img.shields.io/github/license/anlit75/ChipForAll)
![Docker](https://img.shields.io/badge/docker-ready-blue)

## 1. Introduction
**ChipForAll** is an **Instant Open Source Chip Design Template**. It provides a production-ready environment for digital logic design (Verilog) without the hassle of installing complex EDA tools.

Under the hood, it uses the **[c4o-core](https://github.com/anlit75/c4o-core)** engine—a unified Docker container that packages Yosys, Verilator, Icarus Verilog, and Volare together. This means you can focus on your RTL, not your toolchain.

---

## 2. Prerequisites

The only requirement is **Docker** (Desktop or Engine). No local EDA tools are needed.

*   **Recommended**: [VS Code](https://code.visualstudio.com/) + [DevContainers Extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) for a one-click environment setup.

---

## 3. Quick Start (The "Happy Path")

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/anlit75/ChipForAll.git
    cd ChipForAll
    ```

2.  **Configure your design**:
    Edit `config.json` in the project root to point to your Verilog files.
    *(Default is pre-configured for `src/blinky.v`)*

3.  **Install PDK (Sky130)**:
    This downloads and installs the SkyWater 130nm Process Design Kit inside the project folder (managed by `volare`).
    ```bash
    make pdk
    ```

4.  **Build & Verify**:
    Runs Linting, Simulation, and Synthesis in one go.
    ```bash
    make all
    ```

5.  **Physical Design (GDSII)**:
    Generates the final layout using OpenLane.
    ```bash
    make gds
    ```
    *Output artifact: `build/blinky.gds`*

---

## 4. Project Structure

```text
.
├── config.json       # Project Configuration (Root) - Defines design name, source files, PDK, etc.
├── Makefile          # Main entry point (Wraps Docker commands for c4o-core and OpenLane)
├── src/              # RTL Source Code
│   └── blinky.v      # Example: A simple LED blinker
├── test/             # Testbenches
│   └── tb_blinky.v   # Example: Verifies the blinky module
└── build/            # Artifacts (Simulation waves, GDS, netlists)
    ├── sim.vvp       # Compiled simulation
    ├── synthesis.json # Synthesized netlist
    └── blinky.gds    # Final GDSII layout
```

---

## 5. Commands Reference

| Target | Description | Tool Used |
| :--- | :--- | :--- |
| `make lint` | Check Verilog syntax for errors | **Verilator** |
| `make sim` | Run behavioral simulation | **Icarus Verilog** |
| `make synth` | Synthesize RTL to gate-level netlist | **Yosys** |
| `make pdk` | Download & Enable Sky130 PDK | **Volare** |
| `make gds` | Run full RTL-to-GDSII flow | **OpenLane** |
| `make clean` | Remove all build artifacts (`build/`) | `rm` |

---

## 6. VS Code DevContainer (Recommended)

This repository includes a `.devcontainer` configuration. If you open this folder in VS Code, you will be prompted to "Reopen in Container". Doing so gives you a pre-configured environment with:

*   **Waveform Viewer**: Inspect `.vcd` files directly in VS Code using the **WaveTrace** extension.
*   **Schematic Viewer**: Visualize your netlist using the **Yosys Viewer**.
*   **Syntax Highlighting**: Full Verilog support out of the box.

---

## 🤝 Contributing

We welcome contributions! Please see `CONTRIBUTING.md` for details on how to submit pull requests.

Maintained by [anlit75](https://github.com/anlit75).
