# ⚡ ChipForAll (C4O)

![CI Status](https://github.com/anlit75/ChipForAll/actions/workflows/verify.yml/badge.svg)
![License](https://img.shields.io/github/license/anlit75/ChipForAll)
![Docker](https://img.shields.io/badge/docker-ready-blue)

> **A Zero-Configuration Starter Kit for Open Source Silicon Design.**
> Focus on your Verilog, not your environment variables.

---

## 🚀 Quick Start

**The fastest way to start designing chips:**

1.  **Create your repo**: Click the **[Use this template](https://github.com/anlit75/ChipForAll/generate)** button above.
2.  **Launch environment**: Open your new repo in **GitHub Codespaces** (Green Code button -> Codespaces).
3.  **Run the demo**:
    ```bash
    make test
    ```
    *You should see a passing testbench and a generated waveform in `build/`.*

---

## 🔋 Batteries Included

This template provides a production-ready EDA (Electronic Design Automation) environment out of the box.

* **🐳 Pre-built Docker Environment**: No need to install Yosys, Verilator, or Icarus Verilog manually. We pull `ghcr.io/anlit75/c4o-core` automatically.
* **🛠️ Unified Makefile**: One interface for all tools. Whether you are on Linux, Mac, or Windows (via WSL/Docker), the commands are the same.
* **✅ CI/CD Ready**: GitHub Actions are pre-configured to lint, simulate, and synthesize your design on every push.
* **💻 VS Code Optimized**: Includes extensions for Verilog syntax highlighting and IntelliSense.

---

## 📂 Project Structure

```text
.
├── src/                # Your RTL Design (Verilog)
│   └── blinky.v        # Example: A simple LED blinker
├── test/               # Your Testbenches
│   └── tb_blinky.v     # Example: Verifies the blinky module
├── build/              # Generated Artifacts (Waveforms, Netlists)
├── Makefile            # The magic script that handles Docker/Local execution
└── .github/            # CI Workflows
```

---

## 🛠️ Usage

This project uses a smart Makefile. If you have tools installed locally, it uses them. If not, it automatically runs them inside the Docker container.

### 1. Check Syntax (Lint)
Runs `verilator --lint-only` to catch syntax errors early.
```bash
make lint
```

### 2. Run Simulation (Test)
Compiles with `iverilog` and runs the simulation. Output waveform (`.vcd`) is saved to `build/`.
```bash
make test
```

### 3. Synthesize (Build)
Runs `yosys` to convert your Verilog into a gate-level netlist (JSON/BLIF).
```bash
make synth
```

### 4. Clean Up
Removes the `build/` directory.
```bash
make clean
```

## 🏗️ Physical Design (ASIC Flow)

Turn your Verilog into a manufacturable chip layout using **OpenLane** and the **SkyWater 130nm PDK**.

### 1. Install PDK (First Time Only)
Downloads the Sky130 PDK (~3GB). This is managed by `volare`.
```bash
make pdk
```

### 2. Generate GDSII
Runs the full OpenLane flow (Synthesis -> Floorplan -> Placement -> Routing -> Signoff) inside Docker.
```bash
make gds
```
* Output: `build/blinky.gds`
* Viewer: Use [KLayout](https://www.klayout.de/) to open the GDS file and see your chip!

---

## 🤝 Contributing

We welcome contributions! Please see `CONTRIBUTING.md` for details on how to submit pull requests.

Maintained by [anlit75](https://github.com/anlit75).
