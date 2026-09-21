CHILD_VERSION := CF_SRAM_1024x32-v1.2.3
CHILD_LEF := .cache/CF_SRAM_1024x32.lef
CHILD_LEF_URL := https://raw.githubusercontent.com/chipfoundry/CF_SRAM_1024x32/$(CHILD_VERSION)/lef/CF_SRAM_1024x32.lef
CHILD_RAW_URL := https://raw.githubusercontent.com/chipfoundry/CF_SRAM_1024x32/$(CHILD_VERSION)
CHILD_RTL := .cache/CF_SRAM_1024x32.v
CHILD_MODEL := .cache/CF_SRAM_1024x32.tt_180V_25C.v

SKY130_REPO := https://github.com/google/skywater-pdk-libs-sky130_fd_sc_hd.git
SKY130_REV := ac7fb61f06e6470b94e8afdf7c25268f62fbd7b1
SKY130_DIR := .cache/sky130_fd_sc_hd
SKY130_READY := $(SKY130_DIR)/.ready-$(SKY130_REV)
SKY130_MODELS := .cache/sky130_fd_sc_hd_models.v
SKY130_CELL_DIRS = $(wildcard $(SKY130_DIR)/cells/*)
SKY130_INCLUDE_FLAGS = $(foreach dir,$(SKY130_CELL_DIRS),-I $(dir))

IVERILOG ?= iverilog
VVP ?= vvp
SEED ?= 1099956274
BUILD_DIR := build
TB := verilog/dv/tb_sram_4096x32.sv
EF_STUBS := verilog/dv/sky130_ef_sc_hd_sim_stubs.v
RTL_SIM := $(BUILD_DIR)/rtl_sim.vvp
GL_SIM := $(BUILD_DIR)/gl_sim.vvp
VVP_ARGS := +SEED=$(SEED)
ifneq ($(VCD),)
VVP_ARGS += +VCD
endif

.PHONY: verify verify-interface verify-layout sim-deps lint-rtl lint-gl \
	test test-quick test-rtl test-gl test-rtl-quick test-gl-quick clean \
	distclean

verify: verify-interface verify-layout

verify-interface: $(CHILD_LEF)
	python3 scripts/check_macro_interfaces.py \
		--lef $(CHILD_LEF) \
		--netlist hdl/gl/CF_SRAM_4096x32.v

verify-layout: $(CHILD_LEF)
	@command -v klayout >/dev/null || { echo "KLayout is required for verify-layout"; exit 1; }
	GDS=gds/CF_SRAM_4096x32.gds MACRO_LEF=$(CHILD_LEF) \
		klayout -b -r scripts/check_met1_pin_shorts.rb

$(CHILD_LEF):
	mkdir -p $(@D)
	curl --fail --location --silent --show-error $(CHILD_LEF_URL) --output $@

$(CHILD_RTL):
	mkdir -p $(@D)
	curl --fail --location --silent --show-error \
		$(CHILD_RAW_URL)/hdl/CF_SRAM_1024x32.v --output $@

$(CHILD_MODEL):
	mkdir -p $(@D)
	curl --fail --location --silent --show-error \
		$(CHILD_RAW_URL)/hdl/beh_models/CF_SRAM_1024x32.tt_180V_25C.v \
		--output $@

$(SKY130_READY):
	rm -rf $(SKY130_DIR)
	git clone --quiet --filter=blob:none --no-checkout $(SKY130_REPO) $(SKY130_DIR)
	git -C $(SKY130_DIR) checkout --quiet $(SKY130_REV)
	touch $@

$(SKY130_MODELS): hdl/gl/CF_SRAM_4096x32.v \
		scripts/prepare_gl_models.py $(SKY130_READY)
	python3 scripts/prepare_gl_models.py --netlist $< \
		--library $(SKY130_DIR) --output $@

sim-deps: $(CHILD_RTL) $(CHILD_MODEL) $(SKY130_MODELS)

$(BUILD_DIR):
	mkdir -p $@

$(RTL_SIM): $(TB) hdl/CF_SRAM_4096x32.v \
		hdl/bus_wrapper/CF_SRAM_4096x32_wb_wrapper.v \
		hdl/controllers/ram_controller_wb.v $(CHILD_RTL) $(CHILD_MODEL) | $(BUILD_DIR)
	$(IVERILOG) -g2012 -Wall -DUSE_POWER_PINS -Dfunctional \
		-s tb_sram_4096x32 \
		-o $@ $(TB) hdl/bus_wrapper/CF_SRAM_4096x32_wb_wrapper.v \
		hdl/controllers/ram_controller_wb.v hdl/CF_SRAM_4096x32.v \
		$(CHILD_RTL) $(CHILD_MODEL)

$(GL_SIM): $(TB) $(EF_STUBS) hdl/gl/CF_SRAM_4096x32.v \
		$(CHILD_RTL) $(CHILD_MODEL) $(SKY130_MODELS) | $(BUILD_DIR)
	$(IVERILOG) -g2012 -Wall -DGATE_LEVEL -DUSE_POWER_PINS \
		-DFUNCTIONAL -Dfunctional -s tb_sram_4096x32 \
		$(SKY130_INCLUDE_FLAGS) -o $@ $(TB) $(EF_STUBS) \
		$(SKY130_MODELS) hdl/gl/CF_SRAM_4096x32.v \
		$(CHILD_RTL) $(CHILD_MODEL)

lint-rtl: $(RTL_SIM)
	@echo "RTL elaboration passed"

lint-gl: $(GL_SIM)
	@echo "Gate-level elaboration passed"

test: test-rtl test-gl

test-quick: test-rtl-quick test-gl-quick

test-rtl: $(RTL_SIM)
	$(VVP) $< $(VVP_ARGS)

test-gl: $(GL_SIM)
	$(VVP) $< $(VVP_ARGS)

test-rtl-quick: $(RTL_SIM)
	$(VVP) $< $(VVP_ARGS) +QUICK

test-gl-quick: $(GL_SIM)
	$(VVP) $< $(VVP_ARGS) +QUICK

clean:
	rm -rf $(BUILD_DIR)

distclean: clean
	rm -rf .cache
