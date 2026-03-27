A very simple debugging monitor capability using Apple's Wozmon.  Mainly a test of writing to a TCP address via Fujinet.

To use change the IP destination in main.c to be your endpoint (netcat works well)

const char url[]="N:TCP://192.168.1.97:6502";

Core Commands and Syntax
Wozmon operates line-by-line, using hexadecimal values for addresses and data, followed by [ENTER]. 

    Examine Memory: Type a memory address in hex (e.g., 0300) to display the value at that address.
    Modify Memory (Store): Type the address followed by a colon and the new hex value (e.g., 0300:FF) to change memory contents.
    Block Examine: Type two addresses separated by a period (e.g., 0300.030F) to view a range of memory.
    Run Program: Type the starting address followed by R (e.g., 0300R) to start execution at that location.
    Return to Monitor: If running a custom program, ensure it ends with a RTS instruction to return control to Wozmon.
