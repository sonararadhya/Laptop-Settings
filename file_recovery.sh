#!/bin/bash

# ============================================================
#  file_recovery.sh — Corrupt File Recovery Tool for Kali Linux
#  Run as root: sudo bash file_recovery.sh [target_directory]
#  Default scan target: current directory
# ============================================================

TARGET_DIR="${1:-.}"
TARGET_DIR="$(realpath "$TARGET_DIR")"
RECOVERY_DIR="$TARGET_DIR/recovery"
REPORT="$TARGET_DIR/recovery_report_$(date +%Y%m%d_%H%M%S).txt"
FIXED=0; FAILED=0; SKIPPED=0

# Colours
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

divider()  { echo "============================================================" >> "$REPORT"; }
section()  {
    echo -e "\n${CYAN}${BOLD}[*] $1${NC}"
    echo "" >> "$REPORT"; divider
    echo "  $1"   >> "$REPORT"; divider
}
log_ok()   { echo -e "  ${GREEN}[✓]${NC} $1"; echo "  [RECOVERED] $1" >> "$REPORT"; ((FIXED++));   }
log_fail() { echo -e "  ${RED}[✗]${NC} $1"; echo "  [FAILED]    $1" >> "$REPORT"; ((FAILED++));  }
log_skip() { echo -e "  ${YELLOW}[~]${NC} $1"; echo "  [SKIPPED]   $1" >> "$REPORT"; ((SKIPPED++)); }
log_info() { echo -e "  ${BLUE}[i]${NC} $1"; echo "  [INFO]      $1" >> "$REPORT"; }

# ── Dependency check ─────────────────────────────────────────
need() { command -v "$1" &>/dev/null || { echo -e "${YELLOW}[!] '$1' not found — install with: apt install $2${NC}"; }; }

# ── Root check ───────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[!] Run as root:  sudo bash file_recovery.sh [directory]${NC}"
    exit 1
fi

# ── Banner ───────────────────────────────────────────────────
echo -e "${BOLD}${CYAN}"
cat << 'EOF'
  ██████╗ ███████╗ ██████╗ ██████╗ ██╗   ██╗███████╗██████╗ ██╗   ██╗
  ██╔══██╗██╔════╝██╔════╝██╔═══██╗██║   ██║██╔════╝██╔══██╗╚██╗ ██╔╝
  ██████╔╝█████╗  ██║     ██║   ██║██║   ██║█████╗  ██████╔╝ ╚████╔╝
  ██╔══██╗██╔══╝  ██║     ██║   ██║╚██╗ ██╔╝██╔══╝  ██╔══██╗  ╚██╔╝
  ██║  ██║███████╗╚██████╗╚██████╔╝ ╚████╔╝ ███████╗██║  ██║   ██║
  ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝   ╚═══╝  ╚══════╝╚═╝  ╚═╝   ╚═╝
EOF
echo -e "${NC}"
echo -e "${BOLD}       Corrupt File Recovery Tool — $(date)${NC}"
echo -e "${BOLD}       Scan Target : ${TARGET_DIR}${NC}\n"

# ── Setup ────────────────────────────────────────────────────
mkdir -p "$RECOVERY_DIR"
{
    echo "============================================================"
    echo "       FILE RECOVERY REPORT"
    echo "       Generated  : $(date)"
    echo "       Scan Target: $TARGET_DIR"
    echo "       Recovery To: $RECOVERY_DIR"
    echo "============================================================"
} > "$REPORT"

echo -e "${GREEN}[+] Recovery folder  :${NC} $RECOVERY_DIR"
echo -e "${GREEN}[+] Report file      :${NC} $REPORT\n"

# ════════════════════════════════════════════════════════════
#  HELPER: copy a fixed file to recovery/
# ════════════════════════════════════════════════════════════
save_recovered() {
    local src="$1"
    local rel
    rel="$(realpath --relative-to="$TARGET_DIR" "$src" 2>/dev/null || basename "$src")"
    local dest="$RECOVERY_DIR/$rel"
    mkdir -p "$(dirname "$dest")"
    cp -f "$src" "$dest" 2>/dev/null && echo "$dest"
}

# ════════════════════════════════════════════════════════════
#  1. DETECT CORRUPT FILES  (magic-byte vs extension mismatch)
# ════════════════════════════════════════════════════════════
section "SCANNING FOR CORRUPT / MISIDENTIFIED FILES"

declare -A CORRUPT_FILES   # path → detected_type

while IFS= read -r -d '' f; do
    [[ "$f" == "$RECOVERY_DIR"* ]] && continue
    [[ "$f" == "$REPORT"        ]] && continue

    detected=$(file --brief --mime-type "$f" 2>/dev/null)
    ext="${f##*.}"

    echo "  Checking: $f  [$detected]" >> "$REPORT"

    # Flag truncated / empty files
    if [[ ! -s "$f" ]]; then
        log_info "Empty file: $f"
        CORRUPT_FILES["$f"]="empty"
        continue
    fi

    # Flag known corruption signatures
    case "$detected" in
        application/octet-stream)
            CORRUPT_FILES["$f"]="$detected" ;;
        inode/x-empty)
            CORRUPT_FILES["$f"]="empty" ;;
    esac

    # Extension vs MIME mismatch
    case "$ext" in
        jpg|jpeg) [[ "$detected" != image/jpeg  ]] && CORRUPT_FILES["$f"]="$detected" ;;
        png)      [[ "$detected" != image/png   ]] && CORRUPT_FILES["$f"]="$detected" ;;
        gif)      [[ "$detected" != image/gif   ]] && CORRUPT_FILES["$f"]="$detected" ;;
        bmp)      [[ "$detected" != image/bmp   ]] && CORRUPT_FILES["$f"]="$detected" ;;
        webp)     [[ "$detected" != image/webp  ]] && CORRUPT_FILES["$f"]="$detected" ;;
        mp4|m4v)  [[ "$detected" != video/mp4   ]] && CORRUPT_FILES["$f"]="$detected" ;;
        avi)      [[ "$detected" != video/x-msvideo ]] && CORRUPT_FILES["$f"]="$detected" ;;
        mkv)      [[ "$detected" != video/x-matroska ]] && CORRUPT_FILES["$f"]="$detected" ;;
        mp3)      [[ "$detected" != audio/mpeg  ]] && CORRUPT_FILES["$f"]="$detected" ;;
        flac)     [[ "$detected" != audio/flac  ]] && CORRUPT_FILES["$f"]="$detected" ;;
        ogg)      [[ "$detected" != audio/ogg   ]] && CORRUPT_FILES["$f"]="$detected" ;;
        pdf)      [[ "$detected" != application/pdf ]] && CORRUPT_FILES["$f"]="$detected" ;;
        zip)      [[ "$detected" != application/zip ]] && CORRUPT_FILES["$f"]="$detected" ;;
        gz|tgz)   [[ "$detected" != application/gzip ]] && CORRUPT_FILES["$f"]="$detected" ;;
        tar)      [[ "$detected" != application/x-tar ]] && CORRUPT_FILES["$f"]="$detected" ;;
        docx|xlsx|pptx) [[ "$detected" != application/zip ]] && CORRUPT_FILES["$f"]="$detected" ;;
        sqlite|db)[[ "$detected" != application/x-sqlite3 ]] && CORRUPT_FILES["$f"]="$detected" ;;
        sh)       [[ "$detected" != text/x-shellscript && "$detected" != text/plain ]] \
                      && CORRUPT_FILES["$f"]="$detected" ;;
        py)       [[ "$detected" != text/x-python && "$detected" != text/plain ]] \
                      && CORRUPT_FILES["$f"]="$detected" ;;
        xml)      [[ "$detected" != text/xml && "$detected" != application/xml \
                      && "$detected" != text/plain ]] && CORRUPT_FILES["$f"]="$detected" ;;
        json)     [[ "$detected" != application/json && "$detected" != text/plain ]] \
                      && CORRUPT_FILES["$f"]="$detected" ;;
        html|htm) [[ "$detected" != text/html && "$detected" != text/plain ]] \
                      && CORRUPT_FILES["$f"]="$detected" ;;
    esac

done < <(find "$TARGET_DIR" -maxdepth 6 -not -path "$RECOVERY_DIR/*" \
             -not -name "recovery_report_*.txt" -type f -print0 2>/dev/null)

if [[ ${#CORRUPT_FILES[@]} -eq 0 ]]; then
    echo -e "  ${GREEN}No obviously corrupt files detected.${NC}"
    echo "  No obviously corrupt files detected." >> "$REPORT"
else
    echo -e "  ${YELLOW}Found ${#CORRUPT_FILES[@]} suspect file(s).${NC}"
    echo "  Found ${#CORRUPT_FILES[@]} suspect file(s)." >> "$REPORT"
fi


# ════════════════════════════════════════════════════════════
#  2. RECOVERY ROUTINES  (per file type)
# ════════════════════════════════════════════════════════════
section "ATTEMPTING RECOVERY"

attempt_image() {
    local f="$1" ext="$2"
    local tmp; tmp=$(mktemp --suffix=".$ext")
    if command -v convert &>/dev/null; then
        convert "$f" "$tmp" 2>/dev/null && {
            dest=$(save_recovered "$tmp")
            mv "$tmp" "$RECOVERY_DIR/$(basename "$f" | sed "s/\.[^.]*$/.$ext/")"
            log_ok "Image repaired (ImageMagick): $f"
            return 0
        }
    fi
    rm -f "$tmp"
    # Fallback: try ffmpeg for images
    if command -v ffmpeg &>/dev/null; then
        ffmpeg -y -i "$f" "$tmp" 2>/dev/null && {
            mv "$tmp" "$RECOVERY_DIR/$(basename "$f" | sed "s/\.[^.]*$/.$ext/")"
            log_ok "Image repaired (ffmpeg): $f"
            return 0
        }
    fi
    rm -f "$tmp"
    log_fail "Cannot repair image: $f"
}

attempt_video() {
    local f="$1" ext="$2"
    local out="$RECOVERY_DIR/$(basename "$f")"
    if command -v ffmpeg &>/dev/null; then
        ffmpeg -y -err_detect ignore_err -i "$f" -c copy "$out" 2>/dev/null && {
            log_ok "Video repaired (ffmpeg -c copy): $f"
            return 0
        }
        # Re-encode attempt
        ffmpeg -y -err_detect ignore_err -i "$f" \
               -vcodec libx264 -acodec aac "$out" 2>/dev/null && {
            log_ok "Video re-encoded (ffmpeg): $f"
            return 0
        }
    fi
    log_fail "Cannot repair video: $f"
}

attempt_audio() {
    local f="$1" ext="$2"
    local out="$RECOVERY_DIR/$(basename "$f")"
    if command -v ffmpeg &>/dev/null; then
        ffmpeg -y -err_detect ignore_err -i "$f" -c copy "$out" 2>/dev/null && {
            log_ok "Audio repaired (ffmpeg -c copy): $f"
            return 0
        }
        ffmpeg -y -err_detect ignore_err -i "$f" \
               -acodec libmp3lame "$out" 2>/dev/null && {
            log_ok "Audio re-encoded (ffmpeg): $f"
            return 0
        }
    fi
    log_fail "Cannot repair audio: $f"
}

attempt_pdf() {
    local f="$1"
    local out="$RECOVERY_DIR/$(basename "$f")"
    # Try ghostscript first
    if command -v gs &>/dev/null; then
        gs -o "$out" -sDEVICE=pdfwrite -dPDFSETTINGS=/prepress \
           -dNOPAUSE -dBATCH "$f" 2>/dev/null && {
            log_ok "PDF repaired (Ghostscript): $f"
            return 0
        }
    fi
    # Try pdf2ps | ps2pdf round-trip
    if command -v pdf2ps &>/dev/null && command -v ps2pdf &>/dev/null; then
        local tmp_ps; tmp_ps=$(mktemp --suffix=".ps")
        pdf2ps "$f" "$tmp_ps" 2>/dev/null
        ps2pdf "$tmp_ps" "$out"  2>/dev/null && {
            rm -f "$tmp_ps"
            log_ok "PDF repaired (pdf2ps+ps2pdf): $f"
            return 0
        }
        rm -f "$tmp_ps"
    fi
    # Try pdfinfo / mutool clean
    if command -v mutool &>/dev/null; then
        mutool clean "$f" "$out" 2>/dev/null && {
            log_ok "PDF cleaned (mutool): $f"
            return 0
        }
    fi
    log_fail "Cannot repair PDF: $f"
}

attempt_zip() {
    local f="$1"
    local out_dir="$RECOVERY_DIR/$(basename "$f" .zip)_extracted"
    mkdir -p "$out_dir"
    if command -v unzip &>/dev/null; then
        unzip -o "$f" -d "$out_dir" 2>/dev/null && {
            log_ok "ZIP extracted (partial recovery): $f  →  $out_dir"
            return 0
        }
    fi
    if command -v 7z &>/dev/null; then
        7z x "$f" -o"$out_dir" -y 2>/dev/null && {
            log_ok "ZIP extracted via 7z: $f  →  $out_dir"
            return 0
        }
    fi
    log_fail "Cannot repair ZIP: $f"
}

attempt_archive() {
    local f="$1" ext="$2"
    local out_dir="$RECOVERY_DIR/$(basename "$f" ".$ext")_extracted"
    mkdir -p "$out_dir"
    if command -v 7z &>/dev/null; then
        7z x "$f" -o"$out_dir" -y 2>/dev/null && {
            log_ok "Archive extracted (7z): $f  →  $out_dir"
            return 0
        }
    fi
    if command -v tar &>/dev/null; then
        tar --ignore-failed-read -xf "$f" -C "$out_dir" 2>/dev/null && {
            log_ok "Archive extracted (tar): $f  →  $out_dir"
            return 0
        }
    fi
    log_fail "Cannot repair archive: $f"
}

attempt_sqlite() {
    local f="$1"
    local out="$RECOVERY_DIR/$(basename "$f")"
    if command -v sqlite3 &>/dev/null; then
        sqlite3 "$f" ".recover" 2>/dev/null | sqlite3 "$out" 2>/dev/null && {
            log_ok "SQLite recovered (.recover): $f"
            return 0
        }
        # Fallback: dump and reimport
        sqlite3 "$f" ".dump" 2>/dev/null | sqlite3 "$out" 2>/dev/null && {
            log_ok "SQLite recovered (.dump): $f"
            return 0
        }
    fi
    log_fail "Cannot repair SQLite: $f"
}

attempt_text() {
    local f="$1"
    local out="$RECOVERY_DIR/$(basename "$f")"
    # Strip null bytes and non-printable chars, re-encode to UTF-8
    if command -v iconv &>/dev/null; then
        iconv -f utf-8 -t utf-8 -c "$f" 2>/dev/null > "$out" && [[ -s "$out" ]] && {
            log_ok "Text file cleaned (iconv UTF-8): $f"
            return 0
        }
        # Try latin-1 → utf-8
        iconv -f latin-1 -t utf-8 -c "$f" 2>/dev/null > "$out" && [[ -s "$out" ]] && {
            log_ok "Text file re-encoded latin-1→UTF-8: $f"
            return 0
        }
    fi
    # Strip non-printable
    tr -cd '\11\12\15\40-\176' < "$f" > "$out" 2>/dev/null && [[ -s "$out" ]] && {
        log_ok "Text file sanitised (stripped non-printable): $f"
        return 0
    }
    log_fail "Cannot repair text file: $f"
}

attempt_docx_xlsx() {
    local f="$1" ext="$2"
    local out_dir="$RECOVERY_DIR/$(basename "$f" ".$ext")_extracted"
    local out_zip="$RECOVERY_DIR/$(basename "$f")"
    mkdir -p "$out_dir"
    # Office Open XML files are ZIP archives
    if command -v unzip &>/dev/null; then
        unzip -o "$f" -d "$out_dir" 2>/dev/null && {
            # Re-zip into a clean copy
            (cd "$out_dir" && zip -r "$out_zip" . 2>/dev/null) && {
                log_ok "Office file re-packed (unzip+zip): $f"
                return 0
            }
            log_ok "Office file extracted (partial): $f  →  $out_dir"
            return 0
        }
    fi
    if command -v 7z &>/dev/null; then
        7z x "$f" -o"$out_dir" -y 2>/dev/null && {
            log_ok "Office file extracted (7z): $f  →  $out_dir"
            return 0
        }
    fi
    log_fail "Cannot repair Office file: $f"
}

attempt_empty() {
    local f="$1"
    local out="$RECOVERY_DIR/$(basename "$f").recovered"
    # Try photorec / foremost for raw binary carving if available
    if command -v photorec &>/dev/null; then
        log_info "photorec available — manual carve recommended for: $f"
    fi
    if command -v foremost &>/dev/null; then
        foremost -i "$f" -o "$RECOVERY_DIR/foremost_$(basename "$f")" 2>/dev/null && {
            log_ok "File carved with foremost: $f"
            return 0
        }
    fi
    # If nothing works, copy with note
    cp -f "$f" "$out" 2>/dev/null
    log_fail "Empty/unrecoverable — copied as-is: $f"
}

# ── Main dispatch loop ───────────────────────────────────────
for f in "${!CORRUPT_FILES[@]}"; do
    detected="${CORRUPT_FILES[$f]}"
    ext="${f##*.}"; ext="${ext,,}"

    echo "" >> "$REPORT"
    echo "  File     : $f" >> "$REPORT"
    echo "  Detected : $detected" >> "$REPORT"
    echo "  Ext      : $ext"      >> "$REPORT"

    case "$ext" in
        jpg|jpeg|png|gif|bmp|webp|tiff|tif)
            attempt_image "$f" "$ext" ;;
        mp4|m4v|avi|mkv|mov|wmv|flv|webm|mpeg|mpg)
            attempt_video "$f" "$ext" ;;
        mp3|flac|ogg|wav|aac|m4a|wma)
            attempt_audio "$f" "$ext" ;;
        pdf)
            attempt_pdf "$f" ;;
        zip)
            attempt_zip "$f" ;;
        gz|tgz|bz2|xz|tar|rar|7z)
            attempt_archive "$f" "$ext" ;;
        sqlite|db|sqlite3)
            attempt_sqlite "$f" ;;
        docx|pptx)
            attempt_docx_xlsx "$f" "$ext" ;;
        xlsx)
            attempt_docx_xlsx "$f" "$ext" ;;
        txt|csv|log|conf|cfg|ini|sh|py|json|xml|html|htm|md|yaml|yml)
            attempt_text "$f" ;;
        ""|*)
            # Unknown ext — decide by MIME
            case "$detected" in
                image/*)                attempt_image   "$f" "png" ;;
                video/*)                attempt_video   "$f" "mp4" ;;
                audio/*)                attempt_audio   "$f" "mp3" ;;
                application/pdf)        attempt_pdf     "$f" ;;
                application/zip)        attempt_zip     "$f" ;;
                application/x-sqlite3)  attempt_sqlite  "$f" ;;
                text/*)                 attempt_text    "$f" ;;
                empty)                  attempt_empty   "$f" ;;
                *)                      log_skip "No recovery method for: $f [$detected]" ;;
            esac ;;
    esac
done


# ════════════════════════════════════════════════════════════
#  3. FILESYSTEM INTEGRITY CHECK  (bonus)
# ════════════════════════════════════════════════════════════
section "FILESYSTEM INTEGRITY CHECKS"

{
    echo ""
    echo "── Filesystem check status ──"
    for dev in $(lsblk -ln -o NAME,TYPE 2>/dev/null | awk '$2=="part"{print "/dev/"$1}'); do
        echo "  Checking $dev"
        tune2fs -l "$dev" 2>/dev/null | grep -E "Last checked|Mount count|Max mount|Filesystem state" \
            || echo "  (Not ext2/3/4 or insufficient permissions)"
    done

    echo ""
    echo "── SMART quick health (all disks) ──"
    if command -v smartctl &>/dev/null; then
        for disk in $(lsblk -nd -o NAME 2>/dev/null); do
            echo "  /dev/$disk:"
            smartctl -H "/dev/$disk" 2>/dev/null | grep -E "overall|PASSED|FAILED|result"
        done
    else
        echo "  smartmontools not installed (apt install smartmontools)"
    fi

    echo ""
    echo "── Inode usage per mount ──"
    df -i 2>/dev/null

    echo ""
    echo "── Disk usage ──"
    df -hT 2>/dev/null
} >> "$REPORT"


# ════════════════════════════════════════════════════════════
#  4. DEPENDENCY HINTS
# ════════════════════════════════════════════════════════════
section "TOOL AVAILABILITY CHECK"

{
    TOOLS=(
        "ffmpeg:ffmpeg"
        "convert:imagemagick"
        "gs:ghostscript"
        "mutool:mupdf-tools"
        "sqlite3:sqlite3"
        "unzip:unzip"
        "7z:p7zip-full"
        "foremost:foremost"
        "photorec:testdisk"
        "smartctl:smartmontools"
        "iconv:libc-bin"
        "pdf2ps:ghostscript"
    )
    echo ""
    for entry in "${TOOLS[@]}"; do
        cmd="${entry%%:*}"; pkg="${entry##*:}"
        if command -v "$cmd" &>/dev/null; then
            echo "  [OK]      $cmd ($pkg)"
        else
            echo "  [MISSING] $cmd  →  apt install $pkg"
        fi
    done
} >> "$REPORT"


# ════════════════════════════════════════════════════════════
#  SUMMARY & FOOTER
# ════════════════════════════════════════════════════════════
{
    echo ""
    divider
    echo "  RECOVERY SUMMARY"
    divider
    echo "  Target directory : $TARGET_DIR"
    echo "  Recovery folder  : $RECOVERY_DIR"
    echo "  Files recovered  : $FIXED"
    echo "  Files failed     : $FAILED"
    echo "  Files skipped    : $SKIPPED"
    echo ""
    echo "  Completed : $(date)"
    divider
    echo ""
    echo "  TIPS:"
    echo "  • Run: apt install ffmpeg imagemagick ghostscript testdisk"
    echo "    foremost p7zip-full sqlite3 mupdf-tools"
    echo "    for maximum recovery capability."
    echo "  • For deep block-level recovery use: testdisk / photorec"
    echo "  • For forensic carving:              foremost / scalpel"
    echo "  • For ext2/3/4 filesystem repair:    e2fsck -y /dev/<disk>"
    echo ""
} >> "$REPORT"

echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════╗"
echo -e "║  RECOVERY COMPLETE                                   ║"
printf  "║  %-52s║\n" "Recovered : $FIXED  |  Failed : $FAILED  |  Skipped : $SKIPPED"
echo -e "║                                                      ║"
printf  "║  %-52s║\n" "Recovery folder → $RECOVERY_DIR"
printf  "║  %-52s║\n" "Report saved    → $REPORT"
echo -e "╚══════════════════════════════════════════════════════╝${NC}"
