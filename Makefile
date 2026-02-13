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
	$(DOCKER_RUN) $(C4O_IMAGE) lint

sim:
	$(DOCKER_RUN) $(C4O_IMAGE) sim

synth:
	$(DOCKER_RUN) $(C4O_IMAGE) synth

pdk:
	@echo "📦 Installing PDK (Sky130)..."
	$(DOCKER_RUN) $(C4O_IMAGE) pdk

# --- Physical Design (Sidecar Pattern) ---
# 1. Ensure PDK is ready.
# 2. c4o-core validates the config.
# 3. We run the heavy OpenLane image using the PDKs installed in the previous step.
# Fix: Removed -save_path. We now capture the default output from runs/ and move it.
gds: pdk
	@echo "🟢 Validating config with c4o-core..."
	$(DOCKER_RUN) $(C4O_IMAGE) gds
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
