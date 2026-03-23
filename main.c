/**
 * Lynx Fujinet Debugger interface
 */

#include <6502.h>
#include <lynx.h>
#include <tgi.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <conio.h>
#include <ctype.h>
#include "lynxfnio.h"
#include "wozmon.h"


// URL of server/netcat instance - change this for your network
// NetCat command that you could use:
// netcat -k -l -p 6502
const char url[]="N:TCP://192.168.1.97:6502";

char outbuf[64];			// our buffer to send to Fujinet
unsigned char outindex;		// index into the outbuffer

char s[64];					// string for screen output

struct _oc
{
  unsigned char cmd;
  unsigned char mode;
  unsigned char trans;
  char url[64];
} OC; // open command data

struct _packet
{
  unsigned char cmd;
  char s[64];
} PKT;


// Gets the input from the Fujinet side (READ)
void wozmonio_getline(void)
{
	unsigned short len;
	unsigned char r;
	unsigned char i;


	len = 0;
	// Input from Fujinet loop
    while (len == 0 || len > 30) {
		PKT.cmd = FUJICMD_READ;
		r = fnio_send_buf(FUJI_DEVICEID_NETWORK, (char *) &PKT, 1);				// send read command
		if (r) {
    		r = fnio_recv_buf((char *) WOZINBUF, &len);							// wait for some input
		}
	}

	//tgi_clear();
	//sprintf(s, "len: %d", len);
	//tgi_outtextxy(1, 8, s);

	// Change all characters to uppercase and set bit 7, Apple1 stuff
    for(i=0; i<len; ++i) {
		r = WOZINBUF[i];
		r = toupper(r);							// wozmon only works with uppercase
		r |= 0x80;								// wozmon expects all characters to have bit 7 set
		WOZINBUF[i] = r;
	}
    WOZINBUF[len] = 0x8D;						// put CR on end of input, wozmon expects CR to be 0x8D

	// Debug, print command to lynx screen
	//strncpy(s, (char *) WOZINBUF, len-1);
    //tgi_outtextxy(1, 16, s);

}


// Writes Wozmon output to Fujinet
void __fastcall__ wozmonio_echo(unsigned char c)
{
	unsigned char r;


  	switch(c) {
    	case 0x8D:										// CR character has bit 7 set
	  		outbuf[outindex] = '\n';					// add a newline

	  		// send line to Fujinet
	  		PKT.cmd = FUJICMD_WRITE;
	  		memcpy(&PKT.s, &outbuf, sizeof(PKT.s));
      		r = fnio_send_buf(FUJI_DEVICEID_NETWORK, (char *) &PKT, outindex+2);
			r = fnio_recv_ack();
			
			// clear our output buffer
      		outindex = 0;
      		memset(&outbuf, 0, sizeof(outbuf));
      		break;

    	default:										// all other characters, build output string
      		outbuf[outindex] = c;
      		outindex++;
      		break;
  	}
}



void main(void)
{
  	unsigned char r;
  

  	outindex = 0;						// intialize output buffer

  	// Setup TGI
  	tgi_install(tgi_static_stddrv);
  	tgi_init();

  	// Start Fujinet
  	fnio_init();

  	// Clear the screen
  	tgi_setcolor(TGI_COLOR_WHITE);
  	tgi_clear();

  	// Open connection to server/netcat
  	OC.cmd = FUJICMD_OPEN; 	// OPEN
  	OC.mode = 12; 			// Read/write aka HTTP GET
  	OC.trans = 0; 			// No translation
  	strncpy(OC.url, url, sizeof(OC.url));

	// Send the Open command
  	r = fnio_send_buf(FUJI_DEVICEID_NETWORK, (char *)&OC, sizeof(OC));
	fnio_recv_ack();

  	// output open status
  	sprintf(s, "O:%X", r);
  	tgi_outtext(s);

	// start Wozmon
	if (!r)
		while(1);
	else
  		start_wozmon();

	// close the connection
  	PKT.cmd = FUJICMD_CLOSE;
  	fnio_send_buf(FUJI_DEVICEID_NETWORK, (char *) &PKT, 1);
	fnio_recv_ack();

  	return;
}
