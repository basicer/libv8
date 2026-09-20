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

  link_log="$(mktemp "${TMPDIR:-/tmp}/v8-link-platform.XXXXXX")"

  if ! link_with_platform 2>"$link_log"; then
    cat "$link_log" >&2
    if [ "$(uname -s)" = "Linux" ] &&
      grep -q "skipping incompatible" "$link_log" &&
      grep -q "libv8_libplatform.a" "$link_log" &&
      grep -q "cannot find -lv8_libplatform" "$link_log"; then
      compile_with_libs "-lv8_monolith" "$@" || {
        rm -f "$link_log"
        exit 1
      }
    else
      rm -f "$link_log"
      exit 1
    fi
  fi

  rm -f "$link_log"
)

sh -c "./hello_world"
