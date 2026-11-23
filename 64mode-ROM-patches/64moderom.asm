; 64moderom.asm - updated keyboard driver for 64 mode of 128 to support cursor and keypad keys
; updates are derived from Commodore ROM keyboard driver, enhanced to support up to 87 keys
;
; revisions Copyright (c) 2026 by David R. Van Wagner
; MIT LICENSE
;
; github.com/davervw/c-keymaps
; davevw.com
;
; compiled bytes have been manually encoded into "64mode patch" program which patches a C64 by modifying ROMs into RAM
; alternatively see patches which can be applied to BASIC/KERNAL ROMs with xxd (see README.md)

* = $033C   ; tape buffer, temporary for copying ROMs to RAM
LDX #$20
LDY #$A0
JSR $034B
LDA #$00
LDX #$20
LDY #$E0
STA $FB
STY $FC
TAY
LDA ($FB),Y
STA ($FB),Y
INY
BNE $0350
INC $FC
DEX
BNE $0350
RTS

* = $BF4E   ; to BF70
init_scan:
LDA #$40    ; no key
STA $CB     ; scan code
LDY #$00    ; zero, for shift state, scancode counter, and all standard keyboard rows
STY $028D   ; shift state 3 bits Control(2)=4 CBM(1)=2 Shift(0)=1
LDA #$F8    ; lower 3 bits cleared
LDX #$FF    ; lower 3 bits are extended C128 keyboard row for later
STA $D02F   ; all extended keyboard rows selected
STY $DC00   ; all standard keyboard rows selected
reset_table:
LDA #$81    ; low unshifted table in ROM
STA $F5     ; key table ptr
LDA #$EB    ; high unshifted table in ROM
STA $F6     ; key table ptr + 1
LDA #$FE    ; start with bit 1 clear for later
CPX $DC01   ; compare columns with #$FF - set Z if no keys pressed
RTS
NOP
NOP

* = $E4B7   ; to E4D2
xlat_extended:
!byte  27, 16, 64, 59, 11, 24, 56, 64
!byte  40, 43, 64,  1, 19, 32,  8, 64
!byte  35, 44,135,  7,157, 29, 64, 170
!byte 170,170,170,170

* = $EA87   ; to EADF
JSR init_scan ; some code patched in BASIC ROM
BEQ $EAFB   ; branch if no key press
STX $F5     ; save keyboard row extended 3-bits
--
STX $D02F   ; set extended 3-bits keyboard row
STA $DC00   ; set lower 8-bits keyboard row
PHA         ; save keyboard row lower 8-bits
- 
LDA $DC01   ; load columns
CMP $DC01   ; stable?
BNE -       ; repeat if key bounce
LDX #$08    ; number of columns to read
-
LSR         ; shift low bit into C
BCS +++     ; branch if not this key 
PHA         ; save keyboard columns read (shifted)
LDA $EB81,Y ; get unshifted key mapping
CMP #$05    ; not shift code?
BCS +       ; branch if not shift code
CMP #$03    ; STOP key?
BEQ +       ; branch if STOP (not shift code)
ORA $028D   ; combine with shift code
STA $028D   ; store shift code
BPL ++      ; unconditional branch, don't store scancode
+
STY $CB     ; found keypress that wasn't shift key, store it
++
PLA         ; restore keyboard columns read
+++
INY         ; increment working scancode count
DEX         ; finished one column
BNE -       ; loop until read all columns
PLA         ; restore keyboard row
SEC         ; shifted in bit needs to be set
ROL         ; next row, shift bits left
ROL $F5     ; shift extended bits left
LDX $F5     ; read result
CPX #$F7    ; check if out of range of 11-bits
BNE --      ; branch if limit not reached - scan more keyboard rows
LDY $CB     ; retrieve any scancode
CPY #$41
BCC ++      ; branch if less than 65
LDA xlat_extended-$41, Y ; translate extended keys (and no key, note HELP not mapped with this implementation)
BPL +
INC $028D   ; assume it was zero
AND #$3F
+
STA $CB     ; store translated scancode
++
JSR reset_table
JMP ($028F) ; key is pressed, process it including getting proper shift table pointer
; * = $EAE0

; EAFB no key press
