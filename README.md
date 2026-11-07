# oma.kvitto

Skriv ut text och en inklistrad bild på Epson TM-T88V från Omarchy.
Den här dokumentationen beskriver version **1.3.0**.

## Krav

- Omarchy med `omarchy-shell`/Quickshell och stöd för plugins.
- Bash, Python 3 och vanliga Unixverktyg för filer och text, bland annat
  `mktemp`, `cp`, `rm`, `cat`, `cut`, `sort` och `grep`.
- **ImageMagick** med kommandot `magick` för normal text- och bildrendering.
- **wl-clipboard** med `wl-paste` för inklistringens MIME-kontroll och bildhämtning
  i Wayland-sessionen.
- **fontconfig** med `fc-list` för listan över installerade fonter och `fc-match`
  för att hitta andra valda systemfonter.
- En ansluten skrivare med skrivbar enhetsfil, normalt `/dev/usb/lp0`, eller en
  konfigurerad CUPS-kö som tar emot rå ESC/POS-data. CUPS-alternativet kräver `lp`.

Atkinson Hyperlegible följer med pluginet: ingen separat installation av
`ttf-atkinson-hyperlegible`, inget `sudo pacman` och ingen font-cache behövs för
just den fonten. Git-installationen hämtar hela pluginet inklusive fontfilerna;
den installerar inte systemverktygen ovan.

### Rättigheter till USB-skrivaren

Vid direkt USB-utskrift måste användaren som kör skalet kunna skriva till den
valda enheten. Kontrollera enhetens ägare/grupp och dina grupper:

```bash
ls -l /dev/usb/lp0
id
```

Om enheten tillhör gruppen `lp` och gruppen har skrivrättighet kan medlemskap i
`lp` ge åtkomst:

```bash
sudo usermod -aG lp "$USER"
```

Logga därefter ut och in igen. Gruppmedlemskap är inte ett universellt krav:
det är faktisk skrivåtkomst till enheten som behövs. Vid CUPS-utskrift används
i stället köns åtkomstregler; pluginet öppnar då inte USB-enheten direkt.

## Installera och uppdatera

Installera och aktivera widgeten:

```bash
omarchy plugin add https://github.com/nmlit/oma.kvitto.git --enable
omarchy-restart-shell
```

Uppdatera en befintlig installation:

```bash
omarchy plugin update oma.kvitto --yes
omarchy-restart-shell
```

## Användning

Klicka på **Kvitto** i baren, eller öppna/stäng fönstret med:

```bash
omarchy-shell shell toggle oma.kvitto '{}'
```

1. Skriv eller klistra in vanlig text i textrutan.
2. Välj utskriftsfont och storlek **6–80**.
3. Klistra vid behov in en bild med **Ctrl+V** eller **Shift+Insert** när
   textrutan har fokus.
4. Klicka **Skriv ut**, eller tryck **Ctrl+P** i textrutan för direktutskrift
   utan ytterligare bekräftelseruta.

**Ta bort bild** tar bort bara bilden. **Rensa** tömmer både text och bild.
**Stäng** eller **Esc** stänger fönstret utan att rensa utkastet; utkastet är
inte permanent sparat och återställs inte efter skalomstart.

### Bilder

- Högst **en bild** åt gången; en ny inklistrad bild ersätter den föregående.
- Bilden skrivs **efter texten**. Det går även att skriva ut enbart bilden.
- Förhandsvisningen visar den bearbetade svartvita bilden, anpassad till
  förhandsvisningsrutan utan att ändra proportionerna.
- Bilden skalas till **512 px bredd**, med bibehållna proportioner. Transparens
  läggs på vit bakgrund och gråtoner omvandlas med **Floyd–Steinberg-dithering**.
- Clipboard-formaten PNG, JPEG, WebP, BMP och TIFF stöds. För flerbildsformat
  används första bilden. Utan ett sådant bildformat används Qt:s vanliga
  textinklistrning.
- Högst **32 MiB** hämtad bilddata och **16384 px höjd** efter skalning tillåts.
  Bildhämtning och konvertering har även tids- och resursgränser.
- Vid inklistringsfel visas ett fel och ingen ny bild läggs till. Om en vald
  bild inte kan renderas vid utskrift stoppas utskriften; bilden utelämnas inte
  tyst till förmån för enbart text.

## Utskriftsformat

Normalutskriften renderar text och eventuell bild till ett svartvitt ESC/POS-
raster, anpassat till TM-T88V med 80 mm papper. Rasterbredden är **512 punkter**;
koden räknar med **180 dpi**. Texten har en liten sidomarginal och radbryts efter
fontens uppmätta teckenbredd, inte ett fast antal tecken per rad.

Den renderade rasterytan är **minst 80 mm** lång. De sista **minst 10 mm** är
vita efter allt innehåll, även efter en bild. Därefter skickas kommandot
`GS V B 0`, som matar fram till knivpositionen och gör en partiell skärning.
Knivmatningen tillkommer utöver rasterytan; måttet är inte ett löfte om exakt
fysisk längd på den avskurna pappersbiten.

Inga dekorativa sidostreck eller extra dekorationspunkter genereras.

### Reservläge för enbart text

Om ImageMagick saknas eller normal textrendering misslyckas kan en utskrift
**utan bild** falla tillbaka till skrivarens inbyggda textläge: radbrytning vid
42 tecken, Windows-1252-kodning och cirka 10 mm avslutande matning före
knivkommandot. Tecken som inte kan kodas ersätts. I detta läge används inte den
valda TTF-fonten/storleken och **80 mm minimilängd garanteras inte**.

Miljövariabeln `OMA_KVITTO_STRECK=0` är ett äldre namn som fortfarande väljer
detta textläge för utskrifter utan bild. Den styr inte några sidostreck.
En vald bild kräver alltid ImageMagick och använder rasterläget.

## Typsnitt och sparade inställningar

Vid nyinstallation utan sparade val är standarden **Atkinson Hyperlegible**
och utskriftsstorlek **20**. Storleken kan väljas mellan 6 och 80; renderern
begränsar också värdet till det intervallet. Textfältet visar vald font med
fast visningsstorlek 14 px och är inte en skalenlig förhandsvisning av textens
utskriftsstorlek.

Originalfamiljen Atkinson Hyperlegible **1.006** ingår som fyra oförändrade TTF-
filer: Regular, Bold, Italic och BoldItalic. Detta är familjen i Arch-paketet
`ttf-atkinson-hyperlegible`, inte Next eller Mono. ÅäöÅÄÖ finns i alla fyra filer.
Qt Quick `FontLoader` registrerar filerna lokalt i programmet; renderern använder
Regular-filens sökväg direkt. Andra installerade fonter kan fortfarande väljas.

Fontval och storlek sparas när de ändras i gränssnittet, utanför pluginmappen:

```text
~/.local/state/oma.kvitto/settings.conf
```

Ett redan sparat explicit fontval och en sparad storlek läses vid start och
skrivs **inte över** av nyinstallationsstandarden vid start eller uppdatering.

## Skrivarmål och miljövariabler

| Variabel | Betydelse |
| --- | --- |
| `OMA_KVITTO_DEV` | Enhetsfil för direktutskrift. Standard: `/dev/usb/lp0`. |
| `OMA_KVITTO_CUPS` | Namn på CUPS-kö. Om satt används `lp -d KÖ -o raw` i stället för enhetsfilen. |
| `OMA_KVITTO_OUT` | Skriv ESC/POS-data till angiven fil i stället för till CUPS eller USB-enheten. |
| `OMA_KVITTO_FONT` | Standardfont vid direkt körning av `print.sh` utan fontargument; fontnamn eller filsökväg. Standard: bundled Atkinson Hyperlegible. |
| `OMA_KVITTO_SIZE` | Standardstorlek vid direkt körning av `print.sh` utan storleksargument. Standard: 20. |
| `OMA_KVITTO_STRECK` | Äldre textlägesval; se reservläget ovan. |

Gränssnittet skickar sitt valda fontnamn och sin storlek som argument till
renderern; dessa har företräde framför motsvarande miljövariabler. CUPS-kön
måste redan vara konfigurerad för skrivaren och kunna hantera rå ESC/POS-data.

Variabler för pluginets vanliga utskrifter måste finnas i **omarchy-shells
miljö**. En `export` i en separat terminal ändrar inte ett redan körande skal.
Använd din sessionskonfiguration för bestående miljöval och starta en ny
session så att de ärvs.

## Lokala bildfiler

Bearbetade bilder ligger privat i `$XDG_RUNTIME_DIR/oma.kvitto/images`, med
`~/.cache/oma.kvitto/images` som reserv om runtime-variabeln saknas. De ligger
aldrig i pluginmappen. Ersättning eller borttagning av en bild rensar dess
bildkatalog. Restfiler efter en skalomstart kan finnas kvar tills runtime-
katalogen städas; reservkatalogen har ingen motsvarande automatisk städgaranti.
Ingen bild återläses automatiskt efter omstart.

## Testa utan att skriva ut

Från pluginmappen kan en syntetisk text renderas till en tillfällig fil:

```bash
out="$(mktemp /tmp/oma-kvitto.XXXXXX.bin)"
OMA_KVITTO_OUT="$out" bash ./print.sh 'Test: ÅÄÖ åäö'
printf 'ESC/POS-data sparad i %s\n' "$out"
```

När `OMA_KVITTO_OUT` är satt skickas inget till skrivaren. Filen innehåller
binär ESC/POS-data, inte en vanlig bild eller textfil.

Kör de automatiska syntetiska testerna från pluginmappen:

```bash
python3 tests/test-renderer.py
```

Testerna använder filutdata och mockad clipboard, inte skrivaren eller den
verkliga clipboarden. De kontrollerar bland annat fontfiler/licens, rendering
utan systemfonter, text/bild, rasterlängd, vit avslutning och knivkommando.
Headless QML-tester av FontLoader och sparade val kräver Quickshell; den delen
hoppas över om programmet saknas.

## Avinstallera

```bash
omarchy plugin remove oma.kvitto
```

## Licens och attribution

Pluginets kod: **MIT**, copyright © 2026 Niklas; se [LICENSE](LICENSE).

Medföljande Atkinson Hyperlegible: **SIL Open Font License 1.1**, copyright
2020 Braille Institute of America, Inc. Fontfilerna omfattas inte av pluginets
MIT-licens. Fullständig licens finns i
[fonts/atkinson-hyperlegible/OFL.txt](fonts/atkinson-hyperlegible/OFL.txt).
Pinnad upstream, källadresser och SHA-256 finns i
[fonts/atkinson-hyperlegible/SOURCE.md](fonts/atkinson-hyperlegible/SOURCE.md).

- [Upstream: googlefonts/atkinson-hyperlegible](https://github.com/googlefonts/atkinson-hyperlegible)
- [Braille Institute: Atkinson Hyperlegible](https://www.brailleinstitute.org/freefont/)
- [Arch-paketet ttf-atkinson-hyperlegible](https://archlinux.org/packages/extra/any/ttf-atkinson-hyperlegible/)
