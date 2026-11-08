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

echo "== One-time official CMake upgrade =="
if zopen install --install-or-upgrade --no-deps --verbose --release-line STABLE -y cmake > zopen-install.log 2>&1; then
  rc=0
else
  rc=$?
fi
cat zopen-install.log
test "$rc" -eq 0
set +u
. /data/zopen/etc/zopen-config
set -u
hash -r
command -v cmake
cmake --version
cmake -E sha256sum /data/zopen/usr/local/zopen/cmake/cmake/share/cmake-4.4/Modules/CMakeDetermineCompilerABI.cmake

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

mkdir source-cmake
gtar xzf pcre2-build.tar.gz -C source-cmake
chtag -R -tc ISO8859-1 source-cmake

echo "== CMake, IBM-Clang -m64 compiler =="
# These contain the space-separated CI options, not individual arguments.
# shellcheck disable=SC2086
cmake $cmake_flags -G Ninja -S source-cmake -B build \
  -DPCRE2_EBCDIC=ON -DPCRE2_SUPPORT_UNICODE=OFF \
  -DCMAKE_C_COMPILER=ibm-clang -DCMAKE_C_FLAGS="-m64 $cflags" \
  -DCMAKE_COMPILE_WARNING_AS_ERROR=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build
cd build
if ctest -j3 --output-on-failure; then
  rc=0
else
  rc=$?
fi
cat Testing/Temporary/LastTest.log
test "$rc" -eq 0
