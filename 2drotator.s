;APSFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
;
; input & display disabling startup code v1.0.2
;
; minimum requirements: 68000, OCS, Kickstart 1.2
; compiles with genam and phxass.
;
; Written by Harry Sintonen. Public Domain.
; thanks to _jackal & odin-_ for testing.
;

	INCDIR  "work:includes/include_i/"
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

	include "a5levy1:sourcet/custom.i"


	SECTION CODE,code


        move.l  4,a6
        move.l  #20480,d0               ; Muistin määrä
        move.l  #65538,d1               ; MEMF_CHIP, MEMF_CLEAR
        jsr     -$00c6(a6)              ; AllocMem
        move.l  d0,bplane              ; Muisti BitMap0:lle
        cmp.l   #$0,d0
        beq     Pois                    ; Pois jos ei ole muistia

        move.l  #20480,d0
        move.l  #65538,d1
        jsr     -$00c6(a6)
        move.l  d0,bplane1              ; Muisti BitMap1:lle
        cmp.l   #$0,d0
        beq     Vap1


        movea.l #$dff000,a5

        move.l  #Copper,$080(a5)
        tst.w   $088(a5)                ; Oma copperlista päälle

	move.l	#vertices,a1 	;read vertices
	move.l  #0,angle	;angle = zero

tasa:

DoubleBuffering:
        cmp.b   #1,Kumpi
        beq.s   YksKehiin
        move.l  bplane,ShowScreen
        move.l  bplane1,DrawScreen
        move.b  #1,Kumpi
        bra.w   CopperListaan
YksKehiin:
        move.l  Bplane1,ShowScreen
        move.l  Bplane,DrawScreen
        move.b  #0,Kumpi
CopperListaan:
        move.l  ShowScreen,d3       ; Kirjoitetaan näytettävän
        move.w  d3,low1             ; bittikartan tiedot copperlistaan
        swap    d3
        move.w  d3,high1
        swap    d3
        add.l   #10240,d3
        move.w  d3,low2
        swap    d3
        move.w  d3,high2


ClearScreen:
        moveq   #0,d0
        moveq   #0,d1
        moveq   #0,d2
        moveq   #0,d3
        moveq   #0,d4
        moveq   #0,d5
        moveq   #0,d6

        move.l  DrawScreen,a6           
        add.l   #20480,a6
        move.l  #242,d7
Clear:
        movem.l d0-d6,-(a6)             ; 28 bytes
        movem.l d0-d6,-(a6)             ; 28 bytes
        movem.l d0-d6,-(a6)             ; 28 bytes
                                        ; yht 84 bytes
        dbf     d7,Clear        

; Vielä 68 tavua tyhjentämättä

        movem.l d0-d6,-(a6)             ; 28 bytes
        movem.l d0-d6,-(a6)             ; 28 bytes
        movem.l d0-d2,-(a6)             ; 12 bytes



	move.l	#custom,a6
	move.l  drawscreen,a0
	move.w	#$8000,bltadat(a6)
	move.w	#$ffff,bltbdat(a6)
	move.l	#-1,bltafwm(a6)
	move.w	#40,bltcmod(a6)
	move.w	#40,bltdmod(a6)


	clr.l d0
	clr.l d1
	clr.l d2
	clr.l d3
	clr.l d4
	clr.l d5
	clr.l d6
	clr.l d7

	move.l  angle,d4
	lea	radiantable,a0
	add.w   d4,d4
	move.w  (a0,d4.w),d3
	move.w  d3,d4
	lea 	sin,a2		;sintable to a2
	lea	sin+512,a3	;costable to a3
angles:
	add.w  d4,d4
	move.w (a2,d4.w),d3 ; sin angle to d3
	move.w d3,sinAngle
	add.w  d4,d4
	move.w (a3,d4.w),d5 ; cos angle to d5
	move.w  d5,cosAngle
	
	;x' = x * cos(angle) - y * sin(angle) 
	;y' = x * sin(angle) + y * cos(angle)
juuh:
	move.l #vertices,a1
	clr.l  d7
vertloop:
	
	clr.l	d2
	clr.l	d3

	move.w cosAngle,d2
	move.w sinAngle,d3

	clr.l d0
	clr.l d1
	move.w (a1)+,d0	 ; read vertices
	move.w (a1)+,d1

	muls.w d0,d3
	muls.w d1,d2
	add.l d3,d2
	asr.l #8,d2
	move.w #256,d5
	sub.w  d2,d5
	sub.w  #128,d5	;center y
	move.w d5,y

	clr.l	d2
	clr.l	d3

	move.w cosAngle,d2
	move.w sinAngle,d3

	muls.w  d0,d2 ; x * cosAngle
	muls.w  d1,d3 ; y * sinAngle
	sub.l  d3,d2 
	asr.l   #8,d2
	sub.w	#160,d2 ;center x
	move.w d2,x

	clr.l  d2
	clr.l  d3
	move.w cosAngle,d2
	move.w sinAngle,d3

	move.w (a1)+,d0	 ; read vertices
	move.w (a1)+,d1  

	muls.w d0,d3
	muls.w d1,d2
	add.l d3,d2
	asr.l #8,d2
	move.w #256,d5
	sub.w    d2,d5
	sub.w  #128,d5	;center y
	move.w d5,y1

	clr.l	d2
	clr.l	d3

	move.w cosAngle,d2
	move.w sinAngle,d3


	muls.w  d0,d2 ; x * cosAngle
	muls.w  d1,d3 ; y * sinAngle
	sub.l  d3,d2 
	asr.l   #8,d2
	sub.w	#160,d2	;center x
	move.w d2,x1

	clr.l	d0
	clr.l	d1
	clr.l   d2
	clr.l   d3

	move.w x,d0
	move.w y,d1
	move.w x1,d2
	move.w y1,d3

	move.l  drawscreen,a0
	jsr	drawline1
	addq    #1,d7
	cmp     #4,d7
	bne	vertloop
	clr.l d7

	bsr	waitforbeam


	move.l angle,d7
	addq   #1,d7
	move.l d7,angle
	cmp    #180,d7
	bne    tasa




Vap1    move.l  4,a6
        move.l  #20480,d0
        move.l  Bplane,a1
        jsr     -$00d2(a6)              ; FreeMem

pois:

	moveq	#RETURN_OK,d0

	rts	

WaitForBeam:
        move.w  #$0000,$180(a5)
        move.w  $dff004,d0              ; onko beam kuvaruudun alaosassa?
        btst.l  #0,d0                   
        beq.s   WaitForBeam
        cmp.b   #$2d,$dff006
        bne.s   WaitForBeam
	rts
	

;
; Blitter linedraw routine
; d0=x,d1=y,d2=x,d3=y,a0=plane,a6=custom
; uses : d4,d5
;
drawline1:
	cmp.w	d1,d3
	bhi.s	next1
	exg	d0,d2
	exg	d1,d3	; draw line from up to down
next1:
; if same x and y -> no line drawn
	cmp.w	d3,d1
	bne.s	next2
	cmp.w	d2,d0
	bne.s	next2
	rts
next2:
	moveq	#0,d5
	move.w	d3,d4
	sub.w	d1,d4	;delta y
	add.w	d4,d4	;2deltay
	sub.w	d0,d2	;deltax
	bge.s	dxpos
	neg.w	d2	;delta x to +
	addq.w	#2,d5	;oktant2
dxpos:	cmp.w	d4,d2	;compare if 2deltay was smaller than deltax
	blo.s	allok	
	subq.w	#1,d3	;if yes sub 1 from y coordinates
allok:
; line has proper length now
	sub.w	d1,d3	
	mulu	#40,d1
	move.w	d0,d4
	asr.w	#3,d4
	add.w	d4,d1
	add.l	a0,d1

	move.w	d3,d4
	sub.w	d2,d4
	bge.s	dysdx
	exg	d2,d3
	addq.w	#1,d5
dysdx:	move.b	oktantit(pc,d5),d5
	add.w	d2,d2
	and.w	#$000f,d0
	ror.w	#4,d0
	or.w	#%0000101111001010,d0

oota:
	btst	#14,dmaconr(a6)
	bne.s	oota
	
	
	move.w	d2,bltbmod(a6)
	sub.w	d3,d2
	bge.s	signok
	or.b	#%01000000,d5
signok:	move.w	d2,bltaptl(a6)
	sub.w	d3,d2
	move.w	d2,bltamod(a6)
	move.w	d0,bltcon0(a6)
	move.w	d5,bltcon1(a6)
	move.l	d1,bltcpth(a6)
	move.l	d1,bltdpth(a6)
	lsl.w	#6,d3
	addq.w	#2,d3
	move.w	d3,bltsize(a6)
	
	rts

;
; oktantti-bitit ja linemode-bitti.
;
oktantit:
	dc.b 0+1	;y1<y2, x1<x2, dx<dy = okt6
	dc.b 16+1	;y1<y2, x1<x2, dx>dy = okt7
	dc.b 8+1	;y1<y2, x1>x2, dx<dy = okt5
	dc.b 20+1	;y1<y2, x1>x2, dx>dy = okt4

	section Rebb_data,data_c

copper: 
	dc.w	$0106,$0000,$01fc,$0000		; AGA compatible
	dc.w	$008e,$1a64,$0090,$ffc4		; Setting up display,
	dc.w	$0092,$0038,$0094,$00d0		; modulo and so on
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
	
	dc.w $0100,%0010000000000000 

bplcop: 
	dc.w $00e0
high1:	dc.w $0000 ;address bitplane 1 (high 5 bits) 
	dc.w $00e2
low1:	dc.w $0000 ;address bitplane 1 (low 15 bits) 
	dc.w $00e4
high2:	dc.w $0000 ;address bitplane 2 
	dc.w $00e6
low2:	dc.w $0000 

colorcop: 
	dc.w $0180,$0000 
	dc.w $0182,$0fff 
	dc.w $0184,$0fff 
	dc.w $0186,$0fff 
 
	dc.w $ffff,$fffe

        section muuttujat,data


sin:

	DC.W	$0001,$0002,$0004,$0005,$0007,$0008,$000A,$000B,$000D,$000F
	DC.W	$0010,$0012,$0013,$0015,$0016,$0018,$001A,$001B,$001D,$001E
	DC.W	$0020,$0021,$0023,$0025,$0026,$0028,$0029,$002B,$002C,$002E
	DC.W	$002F,$0031,$0032,$0034,$0036,$0037,$0039,$003A,$003C,$003D
	DC.W	$003F,$0040,$0042,$0043,$0045,$0046,$0048,$0049,$004B,$004C
	DC.W	$004E,$004F,$0051,$0052,$0054,$0055,$0057,$0058,$005A,$005B
	DC.W	$005D,$005E,$0060,$0061,$0062,$0064,$0065,$0067,$0068,$006A
	DC.W	$006B,$006D,$006E,$006F,$0071,$0072,$0074,$0075,$0076,$0078
	DC.W	$0079,$007B,$007C,$007D,$007F,$0080,$0081,$0083,$0084,$0085
	DC.W	$0087,$0088,$0089,$008B,$008C,$008D,$008F,$0090,$0091,$0093
	DC.W	$0094,$0095,$0096,$0098,$0099,$009A,$009C,$009D,$009E,$009F
	DC.W	$00A0,$00A2,$00A3,$00A4,$00A5,$00A7,$00A8,$00A9,$00AA,$00AB
	DC.W	$00AC,$00AE,$00AF,$00B0,$00B1,$00B2,$00B3,$00B4,$00B6,$00B7
	DC.W	$00B8,$00B9,$00BA,$00BB,$00BC,$00BD,$00BE,$00BF,$00C0,$00C1
	DC.W	$00C2,$00C3,$00C4,$00C5,$00C6,$00C7,$00C8,$00C9,$00CA,$00CB
	DC.W	$00CC,$00CD,$00CE,$00CF,$00D0,$00D1,$00D2,$00D3,$00D4,$00D4
	DC.W	$00D5,$00D6,$00D7,$00D8,$00D9,$00DA,$00DA,$00DB,$00DC,$00DD
	DC.W	$00DE,$00DE,$00DF,$00E0,$00E1,$00E2,$00E2,$00E3,$00E4,$00E4
	DC.W	$00E5,$00E6,$00E7,$00E7,$00E8,$00E9,$00E9,$00EA,$00EB,$00EB
	DC.W	$00EC,$00EC,$00ED,$00EE,$00EE,$00EF,$00EF,$00F0,$00F0,$00F1
	DC.W	$00F2,$00F2,$00F3,$00F3,$00F4,$00F4,$00F5,$00F5,$00F5,$00F6
	DC.W	$00F6,$00F7,$00F7,$00F8,$00F8,$00F8,$00F9,$00F9,$00FA,$00FA
	DC.W	$00FA,$00FB,$00FB,$00FB,$00FC,$00FC,$00FC,$00FC,$00FD,$00FD
	DC.W	$00FD,$00FD,$00FE,$00FE,$00FE,$00FE,$00FF,$00FF,$00FF,$00FF
	DC.W	$00FF,$00FF,$0100,$0100,$0100,$0100,$0100,$0100,$0100,$0100
	DC.W	$0100,$0100,$0100,$0100,$0100,$0100,$0101,$0100,$0100,$0100
	DC.W	$0100,$0100,$0100,$0100,$0100,$0100,$0100,$0100,$0100,$0100
	DC.W	$0100,$00FF,$00FF,$00FF,$00FF,$00FF,$00FF,$00FE,$00FE,$00FE
	DC.W	$00FE,$00FD,$00FD,$00FD,$00FD,$00FC,$00FC,$00FC,$00FC,$00FB
	DC.W	$00FB,$00FB,$00FA,$00FA,$00FA,$00F9,$00F9,$00F8,$00F8,$00F8
	DC.W	$00F7,$00F7,$00F6,$00F6,$00F5,$00F5,$00F5,$00F4,$00F4,$00F3
	DC.W	$00F3,$00F2,$00F2,$00F1,$00F0,$00F0,$00EF,$00EF,$00EE,$00EE
	DC.W	$00ED,$00EC,$00EC,$00EB,$00EB,$00EA,$00E9,$00E9,$00E8,$00E7
	DC.W	$00E7,$00E6,$00E5,$00E4,$00E4,$00E3,$00E2,$00E2,$00E1,$00E0
	DC.W	$00DF,$00DE,$00DE,$00DD,$00DC,$00DB,$00DA,$00DA,$00D9,$00D8
	DC.W	$00D7,$00D6,$00D5,$00D4,$00D4,$00D3,$00D2,$00D1,$00D0,$00CF
	DC.W	$00CE,$00CD,$00CC,$00CB,$00CA,$00C9,$00C8,$00C7,$00C6,$00C5
	DC.W	$00C4,$00C3,$00C2,$00C1,$00C0,$00BF,$00BE,$00BD,$00BC,$00BB
	DC.W	$00BA,$00B9,$00B8,$00B7,$00B6,$00B4,$00B3,$00B2,$00B1,$00B0
	DC.W	$00AF,$00AE,$00AC,$00AB,$00AA,$00A9,$00A8,$00A7,$00A5,$00A4
	DC.W	$00A3,$00A2,$00A0,$009F,$009E,$009D,$009C,$009A,$0099,$0098
	DC.W	$0096,$0095,$0094,$0093,$0091,$0090,$008F,$008D,$008C,$008B
	DC.W	$0089,$0088,$0087,$0085,$0084,$0083,$0081,$0080,$007F,$007D
	DC.W	$007C,$007B,$0079,$0078,$0076,$0075,$0074,$0072,$0071,$006F
	DC.W	$006E,$006D,$006B,$006A,$0068,$0067,$0065,$0064,$0062,$0061
	DC.W	$0060,$005E,$005D,$005B,$005A,$0058,$0057,$0055,$0054,$0052
	DC.W	$0051,$004F,$004E,$004C,$004B,$0049,$0048,$0046,$0045,$0043
	DC.W	$0042,$0040,$003F,$003D,$003C,$003A,$0039,$0037,$0036,$0034
	DC.W	$0032,$0031,$002F,$002E,$002C,$002B,$0029,$0028,$0026,$0025
	DC.W	$0023,$0021,$0020,$001E,$001D,$001B,$001A,$0018,$0016,$0015
	DC.W	$0013,$0012,$0010,$000F,$000D,$000B,$000A,$0008,$0007,$0005
	DC.W	$0004,$0002,$0001,$0000,$FFFE,$FFFD,$FFFB,$FFFA,$FFF8,$FFF7
	DC.W	$FFF5,$FFF3,$FFF2,$FFF0,$FFEF,$FFED,$FFEC,$FFEA,$FFE8,$FFE7
	DC.W	$FFE5,$FFE4,$FFE2,$FFE1,$FFDF,$FFDD,$FFDC,$FFDA,$FFD9,$FFD7
	DC.W	$FFD6,$FFD4,$FFD3,$FFD1,$FFD0,$FFCE,$FFCC,$FFCB,$FFC9,$FFC8
	DC.W	$FFC6,$FFC5,$FFC3,$FFC2,$FFC0,$FFBF,$FFBD,$FFBC,$FFBA,$FFB9
	DC.W	$FFB7,$FFB6,$FFB4,$FFB3,$FFB1,$FFB0,$FFAE,$FFAD,$FFAB,$FFAA
	DC.W	$FFA8,$FFA7,$FFA5,$FFA4,$FFA2,$FFA1,$FFA0,$FF9E,$FF9D,$FF9B
	DC.W	$FF9A,$FF98,$FF97,$FF95,$FF94,$FF93,$FF91,$FF90,$FF8E,$FF8D
	DC.W	$FF8C,$FF8A,$FF89,$FF87,$FF86,$FF85,$FF83,$FF82,$FF81,$FF7F
	DC.W	$FF7E,$FF7D,$FF7B,$FF7A,$FF79,$FF77,$FF76,$FF75,$FF73,$FF72
	DC.W	$FF71,$FF6F,$FF6E,$FF6D,$FF6C,$FF6A,$FF69,$FF68,$FF66,$FF65
	DC.W	$FF64,$FF63,$FF62,$FF60,$FF5F,$FF5E,$FF5D,$FF5B,$FF5A,$FF59
	DC.W	$FF58,$FF57,$FF56,$FF54,$FF53,$FF52,$FF51,$FF50,$FF4F,$FF4E
	DC.W	$FF4C,$FF4B,$FF4A,$FF49,$FF48,$FF47,$FF46,$FF45,$FF44,$FF43
	DC.W	$FF42,$FF41,$FF40,$FF3F,$FF3E,$FF3D,$FF3C,$FF3B,$FF3A,$FF39
	DC.W	$FF38,$FF37,$FF36,$FF35,$FF34,$FF33,$FF32,$FF31,$FF30,$FF2F
	DC.W	$FF2E,$FF2E,$FF2D,$FF2C,$FF2B,$FF2A,$FF29,$FF28,$FF28,$FF27
	DC.W	$FF26,$FF25,$FF24,$FF24,$FF23,$FF22,$FF21,$FF20,$FF20,$FF1F
	DC.W	$FF1E,$FF1E,$FF1D,$FF1C,$FF1B,$FF1B,$FF1A,$FF19,$FF19,$FF18
	DC.W	$FF17,$FF17,$FF16,$FF16,$FF15,$FF14,$FF14,$FF13,$FF13,$FF12
	DC.W	$FF12,$FF11,$FF10,$FF10,$FF0F,$FF0F,$FF0E,$FF0E,$FF0D,$FF0D
	DC.W	$FF0D,$FF0C,$FF0C,$FF0B,$FF0B,$FF0A,$FF0A,$FF0A,$FF09,$FF09
	DC.W	$FF08,$FF08,$FF08,$FF07,$FF07,$FF07,$FF06,$FF06,$FF06,$FF06
	DC.W	$FF05,$FF05,$FF05,$FF05,$FF04,$FF04,$FF04,$FF04,$FF03,$FF03
	DC.W	$FF03,$FF03,$FF03,$FF03,$FF02,$FF02,$FF02,$FF02,$FF02,$FF02
	DC.W	$FF02,$FF02,$FF02,$FF02,$FF02,$FF02,$FF02,$FF02,$FF01,$FF02
	DC.W	$FF02,$FF02,$FF02,$FF02,$FF02,$FF02,$FF02,$FF02,$FF02,$FF02
	DC.W	$FF02,$FF02,$FF02,$FF03,$FF03,$FF03,$FF03,$FF03,$FF03,$FF04
	DC.W	$FF04,$FF04,$FF04,$FF05,$FF05,$FF05,$FF05,$FF06,$FF06,$FF06
	DC.W	$FF06,$FF07,$FF07,$FF07,$FF08,$FF08,$FF08,$FF09,$FF09,$FF0A
	DC.W	$FF0A,$FF0A,$FF0B,$FF0B,$FF0C,$FF0C,$FF0D,$FF0D,$FF0D,$FF0E
	DC.W	$FF0E,$FF0F,$FF0F,$FF10,$FF10,$FF11,$FF12,$FF12,$FF13,$FF13
	DC.W	$FF14,$FF14,$FF15,$FF16,$FF16,$FF17,$FF17,$FF18,$FF19,$FF19
	DC.W	$FF1A,$FF1B,$FF1B,$FF1C,$FF1D,$FF1E,$FF1E,$FF1F,$FF20,$FF20
	DC.W	$FF21,$FF22,$FF23,$FF24,$FF24,$FF25,$FF26,$FF27,$FF28,$FF28
	DC.W	$FF29,$FF2A,$FF2B,$FF2C,$FF2D,$FF2E,$FF2E,$FF2F,$FF30,$FF31
	DC.W	$FF32,$FF33,$FF34,$FF35,$FF36,$FF37,$FF38,$FF39,$FF3A,$FF3B
	DC.W	$FF3C,$FF3D,$FF3E,$FF3F,$FF40,$FF41,$FF42,$FF43,$FF44,$FF45
	DC.W	$FF46,$FF47,$FF48,$FF49,$FF4A,$FF4B,$FF4C,$FF4E,$FF4F,$FF50
	DC.W	$FF51,$FF52,$FF53,$FF54,$FF56,$FF57,$FF58,$FF59,$FF5A,$FF5B
	DC.W	$FF5D,$FF5E,$FF5F,$FF60,$FF62,$FF63,$FF64,$FF65,$FF66,$FF68
	DC.W	$FF69,$FF6A,$FF6C,$FF6D,$FF6E,$FF6F,$FF71,$FF72,$FF73,$FF75
	DC.W	$FF76,$FF77,$FF79,$FF7A,$FF7B,$FF7D,$FF7E,$FF7F,$FF81,$FF82
	DC.W	$FF83,$FF85,$FF86,$FF87,$FF89,$FF8A,$FF8C,$FF8D,$FF8E,$FF90
	DC.W	$FF91,$FF93,$FF94,$FF95,$FF97,$FF98,$FF9A,$FF9B,$FF9D,$FF9E
	DC.W	$FFA0,$FFA1,$FFA2,$FFA4,$FFA5,$FFA7,$FFA8,$FFAA,$FFAB,$FFAD
	DC.W	$FFAE,$FFB0,$FFB1,$FFB3,$FFB4,$FFB6,$FFB7,$FFB9,$FFBA,$FFBC
	DC.W	$FFBD,$FFBF,$FFC0,$FFC2,$FFC3,$FFC5,$FFC6,$FFC8,$FFC9,$FFCB
	DC.W	$FFCC,$FFCE,$FFD0,$FFD1,$FFD3,$FFD4,$FFD6,$FFD7,$FFD9,$FFDA
	DC.W	$FFDC,$FFDD,$FFDF,$FFE1,$FFE2,$FFE4,$FFE5,$FFE7,$FFE8,$FFEA
	DC.W	$FFEC,$FFED,$FFEF,$FFF0,$FFF2,$FFF3,$FFF5,$FFF7,$FFF8,$FFFA
	DC.W	$FFFB,$FFFD,$FFFE,$0000,$0001,$0002,$0004,$0005,$0007,$0008
	DC.W	$000A,$000B,$000D,$000F,$0010,$0012,$0013,$0015,$0016,$0018
	DC.W	$001A,$001B,$001D,$001E,$0020,$0021,$0023,$0025,$0026,$0028
	DC.W	$0029,$002B,$002C,$002E,$002F,$0031,$0032,$0034,$0036,$0037
	DC.W	$0039,$003A,$003C,$003D,$003F,$0040,$0042,$0043,$0045,$0046
	DC.W	$0048,$0049,$004B,$004C,$004E,$004F,$0051,$0052,$0054,$0055
	DC.W	$0057,$0058,$005A,$005B,$005D,$005E,$0060,$0061,$0062,$0064
	DC.W	$0065,$0067,$0068,$006A,$006B,$006D,$006E,$006F,$0071,$0072
	DC.W	$0074,$0075,$0076,$0078,$0079,$007B,$007C,$007D,$007F,$0080
	DC.W	$0081,$0083,$0084,$0085,$0087,$0088,$0089,$008B,$008C,$008D
	DC.W	$008F,$0090,$0091,$0093,$0094,$0095,$0096,$0098,$0099,$009A
	DC.W	$009C,$009D,$009E,$009F,$00A0,$00A2,$00A3,$00A4,$00A5,$00A7
	DC.W	$00A8,$00A9,$00AA,$00AB,$00AC,$00AE,$00AF,$00B0,$00B1,$00B2
	DC.W	$00B3,$00B4,$00B6,$00B7,$00B8,$00B9,$00BA,$00BB,$00BC,$00BD
	DC.W	$00BE,$00BF,$00C0,$00C1,$00C2,$00C3,$00C4,$00C5,$00C6,$00C7
	DC.W	$00C8,$00C9,$00CA,$00CB,$00CC,$00CD,$00CE,$00CF,$00D0,$00D1
	DC.W	$00D2,$00D3,$00D4,$00D4,$00D5,$00D6,$00D7,$00D8,$00D9,$00DA
	DC.W	$00DA,$00DB,$00DC,$00DD,$00DE,$00DE,$00DF,$00E0,$00E1,$00E2
	DC.W	$00E2,$00E3,$00E4,$00E4,$00E5,$00E6,$00E7,$00E7,$00E8,$00E9
	DC.W	$00E9,$00EA,$00EB,$00EB,$00EC,$00EC,$00ED,$00EE,$00EE,$00EF
	DC.W	$00EF,$00F0,$00F0,$00F1,$00F2,$00F2,$00F3,$00F3,$00F4,$00F4
	DC.W	$00F5,$00F5,$00F5,$00F6,$00F6,$00F7,$00F7,$00F8,$00F8,$00F8
	DC.W	$00F9,$00F9,$00FA,$00FA,$00FA,$00FB,$00FB,$00FB,$00FC,$00FC
	DC.W	$00FC,$00FC,$00FD,$00FD,$00FD,$00FD,$00FE,$00FE,$00FE,$00FE
	DC.W	$00FF,$00FF,$00FF,$00FF,$00FF,$00FF,$0100,$0100,$0100,$0100
	DC.W	$0100,$0100,$0100,$0100,$0100,$0100,$0100,$0100,$0100,$0100


vertices: 
	dc.w	-40,30,40,30,40,30,40,-20,40,-20,-40,-20,-40,-20,-40,30
;radian table from 0-360 degrees multiplied by 256
radianTable:
	dc.w 0,4,8,13,17,22,26,31,35,40,44,49,53,58,62,66,71,75,80,84,89,93,98,102
	dc.w 107,111,116,120,125,129,133,138,142,147,151,156,160,165,169,174,178,183	
	dc.w 187,192,196,200,205,209,214,218,223,227,232,236,241,245,250,254,259,263
	dc.w 267,272,276,281,285,290,294,299,303,308,312,317,321,326,330,334,339,343
	dc.w 348,352,357,361,366,370,375,379,384,388,392,397,401,406,410,415,419,424
	dc.w 428,433,437,442,446,451,455,459,464,468,473,477,482,486,491,495,500,504
	dc.w 509,513,518,522,526,531,535,540,544,549,553,558,562,567,571,576,580,585
	dc.w 589,593,598,602,607,611,616,620,625,629,634,638,643,647,652,656,660,665
	dc.w 669,674,678,683,687,692,696,701,705,710,714,718,723,727,732,736,741,745
	dc.w 750,754,759,763,768,772,777,781,785,790,794,799,803,808,812,817,821,826
	dc.w 830,835,839,844,848,852,857,861,866,870,875,879,884,888,893,897,902,906
	dc.w 911,915,919,924,928,933,937,942,946,951,955,960,964,969,973,978,982,986
	dc.w 991,995,1000,1004,1009,1013,1018,1022,1027,1031,1036,1040,1044,1049,1053
	dc.w 1058,1062,1067,1071,1076,1080,1085,1089,1094,1098,1103,1107,1111,1116
	dc.w 1120,1125,1129,1134,1138,1143,1147,1152,1156,1161,1165,1170,1174,1178
	dc.w 1183,1187,1192,1196,1201,1205,1210,1214,1219,1223,1228,1232,1237,1241
	dc.w 1245,1250,1254,1259,1263,1268,1272,1277,1281,1286,1290,1295,1299,1304
	dc.w 1308,1312,1317,1321,1326,1330,1335,1339,1344,1348,1353,1357,1362,1366
	dc.w 1370,1375,1379,1384,1388,1393,1397,1402,1406,1411,1415,1420,1424,1429
	dc.w 1433,1437,1442,1446,1451,1455,1460,1464,1469,1473,1478,1482,1487,1491
	dc.w 1496,1500,1504,1509,1513,1518,1522,1527,1531,1536,1540,1545,1549,1554
	dc.w 1558,1563,1567,1571,1576,1580,1585,1589,1594,1598,1603,1607 

BitPlane0_1:     dc.l    0
BitPlane0_2:     dc.l    0
BitPlane1_1:     dc.l    0
BitPlane1_2:     dc.l    0
DrawScreen_1:    dc.l    0
DrawScreen_2:    dc.l    0
ShowScreen:      dc.l    0
DrawScreen:      dc.l    0
xcos:	dc.l	0
xsin:	dc.l	0
ycos:	dc.l	0
ysin:	dc.l	0
angle:	dc.l	0
x1:	dc.w	0
x2:	dc.w	0
y1:	dc.w	0
y2:	dc.w	0
c:	dc.w	0
x:	dc.w	0
y:	dc.w 	0
kerta:	dc.l	0
buff:	ds.l	10
cosAngle: dc.w	0
sinAngle: dc.w	0
bplane:	dc.l	0 ; reserve space for 2 bitplane pic
bplane1:dc.l	0
kumpi:	dc.b	1
	even
gfxlib:		dc.b	"graphics.library",0,0
;gfxbase:	dc.l	0

