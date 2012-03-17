@ Part 1 of program. 
@ Program to show hooking of interrupt vector, chaining of interrupt procedures,
@ and servicing an interrupt produced by a pushbutton (GPIO 91).
@ Extensively used the framework from Dr. Douglas Hall's ECE371 textbook.
@ Jen Hanni, Winter 2011

.text
.global _start
_start:

@ INITIALIZE REGISTERS

.EQU GPDR2, 0x40E00014
.EQU GRER2, 0x40E00000
.EQU CLR27, 0xF7FFFFFF
.EQU SET27, 0x08000000
.EQU ICMR,  0x40D00004

@ INITIALIZE GPIO91 for INPUT AND RISING EDGE DETECT

LDR R0,GPDR2    @ Load pointer of GPDR2 into R0.
LDR R4,[R0]     @ Read GPDR2 register
ORR R4,R4,CLR27 @ Modify - clear bit 27 to make GPIO 91 an input
STR R4,[R0]     @ Write word back to GPDR2
LDR R4,GRER2    @ Load address of GRER2 register
LDR R0,[R4]     @ Read GRER2 register
MOV R2,SET27    @ Load mask to set bit 27 -- calculated word 0x08000000
ORR R0,R0,R2    @ Set bit 27
STR R0,[R4]     @ Write word back to GRER2 register

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

@ INTERRUPT DETECTED - TEST FOR WHETHER IT'S OUR BUTTON

INT_DIRECTOR:           @ Chains button interrupt procedure
STMFD SP!,{R0-R3,LR}    @ Save registers to be used in procedure on stack
                        @ Assume only GPIO 119:2 possible for this program.
                        @ System will take care of others.
LDR R0,=0x40D00000      @ Point at IRQ pending register (ICIP)
LDR R1,[R0]             @ Read ICIP register
TST R1,#0x400           @ Check if GPIO 119:2 IRQ interrupt on IS<10> asserted 
BEQ PASSON              @ No, must be other IRQ, pass on to system program
LDR R0,=0x40E00050      @ Yes, load GEDR2 register address to check if GPIO91
LDR R1,[R0]             @ Read GPIO Edge Detect Register (GEDR2) value
TST R1,#0x800           @ Check if bit 27 = 1 (GPIO91 edge detected) 
BNE BUTTON_SVC          @ Yes, must be button press.
                        @ Go service - return to wait loop from SVC

@ IF IT'S NOT THE BUTTON, PASS ON TO BOOTLOADER IRQ PROCEDURE

PASSON: LDMFD SP!{R0-R3,LR}      @ No, must be other GP 80:2 IRQ
				 @ Restore registers
        LDR PC,BTLDR_IRQ_ADDRESS @ Go to bootloader IRQ service procedure
                                 @ Bootloader will use restored LR to 
				 @ return to mainline loop when done.

@ IF IT'S THE BUTTON, SERVICE THE BUTTON PRESS 

BTLDR_IRQ_ADDRESS:

	.word 0x0	@ space to store the bootloader irq address

.data

	@ data bytes for speaking
SPEECH:	.byte T,h,i,s, ,i,s, ,a, ,t,e,s,t

	@ command control bytes for control
CTRL:	.byte 	

.end
