# ChipForAll Makefile
# Philosophy: Keep it simple. Delegate logic to c4o-core.

# Image Configuration
C4O_IMAGE := ghcr.io/anlit75/c4o-core:latest
OPENLANE_IMAGE := efabless/openlane:2023.11.03
PWD := $(shell pwd)

# Common Docker Flags
# We mount the current directory to /workspace so artifacts persist in build/
DOCKER_RUN := docker run --rm -v $(PWD):/workspace -w /workspace

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
gds: pdk
	@echo "🟢 Validating config with c4o-core..."
	$(DOCKER_RUN) $(C4O_IMAGE) gds
	@echo "🟢 Running OpenLane..."
	docker run --rm \
		-v $(PWD):/openlane \
		-v $(PWD)/pdks:/pdks \
		-e PDK_ROOT=/pdks \
		-e PWD=/openlane \
		-u $(shell id -u):$(shell id -g) \
		$(OPENLANE_IMAGE) \
		/bin/bash -c "./flow.tcl -design . -save_path build/gds -tag blinky_run"

# --- Utilities ---

shell:
	$(DOCKER_RUN) -it --entrypoint /bin/bash $(C4O_IMAGE)

clean:
	rm -rf build/
