#
# HomeRowTests -- the XCTest bundle, for GNUstep.
#
# The bundle compiles the sources it tests rather than linking the app:
# everything under ../HomeRow/Engine is Foundation-only by design, and
# HRResultStore needs CoreData but no AppKit, so none of this needs a
# display.
#
#   make            build the bundle
#   make run-tests  build and run it (also: make check)
#
ifeq ($(GNUSTEP_MAKEFILES),)
  GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
endif
ifeq ($(GNUSTEP_MAKEFILES),)
  $(error GNUSTEP_MAKEFILES is not set. Source GNUstep.sh or install gnustep-make.)
endif

include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = HomeRowTests

HomeRowTests_OBJC_FILES = $(wildcard *.m)
HomeRowTests_OBJC_FILES += \
    $(wildcard ../HomeRow/Engine/*.m) \
    ../HomeRow/HRResultStore.m \
    ../HomeRow/HRManagedObjects.m

HomeRowTests_INCLUDE_DIRS = -I../HomeRow -I../HomeRow/Engine

HomeRowTests_LIBRARIES = objc gnustep-base XCTest
HomeRowTests_BUNDLE_LIBS += -lCoreData

# The data model, compiled by FreeCoreData's momc; see ../HomeRow/GNUmakefile.
HomeRowTests_XCDATAMODELD_FILES = ../HomeRow/HomeRow.xcdatamodeld

XCTEST ?= xctest

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/coredata-model.make
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble

.PHONY: run-tests
# gnustep-make declares check with a double colon; this adds to it
check:: run-tests
run-tests: all
	@echo "Running XCTest bundle: $(BUNDLE_NAME)"
	. $(GNUSTEP_MAKEFILES)/GNUstep.sh; \
	HR_LANGUAGES_DIR="$(CURDIR)/../HomeRow/Resources/Languages" \
	$(XCTEST) "$(BUNDLE_NAME).bundle"
