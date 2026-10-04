# oma.kvitto

Utskrift till Epson TM-T88V från Omarchy.

## Krav

- Omarchy med `omarchy-shell`
- Skrivare på `/dev/usb/lp0` (eller CUPS-kö)
- Användaren i gruppen `lp`

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
