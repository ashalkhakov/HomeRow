/* config.h for the copy of Oniguruma inside HomeRow.
 *
 * Written by hand in place of the one autoconf/cmake would generate: both
 * of HomeRow's build systems (gnustep-make and Xcode) compile these sources
 * directly.  Everything here is true of every platform HomeRow targets
 * (64-bit macOS and Linux, clang). */
#ifndef HOMEROW_ONIG_CONFIG_H
#define HOMEROW_ONIG_CONFIG_H

#define HAVE_ALLOCA 1
#define HAVE_ALLOCA_H 1
#define HAVE_STDINT_H 1
#define HAVE_INTTYPES_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_SYS_TIME_H 1
#define HAVE_SYS_TIMES_H 1
#define HAVE_TIME_H 1
#define HAVE_UNISTD_H 1

#define SIZEOF_INT 4
#define SIZEOF_LONG 8
#define SIZEOF_LONG_LONG 8
#define SIZEOF_VOIDP 8
#define SIZEOF_INTPTR_T 8
#define SIZEOF_TIME_T 8

#define PACKAGE "onig"
#define PACKAGE_VERSION "6.9.10"
#define VERSION "6.9.10"

#endif
