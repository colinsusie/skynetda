PLAT ?= none
PLATS = linux macosx

.PHONY: $(PLATS) clean cleanall lua cjson

none:
	@echo "usage: make <PLAT>"
	@echo "  PLAT is one of: $(PLATS)"

$(PLATS):
	$(MAKE) all PLAT=$@

CC= gcc
IPATH= -I3rd/lua/src
LPATH= -L3rd/lua/src

ifeq ($(PLAT), macosx)
MYFLAGS := -std=gnu99 -O2 -Wall $(IPATH) 
else
MYFLAGS := -std=gnu99 -O2 -Wall -Wl,-E $(IPATH) 
endif

LIBS= -ldl -lm -llua $(LPATH)
HEADER = $(wildcard src/*.h)
SRCS= $(wildcard src/*.c)
BINROOT= vscext/bin/$(PLAT)
PROG= $(BINROOT)/skynetda

all: lua cjson $(PROG)
	
lua: 
	$(MAKE) -C 3rd/lua $(PLAT)

cjson:
	$(MAKE) -C 3rd/lua-cjson install PLAT=$(PLAT)

$(PROG): $(SRCS) $(HEADER)
	$(CC) $(MYFLAGS) -o $@ $(SRCS) $(LIBS)

clean:
	rm -f vscext/bin/linux/skynetda
	rm -f vscext/bin/macosx/skynetda

cleanall: clean
	$(MAKE) -C 3rd/lua clean
	$(MAKE) -C 3rd/lua-cjson clean
	rm -f vscext/bin/linux/*.so
	rm -f vscext/bin/macosx/*.so