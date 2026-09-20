# ChipForAll Makefile
# Philosophy: Keep it simple. Delegate logic to c4o-core.

# Image Configuration
C4O_IMAGE := ghcr.io/anlit75/c4o-core:2.4.0
LIBRELANE_IMAGE := ghcr.io/librelane/librelane:3.0.14
DESIGN_NAME := $(shell grep -E '^DESIGN_NAME:' config.yaml | sed -e 's/^DESIGN_NAME:[[:space:]]*//' -e 's/["'"'"']//g')
PWD := $(shell pwd)

# Common Docker Flags
# We mount the current directory to /workspace so artifacts persist in build/
DOCKER_RUN := docker run --rm -v $(PWD):/workspace -w /workspace -u $(shell id -u):$(shell id -g)

# Check if the entrypoint script exists locally (means we are inside the container)
ENTRYPOINT_SCRIPT := /opt/c4o-core/scripts/entrypoint.py

ifneq ($(wildcard $(ENTRYPOINT_SCRIPT)),)
	# Case A: We are inside the DevContainer
	IS_IN_CONTAINER := yes
	C4O_CMD := python3 $(ENTRYPOINT_SCRIPT)
else
	# Case B: We are on the Host Machine
	IS_IN_CONTAINER := no
	C4O_CMD := $(DOCKER_RUN) $(C4O_IMAGE)
endif

.PHONY: all help lint sim gatesim synth gds pdk report clean shell

all: lint sim synth

help:
	@echo "Available targets:"
	@echo "  make lint    - Run Verilator lint check"
	@echo "  make sim     - Run Icarus Verilog simulation"
	@echo "  make gatesim - Re-simulate the synthesised netlist (~5 min, after make gds)"
	@echo "  make synth   - Run Yosys synthesis"
	@echo "  make pdk     - Install/Enable Sky130 PDK via Ciel"
	@echo "  make gds     - Run LibreLane GDSII flow"
	@echo "  make report  - Show area, timing and power from the last GDS run"
	@echo "  make shell   - Enter c4o-core interactive shell"

# --- Logic Delegated to c4o-core ---

lint:
	$(C4O_CMD) lint

sim:
	$(C4O_CMD) sim

# Simulates build/runs/<tag>/final/nl/, which `make gds` leaves behind, against
# the PDK's own cell models. `make sim` says the RTL behaves; this says the gates
# synthesis produced still behave, which is a different claim.
#
# Budget about five minutes: the netlist has no WIDTH left to shrink, so
# test/gate/tb_blinky_gl.v has to run the divider's full 2**26 cycles.
gatesim:
	$(C4O_CMD) gatesim

synth:
	$(C4O_CMD) synth

pdk:
	@echo "📦 Installing PDK (Sky130)..."
	$(C4O_CMD) pdk

# --- Physical Design (Sidecar Pattern) ---
# 1. Ensure PDK is ready.
# 2. Guard Check: Stop if inside DevContainer.
# 3. c4o-core validates the config.
# 4. We run the heavy LibreLane image using the PDKs installed in the previous step.
#
# The container command mirrors what `librelane --dockerized` runs itself:
# `python3 -m librelane` with the flags, and --user to keep artifacts owned by
# the host user. --manual-pdk stops Ciel from re-resolving the PDK, since the
# `pdk` target above already pinned and enabled it.
gds:
	@# 🛑 Guard Clause: Prevent running Docker-in-Docker
	@if [ "$(IS_IN_CONTAINER)" = "yes" ]; then \
		echo "❌ [ERROR] 'make gds' requires Docker access to run LibreLane."; \
		echo "👉 Please run this command from your HOST terminal, not inside VS Code DevContainer."; \
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
			--run-tag $(DESIGN_NAME)_run config.yaml
	@echo "🟢 Post-processing..."
	# Copy the final GDS to the build folder
	cp runs/$(DESIGN_NAME)_run/final/gds/$(DESIGN_NAME).gds build/$(DESIGN_NAME).gds
	# Clean up: Move the raw runs folder into build/runs
	rm -rf build/runs && mv runs build/runs

	@# The flow just measured area, timing and power. Show them rather than
	@# leaving them in a 300-key metrics.json under build/runs.
	@$(MAKE) --no-print-directory report

# Reads build/runs/<tag>/final/metrics.json, which `make gds` leaves behind.
report:
	$(C4O_CMD) report

# --- Utilities ---

shell:
	$(DOCKER_RUN) -it --entrypoint /bin/bash $(C4O_IMAGE)

clean:
	rm -rf build/
