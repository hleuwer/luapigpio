WRAPPER=pigpio_wrap.c
EOBJS=../pigpio.o ../command.o
WOBJS=$(WRAPPER:.c=.o) pigpio_util.o
OBJS = $(EOBJS) $(WOBJS)
CFLAGS=-O -c -fpic
LDFLAGS=-O -shared
LIBS=-lpthread
LUAV=5.2
INC=-I/usr/include/lua$(LUAV) -I..
LIBDIR=-L/usr/local/lib
IFILE=pigpio.i
TARGET=lgpio.so
LUALIBDIR=/usr/local/lib/lua/$(LUAV)

.SUFFIXES: .c .o

.c.o:
	gcc $(CFLAGS) $(INC) -o $@ $<

$(TARGET): $(OBJS)
	gcc $(LDFLAGS) $(LIBDIR) $(LIBS) -o $(TARGET) $(OBJS)

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
