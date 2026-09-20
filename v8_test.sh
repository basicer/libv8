#!/bin/sh

set -e

dir="$(cd "$(dirname "$0")" && pwd)"

if [ ! -d "${dir}/v8" ]; then
  echo "v8 not found"
  exit 1
fi

(
  set -x
  cxx="g++"
  set --
  if [ "$(uname -s)" = "Linux" ]; then
    cxx="clang++"
  elif [ "$(uname -s)" = "Darwin" ]; then
    cxx="$(xcrun --sdk macosx --find clang++)"
    sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
    set -- -isysroot "$sdk_path" \
      -stdlib=libc++ \
      -framework CoreFoundation \
      -framework Foundation \
      -framework Security
  fi

  compile_with_libs() {
    libs="$1"
    shift
    "$cxx" -I"${dir}/v8" -I"${dir}/v8/include" \
      "${dir}/v8/samples/hello-world.cc" -o hello_world \
      -L"${dir}/v8/out/release/obj/" $libs \
      -pthread -std=c++20 -ldl "$@"
  }

  link_with_platform() {
    compile_with_libs "-lv8_monolith -lv8_libplatform" "$@"
  }

  if ! link_err="$(link_with_platform 2>&1)"; then
    printf "%s\n" "$link_err" >&2
    if [ "$(uname -s)" = "Linux" ] &&
      printf "%s\n" "$link_err" | grep -q "skipping incompatible" &&
      printf "%s\n" "$link_err" | grep -q "libv8_libplatform.a" &&
      printf "%s\n" "$link_err" | grep -q "cannot find -lv8_libplatform"; then
      compile_with_libs "-lv8_monolith" "$@" || exit 1
    else
      exit 1
    fi
  fi
)

sh -c "./hello_world"
