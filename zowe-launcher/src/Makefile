################################################################################
#  This program and the accompanying materials are
#  made available under the terms of the Eclipse Public License v2.0 which accompanies
#  this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html
#
#  SPDX-License-Identifier: EPL-2.0
#
#  Copyright Contributors to the Zowe Project.
################################################################################

# environment
CC = xlclang
LD = xlclang

LAUNCHER_TARGET = ../bin/zowe_launcher

CFLAGS = -O -D_OPEN_THREADS -D_XOPEN_SOURCE=600 \
         "-Wa,goff" -Wall -Wextra -Werror -pedantic \
         -Wno-gnu-zero-variadic-macro-arguments \
         -Wno-missing-braces \
         -Wno-missing-field-initializers \
         -Wno-unused-parameter \
         "-Wc,langlvl(EXTC99),float(HEX),agg,list(),so(),search(),lp64,xplink" \
         "-Wc,goff,xref,gonum,roconst,gonum,asm,asmlib('SYS1.MACLIB'),asmlib('CEE.SCEEMAC')" \
         -I . \

LDFLAGS =
export _C89_LSYSLIB=CEE.SCEELKEX:CEE.SCEELKED:SYS1.CSSLIB:CSF.SCSFMOD0

# C source
SRCS = main.c

OBJS = $(SRCS:%.c=%.o)

# disable built-in rules
MAKEFLAGS += --no-builtin-rules

all: $(LAUNCHER_TARGET)

$(LAUNCHER_TARGET): main.o
	mkdir -p $(dir $(LAUNCHER_TARGET))
	$(LD) $(LDFLAGS) -o $(LAUNCHER_TARGET) $^ || { $(RM) $@; exit 1; }
	cp -X $(LAUNCHER_TARGET) "//'${USER}.DEV.LOADLIB(ZLAUNCH)'"

%.o: %.c
	$(CC) $(CFLAGS) -o $@ -c $<

.PHONY: clean
clean:
	$(RM) $(LAUNCHER_TARGET)
	$(RM) $(OBJS) $(notdir $(OBJS:%.o=%.lst))

