#!/usr/bin/env bash
# BalOS ISO Builder — runs on macOS/Linux via Docker
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/output"
IMAGE_NAME="balos-builder"

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'; M='\033[0;35m'
B='\033[1m'; D='\033[2m'; N='\033[0m'

banner() {
cat << 'EOF'
[0;32m
  ██████╗  █████╗ ██╗      ██████╗ ███████╗
  ██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝
  ██████╔╝███████║██║     ██║   ██║███████╗
  ██╔══██╗██╔══██║██║     ██║   ██║╚════██║
  ██████╔╝██║  ██║███████╗╚██████╔╝███████║
  ╚═════╝ ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚══════╝
[0m     [ hack · play · evade · endure ]
EOF
}

step()  { echo -e "${G}[$(date +%H:%M:%S)]${N} ${B}$*${N}"; }
warn()  { echo -e "${Y}[WARN]${N} $*"; }
die()   { echo -e "${R}[ERROR]${N} $*" >&2; exit 1; }
info()  { echo -e "${C}[info]${N} ${D}$*${N}"; }

banner

# ── Prerequisites ─────────────────────────────────────────────────
command -v docker &>/dev/null || die "Docker required. Install Docker Desktop."
docker info &>/dev/null       || die "Docker daemon not running — start Docker Desktop."

mkdir -p "${OUTPUT_DIR}"

# ── Flags ─────────────────────────────────────────────────────────
CLEAN=false; NO_CACHE=false; KERNEL=false
for arg in "$@"; do
    case "$arg" in
        --clean)         CLEAN=true ;;
        --no-cache)      NO_CACHE=true ;;
        --with-kernel)   KERNEL=true ;;
        --help|-h)
            cat << 'HLP'
BalOS Builder — usage:
  ./build.sh                  Normal build
  ./build.sh --clean          Wipe previous artifacts first
  ./build.sh --no-cache       Rebuild Docker layers from scratch
  ./build.sh --with-kernel    Also compile custom BalKernel (+45 min)

After build, flash the ISO to USB:
  sudo dd if=output/balos-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
  (macOS: use balenaEtcher — safer than dd)
HLP
            exit 0 ;;
    esac
done

if $CLEAN; then
    step "Cleaning previous build..."
    rm -f "${OUTPUT_DIR}"/*.iso
    docker rmi "${IMAGE_NAME}" 2>/dev/null || true
fi

# ── Build image ──────────────────────────────────────────────────
BOPTS=""
$NO_CACHE && BOPTS="--no-cache"
$KERNEL && BOPTS="$BOPTS --build-arg BUILD_KERNEL=1"

# BalOS is x86_64 only; on ARM hosts (Apple Silicon) force amd64 emulation.
HOST_ARCH="$(uname -m)"
PLATFORM_FLAG=""
if [[ "${HOST_ARCH}" != "x86_64" && "${HOST_ARCH}" != "amd64" ]]; then
    PLATFORM_FLAG="--platform linux/amd64"
    warn "Host is ${HOST_ARCH} — forcing linux/amd64 via emulation (build 2-3x slower)."
fi

step "Building Docker environment (first run ~15 min — AUR packages compile)..."
# shellcheck disable=SC2086
docker build ${PLATFORM_FLAG} $BOPTS -t "${IMAGE_NAME}" "${SCRIPT_DIR}"

# ── Build ISO ────────────────────────────────────────────────────
step "Forging BalOS ISO (20-40 min on native x86_64, up to 2h on emulated ARM)..."
info "You can tail progress in another terminal with: docker logs -f \$(docker ps -q)"

# shellcheck disable=SC2086
docker run --rm --privileged ${PLATFORM_FLAG} \
    -v "${OUTPUT_DIR}:/output" \
    "${IMAGE_NAME}"

# ── Verify result ────────────────────────────────────────────────
ISO_FILE=$(find "${OUTPUT_DIR}" -name "balos-*.iso" -newer "${SCRIPT_DIR}/profiledef.sh" 2>/dev/null | head -1)
[[ -z "${ISO_FILE}" ]] && die "Build failed — no ISO produced."

ISO_SIZE=$(du -sh "${ISO_FILE}" | cut -f1)
ISO_SHA=$(shasum -a 256 "${ISO_FILE}" | cut -c1-16)

cat << EOF

${G}${B}╔════════════════════════════════════════════╗${N}
${G}${B}║          BALOS FORGED SUCCESSFULLY         ║${N}
${G}${B}╚════════════════════════════════════════════╝${N}

  ${B}ISO:${N}   ${C}${ISO_FILE}${N}
  ${B}Size:${N}  ${C}${ISO_SIZE}${N}
  ${B}SHA:${N}   ${C}${ISO_SHA}...${N}

  ${B}Next steps — flash to USB:${N}

    ${M}macOS:${N}    balenaEtcher → select ISO → select USB
                (or) sudo dd if=${ISO_FILE} of=/dev/diskN bs=4m

    ${M}Linux:${N}    sudo dd if=${ISO_FILE} of=/dev/sdX bs=4M status=progress oflag=sync

    ${M}Windows:${N}  Rufus — DD mode — select ISO

  ${B}Then boot the laptop from the USB${N} (F12/F2/Esc during boot)
  and choose ${C}"BalOS Live"${N} from the menu.

EOF
