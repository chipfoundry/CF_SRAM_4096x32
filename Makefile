CHILD_VERSION := CF_SRAM_1024x32-v1.2.3
CHILD_LEF := .cache/CF_SRAM_1024x32.lef
CHILD_LEF_URL := https://raw.githubusercontent.com/chipfoundry/CF_SRAM_1024x32/$(CHILD_VERSION)/lef/CF_SRAM_1024x32.lef

.PHONY: verify verify-interface verify-layout clean

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

clean:
	rm -rf .cache
