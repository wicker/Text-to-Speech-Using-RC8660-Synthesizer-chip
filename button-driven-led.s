@ Program to show hooking of interrupt vector, chaining of interrupt procedures, 
@ and servicing an interrupt produced by a pushbutton that turns on and off an 
@ LED. Active low pushbutton on GPIO13. LED control on GPIO 91 (button). 
@ Jenner Hanni, Winter 2011 

.text 
.global _start 
_start: 

.EQU GPDR0, 0x40E0000C
.EQU GPSR0, 0x40E00018
.EQU GPCR0, 0x40E00024
.EQU GPDR2, 0x40E00014
.EQU GPSR2, 0x40E00020
.EQU GPCR2, 0x40E0002C
.EQU GRER2, 0x40E00038 
.EQU GEDR2, 0x40E00050
.EQU CLRAF, 0x000C0000
.EQU ICIP,   0x40D00000  @ Interrupt Controller IRQ Pending Register

.EQU GAFR2L, 0x40E00064


@-------------------------------------------@
@ Set GPIO 73 back to Alternate Function 00 @
@-------------------------------------------@

	LDR R0, =GAFR2L @ Load pointer to GAFR2_L register
	LDR R1, [R0]    @ Read GAFR2_L to get current value
	BIC R1, R1, #CLRAF  @ Clear bit2 18 and 19 to make GPIO 73 not an alternate function
	STR R1, [R0]    @ Write word back to the GAFR2_L

@ INITIALIZE GPIO73 FOR INPUT AND RISING EDGE DETECT 

	LDR R0, =GPDR2  @ Point to GPDR2 register
	LDR R1, [R0]    @ Read GPDR2 to get current value
	BIC R1, R1, #0x200   @ Clear bit 9 to make GPIO 73 an input
	STR R1, [R0]    @ Write word back to the GPDR2

	LDR R0, =GRER2  @ Point to GRER2 register
	LDR R1, [R0]    @ Read current value of GRER2 register
	ORR R1, R1, #0x200   @ Load mask to set bit 9
	STR R1, [R0]    @ Write word back to GRER2 register

@
@ INITIALIZE INTERRUPT CONTROLLER 
@ NOTE: DEFAULT VALUE OF IRQ FOR ICLR BIT 10 IS DESIRED VALUE, SO SEND NO WORD 
@ NOTE: DEFAULT VALUE OF DIM BIT IN ICCR IS DESIRED VALUE, SO NO WORD SENT 
@ 
	LDR R0,=0x40D00004	@ Load address of mask (ICMR) register 
	LDR R1,[R0]		@ Read current value of register 
	ORR R1, #0x400  	@ Set bit 10 to unmask IM10
	STR R1,[R0]		@ Write word back to ICMR register 
@ 
@ HOOK IRQ PROCEDURE ADDRESS AND INSTALL OUR INT_HANDLER ADDRESS 
@ 
	MOV R1,#0x18		@ Load IRQ interrupt vector address 0x18 
	LDR R2,[R1]		@ Read instr from interrupt vector table at 0x18 
	LDR R3,=0xFFF		@ Construct mask 
	AND R2,R2,R3		@ Mask all but offset part of instruction 
	ADD R2,R2,#0x20		@ Build absolute address of IRQ procedure in literal 
				@ pool 
	LDR R3,[R2]		@ Read BTLDR IRQ address from literal pool 
	STR R3,BTLDR_IRQ_ADDRESS @ Save BTLDR IRQ address for use in IRQ_DIRECTOR 
	LDR R0,=INT_DIRECTOR	@ Load absolute address of our interrupt director 
	STR R0,[R2]		@ Store this address literal pool 
@ 
@ MAKE SURE IRQ INTERRUPT ON PROCESSOR ENABLED BY CLEARING BIT 7 IN CPSR 
@ 
	MRS R3,CPSR		@ Copy CPSR to R3 
	BIC R3,#0x80		@ Clear bit 7 (IRQ Enable bit) 
	MSR CPSR_c, R3		@ Write new counter value back in memory 
				@ to lowest 8 bits of CPSR 

@ 
@ WAIT HERE NOW FOR THE INTERRUPT SIGNAL BY DOING PROGRAM THINGS 
@ THIS IS THE MAINLINE 
@ 
LOOP:	NOP			@ Wait for interrupt here (simulate mainline 
	B LOOP		@ program execution) 
@ 
@ HOUSTON WE HAVE AN INTERRUPT -- IS IT BUTTON OR SOMETHING ELSE? 
@ 
INT_DIRECTOR:		@ Chains button interrupt procedure 
        STMFD SP!, {R0-R1, LR}  @ Save registers on stack
        LDR R0, =ICIP   @ Point at IRQ Pending Register (ICIP)
        LDR R1, [R0]    @ Read ICIP
        TST R1, #0x400  @ Check if GPIO 119:2 IRQ interrupt on IP<10> asserted
        BNE PASSON      @ No, must be other IRQ, pass on to system program
        LDR R0, =GEDR2  @ Load GEDR2 register address to check if GPIO73 asserted
        LDR R1, [R0]    @ Read GEDR2 register value
        TST R1, #0x200   @ Check if bit 9 in GEDR2 = 1
        BEQ BUTTON_SVC     @ Yes, must be button press, go service the button
                        @ No, must be other GPIO 119:2 IRQ, pass on:

@ 
@ IT'S NOT THE BUTTON, IT'S NOT THE BUTTON 
@ 
PASSON: LDMFD SP!,{R0-R3,LR}	@ No, must be other GP 80:2 IRQ, restore registers 
	LDR PC,BTLDR_IRQ_ADDRESS @ Go to bootloader IRQ service procedure 
				@ Bootloader will use restored LR to return to 
				@ mainline loop when done. 
@ 
@ IT'S THE BUTTON, IT'S THE BUTTON 
@ SERVICE THE BUTTON PRESS 
@ 
BUTTON_SVC: 
	LDR R0, =GEDR2		@ Point to GEDR2 
	LDR R1, [R0]		@ Read the current value from GEDR2
	BIC R1, R1, #0x200		@ Clear bit 9
	STR R1, [R0]		@ Write to GEDR2

	LDMFD SP!,{R0-R1,LR}	@ Restore registers, including return address 
	SUBS PC,LR,#4		@ Return from interrupt (to wait loop) 

BTLDR_IRQ_ADDRESS: 

	 .word 0x0		@ Space to store bootloader IRQ address 

.data 
DELAYCOUNT: 	.word 0x0A305660	@ This hex contains 170,940,170 clock cycles 
ONOROFF: 	.word 0xB		@ 0xA means on, 0xB is off - should initially be off
.end
