# ChipForAll Makefile
# Philosophy: Keep it simple. Delegate logic to c4o-core.

# Image Configuration
#
# Pinned to the minor, not the patch. c4o-core publishes 2.16.0, 2.16, 2 and
# latest for every release; 2.16 means a fix reaches you without anybody editing
# this line -- for as long as 2.16 is c4o-core's newest minor. Only the newest
# minor gets fixes, so once 2.17 is out this line has to move to keep getting
# them. A new behaviour never arrives unannounced. Pin 2.16.0 instead if you
# want a byte-identical image forever, and remember that you then also own
# noticing its fixes.
#
# Two files carry this version -- here and .devcontainer/devcontainer.json. CI
# refuses to continue when they disagree, so change both together. The workflow
# reads the image name from this line.
C4O_IMAGE := ghcr.io/anlit75/c4o-core:2.16
LIBRELANE_IMAGE := ghcr.io/librelane/librelane:3.0.14

# Extra flags for the LibreLane run, passed through as they are.
LIBRELANE_ARGS ?=
DESIGN_NAME := $(shell grep -E '^DESIGN_NAME:' config.yaml | sed -e 's/^DESIGN_NAME:[[:space:]]*//' -e 's/["'"'"']//g')
PWD := $(shell pwd)

# A full run starts empty: --overwrite removes the previous run. LibreLane's
# default is to append to a run that exists, so a second `make gds` used to
# leave two of every step directory under the same tag.
#
# Not when LIBRELANE_ARGS names a step to start from. That is LibreLane's own
# resume, and it needs the previous run to still be there:
#
#   make gds LIBRELANE_ARGS="--from OpenROAD.Floorplan --with-initial-state <file>"
#
# where <file> is the state_in.json in that step's directory of the last run,
# runs/<tag>/13-openroad-floorplan/state_in.json for the example. The resumed
# steps are appended after the old ones, numbered on from the last.
#
# Most of what you change after the first flow -- FP_CORE_UTIL, the floorplan --
# does not need synthesis redone. CLOCK_PERIOD is not one of those changes: the
# clock is an input to synthesis, so resuming from floorplan measures the old
# gates under the new period. See docs/guide.md, "Iterating without re-running
# the whole flow".
#
# Measured on LibreLane 3.0.14: --last-run cannot be used here, because it and
# --run-tag are mutually exclusive; the step is 'OpenROAD.Floorplan', not
# 'floorplan'; and without --with-initial-state LibreLane starts from the state
# of the finished design, and CTS crashes on it.
ifeq ($(filter --from --from=% -F --only --only=%,$(LIBRELANE_ARGS)),)
	LIBRELANE_OVERWRITE := --overwrite
endif

# Where the Sky130 PDK lives on the host. One copy is 3GB and every checkout
# needs the same one, so a machine with several -- a lab, a teaching account --
# can point them all at one directory instead of paying for it again each time:
#
#   make gds PDK_ROOT=/opt/sky130
#
# Both halves honour it: `make pdk` installs there (c4o-core 2.8.2 and up) and
# the LibreLane sidecar reads from there. Default is this checkout's own pdks/.
PDK_ROOT ?= $(PWD)/pdks

# Common Docker Flags
# We mount the current directory to /workspace so artifacts persist in build/
DOCKER_RUN := docker run --rm -v $(PWD):/workspace -w /workspace -u $(shell id -u):$(shell id -g)

# Check if the entrypoint script exists locally (means we are inside the container)
ENTRYPOINT_SCRIPT := /opt/c4o-core/scripts/entrypoint.py

# C4O_COCOTB is the same command with a seed threaded through. A random test
# is only worth running if its failures repeat: cocotb seeds Python's random
# module from the seed below and logs the value it used, so
#
#   make cocotb SEED=1789965785
#
# replays a failed run exactly. It needs its own variable because the value
# has to cross into the container, which an exported shell variable does not.
#
# SEED here, RANDOM_SEED inside: that is cocotb 1.9's name for it, and cocotb
# 2 renames it again (COCOTB_RANDOM_SEED). Translating at this line is what
# keeps `make cocotb SEED=...` the same command across that change.
# The results page names the commit and CI run it was built from, which c4o-core
# reads from these. Without them a published page cannot say which commit it
# shows. `-e NAME` with no value passes the host's value through, and passes
# nothing when the host has none, so a local `make site` is unaffected.
SITE_ENV := -e GITHUB_SERVER_URL -e GITHUB_REPOSITORY -e GITHUB_SHA -e GITHUB_RUN_ID

ifneq ($(wildcard $(ENTRYPOINT_SCRIPT)),)
	# Case A: We are inside the DevContainer
	C4O_CMD := python3 $(ENTRYPOINT_SCRIPT)
	C4O_COCOTB = $(if $(SEED),env RANDOM_SEED=$(SEED)) $(C4O_CMD)
	C4O_SITE := $(C4O_CMD)
	C4O_PDK := env PDK_ROOT=$(PDK_ROOT) $(C4O_CMD)
else
	# Case B: We are on the Host Machine
	C4O_CMD := $(DOCKER_RUN) $(C4O_IMAGE)
	C4O_COCOTB = $(DOCKER_RUN) $(if $(SEED),-e RANDOM_SEED=$(SEED)) $(C4O_IMAGE)
	C4O_SITE := $(DOCKER_RUN) $(SITE_ENV) $(C4O_IMAGE)
	C4O_PDK := $(DOCKER_RUN) -v $(PDK_ROOT):/pdks -e PDK_ROOT=/pdks $(C4O_IMAGE)
endif

.PHONY: all help lint sim cocotb gatesim synth schematic gds pdk report site clean distclean shell

all: lint sim cocotb synth

help:
	@echo "Available targets:"
	@echo "  make all     - Everything that runs in seconds: lint, sim, cocotb, synth"
	@echo "  make lint    - Run Verilator lint check"
	@echo "  make sim     - Run Icarus Verilog simulation"
	@echo "  make cocotb  - Run the Python (cocotb) testbenches"
	@echo "                 (repeat a random failure: make cocotb SEED=<n>)"
	@echo "  make gatesim - Re-simulate the synthesised netlist (~5 min, after make gds)"
	@echo "  make synth   - Run Yosys synthesis"
	@echo "  make schematic - Draw the circuit as build/schematic.svg"
	@echo "  make pdk     - Install/Enable Sky130 PDK via Ciel, LibreLane's PDK manager"
	@echo "  make gds     - Run LibreLane GDSII flow"
	@echo "  make report  - Show area, timing and power from the last GDS run"
	@echo "  make site    - Put report, layout, schematic and tests on one page (build/site/)"
	@echo "  make shell   - Enter c4o-core interactive shell"
	@echo "  make clean     - Remove build/ (keeps runs/, which report and gatesim read)"
	@echo "  make distclean - Remove build/ and runs/"
	@echo ""
	@echo "  Re-run part of the flow after the first full one:"
	@echo "    make gds LIBRELANE_ARGS=\"--from OpenROAD.Floorplan --with-initial-state <state_in.json>\""
	@echo "    (see docs/guide.md, Iterating without re-running the whole flow)"

# --- Logic Delegated to c4o-core ---

lint:
	$(C4O_CMD) lint

sim:
	$(C4O_CMD) sim

# The same RTL, driven from Python instead of Verilog. Not a replacement for
# `make sim`: it is a second way to write a testbench, and the example shows the
# thing Python is better at -- writing to a signal inside the design.
cocotb:
	$(C4O_COCOTB) cocotb

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
# and leaves a wall of generic gates; this stops after `proc; opt`, where
# the design still looks like the code you wrote.
schematic:
	$(C4O_CMD) schematic

pdk:
	@echo "📦 Installing PDK (Sky130)..."
	@# Created here, not by the mount below: a bind mount of a path that does
	@# not exist yet is made by the daemon and owned by root, which the
	@# --user container then cannot write into.
	mkdir -p $(PDK_ROOT)
	$(C4O_PDK) pdk

# --- Physical Design (Sidecar Pattern) ---
# 1. Guard Check: Stop unless a Docker daemon answers.
# 2. c4o-core validates the config. Before the PDK, not after: `check` reads
#    config.yaml and the RTL and needs no PDK at all, so a DESIGN_NAME that
#    names no module costs a second on a first run instead of arriving behind a
#    3GB download -- which is what the README promises it does.
# 3. Ensure the PDK is ready.
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

	@echo "🟢 Validating config with c4o-core..."
	$(C4O_CMD) check

	$(MAKE) pdk
	@echo "🟢 Running LibreLane..."
	mkdir -p build
	docker run --rm \
		-v $(PWD):/workspace -w /workspace \
		-v $(PDK_ROOT):/pdks \
		-e PDK_ROOT=/pdks \
		-e HOME=/tmp \
		-u $(shell id -u):$(shell id -g) \
		$(LIBRELANE_IMAGE) \
		python3 -m librelane --manual-pdk --pdk-root /pdks \
			$(LIBRELANE_OVERWRITE) $(LIBRELANE_ARGS) \
			--run-tag $(DESIGN_NAME)_run config.yaml
	@echo "🟢 Post-processing..."
	# Copy the final GDS to the build folder
	cp runs/$(DESIGN_NAME)_run/final/gds/$(DESIGN_NAME).gds build/$(DESIGN_NAME).gds
	# runs/ stays where LibreLane put it. Moving it into build/ used to look
	# tidier, and it silently broke resuming: LibreLane looks for the run under
	# runs/, and there was never one there. c4o-core's report and gatesim
	# already search both locations, so nothing else cared.

	@# The flow just measured area, timing and power. Show them rather than
	@# leaving them in a 300-key metrics.json under runs/.
	@$(MAKE) --no-print-directory report

# Reads runs/<tag>/final/metrics.json, which `make gds` leaves behind.
report:
	$(C4O_CMD) report

# build/site/index.html: what `report` prints, the layout render, the schematic
# and the cocotb verdicts, on one page. Shows whatever has been run so far.
# CI publishes it to GitHub Pages; see README, "Publishing the results page".
site:
	$(C4O_SITE) site

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
