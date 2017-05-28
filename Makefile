CXXFLAGS=-Wall -Wextra -Werror `pkg-config --cflags $(LIBS)`

LIBS=OpenCL
LDLIBS=`pkg-config --libs $(LIBS)`

VPATH=src

OBJ=main.o lodepng.o app.o

main: $(OBJ)
	$(CXX) $(LDFLAGS) $^ $(LDLIBS) -o $@

all: main

clean:
	$(RM) main $(OBJ) output.png
