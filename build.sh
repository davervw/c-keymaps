#!/bin/sh -x
# dependencies:
# https://sourceforge.net/projects/acme-crossass/
# https://vice-emu.sourceforge.io/
export ACME=${USERPROFILE}/Downloads/acme0.97win/acme
export VICE=${USERPROFILE}/Downloads/GTK3VICE-3.8-win64/bin
export PROG=64keymaps
export D64=keymaps.d64
${ACME}/acme -f cbm -o ${PROG}.prg -l ${PROG}.lbl -r ${PROG}.lst ${PROG}.asm \
&& ${VICE}/c1541 ${D64} -attach ${D64} 8 -delete "${PROG} 49152" -write ${PROG}.prg "${PROG} 49152" \
&& ${VICE}/x64sc -moncommands ${PROG}.lbl -autostart ${D64} >/dev/null 2>&1 &
