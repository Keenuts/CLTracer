LIBS=OpenCL
VPATH=src

LDFLAGS=
LDLIBS=`pkg-config --libs ${LIBS}`
CXXFLAGS=-Wall -Wextra -Werror $(pkg-config --cflags $(LIBS)) -g -DOUTPUT

OBJ=main.o lodepng.o app.o

main: $(OBJ)
	$(CXX) $^ $(LDLIBS) -o $@

all: main

clean:
	$(RM) main $(OBJ) output.png
