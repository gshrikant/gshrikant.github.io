# Hacky Makefile to build and deploy the site
SRCDIR ?= src
OUTDIR ?= docs	# Workaround until GH action is enable 
TMPLDIR ?= templates

# List of files to be published
PUBLISH := welcome-back.md \
	   session-notes-lmop.md \
	   reading-bx.md \
	   usb-debugging.md \
	   dungeon-map.md

SOURCES := $(PUBLISH:%=$(SRCDIR)/%)
OUTS := $(patsubst %.md,$(OUTDIR)/%.html,$(notdir $(SOURCES)))
METADATA := $(patsubst %.md,%.json,$(notdir $(SOURCES)))

deploy: $(OUTDIR)/index.html style.css
	cp style.css $(OUTDIR)
	cp -r assets $(OUTDIR)

metadata.json: $(METADATA)
	jq -rs '{ "posts": sort_by(.date) | reverse }' $^ > $@

$(SRCDIR)/index.md: $(TMPLDIR)/index.tmpl $(OUTS) metadata.json
	pandoc --from=markdown --to=markdown --template=$< --metadata-file=metadata.json /dev/null -o $@

$(OUTDIR)/%.html: $(SRCDIR)/%.md  $(TMPLDIR)/main.tmpl
	mkdir -p $(dir $@)
	pandoc --from=markdown+yaml_metadata_block --template=$(TMPLDIR)/main.tmpl $< -o $@

%.json: $(SRCDIR)/%.md  $(TMPLDIR)/metadata.tmpl
	pandoc --template=$(TMPLDIR)/metadata.tmpl --metadata html=$(@:%.json=%.html) $< > $@

clean:
	$(RM) -rf $(OUTDIR) $(METADATA) metadata.json

.PHONY: clean
