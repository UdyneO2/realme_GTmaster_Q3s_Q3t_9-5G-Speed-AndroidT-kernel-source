#!/bin/bash
set -e

# ════════════════════════════════════════════════════════════
#  Build Android Kernel - lahaina (SM8350) - versi bash lokal
#  Konversi dari GitHub Actions workflow
# ════════════════════════════════════════════════════════════

# ── Konfigurasi ──
DEFCONFIG="vendor/lahaina_QGKI.config"
KERNEL_ARCH="arm64"
CLANG_VERSION="clang-r383902"
MY_WORKSPACE="/workspaces"

# ── 1. Install dependencies ──
echo "=== [1/7] Install build dependencies ==="
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
    bc bison build-essential cpio flex gcc git kmod \
    libssl-dev libelf-dev python3 rsync unzip wget zip

# ── 2. Setup direktori workspace ──
echo ""
echo "=== [2/7] Setup direktori ==="
mkdir -p "$MY_WORKSPACE/source/prebuilts"
mkdir -p "$MY_WORKSPACE/source/kernel_out"

SOURCE_ROOT="$MY_WORKSPACE/source"
PREBUILTS_PATH="$SOURCE_ROOT/prebuilts"
KERNEL_DIR="$SOURCE_ROOT/msm-5.4"
OUT_DIR="$SOURCE_ROOT/kernel_out"

# Pindahkan/symlink kernel source kamu yang sudah ada ke sini.
# Kalau source kamu sudah ada di folder lain, cukup ganti KERNEL_DIR
# di atas ke path source kamu, atau buat symlink
if [ ! -d "$KERNEL_DIR" ]; then
   echo "cloning"
    git clone https://github.com/realme-kernel-opensource/realme_GTmaster_Q3s_Q3t_9-5G-Speed-AndroidT-kernel-source.git $KERNEL_DIR --depth=1
else
    echo "Dir already"
fi

# ── 3. Clone prebuilt tools ──
echo ""
echo "=== [3/7] Clone prebuilt tools ==="
cd "$PREBUILTS_PATH"

if [ ! -d "build-tools" ]; then
    echo "Cloning build-tools..."
    git clone --depth=1 https://android.googlesource.com/platform/prebuilts/build-tools
else
    echo "Dir already"
fi

if [ ! -d "linux-x86" ] && [ ! -d "clang" ]; then
    echo "Cloning clang host..."
    git clone --depth=1 https://github.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-6573524.git  clang/host/linux-x86/$CLANG_VERSION
else 
     echo "Dir already"
fi

if [ ! -d "gcc" ]; then
    echo "Cloning gcc..."
    git clone --depth=1 https://github.com/xiangfeidexiaohuo/GCC-4.9.git \
        gcc/linux-x86/aarch64/aarch64-linux-android-4.9
fi

echo "Cloning selesai."
df -h

# ── 4. Export environment variables ──
echo ""
echo "=== [4/7] Setup environment variables ==="
MAKE_PATH="$PREBUILTS_PATH/build-tools/linux-x86/bin"
GCC_TOOLCHAIN_PATH="$PREBUILTS_PATH/gcc/linux-x86/aarch64/aarch64-linux-android-4.9"
GCC_BIN_PATH="$GCC_TOOLCHAIN_PATH/bin"
GCC_CROSS_COMPILE="$GCC_BIN_PATH/aarch64-linux-android-"
CLANG_PATH="$PREBUILTS_PATH/clang/host/linux-x86/$CLANG_VERSION/bin"
CLANG_TOOL_PATH="$PREBUILTS_PATH/clang/host/linux-x86/$CLANG_VERSION"

CLANG_TRIPLE="aarch64-linux-gnu-"
ARCH="arm64"
CROSS_COMPILE="aarch64-linux-android-"

export PATH="$GCC_BIN_PATH:$CLANG_PATH:$MAKE_PATH:$PATH"

# ── 5. Verifikasi tools ──
echo ""
echo "=== [5/7] Verifikasi path & tools ==="
echo "--- Environment ---"
echo "SOURCE_ROOT=$SOURCE_ROOT"
echo "PREBUILTS_PATH=$PREBUILTS_PATH"
echo "MAKE_PATH=$MAKE_PATH"
echo "GCC_TOOLCHAIN_PATH=$GCC_TOOLCHAIN_PATH"
echo "CLANG_PATH=$CLANG_PATH"
echo "KERNEL_DIR=$KERNEL_DIR"
echo "OUT_DIR=$OUT_DIR"

echo ""
echo "--- Cek tool ---"
ls -l "$MAKE_PATH/make" || echo "❌ Make not found!"
ls -l "${GCC_CROSS_COMPILE}gcc" || echo "❌ GCC cross-compiler not found!"
ls -l "${GCC_CROSS_COMPILE}ld" || echo "❌ GCC cross-linker not found!"
ls -l "$CLANG_PATH/clang" || echo "❌ Clang compiler not found!"

echo ""
echo "--- Versi tool ---"
make --version || echo "❌ Make check failed!"
"${GCC_CROSS_COMPILE}gcc" --version || echo "❌ GCC check failed!"
clang --version || echo "❌ Clang check failed!"
df -h

# ── 6. Build defconfig ──
echo ""
echo "=== [6/7] Build kernel: make defconfig ==="
cd "$KERNEL_DIR"
make O="$OUT_DIR" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" CLANG_TRIPLE="$CLANG_TRIPLE" \
    CC="clang --gcc-toolchain=$GCC_TOOLCHAIN_PATH" \
    HOSTCC="clang" \
    "$DEFCONFIG"

# ── 7. Build Image & DTBs ──
echo ""
echo "=== [7/7] Build kernel: Image & DTBs ==="
make -j"$(nproc)" O="$OUT_DIR" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" CLANG_TRIPLE="$CLANG_TRIPLE" \
    CC="clang --gcc-toolchain=$GCC_TOOLCHAIN_PATH" \
    HOSTCC="clang"

echo ""
echo "=== ✅ Build selesai ==="
df -h
echo ""
echo "--- Ukuran output ---"
du -sh "$MY_WORKSPACE"/* 2>/dev/null || true
du -sh "$OUT_DIR" 2>/dev/null || true

echo ""
echo "--- Output kernel ---"
find "$OUT_DIR/arch/$ARCH/boot" -iname "Image*" -o -iname "*.dtb" 2>/dev/null

