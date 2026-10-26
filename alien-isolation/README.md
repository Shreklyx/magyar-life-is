# Alien: Isolation magyarítás – Mac

Az *Alien: Isolation magyarítás (1.2)* macOS-re, a Steam-es (Feral Interactive) változathoz. Készítők: **Patyek, Beholder**. Betűtípus: **cockafej**. Windows-os telepítő: **FEARka**. Az alapjáték, a 2 előrendelői DLC és mind az 5 kiegészítő fordítását tartalmazza.

A fordítás fájljai bájtra megegyeznek a Windows-os telepítő (`Alien_Isolation_HUN_1.2.exe`) Steam-es változatában lévőkkel. Csak a telepítő készült újra Mac-re. A feltételeket és a készítőket lásd a [FELTETELEK.txt](FELTETELEK.txt) fájlban.

> **Fontos:** a telepítőt Mac-es mappaszerkezetet utánzó tesztkörnyezetben próbáltam ki, a macOS-éval megegyező bash 3.2-vel. Valódi Macen, a valódi játékkal még nem futott. Ha valami nem működik, nézd meg a [Ha nem működik](#ha-nem-működik) részt.

## Vírusellenőrzés

Az eredeti `Alien_Isolation_HUN_1.2.exe`-t futtatás nélkül, teljesen kicsomagolva ellenőriztem:

- **ClamAV** (3,6 millió vírusdefiníció, 2026. 10. 26-i adatbázis): **0 fertőzött fájl** a telepítőben és mind az 1076 kicsomagolt fájlban.
- A telepítő egy szabványos Inno Setup 6.0 program. A belső szkriptje csak ennyit csinál: a registryből kiolvassa, hol van a játék, elmenti az angol szövegeket, bemásolja a magyarokat. A „Támogatás” gomb megnyitja a készítő weboldalát. Nem futtat más programot, és nem tölt le semmit.
- A benne lévő két DLL (`InnoCallback.dll`, `VclStylesInno.dll`) a telepítő ablakának kinézetéhez kell. Ezek ismert, gyakran használt Inno Setup kiegészítők, és nem kerülnek a játékba.
- A játékba kerülő fájlok: 266 szövegfájl (`.TXT`) és a felület archívuma (`UI.PAK`).
- Az eredeti exe SHA-256 ellenőrzőösszege: `f5b8ff62f14dbdfa2374ad2d132060512b58488ef635451b80ed9a4c4fac8a3e`

## Telepítés

1. Telepítsd az Alien: Isolationt Steamen, és lépj ki belőle.
2. Csomagold ki a ZIP-et.
3. Nyisd meg a **Terminált** (Cmd + Szóköz, írd be: `Terminál`, Enter).
4. Írd be: `bash ` (a végén egy szóközzel), húzd be a Terminál ablakába az `alien-isolation/mac` mappában lévő **`Telepites.command`** fájlt, és nyomj Entert.
5. A telepítő magától megkeresi a játékot, a külső lemezen lévő Steam-könyvtárakban is. Ha nem találja, kérni fogja, hogy húzd be a játék mappáját: Steamen jobb klikk a játékon → **Kezelés** → **Helyi fájlok tallózása**.
6. Indítsd el a játékot.

A `.command` fájlokat dupla kattintással is elindíthatod. Ha a macOS letiltja őket, menj ide: **Rendszerbeállítások → Adatvédelem és biztonság**, és kattints a **Megnyitás mindenképp** gombra.

### A betűkészletről (ő és ű)

A magyar szövegekben `ő` és `ű` helyett `ô` és `û` áll. A magyar `UI.PAK`-ban lévő módosított betűkészlet ezeket `ő`-nek és `ű`-nek rajzolja ki. A telepítő a játék `UI.PAK` fájlját csak akkor cseréli le a magyarra, ha a Mac-es fájl belső felépítése pontosan egyezik a Windows-oséval. Ha eltér, a cserét kihagyja, és szól. A játék ilyenkor is magyar lesz, csak `ô` és `û` látszik a két betű helyén.

Ha a `UI.PAK` cseréje után a menük hibásak, vagy a játék nem indul el, futtasd a **`Telepites-csak-szoveg.command`** fájlt. Ez visszaállítja az eredeti `UI.PAK`-ot, a magyar szövegek maradnak.

### Ha hibát ír ki

- **„A macOS nem engedi, hogy a Terminál módosítsa a játék fájljait”**: Rendszerbeállítások → Adatvédelem és biztonság → **Alkalmazáskezelés** (App Management): kapcsold be a **Terminált**, majd zárd be és nyisd meg újra, és futtasd újra a telepítőt.
- **Mac App Store-os játék**: a telepítőt rendszergazdaként kell futtatni: `sudo bash ` + húzd be az `alien-magyar.sh` fájlt, a végére írd: ` telepites`.

## Eltávolítás

Futtasd az **`Eltavolitas.command`** fájlt. Minden eredeti fájl visszaáll.

A telepítő minden felülírt fájlról mentést készít ide: `~/Library/Application Support/Alien-Magyarositas/`.

Ha a Steam frissíti a játékot, vagy ellenőrzöd a fájlok sértetlenségét, a magyarítás elveszhet. Ilyenkor futtasd újra a telepítőt.

## Ha nem működik

Futtasd az **`Ellenorzes.command`** fájlt. Ez semmit nem módosít, csak készít egy jelentést az Asztalra (`Alien-magyar-jelentes.txt`). Ebből kiderül, hol vannak a játék fájljai a Mac-es változatban, és egyezik-e a `UI.PAK` felépítése.

Haladóknak: ha a jelentés szerint eltér a `UI.PAK` felépítése, de mégis ki akarod próbálni a cserét, a Terminálban: `bash ` + húzd be az `alien-magyar.sh` fájlt + ` telepites --ui-pak-csere`. Ha gond van, a `Telepites-csak-szoveg.command` visszaállítja.

## Mit csinál a telepítő?

A Windows-os telepítő ugyanezt teszi a Windows-os játékkal:

- az angol szövegfájlokat (`DATA/TEXT/ENGLISH` és a kiegészítők `…/TEXT/ENGLISH` mappái) lecseréli a magyarra. A nem telepített kiegészítők fájljait kihagyja,
- a `DATA/UI.PAK`-ot lecseréli a magyar betűkészletes változatra (lásd fent).

A Windows-os telepítő GOG-os, Epic-es és Game Pass-os változatát, a telepítő DLL-jeit és a `visszaallitas.bat`-ot nem tartalmazza a csomag, mert Mac-en nincs rájuk szükség.

## Fájlok

| Hely | Tartalom |
| --- | --- |
| `mac/Telepites.command` | telepítés |
| `mac/Telepites-csak-szoveg.command` | csak a szövegek, az eredeti `UI.PAK` marad |
| `mac/Eltavolitas.command` | visszaállítás |
| `mac/Ellenorzes.command` | jelentés, nem módosít semmit |
| `mac/alien-magyar.sh` | maga a telepítő, ezt hívja a négy fenti fájl |
| `mac/fajlok/` | a fordítás fájljai, a Windows-os telepítőből változatlanul |

A Windows-os telepítőt az [innoextract](https://constexpr.org/innoextract/) programmal lehet futtatás nélkül kicsomagolni: `innoextract --collisions=rename Alien_Isolation_HUN_1.2.exe`. A Steam-es fájlok a `#steam` végződésűek.
