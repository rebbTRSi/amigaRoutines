;APS0000144D0000144D0000144D0000144D0000144D0000144D0000144D0000144D0000144D0000144D
;
; input & display disabling startup code v1.0.2
;
; minimum requirements: 68000, OCS, Kickstart 1.2
; compiles with genam and phxass.
;
; Written by Harry Sintonen. Public Domain.
; thanks to _jackal & odin-_ for testing.
;

	INCDIR  "dh0:asm/include_i/"
	include "exec/types.i"
	include "exec/nodes.i"
	include "exec/ports.i"
	include "exec/lists.i"
	include "devices/input.i"
	include "devices/inputevent.i"
	include "graphics/gfxbase.i"
	include "dos/dosextens.i"
	include "dos/dos.i"

_LVODisable		EQU	-120
_LVOEnable		EQU	-126
_LVOForbid		EQU	-132
_LVOPermit		EQU	-138
_LVOFindTask		EQU	-294
_LVOAllocSignal		EQU	-330
_LVOFreeSignal		EQU	-336
_LVOGetMsg		EQU	-372
_LVOReplyMsg		EQU	-378
_LVOWaitPort		EQU	-384
_LVOCloseLibrary	EQU	-414
_LVOOpenDevice		EQU	-444
_LVOCloseDevice		EQU	-450
_LVODoIO		EQU	-456
_LVOOpenLibrary		EQU	-552

_LVOLoadView		EQU	-222
_LVOWaitBlit		EQU	-228
_LVOWaitTOF		EQU	-270

;	IF	FROMC
;	XREF	_main
;	ENDC

_entry:
	movem.l	d0/a0,_args
	move.l	4.w,a6
	moveq	#RETURN_FAIL,d7

	; handle wb startup
	sub.l	a1,a1
	jsr	_LVOFindTask(a6)
	move.l	d0,a2
	tst.l	pr_CLI(a2)
	bne.s	.iscli
	lea	pr_MsgPort(a2),a0
	jsr	_LVOWaitPort(a6)
	lea	pr_MsgPort(a2),a0
	jsr	_LVOGetMsg(a6)
	move.l	d0,_WBenchMsg
.iscli:
	; init msgport
	moveq	#-1,d0
	jsr	_LVOAllocSignal(a6)
	move.b	d0,_sigbit
	bmi	.nosignal
	move.l	a2,_sigtask

	; hide possible requesters since user has no way to
	; see or close them.
	moveq	#-1,d0
	move.l	pr_WindowPtr(a2),_oldwinptr
	move.l	d0,pr_WindowPtr(a2)

	; open input.device
	lea	.inputname(pc),a0
	moveq	#0,d0
	moveq	#0,d1
	lea	_ioreq(pc),a1
	jsr	_LVOOpenDevice(a6)
	tst.b	d0
	bne	.noinput

	; install inputhandler
	lea	_ioreq(pc),a1
	move.w	#IND_ADDHANDLER,IO_COMMAND(a1)
	move.l	#_ih_is,IO_DATA(a1)
	jsr	_LVODoIO(a6)

	; open graphics.library
	lea	.gfxname(pc),a1
	moveq	#33,d0			; Kickstart 1.2 or higher
	jsr	_LVOOpenLibrary(a6)
	move.l	d0,_GfxBase
	beq	.nogfx
	move.l	d0,a6

	; save old view
	move.l	gb_ActiView(a6),_oldview

	; flush view
	sub.l	a1,a1
	jsr	_LVOLoadView(a6)
	jsr	_LVOWaitTOF(a6)
	jsr	_LVOWaitTOF(a6)

	; do the stuff
	movem.l	_args(pc),d0/a0
	bsr	_main
	move.l	d0,d7

	move.l	_GfxBase,a6

	; restore view & copper ptr
	sub.l	a1,a1
	jsr	_LVOLoadView(a6)
	move.l	_oldview(pc),a1
	jsr	_LVOLoadView(a6)
	move.l	gb_copinit(a6),$DFF080
	jsr	_LVOWaitTOF(a6)
	jsr	_LVOWaitTOF(a6)

	; close graphics.library
	move.l	a6,a1
	move.l	4.w,a6
	jsr	_LVOCloseLibrary(a6)

.nogfx:
	; remove inputhandler
	lea	_ioreq(pc),a1
	move.w	#IND_REMHANDLER,IO_COMMAND(a1)
	move.l	#_ih_is,IO_DATA(a1)
	jsr	_LVODoIO(a6)

	lea	_ioreq(pc),a1
	jsr	_LVOCloseDevice(a6)

.noinput:
	move.l	_sigtask(pc),a0
	move.l	_oldwinptr(pc),pr_WindowPtr(a0)

	moveq	#0,d0
	move.b	_sigbit(pc),d0
	jsr	_LVOFreeSignal(a6)

.nosignal:
	move.l	_WBenchMsg(pc),d0
	beq.s	.notwb
	move.l	a0,a1
	jsr	_LVOForbid(a6)
	jsr	_LVOReplyMsg(a6)

.notwb:
	move.l	d7,d0
	rts


.inputname:
	dc.b	'input.device',0
.gfxname:
	dc.b	'graphics.library',0


	CNOP	0,4

_args:
	dc.l	0,0
_oldwinptr:
	dc.l	0
_WBenchMsg:
	dc.l	0
_GfxBase:
	dc.l	0
_oldview:
	dc.l	0

_msgport:
	dc.l	0,0		; LN_SUCC, LN_PRED
	dc.b	NT_MSGPORT,0	; LN_TYPE, LN_PRI
	dc.l	0		; LN_NAME
	dc.b	PA_SIGNAL	; MP_FLAGS
_sigbit:
	dc.b	-1		; MP_SIGBIT
_sigtask:
	dc.l	0		; MP_SIGTASK
.head:
	dc.l	.tail		; MLH_HEAD
.tail:
	dc.l	0		; MLH_TAIL
	dc.l	.head		; MLH_TAILPRED

_ioreq:
	dc.l	0,0		; LN_SUCC, LN_PRED
	dc.b	NT_REPLYMSG,0	; LN_TYPE, LN_PRI
	dc.l	0		; LN_NAME
	dc.l	_msgport	; MN_REPLYPORT
	dc.w	IOSTD_SIZE	; MN_LENGTH
	dc.l	0		; IO_DEVICE
	dc.l	0		; IO_UNIT
	dc.w	0		; IO_COMMAND
	dc.b	0,0		; IO_FLAGS, IO_ERROR
	dc.l	0		; IO_ACTUAL
	dc.l	0		; IO_LENGTH
	dc.l	0		; IO_DATA
	dc.l	0		; IO_OFFSET

_ih_is:
	dc.l	0,0		; LN_SUCC, LN_PRED
	dc.b	NT_INTERRUPT,127	; LN_TYPE, LN_PRI ** highest priority ** 
	dc.l	.ih_name	; LN_NAME
	dc.l	0		; IS_DATA
	dc.l	.ih_code	; IS_CODE

.ih_code:
	move.l	a0,d0
.loop:
	move.b	#IECLASS_NULL,ie_Class(a0)
	move.l	(a0),a0
	move.l	a0,d1
	bne.b	.loop

	; d0 is the original a0
	rts

.ih_name:
	dc.b	'eat-events inputhandler',0

	CNOP	0,4

;
; _main can poke display registers and copper. all user input
; is swallowed, but task scheduling and system interrupts are
; running normally.
;
; _main MUST allocate further hardware resources it uses:
; blitter, audio, potgo, cia registers (timers, mouse &
; joystick). do not make any assumptations about the initial
; value of any hardware register.
;
; if full interrupt control is desired, _main must _LVODisable,
; save intenar and disable all interrupts by writing $7fff to
; intena. to restore, write $7fff to intena, or $8000 to saved
; intenar value and write it to intena, and finally _LVOEnable.
;
; if dma register control is desired, the same procedure is
; required, but this time for dmaconr and dmacon.
;
; the code poking interrupt-vectors must be aware of 68010+ VBR
; register. interrupt code satisfying an interrupt request must
; write the intreq and 'nop' to avoid problems with fast 040 and
; 060 systems.
;
; selfmodifying code must be aware of 020/030 and 040 caches
; (040 cacheflush handles 060 too).
;

;	IF	FROMC;
;
;	XDEF	_WBenchMsg

;	ELSE

;
;  in: a0.l  UBYTE *argstr
;      d0.l  LONG   arglen
; out: d0.l  LONG   returncode
;
_main:

;One lores screen line takes 40 bytes per bitplane (320 pixels/8)

;plane 1 1st line (40 bytes)
;plane 1 2nd line
;plane 1 3rd
;plane 1 4th

;plane 2 1st
;plane 2 2nd
;plane 2 3rd
;plane 2 4th

;plane 3 1st 
;etc

;we light up the pixel by setting the bit to 1 on planes determined by color
;like >

;10000000 00000000 00000000 00000000 00000000
 
;Plot routine takes x,y and c (color) as input.
;x and y determines where to pixel and color determines what planes to pixel.

;first we find the correct line to plot from y (there are 256 lines)
;then we change the needed bit determined by x on planes determined by c
;Color number tells directly what planes to pixel as follows:

;4 bitplane pic (16 colors)

;Planes  Col N    Planes to plot
;------  -----    --------------
;4321

;0000 -> col0	 plot zero
;0001 m> col1	 plot 1 to plane 1
;0010 -> col2	 plot 1 to plane 2
;0011 -> col3    plot 1 to plane 1 and 2
;0100 -> col4	 plot 1 to plane 3
;0101 -> col5	 plot 1 to plane 3 and 1
;0110 -> col6	 plot 1 to plane 2 and 3
;0111 -> col7 	 plot 1 to plane 1,2 and 3
;1000 -> col8	 plot 1 to plane 4
;1001 -> col9	 plot 1 to plane 4 and 1
;1010 -> col10	 plot 1 to plane 4 and 2
;1011 -> col11	 plot 1 to plane 1,2 and 4
;1100 -> col12	 plot 1 to plane 3 and 4
;1101 -> col13	 plot 1 to plane 1,3,4
;1110 -> col14	 plot 1 to plane 2,3,4
;1111 -> col15	 plot 1 to plane 1,2,3,4

;once we founded the right line:

;test bit 0 on color number if set, plot to the bit on plane 1 ->
;move to the start of next plane
;test bit 1 -> plot plane 2 if set -> move
;test bit 2 -> - " -      3	       -> move
;test bit 3 -> - " -      4	       -> move
;and we are done

	include "a5levy1:sourcet/custom.i"


	move.l #bplane,d0 
	lea bplcop,a0 ;fill copperlist bitplane 
	moveq #4,d1 ;loop 5 times (= number of bitplanes) 


bplloop: 
	move.w d0,6(a0) 
	swap d0 
	move.w d0,2(a0) 
	swap d0 

	add.l #$2800,d0 ;size bitplane= 40bytes*256lines= 10240 ($2800) 
	addq #8,a0 
	dbra d1,bplloop ;next bitplane 

	move.l #copper,$dff080 
	move.w #0,$dff088 

	move.l	#custom,a6
	move.l	$6c,oldvbi
	move.w	intenar(a6),oldintena

	move.w	#%0011111111111111,intena(a6)
	move.l	#vbi,$6c
	move.w	#%1000000000100000,intena(a6)


	move.l #0,d1
	move.l #0,d2
	move.l #0,d3
	move.l #0,d4
	move.l #0,d5
	move.w #0,x
	move.w #0,y
	lea    sintable,a3

byy:	
	move.w x,d4
	move.w y,d5	
	add.w  d4,d5
	move.w (a3,d4.w*2),d2 ; sin x
	asr.w  #8,d2
	move.w (a3,d5.w*2),d3 ; sin y
	asr.w  #8,d3
	sub.w  d3,d2
	add.w  #180,d4
 	
	move.w (a3,d4.w*2),d5
	asr.w  #8,d5
	sub.w  d5,d2
	asr    #3,d2

	add.w  #2,x
	move.w d2,d0
	cmp.w  #1,d0
	bhs    kusi1
	move.w #1,d0


kusi1:	move.l d0,c
	move.w y,d2

	move.l #bplane,a0
;	add.l  #100*40,a0
	jsr    plot

	move.l #0,d4
	move.l #0,d5
	add.l  #1,d1
	cmp.l  #320,d1
	bne    byy

	move.w #0,d1
	move.w #0,x
	add.w  #1,y
	cmp    #255,y
	bne    byy


mouse:	btst #6,$bfe001		; check for mouse
	bne.b mouse	 	; jump if not pressed

	move.w	#%00111111111111111,intena(a6)
	move.l	oldvbi,$6c
	move.w	oldintena,d0
	or.w	#$8000,d0
	move.w	d0,intena(a6)

	moveq	#RETURN_OK,d0

	rts


vbi:	movem.l	d0-d7/a0-a6,-(a7)

	addq	#1,sarja
	cmp	#2,sarja
	bne	iout

jatq:
	move.l #0,sarja
	move.l #0,d1		; clr d1
	lea    colorcop,a0	; load first bar to a0
	move.l #$7e,d0		; get last color to d4

	move.l d0,d5		; store d4 to d5 - " -
	move.w (a0,d0.w),eka	; store color component to eka
	move.w eka,d7
loop:	

	subq   #4,d0
	move.w (a0,d0.w),d1	; - " -			    d1
	move.w d1,(a0,d5.w)	; store it to next color cell
	subq   #4,d5		; add      4 to   d5 - " -

	cmp    #$6,d0		; compare if we have moven all colors once
	bne    loop		; if not jump
	move.w eka,(a0,d0)	; store the last value to first

	lea    colorcop,a0	; get start of bar
iout:
	move.w	#%0000000000100000,intreq(a6)

	movem.l	(a7)+,d0-d7/a0-a6
	rte



	rts

plot:
	;takes d0=color,d1=x,d2=y,a0=bplane


findy:  
	mulu.w	#40,d2	; multiply y with 40 to get add factor for bitplane
	add.l	d2,a0   ; start address for correct line
	
checkplane:
	move.l  c,d0
	btst.l	#0,d0	; testbit on colorvalue to get planes to plot
	beq	Plane2
	jsr	pixset

plane2:
	move.l	#bplane,a0 ; bitplane address to a0
;	add.l   #100*40,a0
	add.l	d2,a0   ; start address for correct line
	add.l	#40*256*1,a0 ; address of plane	
	move.l  c,d0
	btst.l  #1,d0	    
	beq 	plane3
	jsr	pixset


;	move.l  #$fff,$dff180
					
plane3:
	move.l	#bplane,a0
;	add.l  #100*40,a0
	add.l	d2,a0   ; start address for correct line
	add.l	#40*256*2,a0	
	move.l  c,d0
	btst.l	#2,d0
	beq	plane4
	jsr	pixset

plane4:

	move.l	#bplane,a0
;	add.l  #100*40,a0
	add.l	d2,a0 
	add.l	#40*256*3,a0	

	move.l  c,d0
	btst.l  #3,d0
	beq     plane5
	jsr	pixset
	


plane5:

	move.l	#bplane,a0
;	add.l  #100*40,a0
	add.l	d2,a0   ; start address for correct line
	add.l	#40*256*4,a0	
	move.l  c,d0
	btst.l	#4,d0
	beq 	out
	jsr	pixset


out:
	rts

pixset:
	move.l	d1,d4		; copy x to d4
	move.l	d1,d5		; and d5
	move.l	d1,d3		; and d3
	lsr.l	#3,d3		; divide with 8 to get number of byte
	add.l	d3,a0		; get to the byte we are changing

	asl.l	#3,d3		; How many times did x fit in 8?
	cmp	#0,d3		; If zero, x is directly the bits to set
	beq	nolla		;
	sub.l   d3,d4		; Substract multiply of 8 from original x
	move.l	d4,d5		; to get pixel number
nolla:  
	
	move.l  #7,d6		; substract 7 from pixel number
	sub	d5,d6		; to get right bit
	bset	d6,(a0)		; set the "d6 th bit" on a0  


	rts

	section Rebb_data,data_c

copper: 
	dc.w	$0106,$0000,$01fc,$0000		; AGA compatible
	dc.w	$0102,$0000,$0104,$0000
	dc.w	$0106,$0000,$0108,$0000
	dc.w	$0120,$0000,$0122,$0000		; Clear spriteptrs
	dc.w	$0124,$0000,$0126,$0000
	dc.w	$0128,$0000,$012a,$0000
	dc.w	$012c,$0000,$012e,$0000
	dc.w	$0130,$0000,$0132,$0000
	dc.w	$0134,$0000,$0136,$0000
	dc.w	$0138,$0000,$013a,$0000
	dc.w	$013c,$0000,$013e,$0000
	
	dc.w $0100,%0101000000000000		; 5 bitplanes 
	dc.w $0102,$0000 
	dc.w $0104,$0000 
	dc.w $0108,$0000 
	dc.w $010a,$0000 
	dc.w $008e,$2c81 
	dc.w $0090,$2cc1 
	dc.w $0092,$0038 
	dc.w $0094,$00d0 

bplcop: 
	dc.w $00e0,$0000 ;address bitplane 1 (high 5 bits) 
	dc.w $00e2,$0000 ;address bitplane 1 (low 15 bits) 
	dc.w $00e4,$0000 ;address bitplane 2 
	dc.w $00e6,$0000 
	dc.w $00e8,$0000 
	dc.w $00ea,$0000 
	dc.w $00ec,$0000 ;address bitplane 4 
	dc.w $00ee,$0000 ;address bitplane 4 
	dc.w $00f0,$0000 
	dc.w $00f2,$0000 

colorcop: 

col1:	dc.w $180,$0000
	dc.w $182,$0005
	dc.w $184,$0006
	dc.w $186,$0007
	dc.w $188,$0009
	dc.w $18a,$000B
	dc.w $18c,$000F
	dc.w $18e,$002F
	dc.w $190,$0068
	dc.w $192,$0088
	dc.w $194,$00A7
	dc.w $196,$00A5
	dc.w $198,$00E5
	dc.w $19a,$00E0
	dc.w $19c,$06A3
	dc.w $19e,$0870
	dc.w $1a0,$0A60
	dc.w $1a2,$0A30
	dc.w $1a4,$0B20
	dc.w $1a6,$0F10
	dc.w $1a8,$0F00
	dc.w $1aa,$0F04
	dc.w $1ac,$0A06
	dc.w $1ae,$0906
	dc.w $1b0,$0606
	dc.w $1b2,$020B
	dc.w $1b4,$020F
	dc.w $1b6,$000F
	dc.w $1b8,$0009
	dc.w $1ba,$0008
	dc.w $1bc,$0004
	dc.w $1be,$0001
	;Generated by IFFMaster v1.0 by JUNIX / ARCANE!
	dc.w $ffff,$fffe
	
sintable:

	DC.W	$0300,$0400,$0600,$0700,$0900,$0B00,$0C00,$0E00,$0F00,$1100
	DC.W	$1200,$1400,$1600,$1700,$1900,$1A00,$1C00,$1D00,$1F00,$2100
	DC.W	$2200,$2400,$2500,$2700,$2800,$2A00,$2B00,$2D00,$2F00,$3000
	DC.W	$3200,$3300,$3500,$3600,$3800,$3900,$3B00,$3C00,$3E00,$3F00
	DC.W	$4100,$4200,$4400,$4600,$4700,$4900,$4A00,$4C00,$4D00,$4F00
	DC.W	$5000,$5200,$5300,$5500,$5600,$5800,$5900,$5A00,$5C00,$5D00
	DC.W	$5F00,$6000,$6200,$6300,$6500,$6600,$6800,$6900,$6A00,$6C00
	DC.W	$6D00,$6F00,$7000,$7200,$7300,$7400,$7600,$7700,$7900,$7A00
	DC.W	$7B00,$7D00,$7E00,$7F00,$8100,$8200,$8400,$8500,$8600,$8800
	DC.W	$8900,$8A00,$8C00,$8D00,$8E00,$9000,$9100,$9200,$9300,$9500
	DC.W	$9600,$9700,$9900,$9A00,$9B00,$9C00,$9E00,$9F00,$A000,$A100
	DC.W	$A300,$A400,$A500,$A600,$A700,$A900,$AA00,$AB00,$AC00,$AD00
	DC.W	$AF00,$B000,$B100,$B200,$B300,$B400,$B500,$B600,$B800,$B900
	DC.W	$BA00,$BB00,$BC00,$BD00,$BE00,$BF00,$C000,$C100,$C200,$C300
	DC.W	$C400,$C500,$C600,$C700,$C800,$C900,$CA00,$CB00,$CC00,$CD00
	DC.W	$CE00,$CF00,$D000,$D100,$D200,$D300,$D400,$D500,$D600,$D600
	DC.W	$D700,$D800,$D900,$DA00,$DB00,$DC00,$DC00,$DD00,$DE00,$DF00
	DC.W	$E000,$E000,$E100,$E200,$E300,$E300,$E400,$E500,$E600,$E600
	DC.W	$E700,$E800,$E800,$E900,$EA00,$EA00,$EB00,$EC00,$EC00,$ED00
	DC.W	$EE00,$EE00,$EF00,$EF00,$F000,$F100,$F100,$F200,$F200,$F300
	DC.W	$F300,$F400,$F400,$F500,$F500,$F600,$F600,$F700,$F700,$F800
	DC.W	$F800,$F900,$F900,$F900,$FA00,$FA00,$FB00,$FB00,$FB00,$FC00
	DC.W	$FC00,$FC00,$FD00,$FD00,$FD00,$FE00,$FE00,$FE00,$FE00,$FF00
	DC.W	$FF00,$FF00,$FF00,$0000,$0000,$0000,$0000,$0000,$0100,$0100
	DC.W	$0100,$0100,$0100,$0100,$0100,$0100,$0200,$0200,$0200,$0200
	DC.W	$0200,$0200,$0200,$0200,$0200,$0200,$0200,$0200,$0200,$0200
	DC.W	$0200,$0200,$0200,$0200,$0200,$0200,$0100,$0100,$0100,$0100
	DC.W	$0100,$0100,$0100,$0100,$0000,$0000,$0000,$0000,$0000,$FF00
	DC.W	$FF00,$FF00,$FF00,$FE00,$FE00,$FE00,$FE00,$FD00,$FD00,$FD00
	DC.W	$FC00,$FC00,$FC00,$FB00,$FB00,$FB00,$FA00,$FA00,$F900,$F900
	DC.W	$F900,$F800,$F800,$F700,$F700,$F600,$F600,$F500,$F500,$F400
	DC.W	$F400,$F300,$F300,$F200,$F200,$F100,$F100,$F000,$EF00,$EF00
	DC.W	$EE00,$EE00,$ED00,$EC00,$EC00,$EB00,$EA00,$EA00,$E900,$E800
	DC.W	$E800,$E700,$E600,$E600,$E500,$E400,$E300,$E300,$E200,$E100
	DC.W	$E000,$E000,$DF00,$DE00,$DD00,$DC00,$DC00,$DB00,$DA00,$D900
	DC.W	$D800,$D700,$D600,$D600,$D500,$D400,$D300,$D200,$D100,$D000
	DC.W	$CF00,$CE00,$CD00,$CC00,$CB00,$CA00,$C900,$C800,$C700,$C600
	DC.W	$C500,$C400,$C300,$C200,$C100,$C000,$BF00,$BE00,$BD00,$BC00
	DC.W	$BB00,$BA00,$B900,$B800,$B600,$B500,$B400,$B300,$B200,$B100
	DC.W	$B000,$AE00,$AD00,$AC00,$AB00,$AA00,$A900,$A700,$A600,$A500
	DC.W	$A400,$A300,$A100,$A000,$9F00,$9E00,$9C00,$9B00,$9A00,$9900
	DC.W	$9700,$9600,$9500,$9300,$9200,$9100,$9000,$8E00,$8D00,$8C00
	DC.W	$8A00,$8900,$8800,$8600,$8500,$8400,$8200,$8100,$7F00,$7E00
	DC.W	$7D00,$7B00,$7A00,$7900,$7700,$7600,$7400,$7300,$7200,$7000
	DC.W	$6F00,$6D00,$6C00,$6A00,$6900,$6800,$6600,$6500,$6300,$6200
	DC.W	$6000,$5F00,$5D00,$5C00,$5A00,$5900,$5800,$5600,$5500,$5300
	DC.W	$5200,$5000,$4F00,$4D00,$4C00,$4A00,$4900,$4700,$4600,$4400
	DC.W	$4200,$4100,$3F00,$3E00,$3C00,$3B00,$3900,$3800,$3600,$3500
	DC.W	$3300,$3200,$3000,$2F00,$2D00,$2B00,$2A00,$2800,$2700,$2500
	DC.W	$2400,$2200,$2100,$1F00,$1D00,$1C00,$1A00,$1900,$1700,$1600
	DC.W	$1400,$1200,$1100,$0F00,$0E00,$0C00,$0B00,$0900,$0700,$0600
	DC.W	$0400,$0300,$0100,$0000,$FE00,$FD00,$FB00,$F900,$F800,$F600
	DC.W	$F500,$F300,$F200,$F000,$EE00,$ED00,$EB00,$EA00,$E800,$E700
	DC.W	$E500,$E300,$E200,$E000,$DF00,$DD00,$DC00,$DA00,$D900,$D700
	DC.W	$D500,$D400,$D200,$D100,$CF00,$CE00,$CC00,$CB00,$C900,$C800
	DC.W	$C600,$C500,$C300,$C200,$C000,$BE00,$BD00,$BB00,$BA00,$B800
	DC.W	$B700,$B500,$B400,$B200,$B100,$AF00,$AE00,$AC00,$AB00,$AA00
	DC.W	$A800,$A700,$A500,$A400,$A200,$A100,$9F00,$9E00,$9C00,$9B00
	DC.W	$9A00,$9800,$9700,$9500,$9400,$9200,$9100,$9000,$8E00,$8D00
	DC.W	$8B00,$8A00,$8900,$8700,$8600,$8500,$8300,$8200,$8000,$7F00
	DC.W	$7E00,$7C00,$7B00,$7A00,$7800,$7700,$7600,$7400,$7300,$7200
	DC.W	$7100,$6F00,$6E00,$6D00,$6B00,$6A00,$6900,$6800,$6600,$6500
	DC.W	$6400,$6300,$6100,$6000,$5F00,$5E00,$5D00,$5B00,$5A00,$5900
	DC.W	$5800,$5700,$5500,$5400,$5300,$5200,$5100,$5000,$4F00,$4E00
	DC.W	$4C00,$4B00,$4A00,$4900,$4800,$4700,$4600,$4500,$4400,$4300
	DC.W	$4200,$4100,$4000,$3F00,$3E00,$3D00,$3C00,$3B00,$3A00,$3900
	DC.W	$3800,$3700,$3600,$3500,$3400,$3300,$3200,$3100,$3000,$2F00
	DC.W	$2E00,$2E00,$2D00,$2C00,$2B00,$2A00,$2900,$2800,$2800,$2700
	DC.W	$2600,$2500,$2400,$2400,$2300,$2200,$2100,$2100,$2000,$1F00
	DC.W	$1E00,$1E00,$1D00,$1C00,$1C00,$1B00,$1A00,$1A00,$1900,$1800
	DC.W	$1800,$1700,$1600,$1600,$1500,$1500,$1400,$1300,$1300,$1200
	DC.W	$1200,$1100,$1100,$1000,$1000,$0F00,$0F00,$0E00,$0E00,$0D00
	DC.W	$0D00,$0C00,$0C00,$0B00,$0B00,$0B00,$0A00,$0A00,$0900,$0900
	DC.W	$0900,$0800,$0800,$0800,$0700,$0700,$0700,$0600,$0600,$0600
	DC.W	$0600,$0500,$0500,$0500,$0500,$0400,$0400,$0400,$0400,$0400
	DC.W	$0300,$0300,$0300,$0300,$0300,$0300,$0300,$0300,$0200,$0200
	DC.W	$0200,$0200,$0200,$0200,$0200,$0200,$0200,$0200,$0200,$0200
	DC.W	$0200,$0200,$0200,$0200,$0200,$0200,$0200,$0200,$0300,$0300
	DC.W	$0300,$0300,$0300,$0300,$0300,$0300,$0400,$0400,$0400,$0400
	DC.W	$0400,$0500,$0500,$0500,$0500,$0600,$0600,$0600,$0600,$0700
	DC.W	$0700,$0700,$0800,$0800,$0800,$0900,$0900,$0900,$0A00,$0A00
	DC.W	$0B00,$0B00,$0B00,$0C00,$0C00,$0D00,$0D00,$0E00,$0E00,$0F00
	DC.W	$0F00,$1000,$1000,$1100,$1100,$1200,$1200,$1300,$1300,$1400
	DC.W	$1500,$1500,$1600,$1600,$1700,$1800,$1800,$1900,$1A00,$1A00
	DC.W	$1B00,$1C00,$1C00,$1D00,$1E00,$1E00,$1F00,$2000,$2100,$2100
	DC.W	$2200,$2300,$2400,$2400,$2500,$2600,$2700,$2800,$2800,$2900
	DC.W	$2A00,$2B00,$2C00,$2D00,$2E00,$2E00,$2F00,$3000,$3100,$3200
	DC.W	$3300,$3400,$3500,$3600,$3700,$3800,$3900,$3A00,$3B00,$3C00
	DC.W	$3D00,$3E00,$3F00,$4000,$4100,$4200,$4300,$4400,$4500,$4600
	DC.W	$4700,$4800,$4900,$4A00,$4B00,$4C00,$4E00,$4F00,$5000,$5100
	DC.W	$5200,$5300,$5400,$5600,$5700,$5800,$5900,$5A00,$5B00,$5D00
	DC.W	$5E00,$5F00,$6000,$6100,$6300,$6400,$6500,$6600,$6800,$6900
	DC.W	$6A00,$6B00,$6D00,$6E00,$6F00,$7100,$7200,$7300,$7400,$7600
	DC.W	$7700,$7800,$7A00,$7B00,$7C00,$7E00,$7F00,$8000,$8200,$8300
	DC.W	$8500,$8600,$8700,$8900,$8A00,$8B00,$8D00,$8E00,$9000,$9100
	DC.W	$9200,$9400,$9500,$9700,$9800,$9A00,$9B00,$9C00,$9E00,$9F00
	DC.W	$A100,$A200,$A400,$A500,$A700,$A800,$AA00,$AB00,$AC00,$AE00
	DC.W	$AF00,$B100,$B200,$B400,$B500,$B700,$B800,$BA00,$BB00,$BD00
	DC.W	$BE00,$C000,$C200,$C300,$C500,$C600,$C800,$C900,$CB00,$CC00
	DC.W	$CE00,$CF00,$D100,$D200,$D400,$D500,$D700,$D900,$DA00,$DC00
	DC.W	$DD00,$DF00,$E000,$E200,$E300,$E500,$E700,$E800,$EA00,$EB00
	DC.W	$ED00,$EE00,$F000,$F200,$F300,$F500,$F600,$F800,$F900,$FB00
	DC.W	$FD00,$FE00,$0000,$0100

c:	dc.l	0
x:	dc.w	0
y:	dc.w 	0
sarja:	dc.l    0
kerta:	dc.l	0
angle:  dc.w    0
eka:	dc.w 	0
oldintena: dc.w 0
oldvbi:	dc.l 0

bplane:	blk.b	51200,0 ; reserve space for 4 bitplane pic
gfxlib:		dc.b	"graphics.library",0,0
;gfxbase:	dc.l	0

