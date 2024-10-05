
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define DSIZE 0x10000
unsigned int wdata[128];
unsigned char data[DSIZE<<1];

FILE *fp;

void usage ( void )
{
    printf("makeuf2 inputfile.bin outputfile.elf sram/flash arm/risc-v\n");
}

int main ( int argc, char *argv[] )
{
    unsigned int len;
    unsigned int ra;
    unsigned int rb;
    unsigned int blocks;
    unsigned int nblock;
    unsigned int add;
    unsigned int doff;
    unsigned int magic;

    if(argc<5)
    {
        usage();
        return(1);
    }

    if(strcmp(argv[3],"arm")==0) magic=0xE48BFF59; //ARM
    else
    if(strcmp(argv[3],"riscv")==0) magic=0xE48BFF5A; //RISCV
    else
    return(1);

    //if(strcmp(argv[4],"sram")==0) add=0x20000000; //SRAM
    if(strcmp(argv[4],"sram")==0) add=0x20080000; //SRAM 1st 4K bank
    else
    if(strcmp(argv[4],"flash")==0) add=0x10000000; //FLASH
    else
    return(1);

    fp=fopen(argv[1],"rb");
    if(fp==NULL)
    {
        printf("Error opening file [%s]\n",argv[1]);
        return(1);
    }
    memset(data,0x00,sizeof(data));
    len=fread(data,1,sizeof(data),fp);
    fclose(fp);
    printf("%u bytes read\n",len);
    if(len>DSIZE)
    {
        printf("too big\n");
        return(1);
    }
    if(len==0)
    {
        printf("too small\n");
        return(1);
    }
    blocks=(len+0xFF)>>8;
    printf("blocks 0x%X (0x%X)\n",blocks,len);

    fp=fopen(argv[2],"wb");
    if(fp==NULL)
    {
        printf("Error creating file [%s]\n",argv[2]);
        return(1);
    }

    //what is this for?  Do I need it?
    memset(wdata,0x00,sizeof(wdata));
    wdata[0] = 0x0A324655;
    wdata[1] = 0x9E5D5157;
    wdata[2] = 0x00002000;
    wdata[3] = 0x10FFFF00;
    wdata[4] = 0x00000100;
    wdata[5] = 0x00000000;
    wdata[6] = 0x00000002;
    wdata[7] = 0xE48BFF57;
    for(ra=8;ra<72;ra++)
    {
        wdata[ra] = 0xEFEFEFEF;
    }
    wdata[127]=0x0AB16F30;
    fwrite(wdata,1,sizeof(wdata),fp);

    doff=0;
    for(nblock=0;nblock<blocks;nblock++)
    {
        memset(wdata,0x00,sizeof(wdata));
        wdata[0]=0x0A324655;
        wdata[1]=0x9E5D5157;
        wdata[2]=0x00002000;
        wdata[3]=add;
        wdata[4]=0x00000100;
        wdata[5]=nblock;
        wdata[6]=blocks;
        wdata[7]=magic;
        memcpy(&wdata[8],&data[doff],256);
        wdata[127]=0x0AB16F30;
        fwrite(wdata,1,sizeof(wdata),fp);
        add+=0x100;
        doff+=0x100;
    }

    fclose(fp);
    return(0);
}

//-------------------------------------------------------------------------
//
// Copyright (c) 2024 David Welch dwelch@dwelch.com
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
//-------------------------------------------------------------------------


