#!/usr/bin/env bash

set -x

workspace=$1
cmake_flags=$2
cflags=$3
set --
export _BPXK_AUTOCVT=ON
export _CEE_RUNOPTS="FILETAG(AUTOCVT,AUTOTAG) POSIX(ON)"
export _TAG_REDIR_ERR=txt
export _TAG_REDIR_IN=txt
export _TAG_REDIR_OUT=txt
export PATH="/data/zopen/usr/local/bin:/data/zopen/usr/bin:/data/zopen/bin:/data/zopen/boot:/bin:/usr/lpp/IBM/cnw/v2r1/openxl/bin"
. /data/zopen/etc/zopen-config
set -euo pipefail
cd "$workspace"

diagnostics()
{
  rc=$?
  set +e
  cd "$workspace"
  echo "== Build diagnostics (exit $rc) =="
  find . -name CMakeCCompiler.cmake -exec cat {} \;
  find . -name CMakeConfigureLog.yaml -exec cat {} \;
  exit "$rc"
}
trap diagnostics EXIT

echo "== Tool versions =="
uname -a
command -v cmake ninja ibm-clang
cmake --version
ibm-clang --version
df -k .

echo "== Autoconf, XLC compiler =="
mkdir source-autoconf
gtar xzf pcre2-build.tar.gz -C source-autoconf
chtag -R -tc ISO8859-1 source-autoconf
cd source-autoconf
MAKE=gmake CC=xlc ./configure --enable-ebcdic --disable-unicode
gmake
if gmake check; then
  rc=0
else
  rc=$?
fi
for log in test-suite.log Run*Test.log pcre2*_test.log; do
  if test -f "$log"; then
    echo "== $log =="
    cat "$log"
  fi
done
test "$rc" -eq 0
cd ..

echo "== Installed CMake baseline, IBM-Clang -m64 =="
mkdir source-cmake
gtar xzf pcre2-build.tar.gz -C source-cmake
chtag -R -tc ISO8859-1 source-cmake
if cmake -G Ninja -S source-cmake -B baseline \
  -DPCRE2_EBCDIC=ON -DPCRE2_SUPPORT_UNICODE=OFF \
  -DCMAKE_C_COMPILER=ibm-clang -DCMAKE_C_FLAGS=-m64 \
  -DCMAKE_COMPILE_WARNING_AS_ERROR=ON -DCMAKE_BUILD_TYPE=Release; then
  echo "Installed CMake baseline configured successfully"
else
  echo "Installed CMake baseline failed (exit $?)"
fi

echo "== Isolated zopen CMake 4.4.5 =="
mkdir tools
cd tools
pax -rzf ../cmake.pax.Z
cd ..
cmake="$workspace/tools/cmake-4.4.5/bin/cmake"
ctest="$workspace/tools/cmake-4.4.5/bin/ctest"
"$cmake" --version
echo "== Unpatched CMake ABI regression =="
probe="$workspace/source-cmake/.github/scripts/zos-native-probe"
if "$cmake" -G Ninja -S "$probe" -B probe-unpatched \
  -DCMAKE_C_COMPILER=ibm-clang -DCMAKE_C_FLAGS=-m64 \
  -DEXPECTED_POINTER_SIZE=8 -DEXPECTED_CHAR_CODE=193; then
  echo "Expected the unpatched CMake ABI probe to fail" >&2
  exit 1
else
  echo "Unpatched CMake ABI probe failed (exit $?)"
fi

echo "== Preserve the requested ABI in CMake's ASCII probe =="
patch -p1 -d "$workspace/tools/cmake-4.4.5/share/cmake-4.4" \
  < source-cmake/.github/scripts/zos-cmake-abi.patch
for bits in 32 64; do
  for mode in ebcdic ascii; do
    if test "$mode" = ebcdic; then
      char_code=193
    else
      char_code=65
    fi
    "$cmake" -G Ninja -S "$probe" -B "probe-$bits-$mode" \
      -DCMAKE_C_COMPILER=ibm-clang \
      -DCMAKE_C_FLAGS="-m$bits -fzos-le-char-mode=$mode" \
      -DEXPECTED_POINTER_SIZE="$((bits / 8))" \
      -DEXPECTED_CHAR_CODE="$char_code"
  done
done

echo "== CMake, IBM-Clang -m64 compiler =="
# These contain the space-separated CI options, not individual arguments.
# shellcheck disable=SC2086
"$cmake" $cmake_flags -G Ninja -S source-cmake -B build \
  -DPCRE2_EBCDIC=ON -DPCRE2_SUPPORT_UNICODE=OFF \
  -DCMAKE_C_COMPILER=ibm-clang -DCMAKE_C_FLAGS="-m64 $cflags" \
  -DCMAKE_COMPILE_WARNING_AS_ERROR=ON -DCMAKE_BUILD_TYPE=Release
"$cmake" --build build
cd build
if "$ctest" -j3 --output-on-failure; then
  rc=0
else
  rc=$?
fi
cat Testing/Temporary/LastTest.log
test "$rc" -eq 0
