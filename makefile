FILE = teste4

all:
	nasm $(FILE).asm -fbin -o $(FILE).com

clean:
	rm -f $(FILE).com

tj:
	nasm telejogo.asm -fbin -o telejogo.com
