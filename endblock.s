.align
.globl end_block
end_block:
.word 0xFFFFDED3
.word 0x000001FE
.word 0x000001FF
.word start_block - end_block
.word 0xAB123579
