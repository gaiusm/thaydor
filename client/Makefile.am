SUFFIXES = .c .mod .def .d .o

DEPFLAGS=-MMD -MT $@ -MP -MF .deps/$*.d

M2DEPS = \
       color.o \
       Client.o \
       FunctionKey.o \
       Options.o \
       UTF8.o \
       Screen.o

DEPS = $(M2DEPS) \
       SocketControl.o

OPT=-O0
CHECK=-fsoft-check-all
DEBUG=-fm2-g -g -Wuninit-variable-checking
M2FLAGS=$(OPT) $(CHECK) $(DEBUG) -fextended-opaque -fgen-module-list=-

bin_PROGRAMS = thaydor
thaydor_SOURCES = \
       color.mod \
       Client.mod \
       FunctionKey.mod \
       Options.mod \
       UTF8.mod \
       Screen.mod \
       SocketControl.c

thaydor_LDADD = SocketControl.o

thaydor$(EXEEXT): $(DEPS)
	gm2 $(M2FLAGS) -I. -I$(srcdir) $(srcdir)/Thaydor.mod $(DEPS) -o $@

.deps:
	mkdir -p $@

%.o: %.mod .deps/%.d
	echo $(DEPFILES)
	test -z .deps || mkdir -p .deps
	gm2 $(DEPFLAGS) $(M2FLAGS) -I. -I$(srcdir) -c $<

.c.o:
	test -z .deps || mkdir -p .deps
	gcc $(DEPFLAGS) -c -O0 -g $<

DEPFILES=$(thaydor_SOURCES:%.mod=.deps/%.d)

$(DEPFILES):
	echo "Value of DEPFILES = $(DEPFILES)"

include $(wildcard $(DEPFILES))
