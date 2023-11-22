// 0801 + : code
// 2000-2400 : charset logo
// 2400-2800 : charset double
// 2800-2A00 : copie logo
// limite 3fff
// e0-e2 : sauvegarde registres IRQs

* = $0801 "code"
.label pos_x = $fd
.label nb_raster = $f0
.label color1 = $f1
.label etape = $f2
.label fld_pos = $f3
.label pulse = $f4
.label sens = $f5
.label mov_y = $f6
.label add_x_sprites = $f7
.label mov_x = $f8
.label inc_sprites = $f9
.label inc_delay = $fa
.label sound_delay = $fb
.label wait_start = $c0
.label masks = $d0

intro_code:
    sei
    lda #32
    sta nb_raster
    lda #2
    sta wait_start
    ldx #24
    stx inc_delay
    lda #0
    sta sens
    sta $d010

reset_sound:
    sta $d400,x
    dex
    bpl reset_sound
    stx masks
    stx masks+1
    stx masks+2
    stx masks+3
    stx inc_sprites

    // Volume max
    lda #15
    sta $d418
    // ADSR voice 1,2
    lda #$aa
    sta $d405
    sta $d406
    sta $d40d
    sta $d40c
    sta $d413
    sta $d414
    // voice 1,2 = triangle
    lda #17
    sta $d404
    sta $d40b
    //lda #%01000001
    sta $d412

    lda #$33
    sta $01
    ldy #1
    sty mov_y
    sty $fc
    dey
    ldx #$ff
    stx mov_x
    stx $3fff
    inx
    //stx nb_raster
    stx pos_x
    stx color1
    stx $fe
    stx etape
    stx fld_pos
copie_chars:
    lda $d000,y
    sta dest_char1:$2400,x
    inx
    sta dest_char2:$2400,x
    inx
    bne no_inc_x
    inc dest_char1+1
    inc dest_char2+1
no_inc_x:
    iny
    bne copie_chars
    inc copie_chars+2
    dec $fc
    bpl copie_chars

    lda #$35
    sta $01
    sty $d020
    sty $d021
    sty $d022
    sty $d023
aff_logo:
    lda #192
    sta $0500,x
    sta $0600,x
    sta $0700,x
    sta $0400+15*40,x
    sta $0400+16*40,x
    lda #0
    sta $0300,x
    sta $d900,x
    sta $da00,x
    sta $db00,x
    lda logo_pos,x
    sta $0400,x
    lda logo_pos+104,x
    sta $0400+104,x
    lda #8
    sta $d800,x
    sta $d800+104,x
    inx
    bne aff_logo
    ldx #39
aff_scroll:
    lda #1
    sta $d800+15*40,x
    lda #7
    sta $d800+16*40,x
    dex
    bpl aff_scroll

    ldx #7
setup_sprites:
    lda #$0300/64
    sta 2040,x
    lda #1
    sta $d027,x
    dex
    bpl setup_sprites

    lda #$18
    sta $d018
    lda #$d8
    sta $d016

   	//-- init IRQ

	lda #<irq0
	sta $fffe
	lda #>irq0
	sta $ffff
	lda #50+10*8
	sta $d012
    lda #$7f
    sta $dc0d
    sta $dd0d
    lda #$1b
    sta $d011
    lda #1      // enable raster IRQ
    sta $d01a
    lda $dc0d	// ack CIA-1
    lda $dd0d	// ack CIA-2
    //lda #%00110000
    //sta $0300
    //sta $0300+6
    //lda #%11111100
    //sta $0300+3
    lda #$ff
    sta $d015
    cli

    ldx #0

boucle:
    lda etape
    beq boucle

wait_pulse:
    ldy pulse
    bne wait_pulse

    cmp #2
    beq ok_suite
    inc etape
    lda #250
    sta pulse
    jmp boucle

ok_suite:

    lda sens
    bne supprime_logo

update_logo:
    lda $2000,y
    and masks,x
    ora $2800,y
    sta $2000,y

    lda $2100,y
    and masks,x
    ora $2900,y
    sta $2100,y

    lda $2200,y
    and masks,x
    ora $2a00,y
    sta $2200,y
    inx
    txa
    and #3
    tax
    iny
    bne update_logo

    // affiche logo
    asl masks
    asl masks+1
    lsr masks+2
    lsr masks+3
    lda #4
    ldx masks
    bne pas_fini_affichelogo
    inc sens
    lda #255

suite_logo:

    dec masks
    dec masks+1
    dec masks+2
    dec masks+3

pas_fini_affichelogo:
    sta pulse
    jmp boucle

supprime_logo:

    lda #$ff
    eor masks,x
    ora $2000,y
    sta $2000,y

    lda #$ff
    eor masks,x
    ora $2100,y
    sta $2100,y

    lda #$ff
    eor masks,x
    ora $2200,y
    sta $2200,y

    inx
    txa
    and #3
    tax
    iny
    bne supprime_logo

    asl masks
    asl masks+1
    lsr masks+2
    lsr masks+3

    lda #4
    ldx masks
    bne pas_fini_affichelogo

    dec sens
    lda #64
    jmp suite_logo


//------------------------------------------------------------------------------
// irq0 : après logo
//------------------------------------------------------------------------------


irq0:
    sta $e0
    stx $e1
    sty $e2

    ldx #0
    stx $d021
    ldy $d012
wait_raster0:
    cpy $d012
    beq wait_raster0
    stx $d021
    asl $d019
    lda #<irq1
    sta $fffe
    lda #>irq1
    sta $ffff
    lda #50+15*8-2
    sta $d012
    
    // sound

    lda inc_sprites
    and #$3f
    tax
    lda pos_x_sin,x
    lsr
    lsr
    lsr
    sta $d408

    lda sound_delay
    beq sound_finished
    dec sound_delay
    bne not_finished
sound_finished:
    lda #0
    sta $d40f
    sta $d40e
not_finished:

    // check space
    lda #$7F  
    sta $DC00 
    lda $DC01 
    and #$10
    beq is_space
    jmp out_irq
is_space:
    lda #$37
    sta $01
    jmp $fce2

//------------------------------------------------------------------------------
// irq1 : avant le scrolling, FLD
//------------------------------------------------------------------------------
 
irq1:
    sta $e0
    stx $e1
    sty $e2

    ldy fld_pos
    jsr fld_y
    lda pos_x
    ora #$d0
    ldy $d012
wait_raster:
    cpy $d012
    beq wait_raster
    sta $d016
    asl $d019
    lda #<irq2
    sta $fffe
    lda #>irq2
    sta $ffff
    lda #249
    sta $d012
    lda etape
    beq fin_fld
    inc nb_raster
    lda nb_raster
    and #63
    tax
    lda pos_y_sin,x
    sta fld_pos
    lsr
    lsr
    clc
    adc pos_x_sin,x
    lsr
    lsr
    lsr
    sta $d401
    //jsr update_max_y

fin_fld:
    jmp out_irq

//------------------------------------------------------------------------------
// irq2 : fin écran
//------------------------------------------------------------------------------

irq2:
    sta $e0
    stx $e1
    sty $e2

    lda $d011
    and #$f7
    sta $d011
    lda #252
wait_250:
    cmp $d012
    bne wait_250
    lda $d011
    ora #$0f
    sta $d011
    
    // no sprites
    lda #0
    sta $d015

    asl $d019
    lda #$d8
    sta $d016
    lda #<irq3
    sta $fffe
    lda #>irq3
    sta $ffff
    lda #0 // was 49
    sta $d012
    lda #$1b
    sta $d011


    // sprites contents

    dec inc_delay
    bne pas_copie_sprites
    lda #4
    sta inc_delay
    lda inc_sprites
    inc inc_sprites
    and #7
    asl
    asl
    asl
    tax
    ldy #0
copie_sprites:
    lda sprites_contents,x
    sta $0300,y
    iny
    iny
    iny
    inx
    cpy #8*3
    bne copie_sprites
pas_copie_sprites:

    lda pulse
    beq no_pulse
    dec pulse
no_pulse:
    lda etape
    cmp #0
    bne pas0
    inc nb_raster
    bne pas_fini

ok_etape:
    lda wait_start
    beq ok_start
    dec wait_start
    bne pas_fini
ok_start:
    lda #0 // was $30
    sta fld_pos
    inc etape
    bne pas_fini
pas0:
    ldx #11
    stx $d022
    inx
    stx $d023
    lda #15
    sta color1

pas_fini:
    dec pos_x
    bpl fin_irq2
    lda #7
    sta pos_x
    ldx #0
copie:
    lda $0401+40*15,x
    sta $0400+40*15,x
    lda $0401+40+40*15,x
    sta $0400+40+40*15,x
    inx
    cpx #39
    bne copie
    ldx $fe
    lda scroll_text,x
    beq fin_texte
    asl
    ora #128
    sta $0400+39+40*15
    ora #1
    sta $0400+39+40+40*15
    inc $fe
    jmp out_irq
fin_texte:
    sta $fe
fin_irq2:
    jmp out_irq

//------------------------------------------------------------------------------
// irq3 : avant logo, et animation des sprites
//------------------------------------------------------------------------------

irq3:
    sta $e0
    stx $e1
    sty $e2

    ldy color1
    lda $d012
wait3:
    cmp $d012
    beq wait3
    sty $d021
    ldx #$ff
    stx $d015
    inx
    // positions sprites
    stx add_x_sprites
update_sprites:

    lda pos_sprites,x
    clc
    adc mov_y
    sta pos_sprites,x
    and #$3f
    tay
    lda pos_y_sin,y
    pha
    lda pos_x_sin,y
    clc
    adc orig_x
    bcc no_high

    pha
    lda add_x_sprites
    ora sprites_x_mask,x
    sta add_x_sprites
    pla
no_high:
    pha
    txa
    asl
    tay
    pla
    sta $d000,y
    
    pla
    clc
    adc orig_y
    sta $d001,y

    inx
    cpx #8
    bne update_sprites

    clc
    lda orig_x
    adc mov_x
    sta orig_x

    cmp #50
    bne pas_debut_x

    lda #64
    jsr beep

    lda #1
    bne pas_fin_x

pas_debut_x:
    cmp #250
    bne ni_fin_x

    lda #96
    jsr beep

    lda #255
pas_fin_x:
    sta mov_x
ni_fin_x:

    clc
    lda orig_y
    adc mov_y
    sta orig_y

    cmp max_y:#255-64
    bne pas_fin_y
    // was bne
    //jsr update_max_y

    lda #48
    jsr beep

    lda #255
    sta mov_y

    jsr update_max_y // new

    lda max_y
    cmp #255-64
    bne pas_fin_y

    //jsr update_max_y // old

pas_fin_y:
    cmp #32
    bne pas_debut_y

    lda #48
    jsr beep

    lda #1
    sta mov_y

    jsr update_max_y

pas_debut_y:

    lda add_x_sprites
    sta $d010

    asl $d019
    lda #<irq0
    sta $fffe
    lda #>irq0
    sta $ffff
    lda #50+9*8-1
    sta $d012

out_irq:
    
    lda $e0
    ldx $e1
    ldy $e2
    rti

update_max_y:
    lda #50+15*8-60
    clc
    adc fld_pos
    sta max_y
    rts

beep:
    sta $d40f
    lda #4
    sta sound_delay
    rts

//----------------------------------------------------------------------------
// fld_y :	perform FLD effect at current position, Y = length
//----------------------------------------------------------------------------

fld_y:
{
    cpy #0
    beq stop_fld
fld_start:
	ldx $d012
wait_fld:
	cpx $d012
	beq wait_fld
	lda $d011
	clc
	adc #1
	and #7
	ora #$18
	sta $d011
	dey
	bne fld_start
stop_fld:
    rts
}


scroll_text:
    .text "    babygang welcomes you to this small 2k intro for csdb compo released in january 2023. Logo by shine, code by papapower. "
    .text " Greetings to all the amazing c64 scene. see us at babygang.fr and petscii.de  "
    .byte 0

pos_y_sin:
    .import binary "pos_y.bin"
.label pos_x_sin = pos_y_sin + 64

sprites_x_mask:
    .byte 1,2,4,8,16,32,64,128

pos_sprites:
    .byte 0,8,$10,$18,$20,$28,$30,$38

orig_x:
    .byte 240
orig_y:
    .byte 100

sprites_contents:
    .byte %00000000
    .byte %00000000
    .byte %00000000
    .byte %00011000
    .byte %00011000
    .byte %00000000
    .byte %00000000
    .byte %00000000

    .byte %00000000
    .byte %00000000
    .byte %00011000
    .byte %00100100
    .byte %00100100
    .byte %00011000
    .byte %00000000
    .byte %00000000

    .byte %00000000
    .byte %00011000
    .byte %00100100
    .byte %01000010
    .byte %01000010
    .byte %00100100
    .byte %00011000
    .byte %00000000

    .byte %00011000
    .byte %00100100
    .byte %01000010
    .byte %10000001
    .byte %10000001
    .byte %01000010
    .byte %00100100
    .byte %00011000

    .byte %00011000
    .byte %00100100
    .byte %01000010
    .byte %10000001
    .byte %10000001
    .byte %01000010
    .byte %00100100
    .byte %00011000

    .byte %00000000
    .byte %00011000
    .byte %00100100
    .byte %01000010
    .byte %01000010
    .byte %00100100
    .byte %00011000
    .byte %00000000

    .byte %00000000
    .byte %00000000
    .byte %00011000
    .byte %00100100
    .byte %00100100
    .byte %00011000
    .byte %00000000
    .byte %00000000

    .byte %00000000
    .byte %00000000
    .byte %00000000
    .byte %00011000
    .byte %00011000
    .byte %00000000
    .byte %00000000
    .byte %00000000

* = $2000
charset:
    .fill 640,$ff
    //.import binary "charset_logo.bin"
logo_pos:
    .import binary "charset_pos.bin"
* = $2800
    .import binary "charset_logo.bin"

// d021 : 15, d022 : 11, d023 : 12
