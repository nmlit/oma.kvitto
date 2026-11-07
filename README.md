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

## Lokalt bildexperiment (2026-11-07)

Ctrl+V eller Shift+Insert i textrutan klistrar in en clipboard-bild (PNG, JPEG, WebP, BMP eller TIFF). Text klistras annars in med Qt:s vanliga textfunktion. En ny bild ersätter föregående bild. Förhandsvisningen visar svartvit Floyd–Steinberg-dithering, 512 px bredd, bibehållna proportioner och vit bakgrund vid transparens. Bilden skrivs efter texten; även enbart bild går bra. **Ta bort bild** tar bort endast bilden; **Rensa** tar bort text och bild. Ctrl+P skriver fortfarande direkt.

Bildutskrift behåller minst 80 mm och sista 10 mm tomma samt befintlig knivmatning. Fel vid bildrendering stoppar utskriften i stället för att tyst utelämna bilden. Bildfiler ligger privat under `$XDG_RUNTIME_DIR/oma.kvitto/images` (reserv: `~/.cache/oma.kvitto/images`), aldrig i pluginmappen. En kvarvarande bildfil efter skalomstart städas av runtime-katalogens livscykel; ingen bild återläses automatiskt. Max 32 MiB clipboard-data och 16384 px höjd efter skalning.

Detta är endast ett lokalt experiment; inget publicerat eller pushat.

## Paketerad Atkinson Hyperlegible (1.3.0)

Originalfamiljen Atkinson Hyperlegible 1.006 ingår som fyra oförändrade TTF-filer
(Regular, Bold, Italic, BoldItalic). Detta motsvarar familjen i Arch-paketet
`ttf-atkinson-hyperlegible`, inte Next/Mono. ÅäöÅÄÖ finns i samtliga fyra filer.
Fontfilerna omfattas av **SIL Open Font License 1.1**, inte pluginets MIT-licens.
Copyright, fullständig licens, pinnad upstream och SHA-256 finns i
`fonts/atkinson-hyperlegible/OFL.txt` respektive `SOURCE.md`.

Ingen `sudo pacman`, fontinstallation eller font-cache krävs för denna font.
`omarchy plugin add` klonar hela repot och behåller fontkatalogen. QML laddar
TTF-filerna direkt med Qt Quick FontLoader, och utskriftsrenderern använder
Regular-filens absoluta sökväg i pluginmappen utan fontconfig-uppslagning.
Andra installerade typsnitt går fortfarande att välja. Editorn och fontvalets
text visar den valda fonten; utskriftens valda storlek fungerar som tidigare.

Vid nyinstallation utan sparat fontval är Atkinson Hyperlegible standard.
Ett befintligt explicit fontval och en sparad storlek läses som tidigare och
skrivs **inte** över vid start eller uppdatering. Inställningar förblir i
`~/.local/state/oma.kvitto/settings.conf`, utanför pluginmappen. Fontval/storlek
sparas endast när användaren ändrar dem i gränssnittet.

Aktuellt installationssätt (äldre exempel ovan med `bar plugin add` är föråldrat):

```bash
omarchy plugin add https://github.com/nmlit/oma.kvitto.git --enable
```

Uppdatering efter att ändringen finns på standardgrenen:

```bash
omarchy plugin update oma.kvitto --yes
omarchy-restart-shell
```

Font- och bildändringarna kan provas med `OMA_KVITTO_OUT=/tmp/kvitto.bin`
för att skriva ESC/POS till fil i stället för att öppna skrivaren.

### Reproducerbara torrtester

```bash
python3 tests/test-renderer.py
```

Tester använder endast syntetiska data och `OMA_KVITTO_OUT`, aldrig skrivaren
eller verklig clipboard. De provar även tom fontconfig (inga systemfonter),
alla fyra lokala QML FontLoader-filer och bevarat explicit fontval/storlek.
Headless QML-delen kräver Quickshell; övriga tester kräver pluginets befintliga
verktyg Python 3, ImageMagick och fontconfig. Fontbunten lägger inte till något
nytt systempaketkrav.

Bildexperimentavsnittets status ovan beskriver det tidigare lokala testskedet.
Det användarverifierade bildstödet ingår i 1.3.0 tillsammans med fontbunten.
