.align
.globl start_block
start_block:
.word 0xFFFFDED3 // PICOBIN_BLOCK_MARKER_START
.word 0x10210142 ;#@ IMAGE_DEF item
.word 0x000001FF // 
.word end_block - start_block
.word 0xAB123579 // PICOBIN_BLOCK_MARKER_END
