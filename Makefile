# ChipForAll Makefile
# Philosophy: Keep it simple. Delegate logic to c4o-core.

# Image Configuration
C4O_IMAGE := ghcr.io/anlit75/c4o-core:2.7.0
LIBRELANE_IMAGE := ghcr.io/librelane/librelane:3.0.14

# Extra flags for the LibreLane run. The reason this exists is iteration: a
# full flow is three minutes, and most of what you change after the first one
# -- FP_CORE_UTIL, CLOCK_PERIOD, the floorplan -- does not need synthesis redone.
#
#   make gds LIBRELANE_ARGS="--last-run --from floorplan"
#
# --last-run is why runs/ is left where LibreLane put it; see the gds target.
LIBRELANE_ARGS ?=
DESIGN_NAME := $(shell grep -E '^DESIGN_NAME:' config.yaml | sed -e 's/^DESIGN_NAME:[[:space:]]*//' -e 's/["'"'"']//g')
PWD := $(shell pwd)

# Common Docker Flags
# We mount the current directory to /workspace so artifacts persist in build/
DOCKER_RUN := docker run --rm -v $(PWD):/workspace -w /workspace -u $(shell id -u):$(shell id -g)

# Check if the entrypoint script exists locally (means we are inside the container)
ENTRYPOINT_SCRIPT := /opt/c4o-core/scripts/entrypoint.py

ifneq ($(wildcard $(ENTRYPOINT_SCRIPT)),)
	# Case A: We are inside the DevContainer
	C4O_CMD := python3 $(ENTRYPOINT_SCRIPT)
else
	# Case B: We are on the Host Machine
	C4O_CMD := $(DOCKER_RUN) $(C4O_IMAGE)
endif

.PHONY: all help lint sim cocotb gatesim synth schematic gds pdk report clean distclean shell

all: lint sim cocotb synth

help:
	@echo "Available targets:"
	@echo "  make lint    - Run Verilator lint check"
	@echo "  make sim     - Run Icarus Verilog simulation"
	@echo "  make cocotb  - Run the Python (cocotb) testbenches"
	@echo "  make gatesim - Re-simulate the synthesised netlist (~5 min, after make gds)"
	@echo "  make synth   - Run Yosys synthesis"
	@echo "  make schematic - Draw the circuit as build/schematic.svg"
	@echo "  make pdk     - Install/Enable Sky130 PDK via Ciel"
	@echo "  make gds     - Run LibreLane GDSII flow"
	@echo "  make report  - Show area, timing and power from the last GDS run"
	@echo "  make shell   - Enter c4o-core interactive shell"
	@echo "  make clean     - Remove build/ (keeps runs/, which report and gatesim read)"
	@echo "  make distclean - Remove build/ and runs/"
	@echo ""
	@echo "  Re-run part of the flow after the first full one:"
	@echo "    make gds LIBRELANE_ARGS=\"--last-run --from floorplan\""

# --- Logic Delegated to c4o-core ---

lint:
	$(C4O_CMD) lint

sim:
	$(C4O_CMD) sim

# The same RTL, driven from Python instead of Verilog. Not a replacement for
# `make sim`: it is a second way to write a testbench, and the example shows the
# thing Python is better at -- writing to a signal inside the design.
cocotb:
	$(C4O_CMD) cocotb

# Simulates runs/<tag>/final/nl/, which `make gds` leaves behind, against
# the PDK's own cell models. `make sim` says the RTL behaves; this says the gates
# synthesis produced still behave, which is a different claim.
#
# Budget four to five minutes: the netlist has no WIDTH left to shrink, so
# test/gate/tb_blinky_gl.v has to run the divider's full 2**26 cycles.
gatesim:
	$(C4O_CMD) gatesim

synth:
	$(C4O_CMD) synth

# A picture of the RTL, not of the netlist. `make synth` runs a full synthesis
# and leaves a wall of technology cells; this stops after `proc; opt`, where
# the design still looks like the code you wrote.
schematic:
	$(C4O_CMD) schematic

pdk:
	@echo "📦 Installing PDK (Sky130)..."
	$(C4O_CMD) pdk

# --- Physical Design (Sidecar Pattern) ---
# 1. Ensure PDK is ready.
# 2. Guard Check: Stop unless a Docker daemon answers.
# 3. c4o-core validates the config.
# 4. We run the heavy LibreLane image using the PDKs installed in the previous step.
#
# The container command mirrors what `librelane --dockerized` runs itself:
# `python3 -m librelane` with the flags, and --user to keep artifacts owned by
# the host user. --manual-pdk stops Ciel from re-resolving the PDK, since the
# `pdk` target above already pinned and enabled it.
gds:
	@# 🛑 Guard Clause: LibreLane runs as a sidecar container, so this needs a
	@# daemon it can actually talk to. The Dev Container ships one (see
	@# .devcontainer/devcontainer.json); ask the daemon rather than guessing
	@# from where we are, so a container without the feature and a host without
	@# Docker both get the same clear answer instead of a wall of client error.
	@if ! docker info >/dev/null 2>&1; then \
		echo "❌ [ERROR] 'make gds' needs a working Docker daemon to run LibreLane."; \
		echo "👉 On your host: start Docker Desktop, or check 'docker info'."; \
		echo "👉 In the Dev Container: rebuild it so the docker-in-docker feature installs."; \
		exit 1; \
	fi

	$(MAKE) pdk

	@echo "🟢 Validating config with c4o-core..."
	$(C4O_CMD) check
	@echo "🟢 Running LibreLane..."
	mkdir -p build
	docker run --rm \
		-v $(PWD):/workspace -w /workspace \
		-v $(PWD)/pdks:/pdks \
		-e PDK_ROOT=/pdks \
		-e HOME=/tmp \
		-u $(shell id -u):$(shell id -g) \
		$(LIBRELANE_IMAGE) \
		python3 -m librelane --manual-pdk --pdk-root /pdks \
			$(LIBRELANE_ARGS) \
			--run-tag $(DESIGN_NAME)_run config.yaml
	@echo "🟢 Post-processing..."
	# Copy the final GDS to the build folder
	cp runs/$(DESIGN_NAME)_run/final/gds/$(DESIGN_NAME).gds build/$(DESIGN_NAME).gds
	# runs/ stays where LibreLane put it. Moving it into build/ used to look
	# tidier, and it silently broke --last-run: LibreLane looks for a previous
	# run in runs/, and there was never one there. c4o-core's report and
	# gatesim already search both locations, so nothing else cared.

	@# The flow just measured area, timing and power. Show them rather than
	@# leaving them in a 300-key metrics.json under runs/.
	@$(MAKE) --no-print-directory report

# Reads runs/<tag>/final/metrics.json, which `make gds` leaves behind.
report:
	$(C4O_CMD) report

# --- Utilities ---

shell:
	$(DOCKER_RUN) -it --entrypoint /bin/bash $(C4O_IMAGE)

# runs/ is deliberately not in here. `make report` and `make gatesim` both
# read the last flow out of it, so wiping it on every clean costs you the
# ability to look at a finished run again -- which is most of what you want
# after a three-minute flow. `distclean` is there for when you do mean it.
clean:
	rm -rf build/

distclean: clean
	rm -rf runs/
