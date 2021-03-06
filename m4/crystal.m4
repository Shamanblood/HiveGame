# crystal.m4                                                   -*- Autoconf -*-
#==============================================================================
# Copyright (C)2005 by Eric Sunshine <sunshine@sunshineco.com>
#
#    This library is free software; you can redistribute it and/or modify it
#    under the terms of the GNU Library General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or (at your
#    option) any later version.
#
#    This library is distributed in the hope that it will be useful, but
#    WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
#    or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Library General Public
#    License for more details.
#
#    You should have received a copy of the GNU Library General Public License
#    along with this library; if not, write to the Free Software Foundation,
#    Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
#==============================================================================
AC_PREREQ([2.56])

# Should stay in sync with csver.h
m4_define([cs_min_version_default], [1.4.0])


#------------------------------------------------------------------------------
# _CS_AUGMENT_PATHS([PATH-VAR], [PATHS])
#       Add paths from PATHS to the variable PATH-VAR.
#       Handles PATHS being a Win32-style path list.
#       Also adds 'bin/' subdirectories of elements in PATHS to PATH-VAR.
#------------------------------------------------------------------------------
AC_DEFUN([_CS_AUGMENT_PATHS],
[AC_REQUIRE([CS_CHECK_HOST])
AS_IF([test -n "$2"],
    [# On MinGW, CRYSTAL may contain the path in one of two flavors:
     # MSYS paths, separated by $PATH_SEPARATOR, or Win32 paths, separated
     # by ';'. Since for the configure check we need MSYS paths, CRYSTAL
     # is first treated like a Win32-style list. If that yields sensible
     # results these are used subsequently. Otherwise use CRYSTAL as-is.
    case $host_os in
        mingw*)
            my_IFS=$IFS; IFS=\;
            for win32_dir in $2; do
                win32_dir=CS_PATH_NORMALIZE_EMBEDDED([$win32_dir])
                win32_dir=`echo $win32_dir | sed "s/\(.\):/\\/\\1/"`
                AS_IF([test -d "$win32_dir"],
                    [AS_IF([test -n "$$1"], [$1="$$1$PATH_SEPARATOR"])
                    $1="$$1$win32_dir$PATH_SEPARATOR$win32_dir/bin"])
            done
            IFS=$my_IFS
            ;;
    esac
    AS_IF([test -z "$$1"],
        [my_IFS=$IFS; IFS=$PATH_SEPARATOR
        for cs_dir in $2; do
            AS_IF([test -n "$$1"], [$1="$$1$PATH_SEPARATOR"])
            $1="$$1$cs_dir$PATH_SEPARATOR$cs_dir/bin"
        done
        IFS=$my_IFS])])])

#------------------------------------------------------------------------------
# CS_PATH_CRYSTAL_CHECK([DESIRED-VERSION], [ACTION-IF-FOUND],
#                       [ACTION-IF-NOT-FOUND], [REQUIRED-LIBS],
#                       [OPTIONAL-LIBS])
#	Checks for Crystal Space paths and libraries by consulting
#	cs-config. It first looks for cs-config in the paths mentioned by
#	$CRYSTAL, then in the paths mentioned by $PATH, and then in
#	/usr/local/crystalspace/bin.  Emits an error if it can not locate
#	cs-config, if the Crystal Space test program fails, or if the available
#	version number is unsuitable.  Exports the variables
#	CRYSTAL_CONFIG_TOOL, CRYSTAL_AVAILABLE, CRYSTAL_VERSION,
#	CRYSTAL_CFLAGS, CRYSTAL_LIBS, CRYSTAL_INCLUDE_DIR, and
#	CRYSTAL_AVAILABLE_LIBS.  If the check succeeds, then CRYSTAL_AVAILABLE
#	will be 'yes', and the other variables set to appropriate values. If it
#	fails, then CRYSTAL_AVAILABLE will be 'no', and the other variables
#	empty.  If REQUIRED-LIBS is specified, then it is a list of Crystal
#	Space libraries which must be present, and for which appropriate
#	compiler and linker flags will be reflected in CRYSTAL_CFLAGS and
#	CRYSTAL_LFLAGS. If OPTIONAL-LIBS is specified, then it is a list of
#	Crystal Space libraries for which appropriate compiler and linker flags
#	should be returned if the libraries are available.  It is not an error
#	for an optional library to be absent. The client can check
#	CRYSTAL_AVAILABLE_LIBS for a list of all libraries available for this
#	particular installation of Crystal Space.  The returned list is
#	independent of REQUIRED-LIBS and OPTIONAL-LIBS.  Use the results of the
#	check like this: CFLAGS="$CFLAGS $CRYSTAL_CFLAGS" and LDFLAGS="$LDFLAGS
#	$CRYSTAL_LIBS"
#------------------------------------------------------------------------------
AC_DEFUN([CS_PATH_CRYSTAL_CHECK],
[AC_ARG_WITH([cs-prefix],
    [AC_HELP_STRING([--with-cs-prefix=CRYSTAL_PREFIX],
	[specify location of Crystal Space installation; this is the \$prefix
	value used when installing the SDK])],
	[CRYSTAL="$withval"
	export CRYSTAL])
AC_ARG_VAR([CRYSTAL], [Prefix where Crystal Space is installed])
AC_ARG_ENABLE([cstest],
    [AC_HELP_STRING([--enable-cstest],
	[verify that the Crystal Space SDK is actually usable
	(default YES)])], [], [enable_cstest=yes])

# Split the DESIRED-VERSION into the major and minor version number 
# components.
cs_version_desired=m4_default([$1],[cs_min_version_default])
sed_expr_base=['\([0-9][0-9]*\)\.\([0-9][0-9]*\).*']
cs_version_major=`echo $cs_version_desired | sed "s/$sed_expr_base/\1/"`
cs_version_minor=`echo $cs_version_desired | sed "s/$sed_expr_base/\2/"`

# Try to find an installed cs-config.
cs_path=''
_CS_AUGMENT_PATHS([cs_path], [$CRYSTAL])
AS_IF([test -n "$cs_path"], [cs_path="$cs_path$PATH_SEPARATOR"])
cs_path="$cs_path$PATH$PATH_SEPARATOR/usr/local/crystalspace/bin"

# Find a suitable CS version.
# For a given desired version X.Y, the compatibility rules are as follows:
#  Y is even (stable version): compatible are X.Y+1 and X.Y+2.
#  Y is odd (development version): compatible are X.Y+1 up to X.Y+3, assuming 
#                                  no deprecated features are used.
# Generally, an exact version match is preferred. If that is not the case,
# stable versions are preferred over development version, with a closer
# version number preferred.
# This yields the following search order:
#  Y is even (stable version): X.Y, X.Y+2, X.Y+1
#  Y is odd (development version): X.Y, X.Y+1, X.Y+3, X.Y+2

cs_version_sequence="$cs_version_major.$cs_version_minor"

cs_version_desired_is_unstable=`expr $cs_version_minor % 2`

AS_IF([test $cs_version_desired_is_unstable -eq 1],
  [# Development version search sequence
  y=`expr $cs_version_minor + 1`
  cs_version_sequence="$cs_version_sequence $cs_version_major.$y"
  y=`expr $cs_version_minor + 3`
  cs_version_sequence="$cs_version_sequence $cs_version_major.$y"
  y=`expr $cs_version_minor + 2`
  cs_version_sequence="$cs_version_sequence $cs_version_major.$y"],
  [# Stable version search sequence
  y=`expr $cs_version_minor + 2`
  cs_version_sequence="$cs_version_sequence $cs_version_major.$y"
  y=`expr $cs_version_minor + 1`
  cs_version_sequence="$cs_version_sequence $cs_version_major.$y"])

for test_version in $cs_version_sequence; do
  cs_path_X_Y=''
  test_version_major=`echo $test_version | sed "s/$sed_expr_base/\1/"`
  test_version_minor=`echo $test_version | sed "s/$sed_expr_base/\2/"`
  CRYSTAL_X_Y=$(sh -c "echo \$CRYSTAL_`echo ${test_version_major}_${test_version_minor}`")
  AS_IF([test -n "$CRYSTAL_X_Y"],
      [my_IFS=$IFS; IFS=$PATH_SEPARATOR
      for cs_dir in $CRYSTAL_X_Y; do
	  AS_IF([test -n "$cs_path_X_Y"], [cs_path_X_Y="$cs_path_X_Y$PATH_SEPARATOR"])
	  cs_path_X_Y="$cs_path_X_Y$cs_dir$PATH_SEPARATOR$cs_dir/bin"
      done
      IFS=$my_IFS])
  AC_PATH_TOOL([CRYSTAL_CONFIG_TOOL], [cs-config-$test_version], [], 
      [$cs_path_X_Y$PATH_SEPARATOR$cs_path])
  AS_IF([test -n "$CRYSTAL_CONFIG_TOOL"],
    [break])
done
# Legacy: CS 1.0 used a bare-named cs-config
AS_IF([test -z "$CRYSTAL_CONFIG_TOOL"],
  [AC_PATH_TOOL([CRYSTAL_CONFIG_TOOL], [cs-config], [], [$cs_path])])

AS_IF([test -n "$CRYSTAL_CONFIG_TOOL"],
    [cfg="$CRYSTAL_CONFIG_TOOL"

    # Still do cs-config version check - this one will also take the release
    # component into account. Also needed for legacy cs-config.
    CS_CHECK_PROG_VERSION([Crystal Space], ["$cfg" --version],
	m4_default([$1],[cs_min_version_default]), [9.9|.9],
	[cs_sdk=yes], [cs_sdk=no])

    AS_IF([test $cs_sdk = yes],
	[cs_liblist="$4"
	cs_optlibs=CS_TRIM([$5])
	AS_IF([test -n "$cs_optlibs"],
	    [cs_optlibs=`"$cfg" --available-libs $cs_optlibs`
	    cs_liblist="$cs_liblist $cs_optlibs"])
	CRYSTAL_VERSION=`"$cfg" --version $cs_liblist`
	CRYSTAL_CFLAGS=CS_RUN_PATH_NORMALIZE(["$cfg" --cxxflags $cs_liblist])
	CRYSTAL_LIBS=CS_RUN_PATH_NORMALIZE(["$cfg" --libs $cs_liblist])
	CRYSTAL_INCLUDE_DIR=CS_RUN_PATH_NORMALIZE(
	    ["$cfg" --includedir $cs_liblist])
	CRYSTAL_AVAILABLE_LIBS=`"$cfg" --available-libs`
	CRYSTAL_STATICDEPS=`"$cfg" --static-deps`
	CRYSTAL_PREFIX=CS_RUN_PATH_NORMALIZE(["$cfg" --prefix])
	CRYSTAL_EXEC_PREFIX=CS_RUN_PATH_NORMALIZE(["$cfg" --exec-prefix])
	CRYSTAL_TOOLS_PREFIX=CS_RUN_PATH_NORMALIZE(["$cfg" --tools-prefix])
	AS_IF([test -z "$CRYSTAL_LIBS"], [cs_sdk=no])])],
    [cs_sdk=no])

AS_IF([test "$cs_sdk" = yes && test "$enable_cstest" = yes],
    [CS_CHECK_BUILD([if Crystal Space SDK is usable], [cs_cv_crystal_sdk],
	[AC_LANG_PROGRAM(
	    [#include <cssysdef.h>
	    #include <csutil/csstring.h>
	    csStaticVarCleanupFN csStaticVarCleanup;],
	    [csString s; s << "Crystal Space";])],
	[CS_CREATE_TUPLE([$CRYSTAL_CFLAGS],[],[$CRYSTAL_LIBS])], [C++],
	[], [cs_sdk=no])])

AS_IF([test "$cs_sdk" = yes],
   [CRYSTAL_AVAILABLE=yes
   $2],
   [CRYSTAL_AVAILABLE=no
   CRYSTAL_CFLAGS=''
   CRYSTAL_VERSION=''
   CRYSTAL_LIBS=''
   CRYSTAL_INCLUDE_DIR=''
   CRYSTAL_PREFIX=''
   CRYSTAL_EXEC_PREFIX=''
   CRYSTAL_TOOLS_PREFIX=''
   $3])
])


#------------------------------------------------------------------------------
# CS_PATH_CRYSTAL_HELPER([MINIMUM-VERSION], [ACTION-IF-FOUND],
#                        [ACTION-IF-NOT-FOUND], [REQUIRED-LIBS],
#                        [OPTIONAL-LIBS])
#	Deprecated: Backward compatibility wrapper for CS_PATH_CRYSTAL_CHECK().
#------------------------------------------------------------------------------
AC_DEFUN([CS_PATH_CRYSTAL_HELPER],
[CS_PATH_CRYSTAL_CHECK([$1],[$2],[$3],[$4],[$5])])


#------------------------------------------------------------------------------
# CS_PATH_CRYSTAL([MINIMUM-VERSION], [ACTION-IF-FOUND], [ACTION-IF-NOT-FOUND],
#                 [REQUIRED-LIBS], [OPTIONAL-LIBS])
#	Convenience wrapper for CS_PATH_CRYSTAL_CHECK() which also invokes
#	AC_SUBST() for CRYSTAL_AVAILABLE, CRYSTAL_VERSION, CRYSTAL_CFLAGS,
#	CRYSTAL_LIBS, CRYSTAL_INCLUDE_DIR, and CRYSTAL_AVAILABLE_LIBS.
#------------------------------------------------------------------------------
AC_DEFUN([CS_PATH_CRYSTAL],
[CS_PATH_CRYSTAL_CHECK([$1],[$2],[$3],[$4],[$5])
AC_SUBST([CRYSTAL_AVAILABLE])
AC_SUBST([CRYSTAL_VERSION])
AC_SUBST([CRYSTAL_CFLAGS])
AC_SUBST([CRYSTAL_LIBS])
AC_SUBST([CRYSTAL_INCLUDE_DIR])
AC_SUBST([CRYSTAL_AVAILABLE_LIBS])
AC_SUBST([CRYSTAL_STATICDEPS])
AC_SUBST([CRYSTAL_PREFIX])
AC_SUBST([CRYSTAL_EXEC_PREFIX])])
AC_SUBST([CRYSTAL_TOOLS_PREFIX])])


#------------------------------------------------------------------------------
# CS_PATH_CRYSTAL_EMIT([MINIMUM-VERSION], [ACTION-IF-FOUND],
#                      [ACTION-IF-NOT-FOUND], [REQUIRED-LIBS], [OPTIONAL-LIBS],
#                      [EMITTER])
#	Convenience wrapper for CS_PATH_CRYSTAL_CHECK() which also emits
#	CRYSTAL_AVAILABLE, CRYSTAL_VERSION, CRYSTAL_CFLAGS, CRYSTAL_LIBS,
#	CRYSTAL_INCLUDE_DIR, and CRYSTAL_AVAILABLE_LIBS as the build properties
#	CRYSTAL.AVAILABLE, CRYSTAL.VERSION, CRYSTAL.CFLAGS, CRYSTAL.LIBS,
#	CRYSTAL.INCLUDE_DIR, and CRYSTAL.AVAILABLE_LIBS, respectively, using
#	EMITTER.  EMITTER is a macro name, such as CS_JAMCONFIG_PROPERTY or
#	CS_MAKEFILE_PROPERTY, which performs the actual task of emitting the
#	property and value. If EMITTER is omitted, then
#	CS_EMIT_BUILD_PROPERTY()'s default emitter is used.
#------------------------------------------------------------------------------
AC_DEFUN([CS_PATH_CRYSTAL_EMIT],
[CS_PATH_CRYSTAL_CHECK([$1],[$2],[$3],[$4],[$5])
_CS_PATH_CRYSTAL_EMIT([CRYSTAL.AVAILABLE],[$CRYSTAL_AVAILABLE],[$6])
_CS_PATH_CRYSTAL_EMIT([CRYSTAL.VERSION],[$CRYSTAL_VERSION],[$6])
_CS_PATH_CRYSTAL_EMIT([CRYSTAL.CFLAGS],[$CRYSTAL_CFLAGS],[$6])
_CS_PATH_CRYSTAL_EMIT([CRYSTAL.LFLAGS],[$CRYSTAL_LIBS],[$6])
_CS_PATH_CRYSTAL_EMIT([CRYSTAL.INCLUDE_DIR],[$CRYSTAL_INCLUDE_DIR],[$6])
_CS_PATH_CRYSTAL_EMIT([CRYSTAL.AVAILABLE_LIBS],[$CRYSTAL_AVAILABLE_LIBS],[$6])
_CS_PATH_CRYSTAL_EMIT([CRYSTAL.STATICDEPS],[$CRYSTAL_STATICDEPS],[$6])
_CS_PATH_CRYSTAL_EMIT([CRYSTAL.EXEC_PREFIX],[$CRYSTAL_EXEC_PREFIX],[$6])
_CS_PATH_CRYSTAL_EMIT([CRYSTAL.TOOLS_PREFIX],[$CRYSTAL_TOOLS_PREFIX],[$6])
])

AC_DEFUN([_CS_PATH_CRYSTAL_EMIT],
[CS_EMIT_BUILD_PROPERTY([$1],[$2],[],[],[$3])])


#------------------------------------------------------------------------------
# CS_PATH_CRYSTAL_JAM([MINIMUM-VERSION], [ACTION-IF-FOUND],
#                     [ACTION-IF-NOT-FOUND], [REQUIRED-LIBS], [OPTIONAL-LIBS])
#	Deprecated: Jam-specific backward compatibility wrapper for
#	CS_PATH_CRYSTAL_EMIT().
#------------------------------------------------------------------------------
AC_DEFUN([CS_PATH_CRYSTAL_JAM],
[CS_PATH_CRYSTAL_EMIT([$1],[$2],[$3],[$4],[$5],[CS_JAMCONFIG_PROPERTY])])
