#include <stdio.h>
#import <Cocoa/Cocoa.h> 
#import <stdio.h> // printf for debugging purpose
#import <sys/stat.h>
// USB
#import <IOKit/IOKitLib.h>
#import <IOKit/usb/IOUsbLib.h>
#import <IOKit/IOCFPlugIn.h>
#import <pthread.h>

// need to undef these from the macos framework 
// so that we can define these ourselves
#undef internal
#undef assert

#define assert(expression) if(!(expression)) {int *a = 0; *a = 0;}
#define PRINT_ERROR_AND_EXIT(...) {usb_interface->should_exit = true;printf(__VA_ARGS__); goto ERROR_EXIT;}

#include <stdint.h>
#include <float.h>

typedef int8_t i8;
typedef int16_t i16;
typedef int32_t i32;
typedef int64_t i64;
typedef int32_t b32;

typedef uint8_t u8; 
typedef uint16_t u16; 
typedef uint32_t u32;
typedef uint64_t u64;

typedef uintptr_t uintptr;

typedef float f32;
typedef float f32;
typedef double f64;

#define internal static

struct MemoryArena
{
    void *base;
    size_t total_size;
    size_t used;

    u32 temp_memory_count;
};

internal MemoryArena
start_memory_arena(void *base, size_t size, b32 should_be_zero = true)
{
    MemoryArena result = {};

    result.base = (u8 *)base;
    result.total_size = size;

    if(should_be_zero)
    {
        // zero_memory(result.base, result.total_size);
    }

    return result;
}

// NOTE(gh): Works for both platform memory(world arena) & temp memory
#define push_array(memory, type, count) (type *)push_size(memory, count * sizeof(type))
#define push_struct(memory, type) (type *)push_size(memory, sizeof(type))

// TODO(gh) : Alignment might be an issue, always take account of that
internal void *
push_size(MemoryArena *memory_arena, size_t size, b32 should_be_no_temp_memory = true, size_t alignment = 0)
{
   assert(size != 0);

    if(should_be_no_temp_memory)
    {
        assert(memory_arena->temp_memory_count == 0);
    }

    assert(memory_arena->used <= memory_arena->total_size);

    void *result = (u8 *)memory_arena->base + memory_arena->used;
    memory_arena->used += size;

    return result;
}

internal MemoryArena
start_sub_arena(MemoryArena *base_arena, size_t size, b32 should_be_zero = true)
{
    MemoryArena result = {};

    result.base = (u8 *)push_size(base_arena, size, should_be_zero);
    result.total_size = size;

    return result;
}

struct TempMemory
{
    MemoryArena *memory_arena;

    void *base;
    size_t total_size;
    size_t used;
};

// TODO(gh) : Alignment might be an issue, always take account of that
internal void *
push_size(TempMemory *temp_memory, size_t size, size_t alignment = 0)
{
    assert(size != 0);

    void *result = (u8 *)temp_memory->base + temp_memory->used;
    temp_memory->used += size;

    assert(temp_memory->used <= temp_memory->total_size);

    return result;
}

internal TempMemory
start_temp_memory(MemoryArena *memory_arena, size_t size, b32 should_be_zero = true)
{
    TempMemory result = {};
    if(memory_arena)
    {
    result.base = (u8 *)memory_arena->base + memory_arena->used;
    result.total_size = size;
    result.memory_arena = memory_arena;

    push_size(memory_arena, size, false);

    memory_arena->temp_memory_count++;
    if(should_be_zero)
    {
        // zero_memory(result.base, result.total_size);
    }
    }

    return result;
}

internal void
end_temp_memory(TempMemory *temp_memory)
{
    MemoryArena *memory_arena = temp_memory->memory_arena;
    // NOTE(gh) : safe guard for using this temp memory after ending it 
    temp_memory->base = 0;

    memory_arena->temp_memory_count--;
    // IMPORTANT(gh) : As the nature of this, all temp memories should be cleared at once
    memory_arena->used -= temp_memory->total_size;
}

#include "rpid_usb.cpp"

struct PlatformReadFileResult
{
    u8 *memory;
    u32 size; 
};

internal PlatformReadFileResult
debug_macos_read_file(const char *filename)
{
    PlatformReadFileResult result = {};

    int File = open(filename, O_RDONLY);
    int Error = errno;
    if(File >= 0) // NOTE : If the open() succeded, the return value is non-negative value.
    {
        struct stat FileStat;
        fstat(File , &FileStat); 
        off_t fileSize = FileStat.st_size;

        if(fileSize > 0)
        {
            // TODO/gh : no more os level allocations!
            result.size = fileSize;
            result.memory = (u8 *)malloc(result.size);
            if(read(File, result.memory, result.size) == -1)
            {
                free(result.memory);
                result.size = 0;
            }
        }
        else
        {
            printf("Error : File size is 0\n");
        }

        close(File);
    }
    else
    {
        printf("Error : Could not find the file\n");
    }

    return result;
}

// TODO(gh) Seems like MacOS sometimes cache the device even though the device has been disconnected.
// so if the user plugs the device in and out and then in, OS might not call this because it already has the information 
// of the device. 
internal void 
raw_usb_device_added(void *refCon, io_iterator_t io_iter)
{
    /*
        The process of finding and communicating with a USB device is divided into two sets of steps. 

        The first set outlines how to find a USB device, 
        acquire a device interface of type IOUSBDeviceInterface for it, 
        and set or change its configuration. 

        The second set describes how to find an interface in a device, 
        acquire a device interface of type IOUSBInterfaceInterface for it, 
        and use it to communicate with that interface

        Follow this first set of steps only to set or change the configuration of a device. 
        If the device you’re interested in is already configured for your needs, skip these steps and follow the second set of steps.
        Find the IOUSBDevice object that represents the device in the I/O Registry. This includes setting up a matching dictionary with a key from the USB Common Class Specification (see Finding USB Devices and Interfaces). The sample code uses the key elements kUSBVendorName and kUSBProductName to find a particular USB device (this is the second key listed in Table 1-2).
        Create a device interface of type IOUSBDeviceInterface for the device. This device interface provides functions that perform tasks such as setting or changing the configuration of the device, getting information about the device, and resetting the device.
        Examine the device’s configurations with GetConfigurationDescriptorPtr, choose the appropriate one, and call SetConfiguration to set the device’s configuration and instantiate the IOUSBInterface objects for that configuration.

        Follow this second set of steps to find and choose an interface, acquire a device interface for it, and communicate with the device.
        Create an interface iterator to iterate over the available interfaces.
        Create a device interface for each interface so you can examine its properties and select the appropriate one. To do this, you create a device interface of type IOUSBInterfaceInterface. This device interface provides functions that perform tasks such as getting information about the interface, setting the interface’s alternate setting, and accessing its pipes.
        Use the USBInterfaceOpen function to open the selected interface. This will cause the pipes associated with the interface to be instantiated so you can examine the properties of each and select the appropriate one.
        Communicate with the device through the selected pipe. You can write to and read from the pipe synchronously or asynchronously—the sample code in Accessing a USB Device shows how to do both
     */
    RPUSBInterface *usb_interface = (RPUSBInterface *)refCon;

    io_service_t usb_device_iter = IOIteratorNext(io_iter); // returns 0 if there is no more device

    IOUSBDeviceInterface        **usb_device = 0; 
    while (usb_device_iter)
    {
        kern_return_t k_return;
        IOCFPlugInInterface         **plugin_interface = 0;
        /*
           USB Device Descriptor
            offset                  size        description
            0	    bLength	        1           Size of the Descriptor in Bytes (18 bytes)
            1	    bDescriptorType	1           Device Descriptor (0x01)
            2	    bcdUSB          2           USB Specification Number which device complies too.
            4	    bDeviceClass	1	        If equal to Zero, each interface specifies it’s own class code. 
                                                If equal to 0xFF, the class code is vendor specified.
                                                Otherwise field is valid Class Code.
            5	bDeviceSubClass	    1		    Subclass Code (Assigned by USB Org)
            6	bDeviceProtocol	    1		    Protocol Code (Assigned by USB Org)
            7	bMaxPacketSize	    1		    Maximum Packet Size for Zero Endpoint. Valid Sizes are 8, 16, 32, 64
            8	idVendor	        2	        Vendor ID (Assigned by USB Org)
            10	idProduct	        2           Product ID (Assigned by Manufacturer)
            12	bcdDevice	        2	        Device Release Number
            14	iManufacturer	    1		    Index of Manufacturer String Descriptor
            15	iProduct	        1		    Index of Product String Descriptor
            16	iSerialNumber	    1	        Index of Serial Number String Descriptor
            17	bNumConfigurations	1	        Number of Possible Configurations
         */
        i32 score;

        // create an intermediate plug-in
        // TODO(gh) this function is not documented, and seems like it's hanging the xcode(but works fine on CLion)
        IOCreatePlugInInterfaceForService(usb_device_iter,
                                          kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID,
                                          &plugin_interface, &score);
        IOObjectRelease(usb_device_iter); // don’t need the device object after intermediate plug-in is created
        if(plugin_interface)
        {
            // create the device interface
            (*plugin_interface)->QueryInterface(plugin_interface,
                                                CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID),
                                                (void **)&usb_device);

            (*plugin_interface)->Release(plugin_interface); // don’t need the intermediate plug-in after device interface is created


            if (usb_device)
            {
                // check the vendor ID and the product ID of this usb device
                u16 vendor_ID;
                u16 product_ID;
                (*usb_device)->GetDeviceVendor(usb_device, &vendor_ID);
                (*usb_device)->GetDeviceProduct(usb_device, &product_ID);

                if((vendor_ID == RP2350_VendorID) && product_ID == RP2350_ProductID)
                {
                    printf("RP2350 Found!\n");
                    if ((*usb_device)->USBDeviceOpenSeize(usb_device) != kIOReturnSuccess)
                    {
                        (*usb_device)->Release(usb_device);
                        PRINT_ERROR_AND_EXIT("Error : Unable to open the USB device with an exclusive access\n");
                    }

                    break;
                }
                else
                {
                    PRINT_ERROR_AND_EXIT("Error: Found non-RP device, this should not be possible since we setup the dictionary\n");
                    break;
                }
            }
            else
            {
                PRINT_ERROR_AND_EXIT("Error : Couldn’t create a device interface\n");
                break;
            }
        }
        else
        {
            PRINT_ERROR_AND_EXIT("Error : Unable to create a plug-in\n");
            break;
        }

        usb_device_iter = IOIteratorNext(io_iter); // returns 0 if there is no more device
    } // while(usb_device_iter)


    // configure device
    if(usb_device)
    {
        u8 config_count;
        (*usb_device)->GetNumberOfConfigurations(usb_device, &config_count);
        if(config_count == 1)
        {
            /*
               configuration descriptor 
                offset                  size        description
                0	    bLength	        1	        Size of Descriptor in Bytes 
                1	    bDescriptorType	1           Configuration Descriptor (0x02)
                2	    wTotalLength	2	        Total length in bytes of data returned
                4	    bNumInterfaces	1	        Number of Interfaces
                5	bConfigurationValue	1	        Value to use as an argument to select this configuration
                6	iConfiguration	    1		    Index of String Descriptor describing this configuration
                7	bmAttributes	    1	        D7 Reserved, set to 1. (USB 1.0 Bus Powered)
                                                    D6 Self Powered
                                                    D5 Remote Wakeup
                                                    D4..0 Reserved, set to 0.
                8	bMaxPower	        1		    Maximum Power Consumption in 2mA units
             */
            // get the first configuration descriptor 
            IOUSBConfigurationDescriptorPtr config_desc;
            if((*usb_device)->GetConfigurationDescriptorPtr(usb_device, 0, &config_desc) == kIOReturnSuccess)
            {
                // set the device’s configuration. The configuration value is found in
                // the bConfigurationValue field of the configuration descriptor
                if((*usb_device)->SetConfiguration(usb_device, config_desc->bConfigurationValue) == kIOReturnSuccess)
                {
                    // success
                    printf("Configured the usb device for the first-time\n");
                }
                else
                {
                    printf("Error : Failed to set the configuration\n");
                    assert(0);
                }
            }
            else
            {
                printf("Error : Failed to get the configuration descriptor\n");
                assert(0);
            }

            // find the bulk transfer interface of the RP2040/2350 PICOBOOT using the values that were specified in RP2040/2350 DS
            IOUSBFindInterfaceRequest request;
            request.bInterfaceClass = 0xff; // vendor specific
            request.bInterfaceSubClass = 0;
            request.bInterfaceProtocol = 0;
            request.bAlternateSetting = kIOUSBFindInterfaceDontCare;
            io_iterator_t interface_iter;
            (*usb_device)->CreateInterfaceIterator(usb_device,
                                                    &request, &interface_iter);
            io_service_t usb_interface_iter = IOIteratorNext(interface_iter);
            if(usb_interface_iter) // there should be only 1 interface, which is why this is not a while loop
            {
                //Create an intermediate plug-in
                IOCFPlugInInterface         **plugin_interface = 0;
                i32 score;
                IOCreatePlugInInterfaceForService(usb_interface_iter,
                                                kIOUSBInterfaceUserClientTypeID,
                                                kIOCFPlugInInterfaceID,
                                                &plugin_interface, &score);
                // Release the usbInterface object after getting the plug-in
                IOObjectRelease(usb_interface_iter);
                if (!plugin_interface)
                {
                    printf("Error : Unable to create a plug-in\n");
                    // TODO(gh) log
                    assert(0);
                }

                //Now create the device interface for the interface
                /*
                   interface descriptor
                    offset                  size        description
                    0	    bLength	        1	        Size of Descriptor in Bytes (9 Bytes)
                    1	    bDescriptorType	1	        Interface Descriptor (0x04)
                    2	bInterfaceNumber	1	        Number of Interface
                    3	bAlternateSetting	1	        Value used to select alternative setting
                    4	bNumEndpoints	    1	        Number of Endpoints used for this interface
                    5	bInterfaceClass	    1	        Class Code (Assigned by USB Org)
                    6	bInterfaceSubClass	1	        Subclass Code (Assigned by USB Org)
                    7	bInterfaceProtocol	1	        Protocol Code (Assigned by USB Org)
                    8	iInterface	        1	        Index of String Descriptor Describing this interface
                */
                IOUSBInterfaceInterface **macos_usb_interface = 0;
                (*plugin_interface)->QueryInterface(plugin_interface,
                                                    CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID),
                                                    (LPVOID *) &macos_usb_interface);
                // no longer need the intermediate plug-in
                (*plugin_interface)->Release(plugin_interface);
                if(macos_usb_interface)
                {
                    // double-check the class & sub-class IDs
                    u8 interface_class;
                    u8 interface_subclass;
                    u8 interface_number; // TODO(gh) This might vary, what should happen if we cannot find PICOBOOT interface?
                    u8 alternate_setting;
                    (*macos_usb_interface)->GetInterfaceClass(macos_usb_interface,
                                                        &interface_class);
                    (*macos_usb_interface)->GetInterfaceSubClass(macos_usb_interface,
                                                        &interface_subclass);
                    (*macos_usb_interface)->GetInterfaceNumber(macos_usb_interface,
                                                                &interface_number);
                    (*macos_usb_interface)->GetAlternateSetting(macos_usb_interface,
                                                                &alternate_setting);
                    assert((interface_class == 0xff) && (interface_subclass == 0));
                    if(interface_class != 0xff)
                    {
                        PRINT_ERROR_AND_EXIT("Error : Interface class mismatch. This should be 0xff\n");
                    }

                    if(interface_subclass != 0)
                    {
                        PRINT_ERROR_AND_EXIT("Error : Interface subclass mismatch. This should be 0\n");
                    }

                    if((*macos_usb_interface)->USBInterfaceOpen(macos_usb_interface) == kIOReturnSuccess)
                    {
                        usb_interface->macos_usb_interface = macos_usb_interface;
                    }
                    else
                    {
                        PRINT_ERROR_AND_EXIT("Error : Unable to open the usb interface\n");
                    }
                }
                else
                {
                    printf("Error : Unable to get usb interface description\n");
                    assert(0);
                }
            }

            // get bulk in/out endpoint indices
            if(usb_interface->macos_usb_interface)
            {
                IOUSBInterfaceInterface **macos_usb_interface = usb_interface->macos_usb_interface;

                u8 endpoint_count = 0;
                (*macos_usb_interface)->GetNumEndpoints(macos_usb_interface, &endpoint_count);
                if(endpoint_count != 2)
                {
                    PRINT_ERROR_AND_EXIT("Error: Found %u endpoints, should be only 2 except the control endpoint(endpoint 0)\n", endpoint_count);
                }

                // since RP2040/2350 DS says that we should not rely on the index of the endpoints, 
                // loop to find which endpoint is 'in' or 'out'
                for(u32 endpoint_index = 1;
                        endpoint_index < (endpoint_count + 1); // disregard the 0th endpoint(control endpoint)
                        endpoint_index++)
                {
                    /*
                        endpoint descriptor
                        offset                  size        description
                        0	    bLength	        1	        Size of Descriptor in Bytes (7 bytes)
                        1	bDescriptorType	    1	        Endpoint Descriptor (0x05)
                        2	bEndpointAddress	1	        Endpoint Address
                                                            Bits 0..3b Endpoint Number.
                                                            Bits 4..6b Reserved. Set to Zero
                                                            Bits 7 Direction 0 = Out, 1 = In (Ignored for Control Endpoints)

                        3	bmAttributes	    1	        Bits 0..1 Transfer Type
                                                            00 = Control
                                                            01 = Isochronous
                                                            10 = Bulk
                                                            11 = Interrupt
                                                            Bits 2..7 are reserved. If Isochronous endpoint,
                                                            Bits 3..2 = Synchronisation Type (Iso Mode)
                                                            00 = No Synchonisation
                                                            01 = Asynchronous
                                                            10 = Adaptive
                                                            11 = Synchronous
                                                            Bits 5..4 = Usage Type (Iso Mode)
                                                            00 = Data Endpoint
                                                            01 = Feedback Endpoint
                                                            10 = Explicit Feedback Data Endpoint
                                                            11 = Reserved

                        4	wMaxPacketSize	2	            Maximum Packet Size this endpoint is capable of sending or receiving
                        6	bInterval	    1	            Interval for polling endpoint data transfers. Value in frame counts. 
                                                            Ignored for Bulk & Control Endpoints. 
                                                            Isochronous must equal 1 and field may range from 1 to 255 for interrupt endpoints.
                     */

                    // RP2040/2350 has 3 endpoints in PICOBOOT mode, the first one is always the control endpoint which isn't part of num_endpoint.
                    // we can use this one to send the control requests(RP2040 DS 2.8.5.5)
                    // rest of them are bulk in/out endpoints
                    // for more information, see https://github.com/raspberrypi/pico-bootrom/blob/master/bootrom/usb_boot_device.c
                    u8 direction;
                    u8 index;
                    u8 transfer_type;
                    u16 max_packet_size;
                    u8 interval; 
                    if((*macos_usb_interface)->GetPipeProperties(macos_usb_interface,
                                                            endpoint_index, &direction,
                                                            &index, &transfer_type,
                                                            &max_packet_size, &interval) == kIOReturnSuccess)
                    {
                        assert(transfer_type == kUSBBulk); // kUSBBulk == 2
                        switch(direction)
                        {
                            case kUSBOut: // 0
                            {
                                usb_interface->bulk_out_endpoint_index = (u8)endpoint_index;
                            }break;

                            case kUSBIn: // 1
                            {
                                usb_interface->bulk_in_endpoint_index = (u8)endpoint_index;
                            }break;

                            default :
                            {
                                printf("Error : Endpoint other than bulk in or out is not expected\n");
                                assert(0); 
                            }
                        }
                    }
                    else
                    {
                        PRINT_ERROR_AND_EXIT("Error : Couldn't get any endpoint index\n");
                    }
                }
            } // if(usb_interface.macos_usb_interface)
        }
        else
        {
            PRINT_ERROR_AND_EXIT("Error : Configuration count mismatch. There should always be 1 configuration, which is the PICOBOOT\n");
        }
    } 
    else // if(usb_device)
    {
        PRINT_ERROR_AND_EXIT("Error: Could not find RP USB device\n");
    }

#if 0
    if(usb_interface->should_exit == false)
    {
        IOUSBInterfaceInterface **macos_usb_interface = usb_interface->macos_usb_interface;

        // clear any stall/halt bits from every endpoints
        // this also synchronizes bit toggle(usbspec 1.1)
        assert((*usb_interface->macos_usb_interface)->AbortPipe(usb_interface->macos_usb_interface, usb_interface->bulk_in_endpoint_index) == kIOReturnSuccess);
        assert((*usb_interface->macos_usb_interface)->ClearPipeStallBothEnds(usb_interface->macos_usb_interface, usb_interface->bulk_in_endpoint_index) == kIOReturnSuccess);

        assert((*usb_interface->macos_usb_interface)->AbortPipe(usb_interface->macos_usb_interface, usb_interface->bulk_out_endpoint_index) == kIOReturnSuccess);
        assert((*usb_interface->macos_usb_interface)->ClearPipeStallBothEnds(usb_interface->macos_usb_interface, usb_interface->bulk_out_endpoint_index) == kIOReturnSuccess);

        // reset RP2040/2350 usb interface
        IOUSBDevRequest reset_request = {};
        reset_request.bmRequestType = 0b01000001;
        reset_request.bRequest = 0b01000001;
        reset_request.wValue = 0;
        reset_request.wIndex = 1; // in this case, index of the interface
        reset_request.wLength = 0;

        IOReturn kr = (*usb_interface->macos_usb_interface)->ControlRequest(usb_interface->macos_usb_interface, 0, &reset_request);
        assert(kr == kIOReturnSuccess);

#if 0
        // TODO(gh) getting the exclusive access by disabling the mass storage interface doesn't seem to work, 
        // so make sure _not_ to use the mass storage interface
        {
            PicoBootCommand excl_command = {};
            excl_command.magic = PICOBOOT_COMMAND_MAGIC_VALUE;
            excl_command.token = 0xdccccc;
            excl_command.command_ID = 0x1;
            excl_command.command_size = 0x01;
            excl_command.pad0 = 0;
            excl_command.transfer_length = 0;
            excl_command.args0 = 2;
            excl_command.args1 = 0; 
            excl_command.args2 = 0; 
            excl_command.args3 = 0; 
            macos_write_to_bulk_out_endpoint(&usb_interface, &excl_command, sizeof(PicoBootCommand)); 
            macos_wait_for_command_complete(&usb_interface);

            macos_bulk_transfer_in_zero(&usb_interface); // end the command sequence

            int a = 1;
        }
        sleep(1);
#endif

        // Read from the flash to get the memory
        u32 read_size = 256*1024;
        TempMemory temp_read_memory = start_temp_memory(&usb_interface->arena, read_size, false);
        // macos_read_from_rp(usb_interface, 0x10000000, temp_read_memory.base, read_size);

        // TODO(gh) use the argument to get the location of the .bin file
        char *file_path = "/Volumes/work/PLL_engine/code/rp235x/rp235x_main.uf2";
        PlatformReadFileResult bin_file = debug_macos_read_file(file_path);

        // Write the code to ram
        // TODO(gh) use the argument to get the SRAM write location
        u32 core0_instruction_address = 0x20000000;
        macos_write_to_rp(usb_interface, core0_instruction_address, bin_file.memory, bin_file.size);
        macos_verify_write_to_rp(usb_interface, core0_instruction_address, bin_file.memory, bin_file.size);

        // move the PC and reboot RP2040
        PicoBootCommand reboot_command = {};
        reboot_command.magic = PICOBOOT_COMMAND_MAGIC_VALUE;
        reboot_command.token = 0x1234;
        reboot_command.command_ID = PicoBootCommand_REBOOT2;
        reboot_command.command_size = 0x10;
        reboot_command.pad0 = 0;
        reboot_command.transfer_length = 0;
        // TODO(gh) This is different from rp2040, make sure this works
        reboot_command.args0 = 0x0003 | 0x0010;  // REBOOT_TYPE_PC_SP | REBOOT_TO_ARM
        reboot_command.args1 = 0; // delay
        reboot_command.args2 = core0_instruction_address; // PC
        reboot_command.args3 = 1024; 
        macos_bulk_transfer_out(usb_interface, &reboot_command, sizeof(PicoBootCommand)); // write out the command
        macos_wait_for_command_complete(usb_interface);
        macos_bulk_transfer_in_zero(usb_interface); // end the command sequence
    }
#endif

ERROR_EXIT :
    int ___a; // remove warning -Wc++2b-extensions
}

internal void
raw_usb_device_removed(void *refCon, io_iterator_t io_iter)
{
    kern_return_t   kr;
    io_service_t    object;
 
    RPUSBInterface *usb_interface = (RPUSBInterface *)refCon;

    io_service_t usb_device_iter = IOIteratorNext(io_iter);
    while (usb_device_iter)
    {
        if(IOObjectRelease(usb_device_iter) == kIOReturnSuccess)
        {
            printf("Device properly removed.\n");
            usb_interface->properly_removed = true;
            break;
        }
        else
        {
            // TODO(gh) log
            PRINT_ERROR_AND_EXIT("Error : Couldn’t release usb device object.\n")
        }
    }

ERROR_EXIT :
    int ___a; // remove warning -Wc++2b-extensions
}

internal void*
macos_io_thread_proc(void *data)
{
    RPUSBInterface *usb_interface = (RPUSBInterface *)data;

    /*
       This usb initialization sequence is from 
       https://developer.apple.com/library/archive/documentation/DeviceDrivers/Conceptual/USBBook/USBDeviceInterfaces/USBDevInterfaces.html
     */
    // open a master port to talk to the IOKit
    mach_port_t iokit_master_port;
    kern_return_t kernel_return = IOMasterPort(MACH_PORT_NULL, &iokit_master_port);
    assert((kernel_return == 0) && iokit_master_port);

    // create a dictionary to the IOKit so that we can find the usb device that we want
    CFMutableDictionaryRef usb_matching_dict = IOServiceMatching(kIOUSBDeviceClassName);
    assert(usb_matching_dict);

    // set the matching key-value pair for the device
    i32 usb_vendor_ID = RP2350_VendorID; 
    i32 usb_product_ID = RP2350_ProductID;
    CFDictionarySetValue(usb_matching_dict, CFSTR(kUSBVendorName),
                        CFNumberCreate(kCFAllocatorDefault, 
                                        kCFNumberSInt32Type, &usb_vendor_ID));
    CFDictionarySetValue(usb_matching_dict, CFSTR(kUSBProductName),
                    CFNumberCreate(kCFAllocatorDefault,
                                kCFNumberSInt32Type, &usb_product_ID));

    // open a notification port and add it to the CFRunLoop. IOKit will use this port to notify us 
    // whenever there is a new device being connected or the states change
    IONotificationPortRef notification_port = IONotificationPortCreate(iokit_master_port);
    CFRunLoopSourceRef runloop_source = IONotificationPortGetRunLoopSource(notification_port);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), 
                        runloop_source,
                        kCFRunLoopDefaultMode);

    // this is some obj-c crap I think, the explanation from them is : 
    // "Retain additional dictionary references because each call to IOServiceAddMatchingNotification consumes one reference"
    usb_matching_dict = (CFMutableDictionaryRef) CFRetain(usb_matching_dict);
    usb_matching_dict = (CFMutableDictionaryRef) CFRetain(usb_matching_dict);
    usb_matching_dict = (CFMutableDictionaryRef) CFRetain(usb_matching_dict);

    // TODO(gh) remove this malloc
    io_iterator_t *io_iters = (io_iterator_t *)malloc(4*sizeof(io_iterator_t));
    io_iterator_t *usb_deviced_added_iter = io_iters + 0;
    io_iterator_t *usb_deviced_removed_iter = io_iters + 1;

    // initialization routine

    // first connected
    IOServiceAddMatchingNotification(notification_port,
                                     kIOFirstMatchNotification, usb_matching_dict,
                                     raw_usb_device_added, usb_interface, usb_deviced_added_iter);
    raw_usb_device_added(usb_interface, *usb_deviced_added_iter); // debug probe might be already connected, so try finding it

    // termination
    IOServiceAddMatchingNotification(notification_port,
                                     kIOTerminatedNotification, usb_matching_dict,
                                     raw_usb_device_removed, usb_interface, usb_deviced_removed_iter);
    raw_usb_device_removed(usb_interface, *usb_deviced_removed_iter); // TODO(gh) we can either do this or just let the OS call this functino


    // rp2350 should be disconnected by now, since it's going to reboot.
    // next time when it's re-connected, CFRunLoop should catch it and call raw_usb_device_added callback function.

    // once we are done, deallocate the master port 
    mach_port_deallocate(mach_task_self(), iokit_master_port);

    if(usb_interface->should_exit == false)
    {
        CFRunLoopRun(); // infinite loop
    }

    return 0;
}

int main(int argc, char **argv)
{ 
    u64 start_ns = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW);
    
    printf("/*** RP Boot Start ***/\n");

    assert(argc == 3); // TODO(gh) only take one binary for now
    if((argc & 1) == 1) // first one is always the program name, and we need a pair of the 'binary path' and the 'address'
    {
        RPUSBInterface *usb_interface = (RPUSBInterface *)malloc(sizeof(RPUSBInterface)); 
        usb_interface->argv = argv;
        usb_interface->argc = argc;
        u32 usb_interface_buffer_size = 4*1024*1024;
        void *usb_interface_buffer_base = malloc(usb_interface_buffer_size);
        usb_interface->arena = start_memory_arena(usb_interface_buffer_base, usb_interface_buffer_size, false);

        // create iothread and start running
        pthread_attr_t  attr;
        pthread_attr_init(&attr);
        pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_JOINABLE);
        pthread_t io_thread = 0; 
        if(pthread_create(&io_thread, &attr, &macos_io_thread_proc, (void *)usb_interface) != 0)
        {
            assert(0);
        }
        pthread_attr_destroy(&attr);

        pthread_join(io_thread, 0); // wait until io thread to exit
    }
    else
    {
        printf("Error : Provide the pairs of file path and address(in hex) in this order.\n");
    }


    u64 end_ns = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW);
    f64 time_passed_s = (f64)(end_ns - start_ns) * ((+1.0E-9));
    printf("Finished in %.6lf seconds\n", time_passed_s);
    printf("/*** RP Boot End ***/\n");

    return 0;
}











