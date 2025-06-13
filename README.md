# Commodore Keyboard Mappings - Animated Display

The keyboard maps for unshifted, SHIFT, Commodore, and Control are animated on screen drawing the PETSCII character in scan code order.  Commodore 128 adds Alt and Caps Lock maps, and different results will occur if DIN is pressed on international models.

Note the implementation approach was to provide the PETSCII original keyboard layout and use the ROMs to match to scan codes.  This allowed the implementation to not have a pre-determined knowledge of scancodes, and thus portability with Vic-20 which has different scan codes.  The downside is that an international keyboard may have a different unshifted layout than encoded in the DATA statements and would be up to the user to correct that.  Alternative implementation would be to encode the scancode layout instead of PETSCII.

## Commodore 64 (US)

![64keymaps.png](media/64keymaps.png)

## Commodore Vic-20 (US)

![20keymaps.png](media/20keymaps.png)

## Commodore 128 (US)

![128keymaps.png](media/128keymaps.png)
