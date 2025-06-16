; 64keymaps.asm
;
; Copyright (c) 2025 by David R. Van Wagner
; MIT LICENSE
; github.com/davervw
;
; keyboard map editor for Commodore 64
; allows remapping of keyboard on standard hardware
; such as for internationalization for different regions
; or modernization (more closely match modern keyboard layouts)
;
; currently displays keyboard maps, port of BASIC code to 6502
;
; TODO: editor functionality

* = $c000

start:
    jmp init
    jmp reserved

init:
    jsr copy_map_addrs
    jsr copy_maps
    jsr index_chars
    jsr compute_scan_xys
    lda #147
    jsr $ffd2
    lda #0
    ldx #1
    ldy #1
    jsr display_map
    lda #1
    ldx #1
    ldy #7
    jsr display_map
    lda #2
    ldx #1
    ldy #13
    jsr display_map
    lda #3
    ldx #1
    ldy #19
    jsr display_map
    ldx #<xystrings
    ldy #>xystrings
    jsr display_xystrs
    ldy #21
    sty $d6
    lda #13
    jsr $ffd2
    rts

reserved:
    brk

getmap:
    jmp ($028f)

copy_map_addrs:
    ; first retrieve addresses to four sets
    sei ; don't allow IRQ to process keyboard and interfere with us
    
    lda $28d
    pha ; save existing keyboard shift state
    
    ldy #0
    sty $ff
    sty $28d ; keyboard shift state (0,1,2,4)
-   jsr getmap
    lda $f5
    ldy $ff
    sta rom_maps,y
    lda $f6
    sta rom_maps+1,y
    inc $ff
    inc $ff
    lda $28d
    clc
    bne +
    sec
+   rol $28d
    cmp #4
    bcc -

    pla
    sta $28d ; restore shift map

    cli ; restore keyboard
    rts

copy_maps:
    ldx #0
    lda #<remaps
    sta $fd
    lda #>remaps
    sta $fe
--  lda rom_maps,x
    sta $fb
    lda rom_maps+1,x
    sta $fc

    ldy #63
-   lda ($fb),y
    sta ($fd),y
    dey
    bpl -

    clc
    lda $fd
    adc #64
    sta $fd
    bcc +
    inc $fe
+
    inx
    inx
    cpx #8
    bcc --
    rts

index_chars:
    ldx #0
    lda #<remaps
    sta $fb
    lda #>remaps
    sta $fc
    lda #<char_to_scan
    sta $fd
    lda #>char_to_scan
    sta $fe
--  ldy #63
    sty $ff
-   lda ($fb),y
    tay
    lda $ff
    sta ($fd),y
    dec $ff
    ldy $ff
    bpl -
    clc
    lda $fb
    adc #64 ; advance source 64 scancodes
    sta $fb
    bcc +
    inc $fc
+   inc $fe ; advance dest 256 characters
    inx
    cpx #4 ; 4 sets?
    bcc --
    rts

display_map: ; .a = map (0..3), .x/.y = screen coordinates
    stx col_x
    sty row_y

    tax
    lda #<remaps
    sta $fb
    lda #>remaps
    sta $fc
    cpx #0
    beq ++
-   clc
    lda $fb
    adc #64
    sta $fb
    bcc +
    inc $fc
+   dex
    bne -
++
    lda #0
    sta $ff ; scancode
    tay
-   lda ($fb),y ; remap of requested shift state
    cmp #$ff
    beq +

    sta $02 ; save character    
    lda scancode_x, y
    tax
    lda scancode_y, y
    tay
    lda $02 ; restore character

    jsr display_char_at_xy
+   inc $ff
    ldy $ff
    cpy #64
    bcc -
    rts

display_char_at_xy:
    pha
    lda #0
    sta $fe
    cpy #4 ; spacebar row?
    bne +
    lda #8 ; repeat count for spacebar position
+   sta $fe

    jsr locate_xy

    pla
    cmp #160 ; shift space
    beq +
    cmp #32 ; space
+   bne +
    ldx #1
    stx $c7
    bne ++
+   cmp #13 ; return ^M
    bne +
    ldx #1
    stx $c7
    lda #'M'
    bne ++
+   cmp #141 ; shift+return ^M
    bne +
    ldx #1
    stx $c7
    lda #'m'
    bne ++
+   ldx #1
    stx $d4 ; quote mode just in case for control characters
    stx $d8 ; number of inserts just in case for control characters
++  
-   jsr $ffd2
    dec $fe
    bpl - ; repeat for spacebar
    rts

locate_xy:
    tya
    clc
    adc row_y
    cmp #0
    bne +
    lda #19 ; home    
    bne ++
+   sbc #1
    sta $d6 ; physical line
    lda #13
++  jsr $ffd2 ; effect the change
    clc
    txa
    adc col_x
    sta $d3 ; adjust column
    rts

display_xystrs: ; pointer to an xystr, terminated by empty string (0 length)
    stx $fb
    sty $fc
-   ldy #2
    lda ($fb),y
    beq +
    ldx $fb
    ldy $fc
    jsr display_xystr
    jmp -
+   rts

display_xystr: ; string (x/y registers ptr) is prefixed by screen coordinates, terminated by null
    stx $fb
    sty $fc
    ldy #0
    sty col_x
    sty row_y
    lda ($fb),y
    tax
    iny
    lda ($fb),y
    tay
    jsr locate_xy
    clc
    lda $fb
    adc #2
    sta $fb
    bcc +
    inc $fc
+   ldy #0
-   lda ($fb),y
    inc $fb
    bne +
    inc $fc
+   cmp #0
    beq +
    jsr $ffd2
    jmp -
+   rts

compute_scan_xys:
    lda #(5*18-1)
    sta $ff
    ldy #4
    sty $02
--  ldx #17
-   ldy $ff
    lda scan_layout,y
    bmi +
    tay
    txa
    sta scancode_x,y
    lda $02
    sta scancode_y,y
+   dec $ff
    dex
    bpl -
    dec $02
    bpl --
    rts

; this is the hardware scan code physical layout as a 5x18 array
; keys are independent of internationalization, localization
; because these are scancodes - the physical key representations
; independent of the PETSCII codes they map to via KERNAL ROM
; or remapping like we will do
;
; each key 0..63 should be shown exactly once, with 255 for whitespace (not a key)
;
; the purpose of this array is to show where physical keys are
; It does not change.  !!! DO NOT CHANGE !!!
scan_layout: ; 5 rows, 18 columns = 90 bytes
    !byte 57,56,59,8,11,16,19,24,27,32,35,40,43,48,51,0,255,4
    !byte 58,255,62,9,14,17,22,25,30,33,38,41,46,49,54,255,255,5
    !byte 63,255,10,13,18,21,26,29,34,37,42,45,50,53,255,1,255,6
    !byte 61,52,12,23,20,31,28,39,36,47,44,55,255,15,7,2,255,3
    !byte 255,255,255,60,255,255,255,255,255,255,255,255,255,255,255,255,255,255

; coordinates are derived from scan_layout at runtime to avoid redundant maintainance
scancode_x:
    !byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    !byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    
scancode_y:
    !byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    !byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

; with a US ROM, this will display like the following
; _1234567890+-\st E
; d qwertyuiop@*^  F
; c asdfghjkl:;= m G
; bazxcvbnm,./ aq] H

remaps: ; 4 keyboard sets of PETSCII characters indexed by scancode
    !byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    !byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

    !byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    !byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

    !byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    !byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

    !byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    !byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

char_to_scan: ; 4 sets of scancodes indexed by PETSCII characters
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255

    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255

    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255

    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
    !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255

rom_maps: ; addresses of maps in ROM
    !word 0 ; unshifted
    !word 0 ; shifted
    !word 0 ; commodore
    !word 0 ; control

mult_x18:
    !byte 0, 18, 36, 54, 72, 90

row_y: !byte 0
col_x: !byte 0

xystrings:
    ; !text 21,1,18,"SCANCODE",146,"   $",0
    ; !text 22,2,18,"PETSCII",146,"    $",0
    ; !text 26,4,"UNSHIFTED",0
    ; !text 21,5,"UPPERCASE/GRAPHICS",0
    ; !text 26,6,18,"C64.KEY",0
    ; !text 26,11,"[FIND] F1/F2",0
    ; !text 26,12,"[FG+-]",0
    ; !text 26,13,"[BG+-]",0
    ; !text 26,14,"[BORD]",0
    ; !text 26,15,"[TEST]",0
    ; !text 26,16,"[LOAD]",0
    ; !text 26,17,"[SAVE]",0
    ; !text 26,18,"[EXIT]",0
    ; !text 23,22,18,"KEYMAP EDITOR",0
    !text 24,22,18,"C64 KEYMAPS",0
    !text 22,23,"(C)2025 DAVERVW",0
    !text 21,24,"GITHUB.COM/DAVERVW",0
    !text 0,0,0
