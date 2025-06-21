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

chrout = $ffd2
getkey = $ffe4

jiffyclock = $a2
textptr = $d1 ;/d2 - pointer to current logical screen line, leftmost column
colorptr = $f3 ;/f4 - matching pointer to color memory
physline = $d6
logcol = $d3
color = 646
screenpage = 648
remaps_dest = $08fc

* = $c000

start:
    jmp init
    jmp reserved

init:
    jsr copy_map_addrs
    jsr copy_maps
    jsr compute_scan_xys

    jsr redraw_screen

    ldy #0
    sty last_physline
    sty last_logcol
    sty physline
    lda #13
    jsr chrout
    iny
    sty logcol

    lda color    
    and #15
    sta fg_color
    tax
    lda inverse_colors, x
    sta inv_color
    jsr color_the_codes
    jmp main_loop

redraw_screen:
    lda #0
    sta $d4
    sta $d8

    lda #147
    jsr chrout
    
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

    lda #$ff
    sta last_map
    rts

main_loop:
--  jsr check_cursor_moved
    jsr blinkon
-   jsr chkblink
    jsr getkey
    beq -
    jsr blinkoff
    cmp #$11
    bne +
    jsr cursor_down
    jmp --
+   cmp #$91
    bne +
    jsr cursor_up
    jmp --
+   cmp #$1d
    bne +
    jsr cursor_right
    jmp --
+   cmp #$9d
    bne +
    jsr cursor_left
    jmp --
+   cmp #9 ; ^I
    bne +
    jsr cursor_tab
    jmp --
+   cmp #19 ; home
    bne +
    jsr cursor_tab
    jmp --
+   cmp #133 ; F1
    bne +
    jsr bg_color_inc
    jmp --
+   cmp #137 ; F2
    bne +
    jsr bg_color_dec
    jmp --
+   cmp #134 ; F3
    bne +
    inc $d020 ; border
    jmp --
+   cmp #138 ; F4
    bne +
    dec $d020 ; border
    jmp --
+   cmp #136 ; F7
    bne +
    jmp save_map
+   cmp #3 ; STOP
    bne +
--- lda 197
    cmp #64
    bne --- ; wait until key released
    lda #147
    jmp chrout ; and !!!EXIT!!!
+   cmp #13
    bne +
    jsr pick_from_chart
    jmp --
+   cmp #18 ; reverse on
    bne +
    ldx $d021
    lda fg_color
    sta $d021
    txa
    and #$F
    sta color
    jmp start
+   cmp #146 ; reverse off
    bne +
    ldx inv_color
    lda fg_color
    sta inv_color
    txa
    and #$F
    sta color
    jmp start
+   jsr check_color
    jsr edit_key
    jmp --

reserved:
    brk

save_map:
    ; copy driver
    ldy #0
    ldx #driver_length
-   lda driver, y
    sta $800, y
    iny
    dex
    bne -

    ; pad first page with zeros
    txa
-   sta $800, y
    iny
    bne -

    ; copy 65*4 = 260 bytes   
    lda #<remaps_dest
    sta $fb
    lda #>remaps_dest
    sta $fc
-   lda remaps, y
    sta ($fb),y
    iny
    bne -
    inc $fc
    ldx #4
-   lda remaps+256, y
    sta ($fb),y
    iny
    dex
    bne -

    ; pad the last page with zeros
    tya
    clc
    adc $fb
    beq ++ ; nothing to pad
    tay
    lda #0
    sta $fb
    bcc +
    inc $fc
+
-   sta ($fb),y
    iny
    bne -
    
++  ldy #0
-   lda reset_basic, y
    beq +
    jsr chrout
    iny
    bne -
+
    lda #0
    sta 198
    ldy #0
-   lda save_strokes, y
    beq +
    sta 631,y
    iny
    inc 198
    bne -

+   rts ; !!!EXIT!!!

edit_key:
    sta $02
    ldx logcol
    ldy physline
    jsr get_scancode_index
    lda scan_layout, y
    cmp #$ff
    bne +
    inc logcol
    bne ++
+   tay
    lda scancode_x, y
    sta $03
    lda scancode_y, y
    sta $04
    lda $02
    sta ($fb),y
    ldx #1
    stx col_x
    ldy $ff
    lda mult_x6,y
    tay
    iny
    sty row_y
    lda $02
    ldx $03
    ldy $04
    jsr display_char_at_xy ; assumes drawing keyboard with origin set, that's why we moved the origin and x/y
++  lda logcol
    cmp #19
    bcc +
    lda #1
    sta logcol
+   rts

pick_from_chart:
    ldx logcol
    ldy physline
    stx $a3
    sty $a4
    jsr display_chr_chart
    php
    pha
    jsr redraw_screen
    lda #0
    sta col_x
    sta row_y
    ldx $a3
    ldy $a4
    jsr locate_xy
    pla
    plp
    bcc +
    jsr display_codes
    jmp ++
+   jsr edit_key
++  lda #0
    sta col_x
    sta row_y
    rts

display_chr_chart:
    ; clear screen, fill with invisible (for now) reverse spaces
    lda $d021
    and #$F
    ldx #0
-   sta $d800,x
    sta $d900,x
    sta $da00,x
    sta $db00,x
    inx
    bne -
    lda screenpage
    sta $fc
    lda #$a0
    ldx #4
    ldy #0
    sty $fb
-   sta ($fb),y
    iny
    bne -
    inc $fc
    dex
    bne -

    ldx #<xyfind
    ldy #>xyfind
    jsr display_xystr
    ldx #<xyfind_done
    ldy #>xyfind_done
    jsr display_xystr
    ldx #<xystop
    ldy #>xystop
    jsr display_xystr

    lda #0
    sta $ff
    sta $fb
    sta $fc
    lda #12
    sta col_x
    lda #4
    sta row_y

    lda inv_color
    sta color
    ldx #0
    ldy #0
    jsr locate_xy
    lda #'0'
-   jsr chrout
    clc
    adc #1
    cmp #'G'
    beq +
    cmp #0x3A
    bne -
    lda #'A'
    bne -
+   
    dec col_x
    lda #'0'
    sta $fd
-   inc row_y
    ldx #0
    ldy #0
    jsr display_char_at_xy
    clc
    adc #1
    cmp #'G'
    beq +
    cmp #0x3A
    bne -
    lda #'A'
    bne -
+   inc col_x
    lda #5
    sta row_y
    lda fg_color
    sta color

-   lda $ff
    cmp #$20
    beq ++
    cmp #$a0
    bne +
++  jsr chrout
    jmp ++
+   ldx $fb
    ldy $fc
    jsr display_char_at_xy
++  inc $ff
    beq +
    inc $fb
    lda $fb
    cmp #$10
    bne -
    lda #0
    sta $fb
    inc $fc
    bne -

+   ldx #0
    ldy #0
    jsr locate_xy
--  jsr draw_target_on
    jsr blinkon
-   jsr chkblink
    jsr getkey
    beq -
    jsr blinkoff
    sta $ff
    jsr draw_target_off
    lda $ff
    cmp #$11 ; cursor down
    bne +
    sec
    lda physline
    sbc row_y
    cmp #$F
    bcs --
    lda #$11
    jsr chrout
    jmp --
+   cmp #$91 ; cursor up
    bne +
    sec
    lda physline
    sbc row_y
    cmp #1
    bcc --
    lda #$91
    jsr chrout
    jmp --
+   cmp #$1d
    bne +
    sec
    lda logcol
    sbc col_x
    cmp #15
    bcs --
    lda #$1d
    jsr chrout
    jmp --
+   cmp #$9d
    bne +
    sec
    lda logcol
    sbc col_x
    cmp #1
    bcc --
    lda #$9d
    jsr chrout
    jmp --
+   cmp #134 ; F3 - find
    bne +
    ldx col_x
    ldy row_y
    stx $fd
    sty $fe
    ldx #<xyfind
    ldy #>xyfind
    jsr display_xystr
    jsr blinkon
-   jsr chkblink
    jsr getkey
    beq -
    sta $ff
    jsr blinkoff
    ldx #<xyfind_done
    ldy #>xyfind_done
    jsr display_xystr
    ldx $fd
    ldy $fe
    stx col_x
    sty row_y
    lda $ff
--- lsr
    lsr
    lsr
    lsr
    tay
    lda $ff
    and #$F
    tax
    jsr locate_xy
    jmp --
+   cmp #3 ; STOP
    bne +
    lda #$ff
    sec ; not okay
    rts
+   cmp #13
    beq +
    sta $ff
    jmp ---
+   sec
    lda physline
    sbc row_y
    asl
    asl
    asl
    asl
    sta $ff
    sec
    lda logcol
    sbc col_x
    ora $ff
    clc ; OK
    rts

draw_target_on
    lda inv_color
    sta $02
    jmp draw_target

draw_target_off
    lda $d021
    sta $02
    jmp draw_target

draw_target:
    ldy #0
    sty $fb
    lda #$d8
    sta $fc
    ldx physline
-   jsr target_plus_40
    dex
    bne -
    ldy col_x
    dey
    dey
    lda $02
-   sta ($fb),y
    dey
    bpl -
    clc
    lda col_x
    adc #16
    tay
    lda $02
-   sta ($fb),y
    iny
    cpy #40
    bcc -

    ldy #0
    sty $fb
    lda #$d8
    sta $fc
    ldx row_y
    dex
    ldy logcol
-   lda $02
    sta ($fb),y
    jsr target_plus_40
    dex
    bne -
    ldx #17
-   jsr target_plus_40
    dex
    bne -
    sec
    lda #25
    sbc row_y
    sbc #16
    tax
-   lda $02
    sta ($fb),y
    jsr target_plus_40
    dex
    bne -

    rts

target_plus_40:
    clc
    lda $fb
    adc #40
    sta $fb
    bcc +
    inc $fc
+   rts

cursor_down:
    ldx physline
    cpx #23
    bcc +
    ldy logcol
    ldx #0
    stx physline
    lda #13
    jsr chrout
    sty logcol
    rts
+   jsr chrout
    ldx physline
    cpx #6
    bne +
    jsr chrout
+   cpx #12
    bne +
    jsr chrout
+   cpx #18
    bne +
    jsr chrout
+   rts

cursor_up:
    ldx physline
    cpx #2
    bcs +
    ldx #22
    stx physline
    ldy logcol
    lda #13
    jsr chrout
    sty logcol
    rts
+   jsr chrout
    ldx physline
    cpx #6
    bne +
    jsr chrout
+   cpx #12
    bne +
    jsr chrout
+   cpx #18
    bne +
    jsr chrout
+   rts

cursor_right:
    ldx logcol
    cpx #18
    bcc +
    ldx #1
    stx logcol
    rts
+   jsr chrout
    rts

cursor_left:
    ldx logcol
    cpx #2
    bcs +
    ldx #18
    stx logcol
    rts
+   jsr chrout
    rts

cursor_tab:
    clc
    lda physline
    adc #6
    cmp #24
    bcc +
    sbc #24
+   tay
    ldx logcol
    jmp locate_xy

bg_color_inc:
-   inc $d021
    lda $d021
    and #15
    cmp fg_color
    beq -
    rts

bg_color_dec:
-   dec $d021
    lda $d021
    and #15
    cmp fg_color
    beq -
    rts

check_color:
    ldx #0
-   cmp color_chars, x
    beq +
    inx
    cpx #16
    bne -
    rts
+   stx color
    pla ; pull return address
    pla
    jmp start ; restart program

check_cursor_moved:
    ldx logcol
    ldy physline
    cpy last_physline
    bne +
    cpx last_logcol
    beq ++
+   stx last_logcol
    sty last_physline
    jsr display_codes
++  rts

display_codes:
    jsr get_scancode_index
    jsr check_redraw_frame
    lda #70 ; offset of screen to display code at
    sta $fd
    lda screenpage
    sta $fe
    lda scan_layout,y
    sta $02
    jsr display_hex
    jsr display_decimal
    lda $fd
    clc
    adc #40
    sta $fd
    bcc +
    inc $fe
+   ldy $02
    lda #$ff
    cpy #64
    bcs +
    lda ($fb),y
+   sta $02
    jsr display_hex
    jsr display_decimal
    ldx $ff
    bne +
    ldx #<state_none
    ldy #>state_none
    bne ++
+   dex
    bne +
    ldx #<state_shift
    ldy #>state_shift
    bne ++
+   dex
    bne +
    ldx #<state_commodore
    ldy #>state_commodore
    bne ++
+   dex
    bne +++
    ldx #<state_control
    ldy #>state_control
++  lda inv_color
    sta color
    jsr display_xystr
    lda fg_color
    sta color
    ldx last_logcol
    ldy last_physline
    jsr locate_xy
+++ rts

get_scancode_index: ; output: $ff=map, 
    lda #0
    sta $ff ; map #
    lda #<remaps
    sta $fb
    lda #>remaps
    sta $fc    
-   cpy #6
    bcc +
    inc $ff
    tya
    sbc #6
    tay
    clc
    lda $fb
    adc #65
    sta $fb
    bcc -
    inc $fc
    bne -
+   dex ; change col 1 to 0, etc.
    txa
    dey ; change line 1 to 0, etc.
    cpy #4
    bne +
    cmp #3 ; spacebar starts at col 3
    bcc +
    cmp #12 ; spacebar ends at col 11
    bcs +
    lda #3 ; spacebar is always at 3,4 (0 based)
+   clc
    adc mult_x18,y
    tay
    rts

check_redraw_frame:
    lda $ff
    cmp last_map
    beq ++
    clc
    ror $03 ; high bit clear = erase mode
    ldy last_map
    cpy #4
    bcs + ; branch out of range
    jsr draw_frame
+   sec
    ror $03 ; high bit set = draw mode
    lda inv_color
    sta color
    ldy $ff
    sty last_map
    jsr draw_frame
    ldx last_logcol
    ldy last_physline
    jsr locate_xy
    lda fg_color
    sta color
++  rts

draw_frame:
    lda mult_x6,y
    tay
    jsr draw_frame_line
    iny
    lda #5
    sta $02
-   jsr draw_frame_sides
    iny
    dec $02
    bne -
    jsr draw_frame_line
    rts

draw_frame_line:
    ldx #0
    jsr locate_xy
    bit $03
    bpl +
    lda #18 ; reverse
    jsr chrout
+   ldx #20
    lda #32
-   jsr chrout
    dex
    bne -
    rts

draw_frame_sides:
    ldx #0
    jsr locate_xy
    bit $03
    bpl +
    lda #18 ; reverse
    jsr chrout
+   lda #32
    jsr chrout
    ldx #19
    jsr locate_xy
    bit $03
    bpl +
    lda #18 ; reverse
    jsr chrout
+   lda #32
    jsr chrout
    rts

display_hex: ; .A=value, $fd/fe screen dest
    tay
    and #$f
    tax
    lda hexcodes, x
    tax
    tya
    lsr
    lsr
    lsr
    lsr
    tay
    lda hexcodes, y
    ldy #1
    sta ($fd),y
    iny
    txa
    sta ($fd),y
    ldy #0
    lda #'$'
    sta ($fd),y
    rts

display_decimal: ; .A=value (and $02), $fd/fe screen dest (note: display to side of hex)
    ldy #4
    lda #'+'
    sta ($fd),y
    lda $02
    sta $03
    ldx #0
    sec
-   sbc #100
    bcc +
    sta $03
    inx
    bne -
+   lda hexcodes,x
    iny
    sta ($fd),y
    lda $03
    ldx #0
    sec
-   sbc #10
    bcc +
    sta $03
    inx
    bne -
+   lda hexcodes,x
    iny
    sta ($fd),y
    ldx $03
    lda hexcodes,x
    iny
    sta ($fd),y
    rts

chkblink:
    sec
    lda jiffyblink
    cmp jiffyclock
    bne ++
    lda jiffyclock
    adc #20
    sta jiffyblink
    ldx inv_color
    ldy logcol
    lda (colorptr),y
    and #15
    cmp fg_color
    beq +
    ldx fg_color
+   txa
    sta (colorptr),y
+   lda (textptr),y
    eor #$80
    sta (textptr),y
++  rts

blinkoff:
    tax
    ldy logcol
    lda fg_color
    sta (colorptr),y
    lda save_cursor_char
    sta (textptr),y
    txa
    rts

blinkon:
    ldx inv_color ; assume inverse color
    ldy logcol
    lda (textptr),y
    sta save_cursor_char
    ora #$80 ; my cursor starts with reverse character, blinking can toggle
    sta (textptr),y
    bmi + ; yes inverse color
    ldx fg_color ; no regular color
+   txa
    sta (colorptr),y
    clc
    lda jiffyclock
    adc #20
    sta jiffyblink
    rts

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

    ldy #64
-   lda ($fb),y
    sta ($fd),y
    dey
    bpl -

    clc
    lda $fd
    adc #65
    sta $fd
    bcc +
    inc $fe
+
    inx
    inx
    cpx #8
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
    adc #65
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

display_char:
    pha
    sec
    lda physline
    sbc row_y
    tay
    lda logcol
    sbc col_x
    tax
    pla
    ; fall through display_char_at_xy

display_char_at_xy:
    pha
    lda #0
    sta $fe
    cpy #4 ; spacebar row?
    bne +
    cpx #3 ; spacebar col?
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
-   jsr chrout
+   ldx #0
    stx $d4 ; reset quote mode
    stx $d8 ; reset inserts
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
    sta physline
    lda #13
++  jsr chrout ; effect the change
    clc
    txa
    adc col_x
    sta logcol
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
    jsr chrout
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

color_the_codes:
    lda #0
    sta $fb
    lda #$d8
    sta $fc
    lda inv_color
    ldy #61
    ldx #17
-   sta ($fb),y
    iny
    dex
    bne -
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
; It does not change.  !!! DO NOT CHANGE EXCEPT FOR COSMETIC REASONS !!!
scan_layout: ; 5 rows, 18 columns = 90 bytes !!! CODE DEPENDS ON THESE DIMENSIONS !!!
    !byte 57,56,59,8,11,16,19,24,27,32,35,40,43,48,51,0,255,4
    !byte 58,255,62,9,14,17,22,25,30,33,38,41,46,49,54,255,255,5
    !byte 63,255,10,13,18,21,26,29,34,37,42,45,50,53,255,1,255,6
    !byte 61,52,12,23,20,31,28,39,36,47,44,55,255,15,7,2,255,3
    !byte 255,255,255,60,255,255,255,255,255,255,255,255,255,255,255,255,255,255

; with a US ROM, this will display like the following
; _1234567890+-\st E
; d qwertyuiop@*^  F
; c asdfghjkl:;= m G
; bazxcvbnm,./ aq] H

rom_maps: ; addresses of maps in ROM
    !word 0 ; unshifted
    !word 0 ; shifted
    !word 0 ; commodore
    !word 0 ; control

mult_x6:
    !byte 0, 6, 12, 18, 24

mult_x18:
    !byte 0, 18, 36, 54, 72, 90

; origin point for locate_xy
row_y: !byte 0
col_x: !byte 0

last_physline: !byte 0
last_logcol: !byte 0
last_map: !byte 0

jiffyblink: !byte 0
save_cursor_char: !byte 0
fg_color: !byte 14
inv_color: !byte 11

state_none:      !text 25,4,"  NONE   ",0
state_shift:     !text 25,4,"  SHIFT  ",0
state_commodore: !text 25,4,"COMMODORE",0
state_control:   !text 25,4," CONTROL ",0

xystrings:
    !text 21,1,"SCANCODE","          ",0
    !text 22,2,"PETSCII","          ",0
;
    !text 23,7,"NAVIGATION:",0

    !text 23,9,"CURSOR, HOME,",0
    !text 23,10,"COLORS, RVS,",0
    !text 23,11,"RETURN, STOP", 0
;
    !text 23,13,"F1 BACKGROUND+",0
    !text 23,14,"F2 BACKGROUND-",0
    !text 23,15,"F3 BORDER+",0
    !text 23,16,"F4 BORDER-",0
    !text 23,17,"F7 SAVE",0
;
    !text 23,21,18,"KEYMAP EDITOR",0
    !text 22,22,"(C)2025 DAVERVW",0
    !text 24,23,"MIT LICENSE",0
    !text 21,24,"GITHUB.COM/DAVERVW",0
    !text 0,0,0

xyfind:      !text 1,1,"F3   FIND:",0
xyfind_done: !text 10,1,"  ",0
xystop:      !text 1,2,"STOP CANCEL",0

; control characters that change colors, in order colors 0..15
color_chars !byte 144,5,28,159,156,30,31,158,129,149,150,151,152,153,154,155

; complementary colors in relation to colors 0..15
inverse_colors !byte 1,0,5,10,13,2,8,9,6,7,3,14,15,4,11,12

hexcodes !text "0123456789",1,2,3,4,5,6 ; screen codes

reset_basic !text 147,"POKE43,1:POKE44,8:POKE45,0:POKE46,10:CLR:LIST",0
save_strokes !text 19,13,"SAVE",34,0

driver: ; keyboard driver BASIC and assembler code targeting $0801
!byte $00,$20,$08,$0a,$00,$8f,$20,$4b,$45,$59,$42,$4f,$41,$52,$44,$20
!byte $52,$45,$4d,$41,$50,$50,$45,$52,$20,$44,$52,$49,$56,$45,$52,$00
!byte $42,$08,$14,$00,$8f,$20,$32,$30,$32,$35,$20,$42,$59,$20,$44,$41
!byte $56,$49,$44,$20,$52,$2e,$20,$56,$41,$4e,$20,$57,$41,$47,$4e,$45
!byte $52,$00,$56,$08,$1e,$00,$8f,$20,$50,$55,$42,$4c,$49,$43,$20,$44
!byte $4f,$4d,$41,$49,$4e,$00,$63,$08,$28,$00,$9e,$20,$32,$31,$35,$31
!byte $3a,$a2,$00,$00,$00,$00,$00,$a9,$42,$a2,$06,$a0,$08,$20,$92,$08
!byte $a2,$25,$a0,$08,$20,$92,$08,$a9,$0a,$85,$2c,$a9,$00,$8d,$00,$0a
!byte $a2,$47,$a0,$08,$20,$92,$08,$a2,$a7,$a0,$08,$8e,$8f,$02,$8c,$90
!byte $02,$60,$86,$fb,$84,$fc,$a0,$00,$b1,$fb,$f0,$06,$20,$d2,$ff,$c8
!byte $d0,$f6,$a9,$0d,$4c,$d2,$ff,$a2,$00,$ad,$8d,$02,$29,$07,$f0,$04
!byte $e8,$4a,$d0,$fc,$a9,$fc,$a0,$08,$e0,$00,$f0,$09,$18,$69,$41,$90
!byte $01,$c8,$ca,$d0,$f7,$85,$f5,$84,$f6,$4c,$e0,$ea,$00,$00,$00,$00
driver_length = * - driver

remaps = * ; 4 keyboard sets of PETSCII characters indexed by scancode (260 bytes total, 65 bytes each set)

; coordinates are derived from scan_layout at runtime to avoid redundant maintainance
scancode_x = remaps + 260 ; 64 bytes total
scancode_y = scancode_x + 64 ; 64 bytes total

finish = scancode_y + 64 ; end
