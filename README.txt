- 'bash flash.sh' to restart the chip and copy over the new uf2 file.

Couple of things that you need to check : 
  - Change /dev/tty.usbserial-0001 to something else based on the uart cable you're using.
    You can find it by typing 'ls /dev | grep usb' inside the terminal.
  - flash.sh runs 'make' during the sequence, so make sure to update the GCC toolchain path(GCC_PATH) in 'makefile'
