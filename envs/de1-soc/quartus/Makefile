QUARTUS_PROJECT_NAME := utoss-risc-v

SCRIPTS_DIR := scripts
METRICS_DIR := metrics

QUARTUS_SHELL := quartus_sh
QUARTUS_CDB   := quartus_cdb
QUARTUS_ASM   := quartus_asm

synthesize:
	$(QUARTUS_SHELL) --flow compile $(QUARTUS_PROJECT_NAME)

refresh_ram:
	$(QUARTUS_CDB) $(QUARTUS_PROJECT_NAME) --update_mif
	$(QUARTUS_ASM) $(QUARTUS_PROJECT_NAME)

$(METRICS_DIR)/fitter_utilization.csv: $(SCRIPTS_DIR)/panel_to_csv.tcl
	$(QUARTUS_SHELL) -t $< "Fitter||Resource Section||Fitter Resource Utilization by Entity" $@

%.pretty.txt: %.csv
	column -s, -t $< > $@

list_panels:
	$(QUARTUS_SHELL) -t $(SCRIPTS_DIR)/list_panels.tcl

metrics: $(METRICS_DIR)/fitter_utilization.csv
pretty-metrics: $(METRICS_DIR)/fitter_utilization.pretty.txt

.PHONY: synthesize refresh_ram list_panels
