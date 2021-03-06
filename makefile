WRAPPER=pigpio_wrap.c
EOBJS=../pigpio.o ../command.o
WOBJS=$(WRAPPER:.c=.o) pigpio_util.o
#OBJS = $(EOBJS) $(WOBJS)
OBJS = $(WOBJS)
CFLAGS= -ggdb -Wall -c -fpic
LDFLAGS= -shared
LIBS=-lpigpio -lpthread
LUAV=5.2
INC=-I/usr/include/lua$(LUAV) -I..
LIBDIR=-L/usr/local/lib 
IFILE=pigpio.i
TARGET=pigpio/core.so
LUALIBDIR=/usr/local/lib/lua/$(LUAV)

.SUFFIXES: .c .o

.c.o: pigpio
	gcc $(CFLAGS) $(INC) -o $@ $<

$(TARGET): $(OBJS)
	mkdir -p pigpio && gcc $(LDFLAGS) $(OBJS) $(LIBDIR) $(LIBS) -o $(TARGET)

$(WRAPPER:.c=.o): $(WRAPPER)

$(WRAPPER): $(IFILE)
	swig -lua $(IFILE)

clean:
	rm -f $(TARGET) $(WOBJS)
	rm -f `find . -name "*~"`
uclean:
	$(MAKE) clean
	rm -f $(WRAPPER)

install:
	mkdir -p $(LUALIBDIR) && cp -f $(TARGET) $(LUALIBDIR)

uninstall:
	rm -rf $(LUALIBDIR)/$(TARGET)

pigpio_util.o: pigpio_util.c pigpio_util.h
