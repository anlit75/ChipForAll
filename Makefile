.PHONY: all clean test lint synth pdk gds

# Configuration
BUILD_DIR := build
SRC := src/blinky.v
TEST_SRC := test/tb_blinky.v
TOP := blinky
TEST_TOP := tb_blinky

# Tools
IVERILOG := iverilog
VVP := vvp
VERILATOR := verilator
YOSYS := yosys

# OpenLane Configuration
OPENLANE_IMAGE := efabless/openlane:2023.11.03
PDK_ROOT ?= $(shell pwd)/pdk

# Docker Configuration
DOCKER_IMAGE := ghcr.io/anlit75/c4o-core:latest
DOCKER_CMD := docker run --rm -v $(shell pwd):/workspace -w /workspace $(DOCKER_IMAGE)

# Helper to check if a command exists in PATH
# Returns the path if found, empty otherwise
check_tool = $(shell command -v $(1) 2> /dev/null)

all: test lint synth

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Test Target
test: $(BUILD_DIR)
ifneq ($(call check_tool,$(IVERILOG)),)
	@echo "Running test locally..."
	$(IVERILOG) -o $(BUILD_DIR)/$(TEST_TOP).vvp $(SRC) $(TEST_SRC)
	$(VVP) $(BUILD_DIR)/$(TEST_TOP).vvp
else
	@echo "Tool '$(IVERILOG)' not found. Running via Docker..."
	$(DOCKER_CMD) sh -c "$(IVERILOG) -o $(BUILD_DIR)/$(TEST_TOP).vvp $(SRC) $(TEST_SRC) && $(VVP) $(BUILD_DIR)/$(TEST_TOP).vvp"
endif

# Lint Target
lint:
ifneq ($(call check_tool,$(VERILATOR)),)
	@echo "Running lint locally..."
	$(VERILATOR) --lint-only $(SRC)
else
	@echo "Tool '$(VERILATOR)' not found. Running via Docker..."
	$(DOCKER_CMD) $(VERILATOR) --lint-only $(SRC)
endif

# Synthesis Target
synth: $(BUILD_DIR)
ifneq ($(call check_tool,$(YOSYS)),)
	@echo "Running synthesis locally..."
	$(YOSYS) -p "synth -top $(TOP); write_json $(BUILD_DIR)/$(TOP).json" $(SRC)
else
	@echo "Tool '$(YOSYS)' not found. Running via Docker..."
	$(DOCKER_CMD) $(YOSYS) -p "synth -top $(TOP); write_json $(BUILD_DIR)/$(TOP).json" $(SRC)
endif

# PDK Setup Target
pdk:
	mkdir -p $(PDK_ROOT)
ifneq ($(call check_tool,volare),)
	@echo "Running volare locally..."
	volare enable --pdk sky130 bdc9412b3e468c102d01b7cf6337be06ec6e9c9a --pdk-root $(PDK_ROOT)
else
	@echo "Tool 'volare' not found. Running via Docker..."
	docker run --rm \
		-v $(PDK_ROOT):/pdk \
		-e PDK_ROOT=/pdk \
		-u $(shell id -u):$(shell id -g) \
		-e HOME=/tmp \
		$(OPENLANE_IMAGE) sh -c "pip install volare && python3 -m volare enable --pdk sky130 bdc9412b3e468c102d01b7cf6337be06ec6e9c9a"
endif

# GDS Generation Target
gds: pdk $(BUILD_DIR)
	@echo "Running OpenLane flow..."
	docker run --rm \
		-v $(shell pwd):/workspace \
		-v $(PDK_ROOT):/pdk \
		-e PDK_ROOT=/pdk \
		-e PWD=/workspace \
		-u $(shell id -u):$(shell id -g) \
		-e HOME=/tmp \
		$(OPENLANE_IMAGE) \
		flow.tcl -design /workspace/src -tag openlane_run -overwrite
	@echo "Copying GDS to build directory..."
	cp src/runs/openlane_run/results/final/gds/$(TOP).gds $(BUILD_DIR)/$(TOP).gds

clean:
	rm -rf $(BUILD_DIR) *.vcd *.log src/runs
