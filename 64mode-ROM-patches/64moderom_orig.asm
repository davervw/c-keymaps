; ROM listing from Commodore 64 ROM
; comments 2026 by David R. Van Wagner davevw.com github.com/davervw

* = $EA87
LDA #$00    ; zero
STA $028D   ; shift state 3 bits Control(2)=4 CBM(1)=2 Shift(0)=1
LDY #$40    ; no key
STY $CB     ; scan code
STA $DC00   ; all keyboard rows
LDX $DC01   ; load columns
CPX #$FF    ; no key press?
BEQ $EAFB   ; branch if no key press
TAY         ; Y=0
LDA #$81    ; low unshifted table in ROM
STA $F5     ; key table ptr
LDA #$EB    ; high unshifted table in ROM
STA $F6     ; key table ptr + 1
LDA #$FE    ; start with bit 1 clear
STA $DC00   ; set keyboard row
--
LDX #$08    ; count of columns
PHA         ; save keyboard row
- 
LDA $DC01   ; load columns
CMP $DC01   ; stable?
BNE -       ; repeat if key bounce
-
LSR         ; shift low bit into C
BCS +++     ; branch if not this key 
PHA         ; save keyboard columns read (shifted)
LDA ($F5),Y ; get unshifted key mapping
CMP #$05    ; not shift code?
BCS +       ; branch if not shift code
CMP #$03    ; STOP key?
BEQ +       ; branch if STOP (not shift code)
ORA $028D   ; combine with shift code
STA $028D   ; store shift code
BPL ++      ; unconditional branch, don't store scancode
+
STY $CB     ; found keypress that wasn't scancode, store it
++
PLA         ; restore keyboard columns read
+++
INY         ; increment working scancode count
CPY #$41    ; out of range?
BCS +       ; branch if out of range
DEX         ; one less column
BNE -       ; loop until read all columns
SEC
PLA         ; restore keyboard row
ROL         ; next row, shift bits left
STA $DC00   ; set keyboard row to read
BNE --
+ 
PLA         ; throw away saved keyboard row
JMP ($028F) ; key is pressed, process it starting with getting proper shift table pointer
; * = $EAE0

; EAFB no key press