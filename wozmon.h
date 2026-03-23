#ifndef WOZMON_H
#define WOZMON_H


// Input buffer
#define WOZINBUF	((unsigned char *) 0x200)

// Start the Wozmon debugger
void start_wozmon();

// Input/Output routines for wozmon
void wozmonio_getline(void);
void __fastcall__ wozmonio_echo(unsigned char c);


#endif