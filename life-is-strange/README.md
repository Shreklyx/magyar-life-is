# Life is Strange magyarítás – Mac

A **FileRise Fordítócsapat** (Enyedi Feri, Kis Sanyi) *Life is Strange Magyarítás (5.0)* fordítása macOS-re, a Steam-es (Feral Interactive) változathoz.

A fordítás fájljai bájtra megegyeznek a Windows-os telepítőben (`LISHUN-5.0.exe`) lévőkkel. Csak a telepítő készült újra Mac-re. A feltételeket lásd a [FELTETELEK.txt](FELTETELEK.txt) fájlban.

> Valódi Macen kipróbálva: Steam-es (Feral Interactive) változat, külső lemezen lévő Steam-könyvtárban. A játék magyarul fut.

## Vírusellenőrzés

Az eredeti `LISHUN-5.0.exe`-t futtatás nélkül, teljesen kicsomagolva ellenőriztem:

- **ClamAV** (3,6 millió vírusdefiníció, 2026. 10. 26-i adatbázis): **0 fertőzött fájl**, a telepítőben és a kicsomagolt fájlokban sem.
- A telepítő egy szabványos Clickteam Install Creator 2.0 program. Egyetlen futtatható fájl van benne (maga a telepítő), és a beépített eltávolító.
- A 260 telepített fájl mind szöveg: nyelvi fájlok (`.HUN`, `.INT`), filmfeliratok (`.txt`) és egy `BaseEngine.ini`. A bennük lévő linkek mind az eredeti játék szövegeiből származnak (Epic Games, Square Enix).
- Az eredeti exe SHA-256 ellenőrzőösszege: `5d62d4255c09ab10873096388a9a72bea7422b7359bbd267167126c8eed8c090`

## Telepítés

1. Telepítsd a Life is Strange-et Steamen. Érdemes egyszer elindítani, majd kilépni belőle.
2. Töltsd le ezt a csomagot (zöld **Code** gomb → **Download ZIP**), és csomagold ki.
3. Nyisd meg a **Terminált** (Alkalmazások → Segédprogramok → Terminál).
4. Írd be: `bash ` (a végén egy szóközzel), húzd be a Terminál ablakába a `life-is-strange/mac` mappában lévő **`Telepites.command`** fájlt, és nyomj Entert.
5. A telepítő magától megkeresi a játékot. Ha nem találja, kérni fogja, hogy húzd be a játék mappáját: Steamen jobb klikk a játékon → **Kezelés** → **Helyi fájlok tallózása**.
6. Indítsd el a játékot.

A `.command` fájlokat dupla kattintással is elindíthatod. Ilyenkor a macOS az első alkalommal valószínűleg letiltja őket, mert internetről származnak. Ekkor menj ide: **Rendszerbeállítások → Adatvédelem és biztonság**, és alul kattints a **Megnyitás mindenképp** gombra. A 4. lépésben leírt Terminálos indítás ezt a lépést kihagyja.

### Ha angol marad a játék

A Mac-es (Feral) változat a nyelvet a saját indítójában állítja, a beállítófájlokban nincs `Language=` sor. Ilyenkor a telepítő magától a magyar szöveget az angol fájlok helyére is bemásolja, így a játék az angol nyelvi beállítás mellett is magyarul szólal meg. Az angol fájlokról is készül biztonsági mentés.

Ha valamiért mégis angol maradna, a **`Telepites-angol-helyere.command`** ezt a cserét mindenképp elvégzi.

### Ha hibát ír ki

- **„A macOS nem engedi, hogy a Terminál módosítsa a játék fájljait”**: Rendszerbeállítások → Adatvédelem és biztonság → **Alkalmazáskezelés** (App Management): kapcsold be a **Terminált**, majd zárd be és nyisd meg újra, és futtasd újra a telepítőt.
- **Mac App Store-os játék**: a telepítőt rendszergazdaként kell futtatni: `sudo bash ` + húzd be a `lis-magyar.sh` fájlt, a végére írd: ` telepites`. Az App Store-os változat módosítás után akár el sem indulhat, ezért a Steam-es változat ajánlott.

## Eltávolítás

Futtasd az **`Eltavolitas.command`** fájlt. Minden eredeti fájl visszaáll, a magyar fájlok törlődnek.

A telepítő minden megváltoztatott fájlról mentést készít ide: `~/Library/Application Support/LiS-Magyarositas/`.

Ha a Steam frissíti a játékot, vagy ellenőrzöd a fájlok sértetlenségét, a magyarítás egy része elveszhet. Ilyenkor futtasd újra a telepítőt.

## Ha nem működik

Futtasd az **`Ellenorzes.command`** fájlt. Ez semmit nem módosít, csak készít egy jelentést a játék mappáiról az Asztalra (`LiS-magyar-jelentes.txt`). Ebből kiderül, hol vannak a játék fájljai a Mac-es változatban, és ennek alapján javítható a telepítő.

## Mit csinál a telepítő?

A Windows-os telepítő ugyanezt teszi a Windows-os játékkal:

- a magyar nyelvi fájlokat bemásolja a `LifeIsStrangeGame/Localization/HUN` és az `Engine/Localization/HUN` mappába (105 fájl),
- a filmek magyar feliratait az angolok mellé teszi (`BIK_…_HUN.txt`, legfeljebb 35 fájl),
- bemásolja a magyar tartalomjegyzéket (`PCConsoleFINALTOC_HUN.txt`),
- a játék beállításaiban (`BaseEngine.ini` és a Feral-féle felhasználói `…Engine.ini`) a `Language=` sort `HUN`-ra állítja. A Windows-os telepítő a teljes `BaseEngine.ini`-t lecseréli; ez csak az egy sort írja át, a többi Mac-es beállítást meghagyja,
- ha nincs `Language=` sor (a Mac-es változatban nincs), a magyar szöveget az angol (`INT`) fájlok és feliratok helyére is bemásolja.

A Mac-es változat a játékfájlokat a játék mappájában, a `LifeIsStrangeData` mappában tárolja, csupa kisbetűs nevekkel. A telepítő ehhez igazodik.

Az angol eredeti fájlokat (`.INT`), a Windows-os `BaseEngine.ini`-t és az eltávolító programot nem tartalmazza a csomag, mert Mac-en nincs rájuk szükség.

## Fájlok

| Hely | Tartalom |
| --- | --- |
| `mac/Telepites.command` | telepítés |
| `mac/Telepites-angol-helyere.command` | telepítés, a magyar szöveg az angol helyére is |
| `mac/Eltavolitas.command` | visszaállítás |
| `mac/Ellenorzes.command` | jelentés, nem módosít semmit |
| `mac/lis-magyar.sh` | maga a telepítő, ezt hívja a négy fenti fájl |
| `mac/fajlok/` | a fordítás fájljai, a Windows-os telepítőből változatlanul |
| `../tools/extract_clickteam.py` | a Windows-os telepítő kicsomagolója (futtatás nélkül), egy új verzióhoz |
