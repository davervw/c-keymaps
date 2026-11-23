These files are the assembly and patches for enabling 128 cursor keys and keypad in 64 mode.  Also see ../files/64mode patch for a CBM program real-time applying these ROM patches and running from RAM.

Run `./build.sh` to assemble the PRG and regenerate
`64mode-BASIC-ROM-patch.txt`, `64mode-KERNAL-ROM-patch.txt`, and
`64mode-part1.basic.txt`.  The Python generator can also be run directly:

    python3 generate_patches.py 64moderom.prg

`64mode-BASIC-ROM-patch.txt` and `64mode-KERNAL-ROM-patch.txt` contain ROM
offsets and hexadecimal bytes in `xxd -r` format.  For example:

    xxd -r 64mode-BASIC-ROM-patch.txt basic.rom
    xxd -r 64mode-KERNAL-ROM-patch.txt kernal.rom

`64mode-part1.basic.txt` contains generated BASIC DATA statements with
full 64-mode memory addresses.  It is prepended to
`64mode-part2.basic.txt` as `64mode patch PRG.txt` during the build,
then deleted.  `64mode-part2.basic.txt` contains the BASIC loader code.

64mode patch PRG.txt should be manually pasted into a running VICE C128 64 mode session to save as the program ../files/64mode patch
