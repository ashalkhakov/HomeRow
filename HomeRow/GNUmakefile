#
# HomeRow -- the application, for GNUstep.
#
# Needs the from-source stack that .github/scripts/dependencies.sh builds:
# clang, libobjc2 (gnustep-2.0 ABI), ARC, and FreeCoreData with its momc.
#
ifeq ($(GNUSTEP_MAKEFILES),)
  GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
endif
ifeq ($(GNUSTEP_MAKEFILES),)
  $(error GNUSTEP_MAKEFILES is not set. Source GNUstep.sh or install gnustep-make.)
endif

include $(GNUSTEP_MAKEFILES)/common.make

VERSION = 0.1
PACKAGE_NAME = HomeRow
APP_NAME = HomeRow
HomeRow_APPLICATION_ICON = HomeRow.png

#
# Resources.  Languages, Lessons and Themes are copied as whole folders, so a
# new language pack, course or theme is picked up without touching this file.
#
HomeRow_RESOURCE_FILES = \
    Resources/MainMenu.xib \
    Resources/CourseWindow.xib \
    Resources/HomeRow.png \
    Resources/Languages \
    Resources/Layouts \
    Resources/Lessons \
    Resources/Themes

HomeRow_LANGUAGES = en
HomeRow_LOCALIZED_RESOURCE_FILES = Localizable.strings

# Compiled to HomeRow.momd by FreeCoreData's momc and added to the
# resources; see coredata-model.make.
HomeRow_XCDATAMODELD_FILES = HomeRow.xcdatamodeld

#
# Sources.  Engine/ is Foundation-only and is what HomeRowTests compiles.
#
HomeRow_OBJC_FILES = \
    $(wildcard Engine/*.m) \
    HRAppDelegate.m \
    HRChartView.m \
    HRCourseWindowController.m \
    HRKeyboardView.m \
    HRManagedObjects.m \
    HRResultStore.m \
    HRResultsView.m \
    HRTestView.m \
    HRTheme.m \
    main.m

HomeRow_HEADER_FILES = $(wildcard Engine/*.h) $(wildcard *.h)

HomeRow_INCLUDE_DIRS = -IEngine
HomeRow_GUI_LIBS += -lCoreData

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/coredata-model.make
include $(GNUSTEP_MAKEFILES)/application.make
-include GNUmakefile.postamble
