#!/bin/bash
# Alien: Isolation magyarítás (1.2) – macOS telepítő
#
# A fordítást Patyek és Beholder készítette, a betűtípust cockafej
# szerkesztette, a Windows-os telepítőt FEARka. Ez a szkript csak a
# Windows-os telepítő (Steam-es változat) fájljait teszi fel a Mac-es
# (Feral Interactive) játékra, a fordításon nem változtat.
#
# Használat:
#   bash alien-magyar.sh telepites      szövegek + magyar betűkészlet (UI.PAK)
#   bash alien-magyar.sh csak-szoveg    csak a szövegek, az eredeti UI.PAK marad
#   bash alien-magyar.sh eltavolitas    minden eredeti fájl visszaállítása
#   bash alien-magyar.sh ellenorzes     jelentés a játék mappáiról (nem módosít)
#
# A telepites mód a UI.PAK-ot csak akkor cseréli, ha a játékban lévő
# UI.PAK belső fájllistája pontosan egyezik a magyaréval. A
# --ui-pak-csere kapcsolóval ez az ellenőrzés kihagyható.
#
# A macOS beépített bash 3.2-jével is működnie kell.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PAYLOAD="$SCRIPT_DIR/fajlok"
MODE="${1:-telepites}"
FORCE_UI_PAK=0
[ "${2:-}" = "--ui-pak-csere" ] && FORCE_UI_PAK=1

if [ -n "${SUDO_USER:-}" ]; then
	USER_HOME=$(eval echo "~$SUDO_USER")
else
	USER_HOME="$HOME"
fi

STATE_DIR="$USER_HOME/Library/Application Support/Alien-Magyarositas"
ORIG_DIR="$STATE_DIR/eredeti"
MODIFIED_LIST="$STATE_DIR/modositott.txt"
CREATED_LIST="$STATE_DIR/letrehozott.txt"
CREATED_DIRS_LIST="$STATE_DIR/letrehozott-mappak.txt"

GAME_ROOT=""
TEXT_DIR=""
BASE_DIR=""
LOWER_MODE=0

say() { printf '%s\n' "$*"; }

fail() {
	printf '\nHIBA: %s\n' "$*" >&2
	exit 1
}

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# Új fájl- és mappanevek: ha a játék csupa kisbetűs neveket használ
# (a Feral portoknál ez szokás), akkor mi is kisbetűvel hozzuk létre őket.
styled() {
	if [ "$LOWER_MODE" = 1 ]; then lower "$1"; else printf '%s' "$1"; fi
}

# A "/" mentén megadott relatív utat a meglévő mappák tényleges
# kis-/nagybetűs írásmódjához igazítja (kis-nagybetű érzékeny lemezen is).
resolve() {
	local cur="$1" rest="$2" comp found
	local IFS='/'
	set -f
	for comp in $rest; do
		[ -n "$comp" ] || continue
		found=""
		if [ -d "$cur" ]; then
			found=$(ls -1A "$cur" 2>/dev/null | awk -v c="$comp" 'BEGIN { c = tolower(c) } tolower($0) == c { print; exit }')
		fi
		if [ -n "$found" ]; then
			cur="$cur/$found"
		else
			cur="$cur/$(styled "$comp")"
		fi
	done
	set +f
	printf '%s\n' "$cur"
}

# A Terminálba behúzott útvonal (pl. /Users/x/Alien\ Isolation) megtisztítása.
unescape_path() {
	printf '%s' "$1" | sed -e 's/[[:space:]]*$//' -e "s/^'\(.*\)'$/\1/" -e 's/^"\(.*\)"$/\1/' -e 's/\\\(.\)/\1/g'
}

find_roots() {
	local steam="$USER_HOME/Library/Application Support/Steam" vdf
	{
		printf '%s\n' "$steam/steamapps/common/Alien Isolation"
		for vdf in "$steam/steamapps/libraryfolders.vdf" "$steam/config/libraryfolders.vdf"; do
			[ -f "$vdf" ] && awk -F'"' '$2 == "path" { print $4 "/steamapps/common/Alien Isolation" }' "$vdf"
		done
		find /Applications "$USER_HOME/Applications" -maxdepth 1 -iname '*alien*' 2>/dev/null
	} | while IFS= read -r d; do
		[ -d "$d" ] && printf '%s\n' "$d"
	done | awk '!seen[$0]++'
}

# A legrövidebb .../DATA/TEXT/ENGLISH mappa a megadott helyen.
find_text_dir() {
	find "$1" -type d -ipath '*/data/text/english' 2>/dev/null |
		awk '{ print length($0) "\t" $0 }' | sort -n | head -n 1 | cut -f 2-
}

locate_game() {
	local roots root textdir
	roots=$(find_roots)
	while IFS= read -r root; do
		[ -n "$root" ] || continue
		textdir=$(find_text_dir "$root")
		if [ -n "$textdir" ]; then
			GAME_ROOT="$root"
			TEXT_DIR="$textdir"
			break
		fi
	done <<EOF
$roots
EOF

	if [ -z "$TEXT_DIR" ]; then
		say "Nem találtam meg automatikusan a játékot."
		say "Húzd be ebbe az ablakba a játék mappáját (Steamen: jobb klikk a játékon →"
		say "Kezelés → Helyi fájlok tallózása), majd nyomj Entert:"
		[ -t 0 ] || fail "Nem tudok kérdezni (nem Terminálból fut)."
		read -r root
		root=$(unescape_path "$root")
		[ -d "$root" ] || fail "Ez a mappa nem létezik: $root"
		textdir=$(find_text_dir "$root")
		[ -n "$textdir" ] || fail "Ebben a mappában nem találom a játék szövegeit (DATA/TEXT/ENGLISH). Futtasd az Ellenorzes.command-ot, és küldd el a jelentést."
		GAME_ROOT="$root"
		TEXT_DIR="$textdir"
	fi

	BASE_DIR=$(dirname "$(dirname "$(dirname "$TEXT_DIR")")")
	if ls -1 "$TEXT_DIR" | grep -q '[[:upper:]]'; then LOWER_MODE=0; else LOWER_MODE=1; fi
}

check_writable() {
	local t="$TEXT_DIR/.alien-magyar-teszt"
	if ( : >"$t" ) 2>/dev/null; then
		rm -f "$t"
		return 0
	fi
	say ""
	say "A macOS nem engedi, hogy a Terminál módosítsa a játék fájljait."
	say ""
	say "Megoldás:"
	say "  1. Rendszerbeállítások → Adatvédelem és biztonság → Alkalmazáskezelés"
	say "     (angolul: App Management): kapcsold be a Terminált, majd zárd be"
	say "     és nyisd újra a Terminált, és futtasd újra a telepítőt."
	say "  2. Ha a játékot a Mac App Store-ból vetted, a telepítőt rendszergazdaként"
	say "     kell futtatni. Terminálban:"
	say "       sudo bash \"$SCRIPT_DIR/alien-magyar.sh\" $MODE"
	fail "Nincs írási jog: $TEXT_DIR"
}

in_list() { [ -f "$2" ] && grep -Fxq -- "$1" "$2"; }

prepare_state() {
	mkdir -p "$ORIG_DIR" || fail "Nem tudom létrehozni a mentési mappát: $STATE_DIR"
	touch "$MODIFIED_LIST" "$CREATED_LIST" "$CREATED_DIRS_LIST"
	if [ ! -f "$STATE_DIR/jatek-helye.txt" ]; then
		printf '%s\n' "$GAME_ROOT" >"$STATE_DIR/jatek-helye.txt"
	fi
}

# Meglévő fájl mentése, mielőtt először hozzányúlunk.
backup_once() {
	local f="$1"
	in_list "$f" "$CREATED_LIST" && return 0
	in_list "$f" "$MODIFIED_LIST" && return 0
	mkdir -p "$ORIG_DIR$(dirname "$f")" && cp -p "$f" "$ORIG_DIR$f" ||
		fail "Nem sikerült biztonsági mentést készíteni: $f"
	printf '%s\n' "$f" >>"$MODIFIED_LIST"
}

put_file() {
	local src="$1" dst="$2" d missing=""
	if [ -e "$dst" ]; then
		backup_once "$dst"
	else
		in_list "$dst" "$CREATED_LIST" || printf '%s\n' "$dst" >>"$CREATED_LIST"
		d=$(dirname "$dst")
		while [ ! -d "$d" ]; do
			missing="$d
$missing"
			d=$(dirname "$d")
		done
		if [ -n "$missing" ]; then
			mkdir -p "$(dirname "$dst")" || fail "Nem sikerült létrehozni: $(dirname "$dst")"
			printf '%s' "$missing" | while IFS= read -r d; do
				[ -n "$d" ] && printf '%s\n' "$d" >>"$CREATED_DIRS_LIST"
			done
		fi
	fi
	cp "$src" "$dst" || fail "Nem sikerült másolni: $dst"
	if command -v xattr >/dev/null 2>&1; then
		xattr -d com.apple.quarantine "$dst" 2>/dev/null || true
	fi
}

# Egyetlen, korábban felülírt fájl visszaállítása a mentésből.
restore_one() {
	local f="$1" tmp
	in_list "$f" "$MODIFIED_LIST" || return 1
	cp -p "$ORIG_DIR$f" "$f" || fail "Nem sikerült visszaállítani: $f"
	rm -f "$ORIG_DIR$f"
	tmp=$(mktemp "${TMPDIR:-/tmp}/alien-magyar.XXXXXX") || fail "mktemp"
	grep -Fxv -- "$f" "$MODIFIED_LIST" >"$tmp"
	cat "$tmp" >"$MODIFIED_LIST"
	rm -f "$tmp"
}

# Egy PAK2 archívum belső fájlnevei, soronként. A fejléc: "PAK2", a
# névblokk mérete (4 bájt), a fájlok száma (4 bájt), igazítás (4 bájt),
# utána a nullával lezárt nevek.
pak_names() {
	local f="$1" size
	[ "$(head -c 4 "$f" 2>/dev/null)" = "PAK2" ] || return 1
	size=$(od -An -tu4 -j4 -N4 "$f" | tr -d ' \n')
	[ -n "$size" ] || return 1
	head -c $((16 + size)) "$f" | tail -c "$size" | tr '\0' '\n'
}

payload_text_files() {
	(cd "$PAYLOAD" && find . -type f -iname '*.txt' | sed 's|^\./||' | sort)
}

install_text() {
	local rel dst n=0 skipped=0
	say "Magyar szövegek másolása..."
	while IFS= read -r rel; do
		[ -n "$rel" ] || continue
		dst=$(resolve "$BASE_DIR" "$rel")
		if [ -d "$(dirname "$dst")" ]; then
			put_file "$PAYLOAD/$rel" "$dst"
			n=$((n + 1))
		else
			skipped=$((skipped + 1))
		fi
	done <<EOF
$(payload_text_files)
EOF
	say "  $n szövegfájl kész."
	[ "$skipped" -gt 0 ] && say "  $skipped fájl kimaradt, mert a játékban nincs meg a mappája (pl. nem telepített kiegészítő)."
	return 0
}

install_ui_pak() {
	local src="$PAYLOAD/DATA/UI.PAK" dst ours theirs
	say "Magyar betűkészlet (UI.PAK)..."
	dst=$(resolve "$BASE_DIR" "DATA/UI.PAK")
	if [ ! -f "$dst" ]; then
		say "  Nem találom a játék UI.PAK fájlját, kimarad. Az ő és ű betűk helyén ô és û fog látszani."
		return 0
	fi
	if cmp -s "$src" "$dst"; then
		say "  Már a magyar van fent."
		return 0
	fi
	if [ "$FORCE_UI_PAK" != 1 ]; then
		ours=$(pak_names "$src")
		theirs=$(pak_names "$dst")
		if [ -z "$theirs" ] || [ "$ours" != "$theirs" ]; then
			say "  A Mac-es UI.PAK felépítése eltér a Windows-ostól, ezért a biztonság"
			say "  kedvéért nem cserélem le. A játék így is magyar lesz, csak az ő és ű"
			say "  betűk helyén ô és û fog látszani. Futtasd az Ellenorzes.command-ot,"
			say "  és küldd el a jelentést."
			return 0
		fi
	fi
	put_file "$src" "$dst"
	say "  Kész."
}

restore_ui_pak() {
	local dst
	dst=$(resolve "$BASE_DIR" "DATA/UI.PAK")
	if restore_one "$dst"; then
		say "Az eredeti UI.PAK visszaállítva."
	fi
}

uninstall() {
	local f d n=0
	[ -d "$STATE_DIR" ] || fail "Nem találok telepített magyarítást (nincs mentés: $STATE_DIR)."
	say "Eredeti fájlok visszaállítása..."
	if [ -f "$MODIFIED_LIST" ]; then
		while IFS= read -r f; do
			[ -n "$f" ] || continue
			if [ -f "$ORIG_DIR$f" ]; then
				cp -p "$ORIG_DIR$f" "$f" || fail "Nem sikerült visszaállítani: $f"
				n=$((n + 1))
			fi
		done <"$MODIFIED_LIST"
	fi
	say "  $n fájl visszaállítva."
	n=0
	if [ -f "$CREATED_LIST" ]; then
		while IFS= read -r f; do
			[ -n "$f" ] || continue
			rm -f "$f" && n=$((n + 1))
		done <"$CREATED_LIST"
	fi
	say "  $n új fájl törölve."
	if [ -f "$CREATED_DIRS_LIST" ]; then
		awk '{ a[NR] = $0 } END { for (i = NR; i > 0; i--) print a[i] }' "$CREATED_DIRS_LIST" |
			while IFS= read -r d; do
				[ -n "$d" ] && rmdir "$d" 2>/dev/null
			done
	fi
	rm -rf "$STATE_DIR"
	say ""
	say "Kész, a játék visszaállt az eredeti állapotba."
}

report() {
	local out="$USER_HOME/Desktop/Alien-magyar-jelentes.txt" roots ours
	roots=$(find_roots)
	ours=$(pak_names "$PAYLOAD/DATA/UI.PAK")
	{
		say "Alien: Isolation magyarítás – ellenőrző jelentés"
		say "Dátum: $(date)"
		command -v sw_vers >/dev/null 2>&1 && sw_vers
		say ""
		say "== Megtalált játékmappák"
		printf '%s\n' "${roots:-(egy sem)}"
		while IFS= read -r root; do
			[ -n "$root" ] || continue
			say ""
			say "== $root"
			say "-- szövegmappák:"
			find "$root" -type d -ipath '*/text/*' 2>/dev/null | head -n 40
			say "-- UI.PAK fájlok:"
			find "$root" -type f -iname 'ui.pak' 2>/dev/null | while IFS= read -r f; do
				say "$f ($(wc -c <"$f" | tr -d ' ') bájt, $(pak_names "$f" | wc -l | tr -d ' ') belső fájl)"
				if [ "$(pak_names "$f")" = "$ours" ]; then
					say "   felépítése egyezik a magyaréval"
				else
					say "   felépítése ELTÉR a magyarétól"
					pak_names "$f" | head -n 20
				fi
			done
			say "-- mappaszerkezet:"
			find "$root" -maxdepth 6 -type d 2>/dev/null | head -n 300
		done <<EOF
$roots
EOF
		say ""
		say "== Telepítés állapota"
		if [ -d "$STATE_DIR" ]; then
			say "telepítve; módosított: $(wc -l <"$MODIFIED_LIST" | tr -d ' '), létrehozott: $(wc -l <"$CREATED_LIST" | tr -d ' ')"
		else
			say "nincs telepítve"
		fi
	} >"$out" 2>&1
	cat "$out"
	say ""
	say "A jelentést elmentettem ide: $out"
}

say "Alien: Isolation magyarítás (1.2) – Mac"
say "Készítők: Patyek, Beholder · Betűtípus: cockafej · Telepítő: FEARka"
say ""

case "$MODE" in
telepites | csak-szoveg)
	[ -d "$PAYLOAD" ] || fail "Nem találom a fajlok mappát a telepítő mellett: $PAYLOAD"
	locate_game
	say "Játék: $GAME_ROOT"
	say "Szövegmappa: $TEXT_DIR"
	say ""
	check_writable
	prepare_state
	install_text
	if [ "$MODE" = "telepites" ]; then
		install_ui_pak
	else
		restore_ui_pak
		say "A UI.PAK eredeti maradt: az ő és ű betűk helyén ô és û fog látszani."
	fi
	say ""
	say "Kész! Jó játékot! Visszaállítás: Eltavolitas.command."
	;;
eltavolitas)
	uninstall
	;;
ellenorzes)
	report
	;;
*)
	fail "Ismeretlen mód: $MODE (telepites | csak-szoveg | eltavolitas | ellenorzes)"
	;;
esac
