SCRIPTS_DIR := scripts
METRICS_DIR := metrics
QUARTUS_SHELL := quartus_sh

$(METRICS_DIR)/fitter_utilization.csv: $(SCRIPTS_DIR)/panel_to_csv.tcl
	$(QUARTUS_SHELL) -t $< "Fitter||Resource Section||Fitter Resource Utilization by Entity" $@

list_panels:
	$(QUARTUS_SHELL) -t $(SCRIPTS_DIR)/list_panels.tcl

metrics: $(METRICS_DIR)/fitter_utilization.csv
