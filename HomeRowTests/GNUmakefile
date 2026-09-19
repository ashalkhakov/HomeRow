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

HomeRowTests_C_FILES = \
    ../HomeRow/ThirdParty/oniguruma/src/regerror.c \
    ../HomeRow/ThirdParty/oniguruma/src/regparse.c \
    ../HomeRow/ThirdParty/oniguruma/src/regext.c \
    ../HomeRow/ThirdParty/oniguruma/src/regcomp.c \
    ../HomeRow/ThirdParty/oniguruma/src/regexec.c \
    ../HomeRow/ThirdParty/oniguruma/src/regenc.c \
    ../HomeRow/ThirdParty/oniguruma/src/regsyntax.c \
    ../HomeRow/ThirdParty/oniguruma/src/regtrav.c \
    ../HomeRow/ThirdParty/oniguruma/src/regversion.c \
    ../HomeRow/ThirdParty/oniguruma/src/st.c \
    ../HomeRow/ThirdParty/oniguruma/src/unicode.c \
    ../HomeRow/ThirdParty/oniguruma/src/ascii.c \
    ../HomeRow/ThirdParty/oniguruma/src/utf8.c \
    ../HomeRow/ThirdParty/oniguruma/src/utf16_le.c \
    ../HomeRow/ThirdParty/oniguruma/src/unicode_unfold_key.c \
    ../HomeRow/ThirdParty/oniguruma/src/unicode_fold1_key.c \
    ../HomeRow/ThirdParty/oniguruma/src/unicode_fold2_key.c \
    ../HomeRow/ThirdParty/oniguruma/src/unicode_fold3_key.c

HomeRowTests_INCLUDE_DIRS = -I../HomeRow -I../HomeRow/Engine -I../HomeRow/ThirdParty/oniguruma/src

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
	HR_LESSONS_DIR="$(CURDIR)/../HomeRow/Resources/Lessons" \
	HR_LAYOUTS_DIR="$(CURDIR)/../HomeRow/Resources/Layouts" \
	HR_TEXTMATE_FIXTURES_DIR="$(CURDIR)/Fixtures/textmate" \
	HR_CODE_DIR="$(CURDIR)/../HomeRow/Resources/Code" \
	$(XCTEST) "$(BUNDLE_NAME).bundle"
