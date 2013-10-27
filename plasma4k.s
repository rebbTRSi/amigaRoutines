;APS00000000000000000000000000000000000000000000000000000000000000000000000000000000
_main:
DMAWait = 300 ; Set this as low as possible without losing low notes.

n_note		EQU	0  ; W
n_cmd		EQU	2  ; W
n_cmdlo		EQU	3  ; B
n_start		EQU	4  ; L
n_length	EQU	8  ; W
n_loopstart	EQU	10 ; L
n_replen	EQU	14 ; W
n_period	EQU	16 ; W
n_finetune	EQU	18 ; B
n_volume	EQU	19 ; B
n_dmabit	EQU	20 ; W
n_toneportdirec	EQU	22 ; B
n_toneportspeed	EQU	23 ; B
n_wantedperiod	EQU	24 ; W
n_vibratocmd	EQU	26 ; B
n_vibratopos	EQU	27 ; B
n_tremolocmd	EQU	28 ; B
n_tremolopos	EQU	29 ; B
n_wavecontrol	EQU	30 ; B
n_glissfunk	EQU	31 ; B
n_sampleoffset	EQU	32 ; B
n_pattpos	EQU	33 ; B
n_loopcount	EQU	34 ; B
n_funkoffset	EQU	35 ; B
n_wavestart	EQU	36 ; L
n_reallength	EQU	40 ; W

	include "dh1:include_i/custom.i"
Opencopper:
	move.l	#0,d0
	move.l	#gfxname,a1
	move.l	4,a6
	jsr	-$0228(a6)
	move.l	d0,gfxbase
	move.l	d0,a6
	move.l	38(a6),oldcop


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

	jsr mt_init

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
	add.w  d4,d4
	add.w  d5,d5	
	move.w (a3,d4.w),d2 ; sin x
	sub.w  d3,d4
	move.w (a3,d5.w),d3
	add.w  d3,d2
	asr.l  #5,d2

	add.w  #1,x
	move.w d2,d0
	cmp.w  #1,d0
	bhs    kusi1
	move.w #1,d0


kusi1:	move.l d0,c
	move.w y,d2

	move.l #bplane,a0
	jsr    plot

	move.l #0,d4
	move.l #0,d5
	add.l  #1,d1
	cmp.l  #320,d1
	bne    byy

	move.w #0,d1
	move.w #0,x
	add.w  #1,y
	cmp    #56,y
	bne    byy


mouse:	btst #6,$bfe001		; check for mouse
	bne.b mouse	 	; jump if not pressed

	jsr  mt_end

closecop:
	move.l  #custom,a6
	move.l	oldcop,cop1lch(a6)


	move.w	#%00111111111111111,intena(a6)
	move.l	oldvbi,$6c
	move.w	oldintena,d0
	or.w	#$8000,d0
	move.w	d0,intena(a6)

;	moveq	#RETURN_OK,d0

	rts



mt_init	LEA	mt_data,A0
	MOVE.L	A0,mt_SongDataPtr
	MOVE.L	A0,A1
	LEA	952(A1),A1
	MOVEQ	#127,D0
	MOVEQ	#0,D1
mtloop	MOVE.L	D1,D2
	SUBQ.W	#1,D0
mtloop2	MOVE.B	(A1)+,D1
	CMP.B	D2,D1
	BGT.S	mtloop
	DBRA	D0,mtloop2
	ADDQ.B	#1,D2
			
	LEA	mt_SampleStarts,A1
	ASL.L	#8,D2
	ASL.L	#2,D2
	ADD.L	#1084,D2
	ADD.L	A0,D2
	MOVE.L	D2,A2
	MOVEQ	#30,D0
mtloop3	CLR.L	(A2)
	MOVE.L	A2,(A1)+
	MOVEQ	#0,D1
	MOVE.W	42(A0),D1
	ASL.L	#1,D1
	ADD.L	D1,A2
	ADD.L	#30,A0
	DBRA	D0,mtloop3

	OR.B	#2,$BFE001
	MOVE.B	#6,mt_speed
	CLR.B	mt_counter
	CLR.B	mt_SongPos
	CLR.W	mt_PatternPos
mt_end	CLR.W	$DFF0A8
	CLR.W	$DFF0B8
	CLR.W	$DFF0C8
	CLR.W	$DFF0D8
	MOVE.W	#$F,$DFF096
	RTS

mt_music
	MOVEM.L	D0-D4/A0-A6,-(SP)
	ADDQ.B	#1,mt_counter
	MOVE.B	mt_counter,D0
	CMP.B	mt_speed,D0
	BLO.S	mt_NoNewNote
	CLR.B	mt_counter
	TST.B	mt_PattDelTime2
	BEQ.S	mt_GetNewNote
	BSR.S	mt_NoNewAllChannels
	BRA	mt_dskip

mt_NoNewNote
	BSR.S	mt_NoNewAllChannels
	BRA	mt_NoNewPosYet

mt_NoNewAllChannels
	LEA	$DFF0A0,A5
	LEA	mt_chan1temp,A6
	BSR	mt_CheckEfx
	LEA	$DFF0B0,A5
	LEA	mt_chan2temp,A6
	BSR	mt_CheckEfx
	LEA	$DFF0C0,A5
	LEA	mt_chan3temp,A6
	BSR	mt_CheckEfx
	LEA	$DFF0D0,A5
	LEA	mt_chan4temp,A6
	BRA	mt_CheckEfx

mt_GetNewNote
	MOVE.L	mt_SongDataPtr,A0
	LEA	12(A0),A3
	LEA	952(A0),A2	;pattpo
	LEA	1084(A0),A0	;patterndata
	MOVEQ	#0,D0
	MOVEQ	#0,D1
	MOVE.B	mt_SongPos,D0
	MOVE.B	(A2,D0.W),D1
	ASL.L	#8,D1
	ASL.L	#2,D1
	ADD.W	mt_PatternPos,D1
	CLR.W	mt_DMACONtemp

	LEA	$DFF0A0,A5
	LEA	mt_chan1temp,A6
	BSR.S	mt_PlayVoice
	LEA	$DFF0B0,A5
	LEA	mt_chan2temp,A6
	BSR.S	mt_PlayVoice
	LEA	$DFF0C0,A5
	LEA	mt_chan3temp,A6
	BSR.S	mt_PlayVoice
	LEA	$DFF0D0,A5
	LEA	mt_chan4temp,A6
	BSR.S	mt_PlayVoice
	BRA	mt_SetDMA

mt_PlayVoice
	TST.L	(A6)
	BNE.S	mt_plvskip
	BSR	mt_PerNop
mt_plvskip
	MOVE.L	(A0,D1.L),(A6)
	ADDQ.L	#4,D1
	MOVEQ	#0,D2
	MOVE.B	n_cmd(A6),D2
	AND.B	#$F0,D2
	LSR.B	#4,D2
	MOVE.B	(A6),D0
	AND.B	#$F0,D0
	OR.B	D0,D2
	TST.B	D2
	BEQ	mt_SetRegs
	MOVEQ	#0,D3
	LEA	mt_SampleStarts,A1
	MOVE	D2,D4
	SUBQ.L	#1,D2
	ASL.L	#2,D2
	MULU	#30,D4
	MOVE.L	(A1,D2.L),n_start(A6)
	MOVE.W	(A3,D4.L),n_length(A6)
	MOVE.W	(A3,D4.L),n_reallength(A6)
	MOVE.B	2(A3,D4.L),n_finetune(A6)
	MOVE.B	3(A3,D4.L),n_volume(A6)
	MOVE.W	4(A3,D4.L),D3 ; Get repeat
	TST.W	D3
	BEQ.S	mt_NoLoop
	MOVE.L	n_start(A6),D2	; Get start
	ASL.W	#1,D3
	ADD.L	D3,D2		; Add repeat
	MOVE.L	D2,n_loopstart(A6)
	MOVE.L	D2,n_wavestart(A6)
	MOVE.W	4(A3,D4.L),D0	; Get repeat
	ADD.W	6(A3,D4.L),D0	; Add replen
	MOVE.W	D0,n_length(A6)
	MOVE.W	6(A3,D4.L),n_replen(A6)	; Save replen
	MOVEQ	#0,D0
	MOVE.B	n_volume(A6),D0
	MOVE.W	D0,8(A5)	; Set volume
	BRA.S	mt_SetRegs

mt_NoLoop
	MOVE.L	n_start(A6),D2
	ADD.L	D3,D2
	MOVE.L	D2,n_loopstart(A6)
	MOVE.L	D2,n_wavestart(A6)
	MOVE.W	6(A3,D4.L),n_replen(A6)	; Save replen
	MOVEQ	#0,D0
	MOVE.B	n_volume(A6),D0
	MOVE.W	D0,8(A5)	; Set volume
mt_SetRegs
	MOVE.W	(A6),D0
	AND.W	#$0FFF,D0
	BEQ	mt_CheckMoreEfx	; If no note
	MOVE.W	2(A6),D0
	AND.W	#$0FF0,D0
	CMP.W	#$0E50,D0
	BEQ.S	mt_DoSetFineTune
	MOVE.B	2(A6),D0
	AND.B	#$0F,D0
	CMP.B	#3,D0	; TonePortamento
	BEQ.S	mt_ChkTonePorta
	CMP.B	#5,D0
	BEQ.S	mt_ChkTonePorta
	CMP.B	#9,D0	; Sample Offset
	BNE.S	mt_SetPeriod
	BSR	mt_CheckMoreEfx
	BRA.S	mt_SetPeriod

mt_DoSetFineTune
	BSR	mt_SetFineTune
	BRA.S	mt_SetPeriod

mt_ChkTonePorta
	BSR	mt_SetTonePorta
	BRA	mt_CheckMoreEfx

mt_SetPeriod
	MOVEM.L	D0-D1/A0-A1,-(SP)
	MOVE.W	(A6),D1
	AND.W	#$0FFF,D1
	LEA	mt_PeriodTable,A1
	MOVEQ	#0,D0
	MOVEQ	#36,D7
mt_ftuloop
	CMP.W	(A1,D0.W),D1
	BHS.S	mt_ftufound
	ADDQ.L	#2,D0
	DBRA	D7,mt_ftuloop
mt_ftufound
	MOVEQ	#0,D1
	MOVE.B	n_finetune(A6),D1
	MULU	#36*2,D1
	ADD.L	D1,A1
	MOVE.W	(A1,D0.W),n_period(A6)
	MOVEM.L	(SP)+,D0-D1/A0-A1

	MOVE.W	2(A6),D0
	AND.W	#$0FF0,D0
	CMP.W	#$0ED0,D0 ; Notedelay
	BEQ	mt_CheckMoreEfx

	MOVE.W	n_dmabit(A6),$DFF096
	BTST	#2,n_wavecontrol(A6)
	BNE.S	mt_vibnoc
	CLR.B	n_vibratopos(A6)
mt_vibnoc
	BTST	#6,n_wavecontrol(A6)
	BNE.S	mt_trenoc
	CLR.B	n_tremolopos(A6)
mt_trenoc
	MOVE.L	n_start(A6),(A5)	; Set start
	MOVE.W	n_length(A6),4(A5)	; Set length
	MOVE.W	n_period(A6),D0
	MOVE.W	D0,6(A5)		; Set period
	MOVE.W	n_dmabit(A6),D0
	OR.W	D0,mt_DMACONtemp
	BRA	mt_CheckMoreEfx
 
mt_SetDMA
	MOVE.W	#300,D0
mt_WaitDMA
	DBRA	D0,mt_WaitDMA
	MOVE.W	mt_DMACONtemp,D0
	OR.W	#$8000,D0
	MOVE.W	D0,$DFF096
	MOVE.W	#300,D0
mt_WaitDMA2
	DBRA	D0,mt_WaitDMA2

	LEA	$DFF000,A5
	LEA	mt_chan4temp,A6
	MOVE.L	n_loopstart(A6),$D0(A5)
	MOVE.W	n_replen(A6),$D4(A5)
	LEA	mt_chan3temp,A6
	MOVE.L	n_loopstart(A6),$C0(A5)
	MOVE.W	n_replen(A6),$C4(A5)
	LEA	mt_chan2temp,A6
	MOVE.L	n_loopstart(A6),$B0(A5)
	MOVE.W	n_replen(A6),$B4(A5)
	LEA	mt_chan1temp,A6
	MOVE.L	n_loopstart(A6),$A0(A5)
	MOVE.W	n_replen(A6),$A4(A5)

mt_dskip
	ADD.W	#16,mt_PatternPos
	MOVE.B	mt_PattDelTime,D0
	BEQ.S	mt_dskc
	MOVE.B	D0,mt_PattDelTime2
	CLR.B	mt_PattDelTime
mt_dskc	TST.B	mt_PattDelTime2
	BEQ.S	mt_dska
	SUBQ.B	#1,mt_PattDelTime2
	BEQ.S	mt_dska
	SUB.W	#16,mt_PatternPos
mt_dska	TST.B	mt_PBreakFlag
	BEQ.S	mt_nnpysk
	SF	mt_PBreakFlag
	MOVEQ	#0,D0
	MOVE.B	mt_PBreakPos,D0
	CLR.B	mt_PBreakPos
	LSL.W	#4,D0
	MOVE.W	D0,mt_PatternPos
mt_nnpysk
	CMP.W	#1024,mt_PatternPos
	BLO.S	mt_NoNewPosYet
mt_NextPosition	
	MOVEQ	#0,D0
	MOVE.B	mt_PBreakPos,D0
	LSL.W	#4,D0
	MOVE.W	D0,mt_PatternPos
	CLR.B	mt_PBreakPos
	CLR.B	mt_PosJumpFlag
	ADDQ.B	#1,mt_SongPos
	AND.B	#$7F,mt_SongPos
	MOVE.B	mt_SongPos,D1
	MOVE.L	mt_SongDataPtr,A0
	CMP.B	950(A0),D1
	BLO.S	mt_NoNewPosYet
	CLR.B	mt_SongPos
mt_NoNewPosYet	
	TST.B	mt_PosJumpFlag
	BNE.S	mt_NextPosition
	MOVEM.L	(SP)+,D0-D4/A0-A6
	RTS

mt_CheckEfx
;	BSR	mt_UpdateFunk
	MOVE.W	n_cmd(A6),D0
	AND.W	#$0FFF,D0
	BEQ.S	mt_PerNop
	MOVE.B	n_cmd(A6),D0
	AND.B	#$0F,D0
	BEQ.S	mt_Arpeggio
	CMP.B	#1,D0
	BEQ	mt_PortaUp
	CMP.B	#2,D0
	BEQ	mt_PortaDown
	CMP.B	#3,D0
	BEQ	mt_TonePortamento
	CMP.B	#4,D0
	BEQ	mt_Vibrato
	CMP.B	#5,D0
	BEQ	mt_TonePlusVolSlide
	CMP.B	#6,D0
	BEQ	mt_VibratoPlusVolSlide
	CMP.B	#$E,D0
	BEQ	mt_E_Commands
SetBack	MOVE.W	n_period(A6),6(A5)
	CMP.B	#7,D0
;	BEQ	mt_Tremolo
	CMP.B	#$A,D0
	BEQ	mt_VolumeSlide
mt_Return2
	RTS

mt_PerNop
	MOVE.W	n_period(A6),6(A5)
	RTS

mt_Arpeggio
	MOVEQ	#0,D0
	MOVE.B	mt_counter,D0
	DIVS	#3,D0
	SWAP	D0
	CMP.W	#0,D0
	BEQ.S	mt_Arpeggio2
	CMP.W	#2,D0
	BEQ.S	mt_Arpeggio1
	MOVEQ	#0,D0
	MOVE.B	n_cmdlo(A6),D0
	LSR.B	#4,D0
	BRA.S	mt_Arpeggio3

mt_Arpeggio1
	MOVEQ	#0,D0
	MOVE.B	n_cmdlo(A6),D0
	AND.B	#15,D0
	BRA.S	mt_Arpeggio3

mt_Arpeggio2
	MOVE.W	n_period(A6),D2
	BRA.S	mt_Arpeggio4

mt_Arpeggio3
	ASL.W	#1,D0
	MOVEQ	#0,D1
	MOVE.B	n_finetune(A6),D1
	MULU	#36*2,D1
	LEA	mt_PeriodTable,A0
	ADD.L	D1,A0
	MOVEQ	#0,D1
	MOVE.W	n_period(A6),D1
	MOVEQ	#36,D7
mt_arploop
	MOVE.W	(A0,D0.W),D2
	CMP.W	(A0),D1
	BHS.S	mt_Arpeggio4
	ADDQ.L	#2,A0
	DBRA	D7,mt_arploop
	RTS

mt_Arpeggio4
	MOVE.W	D2,6(A5)
	RTS

mt_FinePortaUp
	TST.B	mt_counter
	BNE.S	mt_Return2
	MOVE.B	#$0F,mt_LowMask
mt_PortaUp
	MOVEQ	#0,D0
	MOVE.B	n_cmdlo(A6),D0
	AND.B	mt_LowMask,D0
	MOVE.B	#$FF,mt_LowMask
	SUB.W	D0,n_period(A6)
	MOVE.W	n_period(A6),D0
	AND.W	#$0FFF,D0
	CMP.W	#113,D0
	BPL.S	mt_PortaUskip
	AND.W	#$F000,n_period(A6)
	OR.W	#113,n_period(A6)
mt_PortaUskip
	MOVE.W	n_period(A6),D0
	AND.W	#$0FFF,D0
	MOVE.W	D0,6(A5)
	RTS	
 
mt_FinePortaDown
	TST.B	mt_counter
	BNE	mt_Return2
	MOVE.B	#$0F,mt_LowMask
mt_PortaDown
	CLR.W	D0
	MOVE.B	n_cmdlo(A6),D0
	AND.B	mt_LowMask,D0
	MOVE.B	#$FF,mt_LowMask
	ADD.W	D0,n_period(A6)
	MOVE.W	n_period(A6),D0
	AND.W	#$0FFF,D0
	CMP.W	#856,D0
	BMI.S	mt_PortaDskip
	AND.W	#$F000,n_period(A6)
	OR.W	#856,n_period(A6)
mt_PortaDskip
	MOVE.W	n_period(A6),D0
	AND.W	#$0FFF,D0
	MOVE.W	D0,6(A5)
	RTS

mt_SetTonePorta
	MOVE.L	A0,-(SP)
	MOVE.W	(A6),D2
	AND.W	#$0FFF,D2
	MOVEQ	#0,D0
	MOVE.B	n_finetune(A6),D0
	MULU	#36*2,D0 ;37?
	LEA	mt_PeriodTable,A0
	ADD.L	D0,A0
	MOVEQ	#0,D0
mt_StpLoop
	CMP.W	(A0,D0.W),D2
	BHS.S	mt_StpFound
	ADDQ.W	#2,D0
	CMP.W	#36*2,D0 ;37?
	BLO.S	mt_StpLoop
	MOVEQ	#35*2,D0
mt_StpFound
	MOVE.B	n_finetune(A6),D2
	AND.B	#8,D2
	BEQ.S	mt_StpGoss
	TST.W	D0
	BEQ.S	mt_StpGoss
	SUBQ.W	#2,D0
mt_StpGoss
	MOVE.W	(A0,D0.W),D2
	MOVE.L	(SP)+,A0
	MOVE.W	D2,n_wantedperiod(A6)
	MOVE.W	n_period(A6),D0
	CLR.B	n_toneportdirec(A6)
	CMP.W	D0,D2
	BEQ.S	mt_ClearTonePorta
	BGE	mt_Return2
	MOVE.B	#1,n_toneportdirec(A6)
	RTS

mt_ClearTonePorta
	CLR.W	n_wantedperiod(A6)
	RTS

mt_TonePortamento
	MOVE.B	n_cmdlo(A6),D0
	BEQ.S	mt_TonePortNoChange
	MOVE.B	D0,n_toneportspeed(A6)
	CLR.B	n_cmdlo(A6)
mt_TonePortNoChange
	TST.W	n_wantedperiod(A6)
	BEQ	mt_Return2
	MOVEQ	#0,D0
	MOVE.B	n_toneportspeed(A6),D0
	TST.B	n_toneportdirec(A6)
	BNE.S	mt_TonePortaUp
mt_TonePortaDown
	ADD.W	D0,n_period(A6)
	MOVE.W	n_wantedperiod(A6),D0
	CMP.W	n_period(A6),D0
	BGT.S	mt_TonePortaSetPer
	MOVE.W	n_wantedperiod(A6),n_period(A6)
	CLR.W	n_wantedperiod(A6)
	BRA.S	mt_TonePortaSetPer

mt_TonePortaUp
	SUB.W	D0,n_period(A6)
	MOVE.W	n_wantedperiod(A6),D0
	CMP.W	n_period(A6),D0
	BLT.S	mt_TonePortaSetPer
	MOVE.W	n_wantedperiod(A6),n_period(A6)
	CLR.W	n_wantedperiod(A6)

mt_TonePortaSetPer
	MOVE.W	n_period(A6),D2
	MOVE.B	n_glissfunk(A6),D0
	AND.B	#$0F,D0
	BEQ.S	mt_GlissSkip
	MOVEQ	#0,D0
	MOVE.B	n_finetune(A6),D0
	MULU	#36*2,D0
	LEA	mt_PeriodTable,A0
	ADD.L	D0,A0
	MOVEQ	#0,D0
mt_GlissLoop
	CMP.W	(A0,D0.W),D2
	BHS.S	mt_GlissFound
	ADDQ.W	#2,D0
	CMP.W	#36*2,D0
	BLO.S	mt_GlissLoop
	MOVEQ	#35*2,D0
mt_GlissFound
	MOVE.W	(A0,D0.W),D2
mt_GlissSkip
	MOVE.W	D2,6(A5) ; Set period
	RTS

mt_Vibrato
	MOVE.B	n_cmdlo(A6),D0
	BEQ.S	mt_Vibrato2
	MOVE.B	n_vibratocmd(A6),D2
	AND.B	#$0F,D0
	BEQ.S	mt_vibskip
	AND.B	#$F0,D2
	OR.B	D0,D2
mt_vibskip
	MOVE.B	n_cmdlo(A6),D0
	AND.B	#$F0,D0
	BEQ.S	mt_vibskip2
	AND.B	#$0F,D2
	OR.B	D0,D2
mt_vibskip2
	MOVE.B	D2,n_vibratocmd(A6)
mt_Vibrato2
	MOVE.B	n_vibratopos(A6),D0
	LEA	mt_VibratoTable,A4
	LSR.W	#2,D0
	AND.W	#$001F,D0
	MOVEQ	#0,D2
	MOVE.B	n_wavecontrol(A6),D2
	AND.B	#$03,D2
	BEQ.S	mt_vib_sine
	LSL.B	#3,D0
	CMP.B	#1,D2
	BEQ.S	mt_vib_rampdown
	MOVE.B	#255,D2
	BRA.S	mt_vib_set
mt_vib_rampdown
	TST.B	n_vibratopos(A6)
	BPL.S	mt_vib_rampdown2
	MOVE.B	#255,D2
	SUB.B	D0,D2
	BRA.S	mt_vib_set
mt_vib_rampdown2
	MOVE.B	D0,D2
	BRA.S	mt_vib_set
mt_vib_sine
	MOVE.B	0(A4,D0.W),D2
mt_vib_set
	MOVE.B	n_vibratocmd(A6),D0
	AND.W	#15,D0
	MULU	D0,D2
	LSR.W	#7,D2
	MOVE.W	n_period(A6),D0
	TST.B	n_vibratopos(A6)
	BMI.S	mt_VibratoNeg
	ADD.W	D2,D0
	BRA.S	mt_Vibrato3
mt_VibratoNeg
	SUB.W	D2,D0
mt_Vibrato3
	MOVE.W	D0,6(A5)
	MOVE.B	n_vibratocmd(A6),D0
	LSR.W	#2,D0
	AND.W	#$003C,D0
	ADD.B	D0,n_vibratopos(A6)
	RTS

mt_TonePlusVolSlide
	BSR	mt_TonePortNoChange
	BRA	mt_VolumeSlide

mt_VibratoPlusVolSlide
	BSR.S	mt_Vibrato2
	BRA	mt_VolumeSlide

;mt_Tremolo
;	MOVE.B	n_cmdlo(A6),D0
;	BEQ.S	mt_Tremolo2
;	MOVE.B	n_tremolocmd(A6),D2
;	AND.B	#$0F,D0
;	BEQ.S	mt_treskip
;	AND.B	#$F0,D2
;	OR.B	D0,D2
;mt_treskip
;	MOVE.B	n_cmdlo(A6),D0
;	AND.B	#$F0,D0
;	BEQ.S	mt_treskip2
;	AND.B	#$0F,D2
;	OR.B	D0,D2
;mt_treskip2
;	MOVE.B	D2,n_tremolocmd(A6)
;mt_Tremolo2
;	MOVE.B	n_tremolopos(A6),D0
;	LEA	mt_VibratoTable,A4
;	LSR.W	#2,D0
;	AND.W	#$001F,D0
;	MOVEQ	#0,D2
;	MOVE.B	n_wavecontrol(A6),D2
;	LSR.B	#4,D2
;	AND.B	#$03,D2
;	BEQ.S	mt_tre_sine
;	LSL.B	#3,D0
;	CMP.B	#1,D2
;	BEQ.S	mt_tre_rampdown
;	MOVE.B	#255,D2
;	BRA.S	mt_tre_set
;mt_tre_rampdown
;	TST.B	n_vibratopos(A6)
;	BPL.S	mt_tre_rampdown2
;	MOVE.B	#255,D2
;	SUB.B	D0,D2
;	BRA.S	mt_tre_set
;mt_tre_rampdown2
;	MOVE.B	D0,D2
;	BRA.S	mt_tre_set
;mt_tre_sine
;	MOVE.B	0(A4,D0.W),D2
;mt_tre_set
;	MOVE.B	n_tremolocmd(A6),D0
;	AND.W	#15,D0
;	MULU	D0,D2
;	LSR.W	#6,D2
;	MOVEQ	#0,D0
;	MOVE.B	n_volume(A6),D0
;	TST.B	n_tremolopos(A6)
;	BMI.S	mt_TremoloNeg
;	ADD.W	D2,D0
;	BRA.S	mt_Tremolo3
;mt_TremoloNeg
;	SUB.W	D2,D0
;mt_Tremolo3
;	BPL.S	mt_TremoloSkip
;	CLR.W	D0
;mt_TremoloSkip
;	CMP.W	#$40,D0
;	BLS.S	mt_TremoloOk
;	MOVE.W	#$40,D0
;mt_TremoloOk
;	MOVE.W	D0,8(A5)
;	MOVE.B	n_tremolocmd(A6),D0
;	LSR.W	#2,D0
;	AND.W	#$003C,D0
;	ADD.B	D0,n_tremolopos(A6)
;	RTS

;mt_SampleOffset
;	MOVEQ	#0,D0
;	MOVE.B	n_cmdlo(A6),D0
;	BEQ.S	mt_sononew
;	MOVE.B	D0,n_sampleoffset(A6)
;mt_sononew
;	MOVE.B	n_sampleoffset(A6),D0
;	LSL.W	#7,D0
;	CMP.W	n_length(A6),D0
;	BGE.S	mt_sofskip
;	SUB.W	D0,n_length(A6)
;	LSL.W	#1,D0
;	ADD.L	D0,n_start(A6)
;	RTS
;mt_sofskip
;	MOVE.W	#$0001,n_length(A6)
;	RTS

mt_VolumeSlide
	MOVEQ	#0,D0
	MOVE.B	n_cmdlo(A6),D0
	LSR.B	#4,D0
	TST.B	D0
	BEQ.S	mt_VolSlideDown
mt_VolSlideUp
	ADD.B	D0,n_volume(A6)
	CMP.B	#$40,n_volume(A6)
	BMI.S	mt_vsuskip
	MOVE.B	#$40,n_volume(A6)
mt_vsuskip
	MOVE.B	n_volume(A6),D0
	MOVE.W	D0,8(A5)
	RTS

mt_VolSlideDown
	MOVEQ	#0,D0
	MOVE.B	n_cmdlo(A6),D0
	AND.B	#$0F,D0
mt_VolSlideDown2
	SUB.B	D0,n_volume(A6)
	BPL.S	mt_vsdskip
	CLR.B	n_volume(A6)
mt_vsdskip
	MOVE.B	n_volume(A6),D0
	MOVE.W	D0,8(A5)
	RTS

mt_PositionJump
	MOVE.B	n_cmdlo(A6),D0
	SUBQ.B	#1,D0
	MOVE.B	D0,mt_SongPos
mt_pj2	CLR.B	mt_PBreakPos
	ST 	mt_PosJumpFlag
	RTS

mt_VolumeChange
	MOVEQ	#0,D0
	MOVE.B	n_cmdlo(A6),D0
	CMP.B	#$40,D0
	BLS.S	mt_VolumeOk
	MOVEQ	#$40,D0
mt_VolumeOk
	MOVE.B	D0,n_volume(A6)
	MOVE.W	D0,8(A5)
	RTS

mt_PatternBreak
	MOVEQ	#0,D0
	MOVE.B	n_cmdlo(A6),D0
	MOVE.L	D0,D2
	LSR.B	#4,D0
	MULU	#10,D0
	AND.B	#$0F,D2
	ADD.B	D2,D0
	CMP.B	#63,D0
	BHI.S	mt_pj2
	MOVE.B	D0,mt_PBreakPos
	ST	mt_PosJumpFlag
	RTS

mt_SetSpeed
	MOVE.B	3(A6),D0
	BEQ	mt_Return2
	CLR.B	mt_counter
	MOVE.B	D0,mt_speed
	RTS

mt_CheckMoreEfx
;	BSR	mt_UpdateFunk
	MOVE.B	2(A6),D0
	AND.B	#$0F,D0
	CMP.B	#$9,D0
;	BEQ	mt_SampleOffset
	CMP.B	#$B,D0
	BEQ	mt_PositionJump
	CMP.B	#$D,D0
	BEQ.S	mt_PatternBreak
	CMP.B	#$E,D0
	BEQ.S	mt_E_Commands
	CMP.B	#$F,D0
	BEQ.S	mt_SetSpeed
	CMP.B	#$C,D0
	BEQ	mt_VolumeChange
	BRA	mt_PerNop

mt_E_Commands
	MOVE.B	n_cmdlo(A6),D0
	AND.B	#$F0,D0
	LSR.B	#4,D0
;	BEQ.S	mt_FilterOnOff
	CMP.B	#1,D0
	BEQ	mt_FinePortaUp
	CMP.B	#2,D0
	BEQ	mt_FinePortaDown
	CMP.B	#3,D0
;	BEQ.S	mt_SetGlissControl
	CMP.B	#4,D0
;	BEQ	mt_SetVibratoControl
	CMP.B	#5,D0
	BEQ	mt_SetFineTune
	CMP.B	#6,D0
	BEQ	mt_JumpLoop
	CMP.B	#7,D0
;	BEQ	mt_SetTremoloControl
	CMP.B	#9,D0
;	BEQ	mt_RetrigNote
	CMP.B	#$A,D0
	BEQ	mt_VolumeFineUp
	CMP.B	#$B,D0
	BEQ	mt_VolumeFineDown
	CMP.B	#$C,D0
;	BEQ	mt_NoteCut
	CMP.B	#$D,D0
;	BEQ	mt_NoteDelay
	CMP.B	#$E,D0
;	BEQ	mt_PatternDelay
	CMP.B	#$F,D0
;	BEQ	mt_FunkIt
	RTS

;mt_FilterOnOff
;	MOVE.B	n_cmdlo(A6),D0
;	AND.B	#1,D0
;	ASL.B	#1,D0
;	AND.B	#$FD,$BFE001
;	OR.B	D0,$BFE001
;	RTS	

;mt_SetGlissControl
;	MOVE.B	n_cmdlo(A6),D0
;	AND.B	#$0F,D0
;	AND.B	#$F0,n_glissfunk(A6)
;	OR.B	D0,n_glissfunk(A6)
;	RTS

;mt_SetVibratoControl
;	MOVE.B	n_cmdlo(A6),D0
;	AND.B	#$0F,D0
;	AND.B	#$F0,n_wavecontrol(A6)
;	OR.B	D0,n_wavecontrol(A6)
;	RTS

mt_SetFineTune
	MOVE.B	n_cmdlo(A6),D0
	AND.B	#$0F,D0
	MOVE.B	D0,n_finetune(A6)
	RTS

mt_JumpLoop
	TST.B	mt_counter
	BNE	mt_Return2
	MOVE.B	n_cmdlo(A6),D0
	AND.B	#$0F,D0
	BEQ.S	mt_SetLoop
	TST.B	n_loopcount(A6)
	BEQ.S	mt_jumpcnt
	SUBQ.B	#1,n_loopcount(A6)
	BEQ	mt_Return2
mt_jmploop	MOVE.B	n_pattpos(A6),mt_PBreakPos
	ST	mt_PBreakFlag
	RTS

mt_jumpcnt
	MOVE.B	D0,n_loopcount(A6)
	BRA.S	mt_jmploop

mt_SetLoop
	MOVE.W	mt_PatternPos,D0
	LSR.W	#4,D0
	MOVE.B	D0,n_pattpos(A6)
	RTS

;mt_SetTremoloControl
;	MOVE.B	n_cmdlo(A6),D0
;	AND.B	#$0F,D0
;	LSL.B	#4,D0
;	AND.B	#$0F,n_wavecontrol(A6)
;	OR.B	D0,n_wavecontrol(A6)
;	RTS

;mt_RetrigNote
;	MOVE.L	D1,-(SP)
;	MOVEQ	#0,D0
;	MOVE.B	n_cmdlo(A6),D0
;	AND.B	#$0F,D0
;	BEQ.S	mt_rtnend
;	MOVEQ	#0,D1
;	MOVE.B	mt_counter,D1
;	BNE.S	mt_rtnskp
;	MOVE.W	(A6),D1
;	AND.W	#$0FFF,D1
;	BNE.S	mt_rtnend
;	MOVEQ	#0,D1
;	MOVE.B	mt_counter,D1
;mt_rtnskp
;	DIVU	D0,D1
;	SWAP	D1
;	TST.W	D1
;	BNE.S	mt_rtnend
;mt_DoRetrig
;	MOVE.W	n_dmabit(A6),$DFF096	; Channel DMA off
;	MOVE.L	n_start(A6),(A5)	; Set sampledata pointer
;	MOVE.W	n_length(A6),4(A5)	; Set length
;	MOVE.W	#300,D0
;mt_rtnloop1
;	DBRA	D0,mt_rtnloop1
;	MOVE.W	n_dmabit(A6),D0
;	BSET	#15,D0
;	MOVE.W	D0,$DFF096
;	MOVE.W	#300,D0
;mt_rtnloop2
;	DBRA	D0,mt_rtnloop2
;	MOVE.L	n_loopstart(A6),(A5)
	;MOVE.L	n_replen(A6),4(A5)
;mt_rtnend
;	MOVE.L	(SP)+,D1
;	RTS

mt_VolumeFineUp
	TST.B	mt_counter
	BNE	mt_Return2
	MOVEQ	#0,D0
	MOVE.B	n_cmdlo(A6),D0
	AND.B	#$F,D0
	BRA	mt_VolSlideUp

mt_VolumeFineDown
	TST.B	mt_counter
	BNE	mt_Return2
	MOVEQ	#0,D0
	MOVE.B	n_cmdlo(A6),D0
	AND.B	#$0F,D0
	BRA	mt_VolSlideDown2

;mt_NoteCut
;	MOVEQ	#0,D0
;	MOVE.B	n_cmdlo(A6),D0
;	AND.B	#$0F,D0
;	CMP.B	mt_counter,D0
;	BNE	mt_Return2
;	CLR.B	n_volume(A6)
;	MOVE.W	#0,8(A5)
;	RTS

;mt_NoteDelay
;	MOVEQ	#0,D0
;	MOVE.B	n_cmdlo(A6),D0
;	AND.B	#$0F,D0
;	CMP.B	mt_Counter,D0
;	BNE	mt_Return2
;	MOVE.W	(A6),D0
;	BEQ	mt_Return2
;	MOVE.L	D1,-(SP)
;	BRA	mt_DoRetrig

;mt_PatternDelay
;	TST.B	mt_counter
;	BNE	mt_Return2
;	MOVEQ	#0,D0
;	MOVE.B	n_cmdlo(A6),D0
;	AND.B	#$0F,D0
;	TST.B	mt_PattDelTime2
;	BNE	mt_Return2
;	ADDQ.B	#1,D0
	;MOVE.B	D0,mt_PattDelTime
;	RTS

;mt_FunkIt
;	TST.B	mt_counter
;	BNE	mt_Return2
;	MOVE.B	n_cmdlo(A6),D0
;	AND.B	#$0F,D0
;	LSL.B	#4,D0
;	AND.B	#$0F,n_glissfunk(A6)
;	OR.B	D0,n_glissfunk(A6)
;	TST.B	D0
;	BEQ	mt_Return2
;mt_UpdateFunk
;	MOVEM.L	A0/D1,-(SP)
;	MOVEQ	#0,D0
;	MOVE.B	n_glissfunk(A6),D0
;	LSR.B	#4,D0
;	BEQ.S	mt_funkend
;	LEA	mt_FunkTable,A0
;	MOVE.B	(A0,D0.W),D0
;	ADD.B	D0,n_funkoffset(A6)
;	BTST	#7,n_funkoffset(A6)
;	BEQ.S	mt_funkend
;	CLR.B	n_funkoffset(A6)

;	MOVE.L	n_loopstart(A6),D0
;	MOVEQ	#0,D1
;	MOVE.W	n_replen(A6),D1
;	ADD.L	D1,D0
;	ADD.L	D1,D0
;	MOVE.L	n_wavestart(A6),A0
;	ADDQ.L	#1,A0
;	CMP.L	D0,A0
;	BLO.S	mt_funkok
;	MOVE.L	n_loopstart(A6),A0
;mt_funkok
;	MOVE.L	A0,n_wavestart(A6)
;	MOVEQ	#-1,D0
;	SUB.B	(A0),D0
;	MOVE.B	D0,(A0)
;mt_funkend
;	MOVEM.L	(SP)+,A0/D1
;	RTS

vbi:	movem.l	d0-d7/a0-a6,-(a7)

	jsr     mt_music
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
	; multiply y with 40 to get add factor for bitplane
	clr.l   d3
	add.l   #100,d2
	mulu    #40,d2
	add.l	d2,a0   ; start address for correct line
	
checkplane:
	move.l  c,d0
	btst.l	#0,d0	; testbit on colorvalue to get planes to plot
	beq	plane2
	jsr	pixset

plane2:
	lea	bplane,a0 ; bitplane address to a0
;	add.l   #100*40,a0
	add.l	d2,a0   ; start address for correct line
	add.l	#10240,a0 ; address of plane	
	move.l  c,d0
	btst.l  #1,d0	    
	beq 	plane3
	jsr	pixset


;	move.l  #$fff,$dff180
					
plane3:
	lea	bplane,a0
;	add.l  #100*40,a0
	add.l	d2,a0   ; start address for correct line
	add.l	#20480,a0	
	move.l  c,d0
	btst.l	#2,d0
	beq	plane4
	jsr	pixset

plane4:

	lea	bplane,a0
;	add.l  #100*40,a0
	add.l	d2,a0 
	add.l	#30720,a0	

	move.l  c,d0
	btst.l  #3,d0
	beq     plane5
	jsr	pixset
	


plane5:

	lea	bplane,a0
	add.l	d2,a0   ; start address for correct line
	add.l	#40960,a0	
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
	dc.w $182,$0101
	dc.w $184,$0102
	dc.w $186,$0203
	dc.w $188,$0204
	dc.w $18a,$0305
	dc.w $18c,$0306
	dc.w $18e,$0407
	dc.w $190,$0408
	dc.w $192,$0509
	dc.w $194,$050a
	dc.w $196,$060b
	dc.w $198,$060c
	dc.w $19a,$070d
	dc.w $19c,$070e
	dc.w $19e,$080f
	dc.w $1a0,$080e
	dc.w $1a2,$070d
	dc.w $1a4,$070c
	dc.w $1a6,$060b
	dc.w $1a8,$0609
	dc.w $1aa,$0508
	dc.w $1ac,$0507
	dc.w $1ae,$0406
	dc.w $1b0,$0405
	dc.w $1b2,$0304
	dc.w $1b4,$0303
	dc.w $1b6,$0202
	dc.w $1b8,$0301
	dc.w $1ba,$0208
	dc.w $1bc,$0204
	dc.w $1be,$0101
	;Generated by IFFMaster v1.0 by JUNIX / ARCANE!
	dc.w $ffff,$fffe
	
sintable:


	DC.W	$0009,$001B,$002D,$003E,$0050,$0062,$0073,$0085,$0096,$00A7
	DC.W	$00B7,$00C8,$00D8,$00E8,$00F8,$0108,$0117,$0126,$0134,$0142
	DC.W	$0150,$015D,$016A,$0176,$0182,$018E,$0199,$01A3,$01AD,$01B7
	DC.W	$01C0,$01C8,$01D0,$01D7,$01DE,$01E4,$01EA,$01EF,$01F3,$01F7
	DC.W	$01FA,$01FC,$01FE,$01FF,$0200,$0200,$01FF,$01FE,$01FC,$01FA
	DC.W	$01F7,$01F3,$01EF,$01EA,$01E4,$01DE,$01D7,$01D0,$01C8,$01C0
	DC.W	$01B7,$01AD,$01A3,$0199,$018E,$0182,$0176,$016A,$015D,$0150
	DC.W	$0142,$0134,$0126,$0117,$0108,$00F8,$00E8,$00D8,$00C8,$00B7
	DC.W	$00A7,$0096,$0085,$0073,$0062,$0050,$003E,$002D,$001B,$0009
	DC.W	$FFF7,$FFE5,$FFD3,$FFC2,$FFB0,$FF9E,$FF8D,$FF7B,$FF6A,$FF59
	DC.W	$FF49,$FF38,$FF28,$FF18,$FF08,$FEF8,$FEE9,$FEDA,$FECC,$FEBE
	DC.W	$FEB0,$FEA3,$FE96,$FE8A,$FE7E,$FE72,$FE67,$FE5D,$FE53,$FE49
	DC.W	$FE40,$FE38,$FE30,$FE29,$FE22,$FE1C,$FE16,$FE11,$FE0D,$FE09
	DC.W	$FE06,$FE04,$FE02,$FE01,$FE00,$FE00,$FE01,$FE02,$FE04,$FE06
	DC.W	$FE09,$FE0D,$FE11,$FE16,$FE1C,$FE22,$FE29,$FE30,$FE38,$FE40
	DC.W	$FE49,$FE53,$FE5D,$FE67,$FE72,$FE7E,$FE8A,$FE96,$FEA3,$FEB0
	DC.W	$FEBE,$FECC,$FEDA,$FEE9,$FEF8,$FF08,$FF18,$FF28,$FF38,$FF49
	DC.W	$FF59,$FF6A,$FF7B,$FF8D,$FF9E,$FFB0,$FFC2,$FFD3,$FFE5,$FFF7
	DC.W	$0009,$001B,$002D,$003E,$0050,$0062,$0073,$0085,$0096,$00A7
	DC.W	$00B7,$00C8,$00D8,$00E8,$00F8,$0108,$0117,$0126,$0134,$0142
	DC.W	$0150,$015D,$016A,$0176,$0182,$018E,$0199,$01A3,$01AD,$01B7
	DC.W	$01C0,$01C8,$01D0,$01D7,$01DE,$01E4,$01EA,$01EF,$01F3,$01F7
	DC.W	$01FA,$01FC,$01FE,$01FF,$0200,$0200,$01FF,$01FE,$01FC,$01FA
	DC.W	$01F7,$01F3,$01EF,$01EA,$01E4,$01DE,$01D7,$01D0,$01C8,$01C0
	DC.W	$01B7,$01AD,$01A3,$0199,$018E,$0182,$0176,$016A,$015D,$0150
	DC.W	$0142,$0134,$0126,$0117,$0108,$00F8,$00E8,$00D8,$00C8,$00B7
	DC.W	$00A7,$0096,$0085,$0073,$0062,$0050,$003E,$002D,$001B,$0009
	DC.W	$FFF7,$FFE5,$FFD3,$FFC2,$FFB0,$FF9E,$FF8D,$FF7B,$FF6A,$FF59
	DC.W	$FF49,$FF38,$FF28,$FF18,$FF08,$FEF8,$FEE9,$FEDA,$FECC,$FEBE
	DC.W	$FEB0,$FEA3,$FE96,$FE8A,$FE7E,$FE72,$FE67,$FE5D,$FE53,$FE49
	DC.W	$FE40,$FE38,$FE30,$FE29,$FE22,$FE1C,$FE16,$FE11,$FE0D,$FE09
	DC.W	$FE06,$FE04,$FE02,$FE01,$FE00,$FE00,$FE01,$FE02,$FE04,$FE06
	DC.W	$FE09,$FE0D,$FE11,$FE16,$FE1C,$FE22,$FE29,$FE30,$FE38,$FE40
	DC.W	$FE49,$FE53,$FE5D,$FE67,$FE72,$FE7E,$FE8A,$FE96,$FEA3,$FEB0
	DC.W	$FEBE,$FECC,$FEDA,$FEE9,$FEF8,$FF08,$FF18,$FF28,$FF38,$FF48
	DC.W	$FF59,$FF6A,$FF7B,$FF8D,$FF9E,$FFB0,$FFC2,$FFD3,$FFE5,$FFF7
	DC.W	$0009,$001B,$002D,$003E,$0050,$0062,$0073,$0084,$0096,$00A7
	DC.W	$00B7,$00C8,$00D8,$00E8,$00F8,$0108,$0117,$0126,$0134,$0142
	DC.W	$0150,$015D,$016A,$0176,$0182,$018E,$0199,$01A3,$01AD,$01B7
	DC.W	$01C0,$01C8,$01D0,$01D7,$01DE,$01E4,$01EA,$01EF,$01F3,$01F7
	DC.W	$01FA,$01FC,$01FE,$01FF,$0200,$0200,$01FF,$01FE,$01FC,$01FA
	DC.W	$01F7,$01F3,$01EF,$01EA,$01E4,$01DE,$01D7,$01D0,$01C8,$01C0
	DC.W	$01B7,$01AD,$01A3,$0199,$018E,$0182,$0176,$016A,$015D,$0150
	DC.W	$0142,$0134,$0126,$0117,$0108,$00F8,$00E8,$00D8,$00C8,$00B8
	DC.W	$00A7,$0096,$0085,$0073,$0062,$0050,$003E,$002D,$001B,$0009
	DC.W	$FFF7,$FFE5,$FFD3,$FFC2,$FFB0,$FF9E,$FF8D,$FF7C,$FF6A,$FF59
	DC.W	$FF49,$FF38,$FF28,$FF18,$FF08,$FEF8,$FEE9,$FEDA,$FECC,$FEBE
	DC.W	$FEB0,$FEA3,$FE96,$FE8A,$FE7E,$FE72,$FE67,$FE5D,$FE53,$FE49
	DC.W	$FE40,$FE38,$FE30,$FE29,$FE22,$FE1C,$FE16,$FE11,$FE0D,$FE09
	DC.W	$FE06,$FE04,$FE02,$FE01,$FE00,$FE00,$FE01,$FE02,$FE04,$FE06
	DC.W	$FE09,$FE0D,$FE11,$FE16,$FE1C,$FE22,$FE29,$FE30,$FE38,$FE40
	DC.W	$FE49,$FE53



;mt_FunkTable dc.b 0,5,6,7,8,10,11,13,16,19,22,26,32,43,64,128

mt_VibratoTable	
	dc.b   0, 24, 49, 74, 97,120,141,161
	dc.b 180,197,212,224,235,244,250,253
	dc.b 255,253,250,244,235,224,212,197
	dc.b 180,161,141,120, 97, 74, 49, 24

mt_PeriodTable
; Tuning 0, Normal
	dc.w	856,808,762,720,678,640,604,570,538,508,480,453
	dc.w	428,404,381,360,339,320,302,285,269,254,240,226
	dc.w	214,202,190,180,170,160,151,143,135,127,120,113
; Tuning 1
	dc.w	850,802,757,715,674,637,601,567,535,505,477,450
	dc.w	425,401,379,357,337,318,300,284,268,253,239,225
	dc.w	213,201,189,179,169,159,150,142,134,126,119,113
; Tuning 2
	dc.w	844,796,752,709,670,632,597,563,532,502,474,447
	dc.w	422,398,376,355,335,316,298,282,266,251,237,224
	dc.w	211,199,188,177,167,158,149,141,133,125,118,112
; Tuning 3
	dc.w	838,791,746,704,665,628,592,559,528,498,470,444
	dc.w	419,395,373,352,332,314,296,280,264,249,235,222
	dc.w	209,198,187,176,166,157,148,140,132,125,118,111
; Tuning 4
	dc.w	832,785,741,699,660,623,588,555,524,495,467,441
	dc.w	416,392,370,350,330,312,294,278,262,247,233,220
	dc.w	208,196,185,175,165,156,147,139,131,124,117,110
; Tuning 5
	dc.w	826,779,736,694,655,619,584,551,520,491,463,437
	dc.w	413,390,368,347,328,309,292,276,260,245,232,219
	dc.w	206,195,184,174,164,155,146,138,130,123,116,109
; Tuning 6
	dc.w	820,774,730,689,651,614,580,547,516,487,460,434
	dc.w	410,387,365,345,325,307,290,274,258,244,230,217
	dc.w	205,193,183,172,163,154,145,137,129,122,115,109
; Tuning 7
	dc.w	814,768,725,684,646,610,575,543,513,484,457,431
	dc.w	407,384,363,342,323,305,288,272,256,242,228,216
	dc.w	204,192,181,171,161,152,144,136,128,121,114,108
; Tuning -8
	dc.w	907,856,808,762,720,678,640,604,570,538,508,480
	dc.w	453,428,404,381,360,339,320,302,285,269,254,240
	dc.w	226,214,202,190,180,170,160,151,143,135,127,120
; Tuning -7
	dc.w	900,850,802,757,715,675,636,601,567,535,505,477
	dc.w	450,425,401,379,357,337,318,300,284,268,253,238
	dc.w	225,212,200,189,179,169,159,150,142,134,126,119
; Tuning -6
	dc.w	894,844,796,752,709,670,632,597,563,532,502,474
	dc.w	447,422,398,376,355,335,316,298,282,266,251,237
	dc.w	223,211,199,188,177,167,158,149,141,133,125,118
; Tuning -5
	dc.w	887,838,791,746,704,665,628,592,559,528,498,470
	dc.w	444,419,395,373,352,332,314,296,280,264,249,235
	dc.w	222,209,198,187,176,166,157,148,140,132,125,118
; Tuning -4
	dc.w	881,832,785,741,699,660,623,588,555,524,494,467
	dc.w	441,416,392,370,350,330,312,294,278,262,247,233
	dc.w	220,208,196,185,175,165,156,147,139,131,123,117
; Tuning -3
	dc.w	875,826,779,736,694,655,619,584,551,520,491,463
	dc.w	437,413,390,368,347,328,309,292,276,260,245,232
	dc.w	219,206,195,184,174,164,155,146,138,130,123,116
; Tuning -2
	dc.w	868,820,774,730,689,651,614,580,547,516,487,460
	dc.w	434,410,387,365,345,325,307,290,274,258,244,230
	dc.w	217,205,193,183,172,163,154,145,137,129,122,115
; Tuning -1
	dc.w	862,814,768,725,684,646,610,575,543,513,484,457
	dc.w	431,407,384,363,342,323,305,288,272,256,242,228
	dc.w	216,203,192,181,171,161,152,144,136,128,121,114

mt_chan1temp	dc.l	0,0,0,0,0,$00010000,0,  0,0,0,0
mt_chan2temp	dc.l	0,0,0,0,0,$00020000,0,  0,0,0,0
mt_chan3temp	dc.l	0,0,0,0,0,$00040000,0,  0,0,0,0
mt_chan4temp	dc.l	0,0,0,0,0,$00080000,0,  0,0,0,0

mt_SampleStarts	dc.l	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
		dc.l	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

mt_SongDataPtr	dc.l 0

mt_speed	dc.b 6
mt_counter	dc.b 0
mt_SongPos	dc.b 0
mt_PBreakPos	dc.b 0
mt_PosJumpFlag	dc.b 0
mt_PBreakFlag	dc.b 0
mt_LowMask	dc.b 0
mt_PattDelTime	dc.b 0
mt_PattDelTime2	dc.b 0,0

mt_PatternPos	dc.w 0
mt_DMACONtemp	dc.w 0
mt_Data:	incbin 'dh2:tristar_and_red_sector11.mod'
;/* End of File */


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
gfxbase: dc.l 0
oldcop: dc.l 0
gfxname: dc.b "graphics.library",0


;gfxbase:	dc.l	0

