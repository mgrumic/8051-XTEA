;********************************************************************************************************************************
;*												
;*	
;*	 			SERIJSKA KOMUNIKACIJA SA PC RACUNAROM PREKO RS232 sa XTEA enkripcijom
;*	
;*
;********************************************************************************************************************************


E	EQU	p2.1			; definisanje simbolickog imena za pin p2.1
RS	EQU	p2.0			; definisanje simbolickog imena za pin p2.0
					; RW nepotreban, radimo samo upisivanje
D4	EQU	p2.2			; DATA pinovi LCD display-a
D5	EQU	p2.3
D6	EQU	p2.4
D7	EQU	p2.5
lcd_port EQU p2				; definisanje simbolickog imena za lcd port

Button_A EQU p1.0			; predefinisan pin za slovo 'A'
Button_W EQU p1.1			; predefinisan pin za slovo 'W'
Button_S EQU p1.2			; predefinisan pin za slovo 'S'
Button_D EQU p1.3			; predefinisan pin za slovo 'D'


;-------------------------------------------------------------------------------------------------------------------------------
;						DATA SEGMENT
;-------------------------------------------------------------------------------------------------------------------------------
DSEG  AT  30h
y0:   DS    1   ;y0 - y3 prva cetiri bajta XTEA buffer-a
y1:   DS    1
y2:   DS    1
y3:   DS    1
z0:   DS    1   ;z0 - z3 druga cetiri bajta XTEA buffer-a
z1:   DS    1
z2:   DS    1
z3:   DS    1
tmp0: DS    1   ;tmp buffer za potrebe XTEA enkripcije/dekripcije
tmp1: DS    1
tmp2: DS    1
tmp3: DS    1
sum0: DS    1   ;sum - za mixanje sum vrijednosti i za shuffelovanje
sum1: DS    1   ;indeksa bajta kljuca 
sum2: DS    1
sum3: DS    1
temp: DS    1   ;tmp pomocna promjenjiva
disp_counter: DS    1 ; counter modula 16 koliko karaktera smo do sada upisali na LCD
rec_char:     DS    1 ; promjenjiva u koju smjestamo primljeni dekriptovan karakter
rec_byte:     DS    1 ; counter modula 8 koliko bajtova smo primili preko RS232
;-------------------------------------------------------------------------------------------------------------------------------
;						KODNI SEGMENT
;-------------------------------------------------------------------------------------------------------------------------------

CSEG

	org 0000h
		jmp POCETAK
	org 0003h
		reti
	org 000bh
		reti
	org 0013h
		reti
	org 001bh
		reti
	org 0023h
		jmp SERIJSKA ; serijska prekidna servisna rutina
	org 002bh
		reti

ORG 0050h

POCETAK:
	call init_display	; pozivamo potprogram za inicijalizaciju displeja
	mov rec_byte, #00h
	mov p0, #0FFh
	mov disp_counter, #80h
	mov p1, #0FFh
	mov	tmod,#20h	; tajmer 1 u auto modu
	mov	th1,#0A9h	; 300 baud rate
	mov	scon,#50h	; inicijalizacija serijske komunikacije
	mov	ie,#90h		; omogucenje prekida serijske komunikacije
	setb	tr1		; startovanje tajmera 1
	mov r3, #00h
	jmp PETLJA
	
; Potprogram za resetovanje XTEA buffera
NULIRAJ:
	mov y0, #00h
	mov y1, #00h
	mov y2, #00h
	mov y3, #00h
	mov z0, #00h
	mov z1, #00h
	mov z2, #00h
	mov z3, #00h
	ret

; Potprogram za slanje XTEA buffera na RS232
; delay nakon slanja svakog bajta, inace ne stigne prekidna rutina da ga obradi
; i posalje na RS232
SEND_BYTES:
	mov sbuf, y0
	call kasnjenje
	mov sbuf, y1
	call kasnjenje
	mov sbuf, y2
	call kasnjenje
	mov sbuf, y3
	call kasnjenje
	mov sbuf, z0
	call kasnjenje
	mov sbuf, z1
	call kasnjenje
	mov sbuf, z2
	call kasnjenje
	mov sbuf, z3
	call kasnjenje
	ret
;---------------------------------------------------------------------------------------------------------------------
;
;		PROGRAM SE VRTI U OVOJ PETLJI
;
;---------------------------------------------------------------------------------------------------------------------
PETLJA:
	mov r7, p1
	cjne r7, #0FFh, GO_GO_GO ; provjeravamo da li je stisnut bilo koji karakter za slanje
	mov r3, #00h
	jmp PETLJA
GO_GO_GO:
	call NULIRAJ
	
	cjne r3, #00h, PETLJA
	mov r3, #01h
	
	mov a, p1 ; provjeravamo koji karakter je pritisnut
	anl a, #001h
	jz A_PUSHED
	
	mov a, p1
	anl a, #002h
	jz W_PUSHED
	
	mov a, p1
	anl a, #004h
	jz S_PUSHED
	
	mov a, p1
	anl a, #008h
	jz D_PUSHED
	
	jmp PETLJA
A_PUSHED:
	mov y0, #041h
	jmp END_THIS
W_PUSHED:
	mov y0, #057h
	jmp END_THIS
S_PUSHED:	
	mov y0, #053h
	jmp END_THIS
D_PUSHED:	
	mov y0, #044h
	;jmp END_THIS ; u sustini nam ne treba jmp ovde
END_THIS:
	call EXTea
	call SEND_BYTES
	jmp PETLJA

;-------------------------------------------------------------------
;
;		POTPROGRAM ZA OPSLUZIVANJE PREKIDA SERIJSKOG PORTA
;
;-------------------------------------------------------------------

SERIJSKA:
	jb ri, PRIJEM	; ako je ri setovan radi se o prijemu u suprotnom o predaji podatka
	clr ti		; mora se softverski obrisati
	RETI		; vracanje iz potprograma

PRIJEM:
	mov rec_char, sbuf ; preuzimamo karakter iz sbuf
	mov a, rec_byte
	cjne a, #00h, dalje1 ; provjeravamo koji karakter smo dobili
	mov y0, rec_char
	jmp die_ende
dalje1:
	cjne a, #01h, dalje2
	mov y1, rec_char
	jmp die_ende
dalje2:
	cjne a, #02h, dalje3
	mov y2, rec_char
	jmp die_ende
dalje3:
	cjne a, #03h, dalje4
	mov y3, rec_char
	jmp die_ende
dalje4:
	cjne a, #04h, dalje5
	mov z0, rec_char
	jmp die_ende
dalje5:
	cjne a, #05h, dalje6
	mov z1, rec_char
	jmp die_ende
dalje6:
	cjne a, #06h, dalje7
	mov z2, rec_char
	jmp die_ende
dalje7:
	mov z3, rec_char
	call DXtea
	mov rec_char, y0
	call ispis
	mov rec_byte, #00h
	clr ri
	RETI
die_ende:
	inc rec_byte ; povecavamo broj primljenih bajtova
	clr ri		; mora se softverski obrisati
	RETI

;==============================================================================================================================
;
;							RS    E     D4    D5    D6    D7
;						PROGRAM 2.0 | 2.1 | 2.2 | 2.3 | 2.4 | 2.5 | 2.6 | 2.7
;							 0     1     1    1      0    0      0     0   
;
;==============================================================================================================================
RESET_LCD:
	mov lcd_port, #11111111b
	call kasnjenje
	
	mov lcd_port, #00001110b
	call kasnjenje
	
	mov lcd_port, #00001100b
	call kasnjenje
	
	mov lcd_port, #00001110b
	call kasnjenje
	mov lcd_port, #00001100b
	call kasnjenje
	
	mov lcd_port, #00001110b
	call kasnjenje
	
	mov lcd_port, #00001100b
	call kasnjenje
	
	mov lcd_port, #00001010b
	call kasnjenje
	
	mov lcd_port, #00001000b
	call kasnjenje
	
	ret

LCD_CMD:
	mov temp, a
	swap a
	anl a, #0Fh
	rl a
	rl a
	add a, #02h
	mov lcd_port, a
	clr E
	call kasnjenje
	
	mov a, temp
	anl a, #0Fh
	rl a
	rl a
	add a, #02h
	mov lcd_port, a
	clr E
	call kasnjenje
ret

LCD_DATA:
	mov temp, a
	swap a
	anl a, #0Fh
	rl a
	rl a
	add a, #03h
	mov lcd_port, a
	nop
	clr E
	call kasnjenje
	
	mov a, temp
	anl a, #0Fh
	rl a
	rl a
	add a, #03h
	mov lcd_port, a
	nop
	clr E
	call kasnjenje
ret

INIT_DISPLAY:
	call RESET_LCD
	mov a, #028h
	call LCD_CMD
	mov a, #01h
	call LCD_CMD
	mov a, #0Fh
	call LCD_CMD
	mov a, #006h
	call LCD_CMD
	mov a, #080h
	call LCD_CMD
 RET

;=====================================================================================================
;
;		POTPROGRAM KOJI ISPISUJE KARAKTER IZ AKUMULATORA NA LCD-a
;
;=====================================================================================================

ISPIS:
	mov r0, disp_counter
	cjne r0, #090h, nope1 ; kraj prvog reda
	mov r0, #0C0h ; 
	jmp nope
	nope1:
	cjne r0, #0D0h, nope ; kraj drugog reda
	mov a, #01h ; brisemo display jer je popunjen
	call LCD_CMD
	mov r0, #080h
	nope:	
	mov	a,r0
	call LCD_CMD
	mov	a, rec_char
	call LCD_DATA
	inc r0
	mov disp_counter, r0
RET


;---------------------------------------------------------------------------------------------------------------------
;
;		XTEA encrypt
;
;---------------------------------------------------------------------------------------------------------------------

EXTea:
      clr   a
      mov   sum0,a   ;sum = 0
      mov   sum1,a
      mov   sum2,a
      mov   sum3,a 
      mov   r2,#32*2   ;nr of rounds *2 (because of trick with twice the main code, one for y and one for z; and another inside...)

      mov   dptr,#key  ;dptr se ne mijenja
ETeaRound:            

      mov   r4,z0
      mov   r5,z1
      mov   r6,z2
      mov   r7,z3
      
ETeaSubRound:
      mov   r0,#tmp3    ;tmp = z << 4 
      mov   a,r7
      swap  a
      mov   @r0,a            ;@r0=tmp3
      mov   a,r6
      swap  a
      xchd  a,@r0            ;@r0=tmp3
      dec   r0
      mov   @r0,a            ;@r0=tmp2
      mov   a,r5
      swap  a
      xchd  a,@r0            ;@r0=tmp2
      dec   r0
      mov   @r0,a            ;@r0=tmp1
      mov   a,r4
      swap  a
      xchd  a,@r0            ;@r0=tmp1
      mov   tmp0,a
      anl   tmp0,#0F0h        

      rrc   a              ;tmp ^=  z >> 5
      anl   a,#07h
      xrl   a,tmp3
      xch   a,tmp3
      rrc   a 
      xrl   a,tmp2
      xch   a,tmp2
      rrc   a 
      xrl   a,@r0  ;tmp1
      xch   a,@r0  ;tmp1
      rrc   a 
      xrl   a,tmp0


      add   a,r4         ;z = z+tmp
      mov   r4,a
      mov   a,r5
      addc  a,tmp1
      mov   r5,a
      mov   a,r6
      addc  a,tmp2
      mov   r6,a
      mov   a,r7
      addc  a,tmp3
      mov   r7,a

      mov   a,r2
      jb    acc.0,ETeaX1
      mov   a,sum0         ;r0 = [sum&3]
      rl    a
      rl    a
      sjmp  ETeaX2
ETeaX1:
      mov   a,sum1         ;r0 = [sum>>11&3]
      rr    a
ETeaX2:
      anl   a,#0Ch
      mov   r0,a

      movc  a,@a+dptr      ;result ^= sum + k[pointer]
      inc   r0
      add   a,sum0
      xrl   a,r4
      mov   r4,a
      mov   a,r0
      movc  a,@a+dptr
      inc   r0
      addc  a,sum1
      xrl   a,r5
      mov   r5,a
      mov   a,r0
      movc  a,@a+dptr
      inc   r0
      addc  a,sum2
      xrl   a,r6
      mov   r6,a
      mov   a,r0
      movc  a,@a+dptr
      addc  a,sum3
      xrl   a,r7
      mov   r7,a

      dec   r2
      mov   a,r2
      jb    acc.0,ETeaSubRound2

      mov   a,r4
      add   a,z0
      mov   z0,a
      mov   a,r5
      addc  a,z1
      mov   z1,a
      mov   a,r6
      addc  a,z2
      mov   z2,a
      mov   a,r7
      addc  a,z3
      mov   z3,a

      cjne  r2,#0,ETeaRoundA
      ret            
ETeaRoundA:
      jmp   ETeaRound

ETeaSubRound2:      
      mov   a,r4
      add   a,y0
      mov   y0,a
      mov   r4,a
      mov   a,r5
      addc  a,y1
      mov   y1,a
      mov   r5,a
      mov   a,r6
      addc  a,y2
      mov   y2,a
      mov   r6,a
      mov   a,r7
      addc  a,y3
      mov   y3,a
      mov   r7,a

      mov   a,sum0   ;sum += delta
      add   a,#0B9h    ;delta[0]
      mov   sum0,a
      mov   a,sum1
      addc  a,#079h    ;delta[1]
      mov   sum1,a
      mov   a,sum2
      addc  a,#037h    ;delta[2]
      mov   sum2,a
      mov   a,sum3
      addc  a,#09Eh    ;delta[3]
      mov   sum3,a
 
      jmp   ETeaSubRound
;---------------------------------------------------------------------------------------------------------------------
;
;		XTEA decrypt
;
;---------------------------------------------------------------------------------------------------------------------
DXTea:
      mov   r2,#32*2   ;nr of rounds *2 (because of trick with twice the main code, one for y and one for z; and another inside...)
      mov   sum3,#0C6h   
      mov   sum2,#0EFh
      mov   sum1,#037h
      mov   sum0,#020h 

      mov   dptr,#key  ;dptr se ne mijanja
DTeaRound:            

      mov   r4,y0
      mov   r5,y1
      mov   r6,y2
      mov   r7,y3
      
DTeaSubRound:
      mov   r0,#tmp3    ;tmp = y << 4 
      mov   a,r7
      swap  a
      mov   @r0,a            ;@r0=tmp3
      mov   a,r6
      swap  a
      xchd  a,@r0            ;@r0=tmp3
      dec   r0
      mov   @r0,a            ;@r0=tmp2
      mov   a,r5
      swap  a
      xchd  a,@r0            ;@r0=tmp2
      dec   r0
      mov   @r0,a            ;@r0=tmp1
      mov   a,r4
      swap  a
      xchd  a,@r0            ;@r0=tmp1
      mov   tmp0,a
      anl   tmp0,#0F0h        

      rrc   a              ;tmp ^=  y >> 5
      anl   a,#07h
      xrl   a,tmp3
      xch   a,tmp3
      rrc   a 
      xrl   a,tmp2
      xch   a,tmp2
      rrc   a 
      xrl   a,@r0  ;tmp1
      xch   a,@r0  ;tmp1
      rrc   a 
      xrl   a,tmp0

      add   a,r4         ;y = y+tmp
      mov   r4,a
      mov   a,r5
      addc  a,tmp1
      mov   r5,a
      mov   a,r6
      addc  a,tmp2
      mov   r6,a
      mov   a,r7
      addc  a,tmp3
      mov   r7,a

      mov   a,r2
      jnb   acc.0,DTeaX1
      mov   a,sum0         ;r0 = [sum&3]
      rl    a
      rl    a
      sjmp  DTeaX2
DTeaX1:
      mov   a,sum1         ;r0 = [sum>>11&3]
      rr    a
DTeaX2:
      anl   a,#0Ch
      mov   r0,a

      movc  a,@a+dptr      ;result ^= sum + k[pointer]
      inc   r0
      add   a,sum0
      xrl   a,r4
      mov   r4,a
      mov   a,r0
      movc  a,@a+dptr
      inc   r0
      addc  a,sum1
      xrl   a,r5
      mov   r5,a
      mov   a,r0
      movc  a,@a+dptr
      inc   r0
      addc  a,sum2
      xrl   a,r6
      mov   r6,a
      mov   a,r0
      movc  a,@a+dptr
      addc  a,sum3
      xrl   a,r7
      mov   r7,a

      dec   r2
      mov   a,r2
      jb    acc.0,DTeaSubRound2

      clr   c
      mov   a,y0
      subb  a,r4
      mov   y0,a
      mov   a,y1
      subb  a,r5
      mov   y1,a
      mov   a,y2
      subb  a,r6
      mov   y2,a
      mov   a,y3
      subb  a,r7
      mov   y3,a

      cjne  r2,#0,DTeaRoundA
      ret            
DTeaRoundA:
      jmp   DTeaRound

DTeaSubRound2:  
      clr   c    
      mov   a,z0
      subb  a,r4
      mov   z0,a
      mov   r4,a
      mov   a,z1
      subb  a,r5
      mov   z1,a
      mov   r5,a
      mov   a,z2
      subb  a,r6
      mov   z2,a
      mov   r6,a
      mov   a,z3
      subb  a,r7
      mov   z3,a
      mov   r7,a

      clr   c
      mov   a,sum0   ;sum += delta
      subb  a,#0B9h    ;delta[0]
      mov   sum0,a
      mov   a,sum1
      subb  a,#079h    ;delta[1]
      mov   sum1,a
      mov   a,sum2
      subb  a,#037h    ;delta[2]
      mov   sum2,a
      mov   a,sum3
      subb  a,#09Eh    ;delta[3]
      mov   sum3,a
 
      jmp   DTeaSubRound
 


;---------------------------------------------------------------------------------------------------------------------
;
;		End XTEA
;
;---------------------------------------------------------------------------------------------------------------------

Key:  
      db    09fh, 012h, 0abh, 099h
      db    0fah, 0e6h, 0e1h, 04dh
      db    000h, 0b1h, 0e8h, 0bbh 
      db    0f3h, 08eh, 088h, 0fah 
;KEY: 0x9f12ab99
;     0xfae6e14d
;     0x00b1e8bb
;     0xf38e88fa 

;===================================================================================================================
;
;	POTPROGRAM ZA KASNJENJE
;
;==================================================================================================================

KASNJENJE:
	
	mov 	r4	,	#1

KASNJENJE3:

	mov 	r2	,	#200

KASNJENJE2:
	
	mov 	r1	,	#210

KASNJENJE1:
	
	djnz 	r1	,	KASNJENJE1
	
	djnz 	r2	,	KASNJENJE2
	
	djnz 	r4	,	KASNJENJE3
	
	ret
	
END	
	
	
	