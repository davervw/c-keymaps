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

chrout = $ffd2
getkey = $ffe4

jiffyclock = $a2
textptr = $d1 ;/d2 - pointer to current logical screen line, leftmost column
colorptr = $f3 ;/f4 - matching pointer to color memory
physline = $d6
logcol = $d3
color = 646
screenpage = 648

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

; main loop
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
+   cmp #19
    bne +
    jsr cursor_home
    jmp --
+   cmp #133 ; F1
    bne +
    jsr bg_color_inc
    jmp --
+   cmp #137 ; F2
    bne +
    jsr bg_color_dec
    jmp --
+   cmp #138 ; F4
    bne +
    jsr border_color_inc
    jmp --
+   cmp #140 ; F8
    bne +
-   lda #147
    jmp chrout ; and !!!EXIT!!!
+   cmp #3 ; STOP
    bne +
--- lda 197
    cmp #64
    bne --- ; wait until key released
    beq -
+   jsr check_color
    jmp --

reserved:
    brk

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

cursor_home:
    lda #0
    sta physline
    lda #13
    jsr chrout
    lda #1
    sta logcol
    rts

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

border_color_inc:
    inc $d020
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
++  jsr display_xystr
    ldx last_logcol
    ldy last_physline
    jsr locate_xy
+++ rts

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

index_chars:
    ldx #0
    lda #$ff
-   sta char_to_scan,x
    sta char_to_scan+$100,x
    sta char_to_scan+$200,x
    sta char_to_scan+$300,x
    inx
    bne -
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
    adc #65 ; advance source 65 scancodes
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
-   jsr chrout
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

mult_x18:
    !byte 0, 18, 36, 54, 72, 90

; origin point for locate_xy
row_y: !byte 0
col_x: !byte 0

last_physline: !byte 0
last_logcol: !byte 0

jiffyblink: !byte 0
save_cursor_char: !byte 0
fg_color: !byte 14
inv_color: !byte 11

state_none:      !text 25,4,"  NONE   ",0
state_shift:     !text 25,4,"  SHIFT  ",0
state_commodore: !text 25,4,"COMMODORE",0
state_control:   !text 25,4," CONTROL ",0

xystrings:
    !text 21,1,18,"SCANCODE",146,"          ",0
    !text 22,2,18,"PETSCII",146,"          ",0
;    !text 21,5,"UPPERCASE/GRAPHICS",0
;    !text 26,6,18,"C64.KEY",0
    !text 26,11,"[BG+ ] F1",0
    !text 26,12,"[BG- ] F2",0
;    !text 26,13,"[FIND] F3",0
    !text 26,14,"[BRD+] F4",0
;    !text 26,15,"[SAVE] F5",0
;    !text 26,16,"[LOAD] F6",0
;    !text 26,17,"[TEST] F7",0
    !text 26,18,"[EXIT] F8",0
    ;!text 23,22,18,"KEYMAP EDITOR",0
    !text 23,22,18,"C64 KEYMAPS",0
    !text 22,23,"(C)2025 DAVERVW",0
    !text 21,24,"GITHUB.COM/DAVERVW",0
    !text 0,0,0

; control characters that change colors, in order colors 0..15
color_chars !byte 144,5,28,159,156,30,31,158,129,149,150,151,152,153,154,155

; complementary colors in relation to colors 0..15
inverse_colors !byte 1,0,5,10,13,2,8,9,6,7,3,14,15,4,11,12

hexcodes !text "0123456789",1,2,3,4,5,6 ; screen codes

remaps = * ; 4 keyboard sets of PETSCII characters indexed by scancode (260 bytes total, 65 bytes each set)

; coordinates are derived from scan_layout at runtime to avoid redundant maintainance
scancode_x = remaps + 260 ; 64 bytes total
scancode_y = scancode_x + 64 ; 64 bytes total

char_to_scan = scancode_y + 64 ; 4 sets of scancodes indexed by PETSCII characters (1024 bytes total)

finish = char_to_scan + 1024 ; end
