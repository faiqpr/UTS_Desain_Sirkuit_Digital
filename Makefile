DIR_BUILD = build
DIR_CONS = constraints
DIR_SRC   = src
DIR_DEMOS = src/demos

TOP_LEVEL = basic
VERILOG_FILES = $(DIR_DEMOS)/$(TOP_LEVEL).v $(DIR_SRC)/tm1638.v
TB_FILE       = $(DIR_SRC)/tm1638_tb.v

compile:
	if not exist $(DIR_BUILD) mkdir $(DIR_BUILD)
	iverilog \
	-o $(DIR_BUILD)/$(TOP_LEVEL)_sim \
	$(VERILOG_FILES) \
	$(TB_FILE)

vvp:
	vvp $(DIR_BUILD)/$(TOP_LEVEL)_sim

gtk:
	gtkwave $(DIR_BUILD)/$(TOP_LEVEL)_tb.vcd

sim:
	if not exist $(DIR_BUILD) mkdir $(DIR_BUILD)
	iverilog -o $(DIR_BUILD)/$(TOP_LEVEL)_sim $(VERILOG_FILES) $(TB_FILE)
	vvp $(DIR_BUILD)/$(TOP_LEVEL)_sim
	gtkwave $(DIR_BUILD)/$(TOP_LEVEL)_tb.vcd

syn:
	if not exist $(DIR_BUILD) mkdir $(DIR_BUILD)
	yosys -p "synth_ice40 -json $(DIR_BUILD)/$(TOP_LEVEL)_netlist.json" $(VERILOG_FILES)

pnr:
	nextpnr-ice40 \
		--up5k \
		--package sg48 \
		--json $(DIR_BUILD)/$(TOP_LEVEL)_netlist.json \
		--pcf $(DIR_CONS)/$(TOP_LEVEL).pcf \
		--asc $(DIR_BUILD)/$(TOP_LEVEL).asc

bit:
	icepack $(DIR_BUILD)/$(TOP_LEVEL).asc $(DIR_BUILD)/$(TOP_LEVEL).bin

flash:
	icesprog $(DIR_BUILD)/$(TOP_LEVEL).bin

all:
	if not exist $(DIR_BUILD) mkdir $(DIR_BUILD)
	yosys -p "synth_ice40 -json $(DIR_BUILD)/$(TOP_LEVEL)_netlist.json" $(VERILOG_FILES)
	nextpnr-ice40 \
		--up5k \
		--package sg48 \
		--json $(DIR_BUILD)/$(TOP_LEVEL)_netlist.json \
		--pcf $(DIR_CONS)/$(TOP_LEVEL).pcf \
		--asc $(DIR_BUILD)/$(TOP_LEVEL).asc
	icepack $(DIR_BUILD)/$(TOP_LEVEL).asc $(DIR_BUILD)/$(TOP_LEVEL).bin

clean:
	if exist $(DIR_BUILD) rmdir $(DIR_BUILD) /S /Q


# DEVICE  = hx8k
# PACKAGE = ct256
# PIN_DEF = ice40hx8k.pcf

# all: demos

# # ------ TEMPLATES ------
# %.json: %.v
# 	yosys -q -p "synth_ice40 -top top -json $@" $^

# %.asc: %.json $(PIN_DEF)
# 	nextpnr-ice40 --$(DEVICE) --package $(PACKAGE) --pcf $(PIN_DEF) --json $< --asc $@

# %.bin: %.asc
# 	icepack $< $@

# %.rpt: %.asc
# 	icetime -d $(DEVICE) -mtr $@ $<

# %_tb.vvp: %_tb.v %.v
# 	iverilog -o $@ $^

# %_tb.vcd: %_tb.vvp
# 	vvp -N $< +vcd=$@

# # ------ DEMOS ------
# demos: basic

# #  BASIC
# basic: src/demos/basic.bin
# basic-prog: src/demos/basic.bin
# 	iceprog $<
# src/demos/basic.bin: src/demos/basic.asc
# src/demos/basic.asc: src/demos/basic.json $(PIN_DEF)
# src/demos/basic.json: src/demos/basic.v src/tm1638.v

# # ------ TEST BENCHES ------
# tests: tm1638_tb

# tm1638_tb: src/tm1638_tb.vcd
# src/tm1638_tb.vcd: src/tm1638_tb.vvp
# src/tm1638_tb.vvp: src/tm1638_tb.v src/tm1638.v

# # ------ HELPERS ------
# clean:
# 	rm -f src/*.json src/*.asc src/*.bin src/*.vvp src/*.vcd
# 	rm -f src/demos/*.json src/demos/*.asc src/demos/*.bin src/demos/*.vvp src/demos/*.vcd

# .SECONDARY:
# .PHONY: all demos tests clean