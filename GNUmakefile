#
# HomeRow -- top level, for GNUstep.
#
#   make            the app and the test bundle
#   make check      build, then run the tests
#   make install    install the app (GNUSTEP_INSTALLATION_DOMAIN=... as usual)
#
ifeq ($(GNUSTEP_MAKEFILES),)
  GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
endif
ifeq ($(GNUSTEP_MAKEFILES),)
  $(error GNUSTEP_MAKEFILES is not set. Source GNUstep.sh or install gnustep-make.)
endif

include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME = HomeRow
SUBPROJECTS = HomeRow HomeRowTests

include $(GNUSTEP_MAKEFILES)/aggregate.make

# `make check` is gnustep-make's own target: it recurses into the
# subprojects, and HomeRowTests hooks its test run onto it.
