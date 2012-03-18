@ Part 1 of program. 
@ Program to show hooking of interrupt vector, chaining of interrupt procedures,
@ and servicing an interrupt produced by a pushbutton (GPIO 91).
@ Extensively used the framework from Dr. Douglas Hall's ECE371 textbook.
@ Jen Hanni, Winter 2011

.text
.global _start
_start:

@ INITIALIZE REGISTERS

.EQU GRER0, 0x40E00030
.EQU GP
.EQU GPDR2, 0x40E00014
.EQU GRER2, 0x40E00000
.EQU CLR27, 0xF7FFFFFF
.EQU SET27, 0x08000000
.EQU ICMR,  0x40D00004
.EQU THR,   0x10800000
.EQU IER,   0x10800002
.EQU ISR,   0x10800004
.EQU LCR,   0x10800006
.EQU MCR,   0x10800008
.EQU LSR,   0x1080000A
.EQU MSR,   0x1080000E

@ INITIALIZE GPIO91 for INPUT AND RISING EDGE DETECT

		@ Word to clear bit 91, sign off when output
		@ Write to GPCR2
LDR R0,GPDR2    @ Load pointer of GPDR2 into R0.
LDR R4,[R0]     @ Read GPDR2 register
ORR R4,R4,CLR27 @ Modify - clear bit 27 to make GPIO 91 an input
STR R4,[R0]     @ Write word back to GPDR2
LDR R4,GRER2    @ Load address of GRER2 register
LDR R0,[R4]     @ Read GRER2 register
MOV R2,SET27    @ Load mask to set bit 27 -- calculated word 0x08000000
ORR R0,R0,R2    @ Set bit 27
STR R0,[R4]     @ Write word back to GRER2 register

@ Initialize GPIO 10 as a rising edge interrupt detect for COM2 UART

	@ Point to GRER0 register
	@ Read GRER0 register
	@ Set bit 10 to enable GPIO10 for rising edge detect
	@ Write back to GRER0

@ INITIALIZE INTERRUPT CONTROLLER
@ NOTE: DEFAULT VALUE OF IRQ FOR ICLR BIT 10 IS DESIRED VALUE, SO SEND NO WORD
@ NOTE: DEFAULT VALUE OF DIM BIT IN ICCR IS DESIRED VALUE, SO SEND NO WORD

LDR R0,ICMR  	@ Load address of mask (ICMR) register
LDR R1,[R0]     @ Read current value of register
MOV R2,#0x400   @ Load value to unmask bit 10 for GPIO82:2 
ORR R1,R1,R2    @ Set bit 10 to unmask IM10
STR R1,[R0]     @ Write word back to ICMR register

@ HOOK THE IRQ PROCEDURE AND INSTALL OUR INT_HANDLER ADDRESS

MOV R1,#0x18             @ Load IRQ interrupt vector address 0x18
LDR R2,[R1]              @ Read instr from interrupt vector table at 0x18
LDR R3,=0xFFF            @ Construct mask
AND R2,R2,R3             @ Mask all but offset part of instruction
ADD R2,R2,#0x20          @ Build absolute address of IRQ procedure in literal 
                         @ pool
LDR R3,[R2]              @ Read BTLDR IRQ address from literal pool
STR R3,BTLDR_IRQ_ADDRESS @ Save BTLDR IRQ address for use in IRQ_DIRECTOR
LDR R0,=INT_DIRECTOR     @ Load absolute address of our interrupt director
STR R0,[R2]              @ Store this address literal pool

@ MAKE SURE IRQ INTERRUPT ON PROCESSOR ENABLED BY CLEARING BIT 7 IN CPSR

MRS R3,CPSR             @ Copy CPSR to R3
BIC R3,R3,#0x80         @ Clear bit 7 (IRQ Enable bit) 
MSR CPSR_c, R3          @ Write new counter value back in memory

@ WAIT HERE NOW FOR THE INTERRUPT SIGNAL BY DOING PROGRAM THINGS
@ THIS IS THE MAINLINE

LOOP:   NOP                     @ Wait for interrupt here (simulate mainline 
        B LOOP                  @ program execution)

@ An interrupt has been detected! Test it to determine a source.
@ IRQ_DIRECTOR

INT_DIRECTOR:
		@ Save registers on stack
		@ Assume only GPIO 119:2 possible for this program.
		@ System will take care of others.
		@ Point at IRQ pending register (ICIP)
		@ Read ICIP
		@ Check if GPIO 119:2 IRQ interrup ton IS<10> asserted
B-- PASSON	@ No, must be other iRQ, pass on to system program
		@ Load address of GEDR0 register
		@ Read GEDR0 register address to check if GPIO10 
		@ Check for UART interrupt on bit 10
B-- TLK_SVC	@ Yes, go send character
		@ If no, check for button.
		@ Load GEDR2 register address to check if GPIO91
		@ Read GEDR2 register value
		@ Check if bit 27 in GEDR2 = 1
B-- BTN_SVC	@ Yes, must be button press
		@ Go service the button - return to wait loop from SVC
		@ No, must be other GPIO 119:2 IRQ, pass on. 

@ The interrupt is not from our button or the UART
@ PASS ON

		@ Restore the registers
		@ Go to bootloader IRQ service procedure
		@ Bootloader will use restored LR to return to loop from SVC.

@ The interrupt came from our button on GPIO pin 91
@ BTN_SVC

		@ Value to clear bit 27 in GEDR2
		@ This will also reset bit 10 in ICPR and ICIP
		@      if no other GPIO 119:2 interrupts
		@ Write to GEDR2.
		@ Pointer to the MCR to enable UART interrupt and assert
		@      CTS# to send message to talker.
		@ Enable UART interrupt
		@ Write back to MCR
		@ Restore registers, including return address
		@ Return from interrupt to wait loop

@ The interrupt came from the CTS# low or THR empty or other interrupt
@ TLKR_SVC

		@ Save additional registers
		@ Point to MSR
		@ Read MSR, resets MSR change interrupt bits
		@ Check if the CTS# is currently asserted (MSR bit 4)
BEQ NOCTS	@ If not, go check for THR status
		@ CTS asserted, read LSR (does not clear interrupt)
		@ Check if THR-ready is asserted
BEQ GOBCK	@ If no, exit and wait for THR-ready
B SEND		@ If yes, both are asserted, send character

@ The interrupt did not come from CTS# low
@ NOCTS

		@ Point to LSR
		@ Read LSR (does not clear interrupt)
		@ Check if THR-ready is asserted
B-- GOBCK	@ Neither CTS or THR are asserted, must be other source
		@ Else no CTS# but THR asserted, disable interrupt on THR
		@       to prevent spinning while waiting for CTS#
		@ Load IER
		@ Disable bit 1 = Tx interrupt enable (Mask THR)
		@ Write to IER
B-- GOBCK	@ Exit to wait for CTS# interrupt
		
@ Unmask THR, send the character, test if more characters
@ SEND

		@ Load pointer to IER
		@ Bit 3 = modem status interrupt, bit 1 = Tx int enable
		@ Write to IER
		@ Load address of char pointer
		@ Load address of desired char in text string
		@ Load address of count store location
		@ Get current char count value
		@ Load char from string, increment char pointer
		@ Put incremented char address into CHAR_PTR fo rnext time
		@ Point at UART THR
		@ Write char to THR, which clears interrupt source for now
		@ Decrement char counter by 1
		@ Store char value counter back in memory
		@ Test char counter value
BPL GOBCK	@ If greater than zero, go get more characters
		@ If not, reload the message. Get address of start string.
		@ Store the string starting address in CHAR_PTR
		@ Load the original number of characters in string again
		@ Write that length to CHAR_CTR
		@ Load address of MCR
		@ Read current value of MCR
		@ Clear bit 3 to disable UART interrupts
		@ Write resulting value with cleared bit 3 back to MCR

@ Restore from the interrupt
@ GOBACK

		@ Restore additional registers
		@ Restore original registers, including return address
		@ Return from interrupt (to wait loop)

 
BTLDR_IRQ_ADDRESS:	.word 0x0	@ space to store the bootloader irq address

@ Control bits are handled in the program itself.
@ Data handled below:

.data		@ Data bytes for speaking
MESSAGE:	.word	0x0D
		.ascii 	"Take me to your leader"
		.word 	0x0D
CHAR_PTR:	.word 	MESSAGE
CHAR_COUNT:	.word 	24

.end
