#!/bin/bash
# Life is Strange magyarítás (5.0) – macOS telepítő
#
# A fordítást a FileRise Fordítócsapat készítette (Enyedi Feri, Kis Sanyi).
# Ez a szkript csak a Windows-os telepítő fájljait teszi fel a Mac-es
# (Feral Interactive) változatra, a fordításon nem változtat.
#
# Használat:
#   bash lis-magyar.sh telepites      magyar fájlok + nyelv átállítása HUN-ra
#   bash lis-magyar.sh angol-helyere  mint a telepites, plusz a magyar szöveg
#                                     az angol (INT) fájlok helyére is kerül
#   bash lis-magyar.sh eltavolitas    minden eredeti fájl visszaállítása
#   bash lis-magyar.sh ellenorzes     jelentés a játék mappáiról (nem módosít)
#
# A macOS beépített bash 3.2-jével is működnie kell, ezért nincs benne
# asszociatív tömb, mapfile vagy ${var,,}.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PAYLOAD="$SCRIPT_DIR/fajlok"
MODE="${1:-telepites}"

if [ -n "${SUDO_USER:-}" ]; then
	USER_HOME=$(eval echo "~$SUDO_USER")
else
	USER_HOME="$HOME"
fi

STATE_DIR="$USER_HOME/Library/Application Support/LiS-Magyarositas"
ORIG_DIR="$STATE_DIR/eredeti"
MODIFIED_LIST="$STATE_DIR/modositott.txt"
CREATED_LIST="$STATE_DIR/letrehozott.txt"
CREATED_DIRS_LIST="$STATE_DIR/letrehozott-mappak.txt"

FERAL_PREF_DIRS="$USER_HOME/Library/Application Support/Feral Interactive/Life Is Strange
$USER_HOME/Library/Containers/com.feralinteractive.lifeisstrange/Data/Library/Application Support/Feral Interactive/Life Is Strange"

GAME_ROOT=""
INT_DIR=""
GAME_DIR=""
DATA_DIR=""
ENGINE_DATA_DIR=""
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

# A Terminálba behúzott útvonal (pl. /Users/x/Life\ Is\ Strange) megtisztítása.
unescape_path() {
	printf '%s' "$1" | sed -e 's/[[:space:]]*$//' -e "s/^'\(.*\)'$/\1/" -e 's/^"\(.*\)"$/\1/' -e 's/\\\(.\)/\1/g'
}

find_roots() {
	local steam="$USER_HOME/Library/Application Support/Steam" vdf
	{
		printf '%s\n' "$steam/steamapps/common/Life Is Strange"
		for vdf in "$steam/steamapps/libraryfolders.vdf" "$steam/config/libraryfolders.vdf"; do
			[ -f "$vdf" ] && awk -F'"' '$2 == "path" { print $4 "/steamapps/common/Life Is Strange" }' "$vdf"
		done
		printf '%s\n' "/Applications/Life Is Strange.app"
		printf '%s\n' "$USER_HOME/Applications/Life Is Strange.app"
	} | while IFS= read -r d; do
		[ -d "$d" ] && printf '%s\n' "$d"
	done | awk '!seen[$0]++'
}

# A legrövidebb .../LifeIsStrangeGame/Localization/INT mappa a megadott helyen.
find_int_dir() {
	find "$1" -type d -ipath '*/lifeisstrangegame/localization/int' 2>/dev/null |
		awk '{ print length($0) "\t" $0 }' | sort -n | head -n 1 | cut -f 2-
}

locate_game() {
	local roots root intdir enginedir
	roots=$(find_roots)
	while IFS= read -r root; do
		[ -n "$root" ] || continue
		intdir=$(find_int_dir "$root")
		if [ -n "$intdir" ]; then
			GAME_ROOT="$root"
			INT_DIR="$intdir"
			break
		fi
	done <<EOF
$roots
EOF

	if [ -z "$INT_DIR" ]; then
		say "Nem találtam meg automatikusan a játékot."
		say "Húzd be ebbe az ablakba a játék mappáját (vagy a \"Life Is Strange.app\"-ot),"
		say "majd nyomj Entert:"
		[ -t 0 ] || fail "Nem tudok kérdezni (nem Terminálból fut)."
		read -r root
		root=$(unescape_path "$root")
		[ -d "$root" ] || fail "Ez a mappa nem létezik: $root"
		intdir=$(find_int_dir "$root")
		[ -n "$intdir" ] || fail "Ebben a mappában nem találom a játék nyelvi fájljait (LifeIsStrangeGame/Localization/INT). Futtasd az Ellenorzes.command-ot, és küldd el a jelentést."
		GAME_ROOT="$root"
		INT_DIR="$intdir"
	fi

	GAME_DIR=$(dirname "$(dirname "$INT_DIR")")
	DATA_DIR=$(dirname "$GAME_DIR")

	if ls -1 "$INT_DIR" | grep -q '[[:upper:]]'; then LOWER_MODE=0; else LOWER_MODE=1; fi

	ENGINE_DATA_DIR="$DATA_DIR"
	if [ ! -d "$(resolve "$DATA_DIR" "Engine/Localization")" ]; then
		enginedir=$(find "$GAME_ROOT" -type d -ipath '*/engine/localization/int' 2>/dev/null | head -n 1)
		if [ -n "$enginedir" ]; then
			ENGINE_DATA_DIR=$(dirname "$(dirname "$(dirname "$enginedir")")")
		else
			ENGINE_DATA_DIR=""
		fi
	fi
}

check_writable() {
	local t="$INT_DIR/.lis-magyar-teszt"
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
	say "       sudo bash \"$SCRIPT_DIR/lis-magyar.sh\" $MODE"
	fail "Nincs írási jog: $INT_DIR"
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

# Language= sor átírása egy .ini fájlban. A módosítás idejét megtartjuk,
# hogy a játék ne generálja újra a felhasználói beállításokat.
set_language() {
	local f="$1" lang="$2" tmp ref bom utf16=0
	bom=$(head -c 2 "$f" | od -An -tx1 | tr -d ' \n')
	tmp=$(mktemp "${TMPDIR:-/tmp}/lis-magyar.XXXXXX") || fail "mktemp"
	if [ "$bom" = "fffe" ]; then
		utf16=1
		iconv -f UTF-16 -t UTF-8 "$f" >"$tmp" || { rm -f "$tmp"; return 1; }
	else
		cp "$f" "$tmp"
	fi
	if ! grep -q '^[[:space:]]*Language=' "$tmp"; then
		rm -f "$tmp"
		return 1
	fi
	if ! grep '^[[:space:]]*Language=' "$tmp" | tr -d '\r' | grep -qv "^[[:space:]]*Language=$lang\$"; then
		rm -f "$tmp"
		return 0
	fi
	backup_once "$f"
	ref="$tmp.ref"
	cp -p "$f" "$ref"
	awk -v L="$lang" '{
		if ($0 ~ /^[ \t]*Language=/) {
			cr = ""
			if ($0 ~ /\r$/) cr = "\r"
			print "Language=" L cr
		} else print
	}' "$tmp" >"$tmp.new"
	if [ "$utf16" = 1 ]; then
		{ printf '\377\376'; iconv -f UTF-8 -t UTF-16LE "$tmp.new"; } >"$f"
	else
		cat "$tmp.new" >"$f"
	fi
	touch -r "$ref" "$f"
	rm -f "$tmp" "$tmp.new" "$ref"
	say "  Nyelv: Language=$lang → $f"
	return 0
}

engine_inis() {
	find "$DATA_DIR" -maxdepth 3 -type f -iname '*engine.ini' 2>/dev/null
	if [ -n "$ENGINE_DATA_DIR" ] && [ "$ENGINE_DATA_DIR" != "$DATA_DIR" ]; then
		find "$ENGINE_DATA_DIR" -maxdepth 3 -type f -iname 'baseengine.ini' 2>/dev/null
	fi
	printf '%s\n' "$FERAL_PREF_DIRS" | while IFS= read -r d; do
		[ -d "$d" ] && find "$d" -type f -iname '*engine.ini' 2>/dev/null
	done
}

payload_loc_files() {
	(cd "$PAYLOAD" && find . -type f -ipath '*/localization/hun/*' | sed 's|^\./||' | sort)
}

payload_movie_files() {
	(cd "$PAYLOAD" && find . -type f -iname 'bik_*_hun.txt' | sed 's|^\./||' | sort)
}

game_movie_int_files() {
	find "$DATA_DIR" -type f -iname 'bik_*_int.txt' 2>/dev/null | sort
}

# Melyik csomagbeli feliratot tegyük az adott helyre: epizód (DLC) mappába
# a DLC-s példányt, a fő Movies mappába a fő példányt, ahogy a Windows-os
# telepítő is teszi.
pick_movie_payload() {
	local base_lower="$1" target="$2" main="" dlc="" rel
	while IFS= read -r rel; do
		[ "$(lower "$(basename "$rel")")" = "$base_lower" ] || continue
		case "$(lower "$rel")" in
		*/dlc/*) dlc="$rel" ;;
		*) main="$rel" ;;
		esac
	done <<EOF
$(payload_movie_files)
EOF
	case "$(lower "$target")" in
	*/dlc/*) [ -n "$dlc" ] && { printf '%s\n' "$dlc"; return; } ;;
	esac
	if [ -n "$main" ]; then printf '%s\n' "$main"; else printf '%s\n' "$dlc"; fi
}

install_hun() {
	local rel dst f n=0 skipped=0 movies_int base hun_name src placed toc tocs

	say "Magyar nyelvi fájlok másolása..."
	while IFS= read -r rel; do
		case "$(lower "$rel")" in
		engine/*)
			if [ -z "$ENGINE_DATA_DIR" ]; then
				skipped=$((skipped + 1))
				continue
			fi
			dst=$(resolve "$ENGINE_DATA_DIR" "$rel")
			;;
		*) dst=$(resolve "$DATA_DIR" "$rel") ;;
		esac
		put_file "$PAYLOAD/$rel" "$dst"
		n=$((n + 1))
	done <<EOF
$(payload_loc_files)
EOF
	say "  $n fájl kész."
	[ "$skipped" -gt 0 ] && say "  Figyelem: az Engine mappát nem találtam, $skipped motorfájl kimaradt."

	say "Filmfeliratok másolása..."
	n=0
	movies_int=$(game_movie_int_files)
	placed=""
	if [ -n "$movies_int" ]; then
		while IFS= read -r dst; do
			[ -n "$dst" ] || continue
			base=$(basename "$dst")
			base=${base%????????}
			hun_name="${base}_HUN.txt"
			src=$(pick_movie_payload "$(lower "$hun_name")" "$dst")
			[ -n "$src" ] || continue
			put_file "$PAYLOAD/$src" "$(dirname "$dst")/$(styled "$hun_name")"
			placed="$placed$(lower "$hun_name")
"
			n=$((n + 1))
		done <<EOF
$movies_int
EOF
	fi
	# Amihez a játékban nincs angol feliratfájl: a Windows-os helyére tesszük,
	# ha ott a mappa létezik.
	while IFS= read -r rel; do
		[ -n "$rel" ] || continue
		printf '%s' "$placed" | grep -Fxq -- "$(lower "$(basename "$rel")")" && continue
		dst=$(resolve "$DATA_DIR" "$rel")
		if [ -d "$(dirname "$dst")" ]; then
			put_file "$PAYLOAD/$rel" "$dst"
			n=$((n + 1))
		fi
	done <<EOF
$(payload_movie_files)
EOF
	say "  $n felirat kész."

	say "Tartalomjegyzék (TOC) másolása..."
	src=$(cd "$PAYLOAD" && find . -type f -iname '*toc_hun.txt' | sed 's|^\./||' | head -n 1)
	tocs=$(find "$GAME_DIR" -maxdepth 1 -type f -iname '*toc_int.txt' 2>/dev/null)
	if [ -n "$tocs" ]; then
		while IFS= read -r toc; do
			[ -n "$toc" ] || continue
			base=$(basename "$toc")
			base=${base%????????}
			put_file "$PAYLOAD/$src" "$GAME_DIR/$base$(styled "_HUN.txt")"
		done <<EOF
$tocs
EOF
	else
		put_file "$PAYLOAD/$src" "$(resolve "$DATA_DIR" "$src")"
	fi

	say "Nyelv átállítása magyarra..."
	n=0
	while IFS= read -r f; do
		[ -n "$f" ] || continue
		set_language "$f" HUN && n=$((n + 1))
	done <<EOF
$(engine_inis)
EOF
	[ "$n" -gt 0 ] || say "  Figyelem: nem találtam Language= beállítást. Ha angol marad a játék, használd a Telepites-angol-helyere.command-ot."
}

# A magyar szöveg az angol (INT) fájlok helyére: így akkor is magyar lesz
# a játék, ha a Feral-féle indító angol nyelvet állít be.
install_over_int() {
	local rel int_rel dst n=0 base hun_name src
	say "Magyar szöveg másolása az angol fájlok helyére..."
	while IFS= read -r rel; do
		int_rel=$(printf '%s' "$rel" | awk '{
			n = split($0, p, "/")
			out = ""
			for (i = 1; i < n; i++) {
				if (tolower(p[i]) == "hun") p[i] = "INT"
				out = out p[i] "/"
			}
			sub(/\.[^.]*$/, ".INT", p[n])
			print out p[n]
		}')
		case "$(lower "$rel")" in
		engine/*)
			[ -n "$ENGINE_DATA_DIR" ] || continue
			dst=$(resolve "$ENGINE_DATA_DIR" "$int_rel")
			;;
		*) dst=$(resolve "$DATA_DIR" "$int_rel") ;;
		esac
		[ -f "$dst" ] || continue
		put_file "$PAYLOAD/$rel" "$dst"
		n=$((n + 1))
	done <<EOF
$(payload_loc_files)
EOF
	say "  $n nyelvi fájl kész."

	n=0
	while IFS= read -r dst; do
		[ -n "$dst" ] || continue
		base=$(basename "$dst")
		base=${base%????????}
		hun_name="${base}_HUN.txt"
		src=$(pick_movie_payload "$(lower "$hun_name")" "$dst")
		[ -n "$src" ] || continue
		put_file "$PAYLOAD/$src" "$dst"
		n=$((n + 1))
	done <<EOF
$(game_movie_int_files)
EOF
	say "  $n filmfelirat kész."
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
	say "  $n magyar fájl törölve."
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
	local out="$USER_HOME/Desktop/LiS-magyar-jelentes.txt" roots
	roots=$(find_roots)
	{
		say "Life is Strange magyarítás – ellenőrző jelentés"
		say "Dátum: $(date)"
		command -v sw_vers >/dev/null 2>&1 && sw_vers
		say ""
		say "== Megtalált játékmappák"
		printf '%s\n' "${roots:-(egy sem)}"
		while IFS= read -r root; do
			[ -n "$root" ] || continue
			say ""
			say "== $root"
			say "-- nyelvi mappák:"
			find "$root" -type d -ipath '*/localization/*' 2>/dev/null | head -n 40
			say "-- TOC fájlok:"
			find "$root" -type f -iname '*toc*.txt' 2>/dev/null | head -n 40
			say "-- angol filmfeliratok száma: $(find "$root" -type f -iname 'bik_*_int.txt' 2>/dev/null | wc -l | tr -d ' ')"
			say "-- Language= sorok a játék .ini fájljaiban:"
			find "$root" -type f -iname '*engine*.ini' -exec grep -H -a '^[[:space:]]*Language=' {} \; 2>/dev/null | head -n 20
			say "-- mappaszerkezet:"
			find "$root" -maxdepth 6 -type d 2>/dev/null | head -n 300
		done <<EOF
$roots
EOF
		say ""
		say "== Feral beállítások"
		printf '%s\n' "$FERAL_PREF_DIRS" | while IFS= read -r d; do
			[ -d "$d" ] || continue
			say "-- $d"
			find "$d" -type f -iname '*.ini' 2>/dev/null | head -n 40
			find "$d" -type f -iname '*engine*.ini' -exec grep -H -a '^[[:space:]]*Language=' {} \; 2>/dev/null
		done
		if command -v defaults >/dev/null 2>&1; then
			defaults domains 2>/dev/null | tr ',' '\n' | grep -i feral
			defaults read com.feralinteractive.lifeisstrange 2>/dev/null | head -n 80
		fi
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

say "Life is Strange magyarítás (5.0) – Mac"
say "Fordította: FileRise Fordítócsapat (Enyedi Feri, Kis Sanyi)"
say ""

case "$MODE" in
telepites | angol-helyere)
	[ -d "$PAYLOAD" ] || fail "Nem találom a fajlok mappát a telepítő mellett: $PAYLOAD"
	locate_game
	say "Játék: $GAME_ROOT"
	say "Nyelvi mappa: $INT_DIR"
	say ""
	check_writable
	prepare_state
	install_hun
	[ "$MODE" = "angol-helyere" ] && install_over_int
	say ""
	say "Kész! Jó játékot! Ha a játék angol marad, futtasd a"
	say "Telepites-angol-helyere.command-ot. Visszaállítás: Eltavolitas.command."
	;;
eltavolitas)
	uninstall
	;;
ellenorzes)
	report
	;;
*)
	fail "Ismeretlen mód: $MODE (telepites | angol-helyere | eltavolitas | ellenorzes)"
	;;
esac
