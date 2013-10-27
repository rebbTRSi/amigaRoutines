;APS00000000000000000000000000000000000000000000000000000000000000000000000000000000

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
;0001 -> col1	 plot 1 to plane 1
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


	move.l #bplane,d0 
	lea bplcop,a0 ;fill copperlist bitplane 
	moveq #3,d1 ;loop 4 times (= number of bitplanes) 


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

	move.l #0,d1

byy:	
	move.l #40,d2		
	move.l #5,d0
	move.l #bplane,a0
	jsr    plot

	add.l  #1,d1
	cmp.l  #9,d1
	bne    byy
	
hiiri:	btst   #6,$bfe001
	bne    hiiri


	rts

plot:
	;takes d0=color,d1=x,d2=y,a0=bplane


findy:  
	mulu	#40,d2	; multiply y with 40 to get add factor for bitplane
	add.l	d2,a0   ; start address for correct line
	
checkplane:

	btst.l	#0,d0	; testbit on colorvalue to get planes to plot
	beq	Plane2
	jsr	bitset	; Plot the pixel
		
plane2:

	move.l	#bplane,a0 ; bitplane address to a0
	add.l	d2,a0	   ; get to the right row
	add.l	#40*256*1,a0 ; address of plane	
	btst.l  #1,d0	    
	beq 	plane3
	jsr	bitset
				
plane3:

	move.l	#bplane,a0
	add.l	d2,a0

	add.l	#40*256*2,a0	

	btst.l	#2,d0
	beq	plane4
	jsr	bitset

plane4:

	move.l	#bplane,a0
	add.l	d2,a0

	add.l	#$40*256*3,a0	

	btst.l	#3,d0
	beq 	out
	jsr	bitset

out:
	rts

bitset:
	move.l	d1,d4		; copy x to d4
	move.l	d1,d5		; and d5
	move.l	d1,d3		; and d3
	divu.l	#8,d3		; divide with 8 to get number of byte
	add.l	d3,a0		; get to the byte we are changing

	mulu.l	#8,d3		; How many times did x fit in 8?
	cmp	#0,d3		; If zero, x is directly the bits to set
	beq	nolla		;
	sub.l   d3,d4		; Substract multiply of 8 from original x
	move.l	d4,d5		; to get bits to set
nolla:  
plot2:	
	bset	d5,(a0)		; set the "d5th bit" on a0  
	rts

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
	
	dc.w $0100,%0100000000000000 
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
	dc.w $0180,$0000 
	dc.w $0182,$0fff 
	dc.w $0184,$0f00 
	dc.w $0186,$00f0 
	dc.w $0188,$000f 
	dc.w $018a,$0ff0 
	dc.w $018c,$0fff 	
	dc.w $018e,$00ff 
	dc.w $0190,$0f0f 
	dc.w $0192,$0400 
	dc.w $0194,$0f02 
	dc.w $0196,$0800 
	dc.w $0198,$0f20 
	dc.w $019a,$0f40 
	dc.w $019c,$0f60 
	dc.w $019e,$0f80 
	dc.w $ffff,$fffe
	

	
	
c:	dc.l	0
x:	dc.l	0
y:	dc.l 	0
kerta:	dc.l	0
bplane:	blk.b	40960,0 ; reserve space for 4 bitplane pic
gfxlib:		dc.b	"graphics.library",0,0
gfxbase:	dc.l	0

