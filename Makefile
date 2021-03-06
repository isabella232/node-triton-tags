#
# Copyright (c) 2018, Joyent, Inc.
#
# Makefile for node-triton-tags
#

#
# Vars, Tools, Files, Flags
#
JS_FILES	:= $(shell find lib test -name '*.js' | grep -v '/tmp/')
PEGJS_FILES	:= lib/cns-svc-tag.js lib/cmon-groups-tag.js
# Exclude the auto-generated PEGJS outputs from "make check"
JS_FILES	:= $(filter-out $(PEGJS_FILES),$(JS_FILES))

JSL_CONF_NODE	 = tools/jsl.node.conf
JSL_FILES_NODE	 = $(JS_FILES)
JSSTYLE_FILES	 = $(JS_FILES)
JSSTYLE_FLAGS	 = -f tools/jsstyle.conf
CLEAN_FILES += ./node_modules
PEGJS	= node_modules/.bin/pegjs

include ./tools/mk/Makefile.defs


#
# Targets
#

.PHONY: all
all $(PEGJS):
	npm install

# The phony "pegjsfiles" target is here for the "prepublish" npm script to call
# to ensure pegjs files are rendered before release.
.PHONY: pegjsfiles
pegjsfiles: $(PEGJS_FILES)

%.js: %.pegjs $(PEGJS)
	$(PEGJS) $< > $@

CLEAN_FILES += $(PEGJS_FILES) triton-tags-*.tgz


.PHONY: test
test: all
	NODE_NDEBUG= ./node_modules/.bin/tape test/*.test.js

.PHONY: test-in-parallel
test-in-parallel: all
	NODE_NDEBUG= prove -j15 -e ./node_modules/.bin/tape test/*.test.js


# Ensure CHANGES.md and package.json have the same version.
.PHONY: check-version
check-version:
	@echo version is: $(shell cat package.json | json version)
	[[ `cat package.json | json version` == `grep '^## ' CHANGES.md | head -2 | tail -1 | awk '{print $$2}'` ]]

check:: check-version

# Publish a release to npm properly.
.PHONY: cutarelease
cutarelease: pegjsfiles check-version
	[[ -z `git status --short` ]]  # If this fails, the working dir is dirty.
	@which json 2>/dev/null 1>/dev/null && \
	    ver=$(shell json -f package.json version) && \
	    name=$(shell json -f package.json name) && \
	    publishedVer=$(shell npm view -j $(shell json -f package.json name)@$(shell json -f package.json version) version 2>/dev/null) && \
	    if [[ -n "$$publishedVer" ]]; then \
		echo "error: $$name@$$ver is already published to npm"; \
		exit 1; \
	    fi && \
	    echo "** Are you sure you want to tag and publish $$name@$$ver to npm?" && \
	    echo "** Enter to continue, Ctrl+C to abort." && \
	    read
	ver=$(shell cat package.json | json version) && \
	    date=$(shell date -u "+%Y-%m-%d") && \
	    git tag -a "v$$ver" -m "version $$ver ($$date)" && \
	    git push --tags origin && \
	    npm publish

.PHONY: git-hooks
git-hooks:
	ln -sf ../../tools/pre-commit.sh .git/hooks/pre-commit

.PHONY: dumpvar
dumpvar:
	@if [[ -z "$(VAR)" ]]; then \
		echo "error: set 'VAR' to dump a var"; \
		exit 1; \
	fi
	@echo "$(VAR) is '$($(VAR))'"

include ./tools/mk/Makefile.deps
include ./tools/mk/Makefile.targ
JSL_FLAGS += --nofilelist
