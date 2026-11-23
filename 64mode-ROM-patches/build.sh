#!/bin/sh -x
# dependencies:
# https://sourceforge.net/projects/acme-crossass/
# https://vice-emu.sourceforge.io/
export ACME=${USERPROFILE}/Downloads/acme0.97win/acme
export PROG=64moderom
${ACME}/acme -f cbm -o ${PROG}.prg -l ${PROG}.lbl -r ${PROG}.lst ${PROG}.asm \
&& python3 generate_patches.py ${PROG}.prg \
&& cat 64mode-part1.basic.txt 64mode-part2.basic.txt > "64mode patch PRG.txt" \
&& rm ${PROG}.lbl ${PROG}.prg 64mode-part1.basic.txt
