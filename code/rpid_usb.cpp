#include "rpid_usb.h"

// returns 16-byte command status from the PICOBOOT interface
internal void
macos_get_usb_command_status(RPUSBInterface *usb_interface, u32 *read_buffer)
{
    IOUSBInterfaceInterface **macos_usb_interface = usb_interface->macos_usb_interface;
    IOUSBDevRequestTO command_packet = {};
    command_packet.bmRequestType = 0b11000001; // request status from USB interface
    command_packet.bRequest = 0x42;
    command_packet.wValue = 0;
    command_packet.wIndex = 1; // in this case, index of the interface
    command_packet.wLength = 16; // always 16 bytes
    command_packet.pData = (void *)read_buffer;
    command_packet.noDataTimeout = 300;
    command_packet.completionTimeout = 500;

    IOReturn r = (*macos_usb_interface)->ControlRequestTO(macos_usb_interface, 0, &command_packet);
    assert(r == kIOReturnSuccess);
    assert(command_packet.wLenDone == 16);
}

internal b32
macos_bulk_transfer_out(RPUSBInterface *usb_interface, void *buffer, u32 byte_count)
{
    b32 result = false;
    IOUSBInterfaceInterface **macos_usb_interface = usb_interface->macos_usb_interface;

    u64 start_ns = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
    while(!result)
    {
        IOReturn kr = (*macos_usb_interface)->WritePipeTO(macos_usb_interface, usb_interface->bulk_out_endpoint_index, buffer, byte_count, 100, 200);

        if(kr == kIOReturnSuccess)
        {
            result = true;
            break;
        }
        else
        {
            u32 read_buffer[4];
            macos_get_usb_command_status(usb_interface, read_buffer);

            // TODO(gh) log, clear the pipe and retry
            assert(0);
        }

        u64 end_ns = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
        u64 time_passed_ms = (((end_ns - start_ns) / 1000000));
        if(time_passed_ms > 100) 
        {
            // TODO(gh) log
            printf("Error : Could not do bulk write for %llums, aborting... \n", time_passed_ms);
            assert(0);
            break;
        }
    }

    return result;
}


// mostly used to let the RP2040/2350 know that the write has been finished
internal void
macos_bulk_transfer_in_zero(RPUSBInterface *usb_interface)
{
    u8 read_buffer[1];
    u32 bytes_read = 1;
    IOReturn kr = (*usb_interface->macos_usb_interface)->ReadPipeTO(usb_interface->macos_usb_interface, usb_interface->bulk_in_endpoint_index, read_buffer, &bytes_read, 10, 10);
    assert(bytes_read == 0);
}

internal void
macos_bulk_transfer_out_zero(RPUSBInterface *usb_interface)
{
    u8 write_buffer[0];
    IOReturn kr = (*usb_interface->macos_usb_interface)->WritePipeTO(usb_interface->macos_usb_interface, usb_interface->bulk_out_endpoint_index, write_buffer, 1, 100, 200);
}

internal void
macos_wait_for_command_complete(RPUSBInterface *usb_interface)
{
    do
    {
        u32 read_buffer[4] = {};
        macos_get_usb_command_status(usb_interface, read_buffer);
        
        if((read_buffer[1] == 0) && 
            ((read_buffer[2] >> 8) == 0))
        {
            break;
        }
    } while(1);
}

internal b32
macos_read_from_rp(RPUSBInterface *usb_interface, u32 address, void *read_buffer, u32 bytes_to_read, u32 token = 0xdcdcdcdc)
{
    b32 result = false;

    u64 start_ns = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
    while(!result)
    {
        // write the 'read command' to the bulk out endpoint
        PicoBootCommand read_command = {};
        read_command.magic = PICOBOOT_COMMAND_MAGIC_VALUE;
        read_command.token = token;
        read_command.command_ID = PicoBootCommand_READ;
        read_command.command_size = 0x08;
        read_command.pad0 = 0;
        read_command.transfer_length = bytes_to_read;
        read_command.args0 = address; // address
        read_command.args1 = bytes_to_read;
        read_command.args2 = 0;
        read_command.args3 = 0;
        // assert(sizeof(PicoBootCommand) == 32);

        if(macos_bulk_transfer_out(usb_interface, &read_command, sizeof(PicoBootCommand)))
        {
            // macos_wait_for_command_complete(usb_interface);
            IOUSBInterfaceInterface **macos_usb_interface = usb_interface->macos_usb_interface;
            u32 bytes_read = bytes_to_read;

            IOReturn kr = (*macos_usb_interface)->ReadPipeTO(macos_usb_interface, usb_interface->bulk_in_endpoint_index, read_buffer, &bytes_read, 100, 100);
            if(kr == kIOReturnSuccess)
            {
                result = true;
                break;
            }
        }

#if 0
        u64 end_ns = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
        u64 time_passed_ms = (((end_ns - start_ns) / 1000000));
        if(time_passed_ms > 100) 
        {
            // TODO(gh) log
            printf("Error : Couldn't do bulk read for %llums, aborting... \n", time_passed_ms);
            assert(0);
            break;
        }
#endif 
    }

    macos_wait_for_command_complete(usb_interface);
    macos_bulk_transfer_out_zero(usb_interface); // finish the command sequence

    return result;
}

internal void
macos_write_to_rp(RPUSBInterface *usb_interface, u32 address, void *source, u32 bytes_to_write, u32 token = 0xcdcdcdcd)
{
    PicoBootCommand write_command = {};
    write_command.magic = PICOBOOT_COMMAND_MAGIC_VALUE;
    write_command.token = token;
    write_command.command_ID = 0x5;
    write_command.command_size = 0x08;
    write_command.pad0 = 0;
    write_command.transfer_length = bytes_to_write;
    write_command.args0 = address;
    write_command.args1 = bytes_to_write;
    write_command.args2 = 0;
    write_command.args3 = 0;

    macos_bulk_transfer_out(usb_interface, &write_command, sizeof(PicoBootCommand)); // write out the command
    macos_bulk_transfer_out(usb_interface, source, bytes_to_write); // write out the data bytes
    macos_wait_for_command_complete(usb_interface);
    macos_bulk_transfer_in_zero(usb_interface); // end the command sequence
}

internal void
macos_verify_write_to_rp(RPUSBInterface *usb_interface, u32 address, void *buffer_to_compare, u32 size)
{
    TempMemory temp_memory = start_temp_memory(&usb_interface->arena, size, false);

    macos_read_from_rp(usb_interface, address, temp_memory.base, size);
    if(memcmp(temp_memory.base, buffer_to_compare, size) != 0)
    {
        // TODO(gh) log
        printf("Error : Content stored in RP is different from source.\n");
        assert(0);
    }

    end_temp_memory(&temp_memory);
}


