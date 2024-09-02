COMPILER = clang 
ARCHITECTURE = -arch arm64 # check this VS -march armv8+simd
MAKEFLAGS += --silent

VPU_ASSEMBLER = ../tools/vasm/vasmvidcore_std
VPU_DISASSEMBLER = ../tools/vasm_bad/vobjdump

MAIN_CODE_PATH = ../code
MACOS_BUILD_PATH = ../build
MACOS_APP_NAME = rpi_debugger.app
MACOS_EXE_PATH = $(MACOS_BUILD_PATH)/$(MACOS_APP_NAME)/Contents/MacOS
MACOS_RESOURCE_PATH = $(MACOS_BUILD_PATH)/$(MACOS_APP_NAME)/Contents/Resources
MACOS_FRAMEWORK = -framework Cocoa -framework CoreFoundation -framework IOKit 

# -O0 = unoptimized, -O2 = compiler optimized
COMPILER_FLAGS = -g -Wall -O0 -pthread -D RPID_DEBUG=1 -D RPID_SLOW=1 -D RPID_ARM=1 -D RPID_X86_X64=0 -D RPID_LLVM=1 -D RPID_MSVC=0 -D RPID_MACOS=1 -D RPID_LINUX=0 -D RPID_VULKAN=0 -D RPID_METAL=1

# prefix the name of the warning with 'no-' to disable certain warning
COMPILER_IGNORE_WARNINGS = -Wno-unused-variable -Wno-unused-function -Wno-deprecated-declarations -Wno-writable-strings -Wno-switch -Wno-objc-missing-super-calls -Wno-missing-braces -Wnonportable-include-path -Wno-uninitialized -Wno-nonportable-include-path -Wno-tautological-bitwise-compare -Wno-unused-but-set-variable -Wno-nullability-completeness

all : make_directory compile_main cleanup

make_directory : 
	mkdir -p $(MACOS_BUILD_PATH)

compile_main : $(MAIN_CODE_PATH)/macos_rpid.mm
	$(COMPILER) $(ARCHITECTURE) $(COMPILER_FLAGS) $(COMPILER_IGNORE_WARNINGS) $(MACOS_FRAMEWORK) -o $(MACOS_BUILD_PATH)/rp_boot $(MAIN_CODE_PATH)/macos_rpid.mm 

#clean all the object files.
cleanup : 
	 rm -rf *.o 
