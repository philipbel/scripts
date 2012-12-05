apple-kbd-dat-icon-extract.py
=============================

After creating a custom [1] keyboard layout with
[Ukelele](http://scripts.sil.org/cms/scripts/page.php?site_id=nrsi&id=ukelele),
I wanted it to match the original layout's icon.  It turns out that OS X stores
the country flags in
`/System/Library/Keyboard Layouts/AppleKeyboardLayouts.bundle/Contents/Resources/AppleKeyboardLayouts-L.dat`.

I don't know the exact structure of that file, but the icons are simply
there (look for icns in hex, i.e. 0x69636e73.

`apple-kbd-dat-icon-extract.py` is a quick and dirty script the exracts the
icons (*icns* files) from the above file and writes them to the specified
output directory.


[1] Not really custom.  OS X doesn't support the [БДС
5237-2005](http://www.metodii.com/bds52372005.pdf) Bulgarian phonetic layout
(GNU/Linux does).


Sample usage
------------

 % mkdir /tmp/icons
 % ./apple-kbd-dat-icon-extract.py -o /tmp/icons
 ./apple-kbd-dat-icon-extract.py: Reading /System/Library/Keyboard Layouts/AppleKeyboardLayouts.bundle/Contents/Resources/AppleKeyboardLayouts-L.dat
 ./apple-kbd-dat-icon-extract.py: Writing icon file /tmp/icons/icon1.icns
 ./apple-kbd-dat-icon-extract.py: Writing icon file /tmp/icons/icon2.icns
 ./apple-kbd-dat-icon-extract.py: Writing icon file /tmp/icons/icon3.icns
 ...
 ./apple-kbd-dat-icon-extract.py: Writing icon file /tmp/icons/icon132.icns
 %
