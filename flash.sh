# tty.usbserial-ABSCDJ3S should be given by typign ls /dev | grep usb
# UART_DEVICE = /dev/tty.usbserial-0001
# Send the magic number through UART.
# minicom --8bit -b 115200 -w -o -D /dev/tty.usbserial-ABSCDJ3S -S minicom.script

# https://stackoverflow.com/questions/55047727/how-to-exit-minicom-via-scripting
( echo -ne "\x01x\r" ) | minicom --8bit -b 115200 -w -o -D /dev/tty.usbserial-0001 -S minicom.script

# Build the project
make

# Create uf2 file
./makeuf2 rp235x_main.bin rp235x_main.uf2 arm sram

# Try to detect rp2350 as a mass storage device

if test -d /Volumes/rp2350; then
    echo "Found the device. Flashing..."
else
    for I in in $(seq 1 2000); 
    do
        if test -d /Volumes/rp2350; then
            echo "Found the device. Flashing..."
            break # found the device       	    
        else
            diskutil mountDisk /dev/disk4  > /dev/null 2>&1
        fi
    done
fi

# Copy the uf2 file over USB
cp rp235x_main.uf2 /Volumes/rp2350/ # Rebooting the chip is always faster than diskutil... no way to suppress the annoying macos error for now :(
killall NotificationCenter # Suppress MacOS complaining about not 'ejecting' the device properly





