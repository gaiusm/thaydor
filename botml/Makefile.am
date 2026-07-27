SUFFIXES = .c .mod .def .d .o

DEPFLAGS=-MMD -MT $@ -MP -MF .deps/$*.d

M2DEPS = \
       AI.o \
       Bot.o \
       LoadCheckpoint.o \
       colors.o \
       Options.o

DEPS = $(M2DEPS) \
       SocketControl.o

# OPT=-O0 -fm2-g -g -flto
OPT=-O0
CHECK=-fsoft-check-all
DEBUG=-fm2-g -g -Wuninit-variable-checking
M2FLAGS=$(OPT) $(CHECK) $(DEBUG) -fextended-opaque -fgen-module-list=-

bin_PROGRAMS = botml
botml_SOURCES = \
       AI.mod \
       Bot.mod \
       colors.mod \
       LoadCheckpoint.mod \
       SocketControl.c \
       Options.mod

botml_LDADD = SocketControl.o

botml$(EXEEXT): $(DEPS)
	gm2 $(M2FLAGS) -I. -I$(srcdir) $(srcdir)/botml.mod $(DEPS) -o $@

.deps:
	mkdir -p $@

%.o: %.mod .deps/%.d
	echo $(DEPFILES)
	test -z .deps || mkdir -p .deps
	gm2 $(DEPFLAGS) $(M2FLAGS) -I. -I$(srcdir) -c $<

.c.o:
	test -z .deps || mkdir -p .deps
	gcc $(DEPFLAGS) -c -O0 -g $<

DEPFILES=$(botml_SOURCES:%.mod=.deps/%.d)

$(DEPFILES):
	echo "Value of DEPFILES = $(DEPFILES)"

include $(wildcard $(DEPFILES))
