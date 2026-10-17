# oma.kvitto

Utskrift till Epson TM-T88V från Omarchy.

## Krav

- Omarchy med `omarchy-shell`
- Skrivare på `/dev/usb/lp0` (eller CUPS-kö)
- Användaren i gruppen `lp`
- ImageMagick (`magick`) för de lodräta strecken (finns normalt i Omarchy, annars `sudo pacman -S imagemagick`)

```bash
sudo usermod -aG lp "$USER"
```

Logga ut ur sessionen och in igen.

## Installera

```bash
omarchy plugin add https://github.com/nmlit/oma.kvitto.git --enable
omarchy bar plugin add oma.kvitto --section right
omarchy-restart-shell
```

## Använda

Klicka på **Kvitto** i baren, eller:

```bash
omarchy-shell shell toggle oma.kvitto '{}'
```

## Lodräta streck

Kvittot skrivs ut som en bild med ett svart lodrätt streck (5 cm högt, ca 2,8 mm brett) längs vänster och höger kant, med start överst på kvittot. Strecken är alltid 5 cm även om texten är kortare. Texten skrivs i ett monospace-typsnitt, upp till cirka 38 tecken per rad, och å, ä, ö och € fungerar.

Saknas ImageMagick, eller om bildrenderingen misslyckas, skrivs kvittot ut som ren text utan streck, precis som tidigare.

```bash
# Stäng av strecken (ren text, 42 tecken per rad)
echo 'export OMA_KVITTO_STRECK=0' > ~/.config/uwsm/env.d/kvitto-streck

# Valfritt: annat typsnitt (standard är systemets monospace)
echo 'export OMA_KVITTO_FONT=/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf' > ~/.config/uwsm/env.d/kvitto-font
```

Ny session efteråt. Vill du testa utan att skriva ut sparar `OMA_KVITTO_OUT=/tmp/kvitto.bin ./print.sh "test"` ESC/POS-datan till en fil.

## CUPS

```bash
lpstat -p -d
echo 'export OMA_KVITTO_CUPS=KONAMN' > ~/.config/uwsm/env.d/kvitto
```

Ny session efteråt.

## Ta bort

```bash
omarchy plugin remove oma.kvitto
```
