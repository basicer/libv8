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
    "$cxx" -I"${dir}/v8" -I"${dir}/v8/include" \
      "${dir}/v8/samples/hello-world.cc" -o hello_world \
      -L"${dir}/v8/out/release/obj/" "$@"
  }

  link_with_platform() {
    compile_with_libs -lv8_monolith -lv8_libplatform \
      -pthread -std=c++20 -ldl "$@"
  }

  if ! link_err="$(link_with_platform 2>&1)"; then
    if [ "$(uname -s)" = "Linux" ] &&
      printf "%s\n" "$link_err" | grep -q "skipping incompatible" &&
      printf "%s\n" "$link_err" | grep -q "libv8_libplatform.a" &&
      printf "%s\n" "$link_err" | grep -q "cannot find -lv8_libplatform"; then
      echo "Retrying link without -lv8_libplatform due to incompatible archive format." >&2
      compile_with_libs -lv8_monolith \
        -pthread -std=c++20 -ldl "$@" || exit 1
    else
      printf "%s\n" "$link_err" >&2
      exit 1
    fi
  fi
)

sh -c "./hello_world"
