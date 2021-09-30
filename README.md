# Jaguar GameDrive Homebrew API
## Usage
Include the **gdbios_bindings.s** file in your project. This file maps the stack based C parameter passing ABI to the registers expected by the underlying GD BIOS.
Registers d0-d1 and a0-a1 are considered scratch registers, all other registers will be preserved in compliance with the C ABI.

If you wish to call the GSBIOS calls directly from assembler the register mapping can be figured out by looking at the binding code.

Before use the GDBIOS layer must be installed in memory. The GDBIOS can be installed at any memory location and is installed by calling `GD_Install`, passing a pointer to a
long aligned block of memory 4KB in size. If you try to install the GDBIOS on a firmware version of the GDBIOS which does not support it, the call will return a negative number.
On success it will return 0. The user must update their firmware to be able to use the GDBIOS if the call fails.

Once instlled the user can optionally install the GPU file handler. This allows very fast asynchronous reading of files by the GPU and is analogous to the CD-ROM GPU file reading.
To install the GPU file handler call `GD_InitGPURead` passing a pointer to a long aligned block of GPU RAM 224 bytes in length and a flag for which version of the handler is
required. 
`GD_GPU_READ_PRESERVE` saves all GPU registers used requires 4 longs on the stack. 
`GD_GPU_READ_FAST` is a slightly faster version but does not preserve any registers. It uses r24-r27 in the interrupt register bank along with r28-r31 which are the standard interrupt processing registers.

This will call will also modify the GPU interrupt table to jump the file handler code. When starting the GPU you must enable DSP interrupts by setting `G_DSPENA` in `G_FLAGS`
and enable the external interrupt on Jerry by setting `J_EXTENA` on `J_INT`.

Once installed you are free to use any functions available. Without calling `GD_InitGPURead` the `GD_FREAD_GPU` read modes will not function.

## Simple File Example

```
#include "gdbios.h"

u8 buffer[1024];

void main()
{
  u16 handle;
  GD_Install(0x3000);
  handle = GD_FOpen("/myfile.bin", GD_FOPEN_READ|GD_FOPEN_OPEN_EXISTING);
  if (handle >= 0)
  {
    // read 1K using CPU transfer
    GD_FRead(handle, buffer, 1024, GD_FREAD_CPU);
    GD_FClose(handle);
  }
}
```
