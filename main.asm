;
; MPPT.asm
;
; Created: 11.07.2020 23:43:55
; Author : Admin
;
.include	"tn15def.inc"

;To hold 32 bit answer
.DEF ANS1 = R20              
.DEF ANS2 = R21
.DEF ANS3 = R22
.DEF ANS4 = R23
;To hold 32 bit answer

;hold 32bit old power value
.def POWEROLD1 = r8
.def POWEROLD2 = r9
.def POWEROLD3 = r10
.def POWEROLD4 = r11
;hold 32bit old power value

;hold 32bit new power value
.def POWERNEW1 = r12
.def POWERNEW2 = r13
.def POWERNEW3 = r14
.def POWERNEW4 = r15
;hold 32bit new power value

.org 0x00
    rjmp reset	

reset: ;init 

      ;set pb1 to output
      ldi r16, PB1
	  out DDRB,r16
	  ;set pb1 to output

	  ;set pwm to 100%
	  ldi r16,0xFF
	  out OCR1A,r16
	  ;set pwm to 100%

	  ;set timer to 150khz pwm mode
	  ldi r16,0b01100001
      out TCCR1,r16
	  ;set timer to 150khz pwm mode

	  rcall p_measure

	  mov POWEROLD1, ANS1
	  mov POWEROLD2, ANS2
	  mov POWEROLD3, ANS3
	  mov POWEROLD4, ANS4
	  
	  rjmp main

main:;forever loop
decpwm:
    in r16, OCR1A
	dec r16
	out OCR1A, r16

	rcall p_measure
    mov POWERNEW1,ANS1
	mov POWERNEW2,ANS2
	mov POWERNEW3,ANS3
	mov POWERNEW4,ANS4

	cp  POWEROLD1,POWERNEW1
	cpc POWEROLD2,POWERNEW2
	cpc POWEROLD3,POWERNEW3
	cpc POWEROLD4,POWERNEW4
	   brlo recnewvalue1

incpwm:
    in r16, OCR1A
	inc r16
	out OCR1A, r16

	rcall p_measure
    mov POWERNEW1, ANS1
	mov POWERNEW2, ANS2
	mov POWERNEW3, ANS3
	mov POWERNEW4, ANS4

	cp  POWEROLD1,POWERNEW1
	cpc POWEROLD2,POWERNEW2
	cpc POWEROLD3,POWERNEW3
	cpc POWEROLD4,POWERNEW4
	   brlo recnewvalue2  

	rjmp main

recnewvalue1:
    mov POWEROLD1,POWERNEW1
	mov POWEROLD2,POWERNEW2
	mov POWEROLD3,POWERNEW3
	mov POWEROLD4,POWERNEW4
	   rjmp decpwm

recnewvalue2:
    mov POWEROLD1,POWERNEW1
	mov POWEROLD2,POWERNEW2
	mov POWEROLD3,POWERNEW3
	mov POWEROLD4,POWERNEW4
	   rjmp incpwm

p_measure:
	ldi			r16,0b11000111		; Internal ref + cap dif input with 20x gain (adc2+adc3)
	rcall		convert_average			; Measure Current
	mov			r4, r0				; Record low
	mov			r5, r1				; Record high

	ldi			r16,0b11000001		; Internal ref + cap
	rcall		convert_average			; Measure Voltage
	mov			r6, r0              ; Record low
	mov			r7, r1				; Record high

mul16:
        clr      ANS3             ;Set high bytes of result to zero            
        clr      ANS4             ;
        ldi      r16,16             ;Bit Counter
loop:   lsr      r4               ;Shift Multiplier to the right
        ror      r5               ;Shift lowest bit into Carry Flag
         brcc    skip           ;If carry is zero skip addition 
        add      ANS3,r6          ;Add Multiplicand into high bytes
        adc      ANS4,r7          ;of the Result
skip:   ror      ANS4             ;Rotate high bytes of result into
        ror      ANS3             ;the lower bytes
        ror      ANS2             ;
        ror      ANS1             ;
        dec      r16              ;Check if all 16 bits handled
         brne    loop           ;If not then loop back
         ret                  ; return to main



convert_average:
	out			ADMUX, r16				; Set ADC Parameters

	clr			r0
	clr			r1					; Clear Average Registers
	ldi			r17,16 	; Set loop counter
 	ldi		 	r16,0b11010100 ; CK/16 
	out			ADCSR,r16

convert_start:
	sbi			ADCSR, ADSC				; Start A/D Conversions

convert_wait:
	sbis		ADCSR, ADIF
	rjmp		convert_wait			; Wait for Conversion to finish

	in			r16, ADCL
	add			r0, r16
	in			r16, ADCH
	adc			r1, r16				; Add measured value to average
	
	dec			r17
	brne		convert_start			; Repeat 16 times
	
	ldi			r17, 4		; Set shift counter
convert_avg:	
	lsr			r1
	ror			r0					; r1:r0 = r1:r0/2
	dec			r17
	brne		convert_avg				; Repeat 4 times

	cbi			ADCSR,ADEN
	   ret									; return to measure