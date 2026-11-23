#!/bin/sh -x
# dependencies:
# https://sourceforge.net/projects/acme-crossass/
# https://vice-emu.sourceforge.io/
export ACME=${USERPROFILE}/Downloads/acme0.97win/acme
export PROG=64moderom
${ACME}/acme -f cbm -o ${PROG}.prg -l ${PROG}.lbl -r ${PROG}.lst ${PROG}.asm \
&& rm ${PROG}.prg ${PROG}.lbl
