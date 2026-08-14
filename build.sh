#!/bin/bash
set -o pipefail

export TZ="Asia/Jakarta"
export LC_ALL=C

# ============================================================
# KERNEL INFO
# ============================================================

KERNNAME="RMX2020-KERNEL"
KERNVER="r1"
BUILDDATE="$(date +%Y%m%d)"

# ============================================================
# WORKSPACE
# ============================================================

SOURCE_ROOT="$(cd "$(dirname "$0")" && pwd)"

KERNEL_DIR="$SOURCE_ROOT"
KERNEL_OUT="$KERNEL_DIR/../kernel_out"
OUT_DIR="$KERNEL_OUT"

# ============================================================
# TOOLCHAINS
# ============================================================

# Realme vendor How-To:
#
#   Clang: clang-r353983c
#   GCC:   aarch64-linux-android-4.9
#

CLANG_DIR="/tc/clang/clang-r353983c"
GCC_DIR="/tc/gcc/google_gcc-4.9"

CLANG="$CLANG_DIR/bin/clang"

GCC64="$GCC_DIR/bin/aarch64-linux-android-"
GCC32="$GCC_DIR/bin/arm-linux-androideabi-"

# ============================================================
# BUILD TOOLS
# ============================================================

# Vendor How-To normally uses:
#
#   prebuilts/build-tools/linux-x86/bin/make
#
# Our environment does not have that make, so use system GNU Make.

if [ -x "/tc/build-tools/linux-x86/bin/make" ]; then
    MAKE="/tc/build-tools/linux-x86/bin/make"
else
    MAKE="$(command -v make)"
fi

# ============================================================
# TARGET
# ============================================================

export DEFCONFIG="oppo6769_defconfig"
export COMPILE_PLATFORM="oppo6769"
export OPPO_COMPILE_PLATFORM="oppo6769"

export KERNEL_ARCH="arm64"
export ARCH="$KERNEL_ARCH"

# ============================================================
# OPPO / REALME PRODUCT
# ============================================================

# IMPORTANT:
#
# The vendor Makefile uses TARGET_PRODUCT to determine the
# platform for oppo_secure_common.
#
# Without this, standalone kernel builds fall through to:
#
#   CONFIG_OPPO_BSP_SECCOM_PLATFORM=0
#
# which causes:
#
#   #include <soc/qcom/smem.h>
#
# MT6768/RMX2020 must use:
#
#   full_oppo6769
#
# which resolves to:
#
#   CONFIG_OPPO_BSP_SECCOM_PLATFORM=6768
#

export TARGET_PRODUCT="full_oppo6769"

# ============================================================
# CROSS COMPILE
# ============================================================

export CROSS_COMPILE="$GCC64"
export CROSS_COMPILE_ARM32="$GCC32"

export CLANG_TRIPLE="aarch64-linux-gnu-"

# ============================================================
# PATH
# ============================================================

export PATH="$CLANG_DIR/bin:$GCC_DIR/bin:/usr/bin:/bin:$PATH"

# ============================================================
# TARGET KERNEL MAKE ENVIRONMENT
# ============================================================

# Vendor How-To:
#
#   LD=ld.lld
#   NM=llvm-nm
#   OBJCOPY=llvm-objcopy
#   CC=<clang>
#

export TARGET_KERNEL_MAKE_ENV="LD=ld.lld NM=llvm-nm OBJCOPY=llvm-objcopy CC=$CLANG"

export TARGET_INCLUDES="${TARGET_KERNEL_MAKE_CFLAGS:-}"
export TARGET_LINCLUDES="${TARGET_KERNEL_MAKE_LDFLAGS:-}"

# ============================================================
# CLEAN
# ============================================================

if [ "$1" = "-c" ]; then

    echo
    echo "=============================================="
    echo " Cleaning kernel output"
    echo "=============================================="
    echo
    echo "Output:"
    echo "  $KERNEL_OUT"
    echo

    rm -rf "$KERNEL_OUT"

    echo "Clean complete."
    echo

    exit 0
fi

# ============================================================
# BANNER
# ============================================================

echo
echo "=============================================="
echo " Realme C3 / OPPO MT6768 Kernel Build"
echo "=============================================="
echo
echo "SOURCE_ROOT:"
echo "  $SOURCE_ROOT"
echo
echo "KERNEL_DIR:"
echo "  $KERNEL_DIR"
echo
echo "KERNEL_OUT:"
echo "  $KERNEL_OUT"
echo
echo "DEFCONFIG:"
echo "  $DEFCONFIG"
echo
echo "TARGET_PRODUCT:"
echo "  $TARGET_PRODUCT"
echo
echo "PLATFORM:"
echo "  $COMPILE_PLATFORM"
echo
echo "ARCH:"
echo "  $ARCH"
echo
echo "MAKE:"
echo "  $MAKE"
echo
echo "CLANG:"
echo "  $CLANG"
echo
echo "GCC64:"
echo "  $CROSS_COMPILE"
echo
echo "GCC32:"
echo "  $CROSS_COMPILE_ARM32"
echo

# ============================================================
# CHECK TOOLS
# ============================================================

echo "Checking toolchain..."
echo

if [ -z "$MAKE" ] || [ ! -x "$MAKE" ]; then
    echo "ERROR: GNU make not found."
    exit 1
fi

if [ ! -x "$CLANG" ]; then

    echo
    echo "ERROR: Clang not found:"
    echo "  $CLANG"
    echo

    echo "Available Clang binaries:"
    find /tc/clang \
        -type f \
        -path '*/bin/clang' \
        2>/dev/null

    echo
    exit 1
fi

if [ ! -x "${CROSS_COMPILE}gcc" ]; then

    echo "ERROR: AArch64 GCC not found:"
    echo "  ${CROSS_COMPILE}gcc"

    exit 1
fi

if [ ! -x "${CROSS_COMPILE_ARM32}gcc" ]; then

    echo "ERROR: ARM32 GCC not found:"
    echo "  ${CROSS_COMPILE_ARM32}gcc"

    exit 1
fi

echo "Make:"
"$MAKE" --version | head -1

echo
echo "Clang:"
"$CLANG" --version | head -1

echo
echo "GCC64:"
"${CROSS_COMPILE}gcc" --version | head -1

echo
echo "GCC32:"
"${CROSS_COMPILE_ARM32}gcc" --version | head -1

echo

# ============================================================
# LLVM TOOLS
# ============================================================

echo "Checking LLVM tools..."

for tool in ld.lld llvm-nm llvm-objcopy
do

    if ! command -v "$tool" >/dev/null 2>&1; then

        echo "ERROR: $tool not found."

        if [ -x "$CLANG_DIR/bin/$tool" ]; then

            echo
            echo "Found it inside Clang directory:"
            echo "  $CLANG_DIR/bin/$tool"
            echo

        fi

        exit 1
    fi

done

echo "LLVM tools: OK"
echo

# ============================================================
# OUTPUT DIRECTORY
# ============================================================

mkdir -p "$OUT_DIR"

# ============================================================
# STEP 1 — DEFCONFIG
# ============================================================

echo
echo "=============================================="
echo " Step 1: Generate defconfig"
echo "=============================================="
echo

cd "$KERNEL_DIR" || exit 1

"$MAKE" \
    O="$OUT_DIR" \
    ARCH="$ARCH" \
    TARGET_PRODUCT="$TARGET_PRODUCT" \
    CROSS_COMPILE="$CROSS_COMPILE" \
    CROSS_COMPILE_ARM32="$CROSS_COMPILE_ARM32" \
    CLANG_TRIPLE="$CLANG_TRIPLE" \
    HOSTLDFLAGS="$TARGET_LINCLUDES" \
    $TARGET_KERNEL_MAKE_ENV \
    "$DEFCONFIG"

DEFCONFIG_STATUS=$?

if [ "$DEFCONFIG_STATUS" -ne 0 ]; then

    echo
    echo "=============================================="
    echo " DEFCONFIG FAILED"
    echo "=============================================="
    echo
    echo "Exit code: $DEFCONFIG_STATUS"

    exit "$DEFCONFIG_STATUS"
fi

echo
echo "Defconfig completed successfully."

# ============================================================
# VERIFY OPPO PLATFORM
# ============================================================

echo
echo "Checking OPPO secure-common platform..."

SEC_PLATFORM="$(
    "$MAKE" \
        -pn \
        O="$OUT_DIR" \
        ARCH="$ARCH" \
        TARGET_PRODUCT="$TARGET_PRODUCT" \
        CROSS_COMPILE="$CROSS_COMPILE" \
        2>/dev/null \
        | grep -m1 'DEFS_PLATFORM'
)"

echo "$SEC_PLATFORM"

if echo "$SEC_PLATFORM" | grep -q 'CONFIG_OPPO_BSP_SECCOM_PLATFORM=6768'; then

    echo
    echo "OPPO secure-common platform: MT6768"
    echo "OK: Qualcomm SMEM path should NOT be selected."

else

    echo
    echo "WARNING: Could not verify:"
    echo "  CONFIG_OPPO_BSP_SECCOM_PLATFORM=6768"
    echo
    echo "Do NOT create a fake soc/qcom/smem.h."
    echo

fi

# ============================================================
# SHOW CONFIG
# ============================================================

if [ -f "$OUT_DIR/.config" ]; then

    echo
    echo "Important configuration:"
    echo

    grep -E \
        '^(CONFIG_CROSS_COMPILE|CONFIG_MACH_MT6768|CONFIG_CC_STACKPROTECTOR|CONFIG_MTK_COMBO|CONFIG_MTK_COMBO_CHIP|CONFIG_MTK_COMBO_WIFI|CONFIG_MTK_COMBO_GPS)' \
        "$OUT_DIR/.config" || true

fi

# ============================================================
# STEP 2 — BUILD KERNEL + DTB
# ============================================================

echo
echo "=============================================="
echo " Step 2: Build kernel + DTB"
echo "=============================================="
echo

cd "$OUT_DIR" || exit 1

JOBS="$(nproc --all)"

echo "Jobs:"
echo "  $JOBS"

echo
echo "TARGET_PRODUCT:"
echo "  $TARGET_PRODUCT"

echo

"$MAKE" \
    -j"$JOBS" \
    ARCH="$ARCH" \
    TARGET_PRODUCT="$TARGET_PRODUCT" \
    CROSS_COMPILE="$CROSS_COMPILE" \
    CROSS_COMPILE_ARM32="$CROSS_COMPILE_ARM32" \
    CLANG_TRIPLE="$CLANG_TRIPLE" \
    HOSTCFLAGS="$TARGET_INCLUDES" \
    HOSTLDFLAGS="$TARGET_LINCLUDES" \
    O="$OUT_DIR" \
    $TARGET_KERNEL_MAKE_ENV

BUILD_STATUS=$?

if [ "$BUILD_STATUS" -ne 0 ]; then

    echo
    echo "=============================================="
    echo " BUILD FAILED"
    echo "=============================================="
    echo
    echo "Exit code: $BUILD_STATUS"

    exit "$BUILD_STATUS"
fi

# ============================================================
# OUTPUT
# ============================================================

echo
echo "=============================================="
echo " Checking build output"
echo "=============================================="
echo

IMAGE="$OUT_DIR/arch/arm64/boot/Image.gz-dtb"

if [ -f "$IMAGE" ]; then

    echo "Kernel image:"
    ls -lh "$IMAGE"

else

    echo "WARNING: Image.gz-dtb was not found."

    echo
    echo "Available kernel images:"

    find "$OUT_DIR/arch/arm64/boot" \
        -maxdepth 1 \
        -type f \
        \( -name "Image*" -o -name "zImage*" \) \
        -ls 2>/dev/null || true

fi

echo
echo "DTB/DTBO files:"

find "$OUT_DIR/arch/arm64/boot" \
    -type f \
    \( -name "*.dtb" -o -name "*.dtbo" \) \
    -print 2>/dev/null || true

# ============================================================
# SUCCESS
# ============================================================

echo
echo "=============================================="
echo " BUILD FINISHED SUCCESSFULLY"
echo "=============================================="
echo

echo "Output:"
echo "  $OUT_DIR"

echo
echo "Image:"
echo "  $IMAGE"

echo
echo "Target:"
echo "  $TARGET_PRODUCT"

echo
echo "Toolchain:"
echo "  Clang r353983c (Clang 9.0.0)"
echo "  GCC 4.9.x"

echo