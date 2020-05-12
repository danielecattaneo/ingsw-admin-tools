GITSTATS ?= gitstats
REPOS_DIR := repos
STATS_DIR := stats
STATS_DIRS = $(patsubst $(REPOS_DIR)/%, $(STATS_DIR)/%, $(wildcard $(REPOS_DIR)/group_??))


stats: $(STATS_DIRS)

.PHONY: $(STATS_DIR)/%
$(STATS_DIR)/%:
	mkdir -p $(STATS_DIR)
	if [[ -e $@ ]]; then rm -rf $@; fi
	$(GITSTATS) $(REPOS_DIR)/$* $@


