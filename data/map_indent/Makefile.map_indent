#

map_indent: map_indent.yy.cc map_indent.yy.o
	g++ -o map_indent map_indent.yy.o -lfl; rm map_indent.yy.*

map_indent.yy.cc:
	flex -omap_indent.yy.cc map_indent.yy

clean: 
	rm map_indent; rm map_indent.yy.cc
