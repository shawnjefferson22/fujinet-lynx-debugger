;-------------------------------------------------------------------------
;
;   The WOZ Monitor for the Apple 1
;   Written by Steve Wozniak 1976
;
;   Converted to assemble with ca65 by cbmeeks
;
;   Original code with comments taken from 
;   http://www.sbprojects.com/projects/apple1/wozmon.php
;
;-------------------------------------------------------------------------
;    .debuginfo  +
;    .setcpu     "65C02"
;    .ORG        $FF00

	.export	_start_wozmon
	.import _wozmonio_getline, _wozmonio_echo


;-------------------------------------------------------------------------
;  Memory declaration
;-------------------------------------------------------------------------
		.zeropage

XAML:            .res 1             ; Last "opened" location Low
XAMH:            .res 1             ; Last "opened" location High
STL:             .res 1             ; Store address Low
STH:             .res 1             ; Store address High
L:               .res 1             ; Hex value parsing Low
H:               .res 1             ; Hex value parsing High
YSAV:            .res 1             ; Used to see if hex value is given
MODE:            .res 1             ; $00=XAM, $7F=STOR, $AE=BLOCK XAM
CSAV:		 .res 1		    ; character save (for calling echo routine)

IN              :=      $0200           ; Input buffer ($0200 - $027F)


;-------------------------------------------------------------------------
;  Constants
;-------------------------------------------------------------------------

CR              :=      $8D             ; Carriage Return
PROMPT          :=      '\'             ; Prompt character

;-------------------------------------------------------------------------
;  Let's get started
;
;  The RESET routine is only to be entered by asserting the RESET line of
;  the system. This ensures that the data direction registers are selected.
;-------------------------------------------------------------------------

		.code

_start_wozmon:
RESET:
                CLD                      ; Clear decimal arithmetic mode
                CLI

; Program falls through to the GETLINE routine to save some program bytes
; Please note that Y still holds $7F, which will cause an automatic Escape

;-------------------------------------------------------------------------
; The GETLINE process
;-------------------------------------------------------------------------

ESCAPE:
                LDA     #PROMPT         ; Print prompt character
                JSR     ECHO            ; Output it

GETLINE:
                LDA     #CR             ; Send CR
                JSR     ECHO
		JSR	_wozmonio_getline

; Line received, now let's parse it

                LDY     #-1 + 255       ; Reset text index
                LDA     #0              ; Default mode is XAM
                TAX                     ; X=0

SETSTOR:
                ASL                     ; Leaves $7B if setting STOR mode
SETMODE:
                STA     MODE            ; Set mode flags
BLSKIP:
                INY                     ; Advance text index
NEXTITEM:
                LDA     IN, Y           ; Get character
                CMP     #CR
                BEQ     GETLINE         ; We're done if it's CR
                CMP     #'.'+$80
                BCC     BLSKIP          ; Ignore everything below "."
                BEQ     SETMODE         ; Set BLOCK XAM mode ("." = $AE)
                CMP     #':'+$80
                BEQ     SETSTOR         ; Set STOR mode. $BA will become $7B
                CMP     #'R'+$80
                BEQ     RUN             ; Run the program. Forget the rest.
                STX     L               ; Clear input value (X=0)
                STX     H
                STY     YSAV            ; Save Y for comparison

; Here we're trying to parse a new hex value

NEXTHEX:
                LDA     IN,Y            ; Get character for hex test
                EOR     #$B0            ; Map digits to 0-9
                CMP     #9+1            ; Is it a decimal digit?
                BCC     DIG             ; Yes!
                ADC     #$88            ; Map letter "A"-"F" to $FA-FF
                CMP     #$FA            ; Hex letter?
                BCC     NOTHEX          ; No! Character not hex

DIG:
                ASL
                ASL                     ; Hex digit to MSD of A
                ASL
                ASL

                LDX     #4              ; Shift count
HEXSHIFT:
                ASL                     ; Hex digit left, MSB to carry
                ROL     L               ; Rotate into LSD
                ROL     H               ; Rotate into MSD
                DEX                     ; Done 4 shifts?
                BNE     HEXSHIFT        ; No, loop
                INY                     ; Advance text index
                BNE     NEXTHEX         ; Always taken

NOTHEX:
                CPY     YSAV            ; Was at least 1 hex digit given?
                BEQ     ESCAPE          ; No! Ignore all, start from scratch

                BIT     MODE            ; Test MODE byte
                BVC     NOTSTOR         ; B6=0 is STOR, 1 is XAM or BLOCK XAM

; STOR mode, save LSD of new hex byte

                LDA     L               ; LSDs of hex data
                STA     (STL,X)         ; Store current 'store index'(X=0)
                INC     STL             ; Increment store index.
                BNE     NEXTITEM        ; No carry!
                INC     STH             ; Add carry to 'store index' high
TONEXTITEM:
                JMP     NEXTITEM        ; Get next command item.

;-------------------------------------------------------------------------
;  RUN user's program from last opened location
;-------------------------------------------------------------------------

RUN:
                JMP     (XAML)          ; Run user program

;-------------------------------------------------------------------------
;  We're not in Store mode
;-------------------------------------------------------------------------

NOTSTOR:
                BMI     XAMNEXT         ; B7 = 0 for XAM, 1 for BLOCK XAM

; We're in XAM mode now

SETADR:
		LDA	L
		STA	STL
		STA	XAML
		LDA	H
		STA	STH
		STA	XAMH
		LDX	#0

; Print address and data from this address, fall through next BNE.

NXTPRNT:
                BNE     PRDATA          ; NE means no address to print
                LDA     #CR             ; Print CR first
                JSR     ECHO
                LDA     XAMH            ; Output high-order byte of address
                JSR     PRBYTE
                LDA     XAML            ; Output low-order byte of address
                JSR     PRBYTE
                LDA     #':'            ; Print colon
                JSR     ECHO

PRDATA:
                LDA     #' '            ; Print space
                JSR     ECHO
                LDA     (XAML,X)        ; Get data from address (X=0)
                JSR     PRBYTE          ; Output it in hex format
XAMNEXT:
                STX     MODE            ; 0 -> MODE (XAM mode).
                LDA     XAML            ; See if there is more to print
                CMP     L
                LDA     XAMH
                SBC     H
                BCS     TONEXTITEM      ; Not less! No more data to output

                INC     XAML            ; Increment 'examine index'
                BNE     MOD8CHK         ; No carry!
                INC     XAMH

MOD8CHK:
                LDA     XAML            ; If address MOD 8 = 0 start new line
                AND     #%00000111
                BPL     NXTPRNT         ; Always taken.

;-------------------------------------------------------------------------
;  Subroutine to print a byte in A in hex form (destructive)
;-------------------------------------------------------------------------

PRBYTE:
                PHA                     ; Save A for LSD
                LSR
                LSR
                LSR                     ; MSD to LSD position
                LSR
                JSR     PRHEX           ; Output hex digit
                PLA                     ; Restore A

; Fall through to print hex routine

;-------------------------------------------------------------------------
;  Subroutine to print a hexadecimal digit
;-------------------------------------------------------------------------

PRHEX:
                AND     #%00001111     ; Mask LSD for hex print
                ORA     #'0'            ; Add "0"
                CMP     #'9'+1          ; Is it a decimal digit?
                BCC     ECHO            ; Yes! output it
                ADC     #6              ; Add offset for letter A-F

; Fall through to print routine

;-------------------------------------------------------------------------
;  Subroutine to print a character to the terminal
;-------------------------------------------------------------------------

ECHO:
		STA CSAV		 ; save A register (char to be printed)
		TXA			 ; save X and y regs
		PHA
		TYA
		PHA
		LDA CSAV	 	 ; restore char to print to A reg
		jsr _wozmonio_echo	 ; character is in A reg
		PLA			 ; restore x and y regs
		TAY
		PLA
		TAX
		RTS


;-------------------------------------------------------------------------
;  Vector area
;-------------------------------------------------------------------------

;                .word   $0000           ; Unused, what a pity
;NMI_VEC:        .word   $0F00           ; NMI vector
;RESET_VEC:      .word   RESET           ; RESET vector
;IRQ_VEC:        .word   $0000           ; IRQ vector

;-------------------------------------------------------------------------
