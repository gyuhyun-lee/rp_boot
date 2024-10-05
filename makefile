#NOTE(gh) add appropriate path to the arm gnu toolchain if you haven't added the path to system path.
GCC_PATH = /Applications/ArmGNUToolchain/13.2.Rel1/arm-none-eabi/bin/
MAKEFLAGS += --silent
TARGET_CPU = -mcpu=cortex-m33 -mthumb 

ASSEMBLER_FLAGS = $(TARGET_CPU)
COMPILER_FLAGS =  $(TARGET_CPU) -Wall -Wextra -O2 -std=c99 -nostdlib -nostartfiles -ffreestanding -fno-common -ggdb -g0 -c
LINKER_FLAGS = -nostdlib #-nostart_armfiles
DISASM_FLAGS = -d --source-comment=// -r 

SDCARD_PATH = /Volumes/rp2350/

all : clean compile link makeuf2

clean:
	rm -f *.bin
	rm -f *.o
	# rm -f *.elf
	rm -f *.disasm
	# rm -f *.list

compile : 
	$(GCC_PATH)arm-none-eabi-as $(ASSEMBLER_FLAGS) vector_table.s -o vector_table.o
	$(GCC_PATH)arm-none-eabi-as $(ASSEMBLER_FLAGS) startblock.s -o startblock.o
	$(GCC_PATH)arm-none-eabi-as $(ASSEMBLER_FLAGS) endblock.s -o endblock.o
	$(GCC_PATH)arm-none-eabi-gcc $(COMPILER_FLAGS) rp235x_main.S -o rp235x_main.o

link : 
	$(GCC_PATH)arm-none-eabi-ld $(LINKER_FLAGS) -T memorymap.ld vector_table.o startblock.o rp235x_main.o endblock.o -o rp235x_main.elf
	$(GCC_PATH)arm-none-eabi-objdump -D rp235x_main.elf > rp235x_main.list
	$(GCC_PATH)arm-none-eabi-objcopy -O binary rp235x_main.elf rp235x_main.bin

makeuf2 : makeuf2.c
	gcc -O2 makeuf2.c -o makeuf2

