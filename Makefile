# ChipForAll Makefile
# Philosophy: Keep it simple. Delegate logic to c4o-core.

# Image Configuration
C4O_IMAGE := ghcr.io/anlit75/c4o-core:v1.1.1
OPENLANE_IMAGE := efabless/openlane:2023.11.03
DESIGN_NAME := $(shell grep '"DESIGN_NAME"' config.json | sed 's/.*: *"\([^"]*\)".*/\1/')
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

.PHONY: all help lint sim synth gds pdk clean shell

all: lint sim synth

help:
	@echo "Available targets:"
	@echo "  make lint   - Run Verilator lint check"
	@echo "  make sim    - Run Icarus Verilog simulation"
	@echo "  make synth  - Run Yosys synthesis"
	@echo "  make pdk    - Install/Enable Sky130 PDK via Volare"
	@echo "  make gds    - Run OpenLane GDSII flow"
	@echo "  make shell  - Enter c4o-core interactive shell"

# --- Logic Delegated to c4o-core ---

lint:
	$(C4O_CMD) lint

sim:
	$(C4O_CMD) sim

synth:
	$(C4O_CMD) synth

pdk:
	@echo "📦 Installing PDK (Sky130)..."
	$(C4O_CMD) pdk

# --- Physical Design (Sidecar Pattern) ---
# 1. Ensure PDK is ready.
# 2. Guard Check: Stop if inside DevContainer.
# 3. c4o-core validates the config.
# 4. We run the heavy OpenLane image using the PDKs installed in the previous step.
gds:
	@# 🛑 Guard Clause: Prevent running Docker-in-Docker
	@if [ "$(IS_IN_CONTAINER)" = "yes" ]; then \
		echo "❌ [ERROR] 'make gds' requires Docker access to run OpenLane."; \
		echo "👉 Please run this command from your HOST terminal, not inside VS Code DevContainer."; \
		exit 1; \
	fi

	$(MAKE) pdk

	@echo "🟢 Validating config with c4o-core..."
	$(C4O_CMD) gds
	@echo "🟢 Running OpenLane..."
	mkdir -p build
	docker run --rm \
		-v $(PWD):/openlane/designs/$(DESIGN_NAME) \
		-v $(PWD)/pdks:/pdks \
		-e PDK_ROOT=/pdks \
		-e PWD=/openlane/designs/$(DESIGN_NAME) \
		-w /openlane/designs/$(DESIGN_NAME) \
		-u $(shell id -u):$(shell id -g) \
		$(OPENLANE_IMAGE) \
		/bin/bash -c "/openlane/flow.tcl -design . -tag $(DESIGN_NAME)_run"
	@echo "🟢 Post-processing..."
	# Copy the final GDS to the build folder
	cp runs/$(DESIGN_NAME)_run/results/final/gds/$(DESIGN_NAME).gds build/$(DESIGN_NAME).gds
	# Clean up: Move the raw runs folder into build/runs
	rm -rf build/runs && mv runs build/runs

# --- Utilities ---

shell:
	$(DOCKER_RUN) -it --entrypoint /bin/bash $(C4O_IMAGE)

clean:
	rm -rf build/
