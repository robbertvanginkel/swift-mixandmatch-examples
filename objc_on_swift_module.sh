source common.sh

function create_files() {
    set_up obcj_on_swift_module

    cat > "$SRCS/Foo.swift" <<EOF
import Foundation
@objc public class Foo: NSObject {
    public func bar() -> Int { return 42; }
}
EOF

    cat >"$SRCS/main.m" <<EOF
#import <Foundation/Foundation.h>
@import Foo;

int main(int argc, char *argv[]) {
  @autoreleasepool {
    printf("%s", [[NSString stringWithFormat:@"%ld", [[[Foo alloc] init] bar]] UTF8String]);
  }
  return 0;
}
EOF
}

function create_buckfiles() {
    touch "$SRCS/.buckconfig"
    cat > "$SRCS/BUCK" <<EOF
apple_binary(
    name = 'main',
    srcs = ['main.m'],
    deps = [':Foo']
)
apple_library(
    name = 'Foo',
    srcs = ['Foo.swift'],
)
EOF
}

function manual() {
  cat > "$OUT/swiftc-output.json" <<EOF
      {
      "": {
          "object": "$OUT/Foo.o",
          "swiftmodule": "$OUT/Foo.swiftmodule",
          "objc-header": "$OUT/Foo-Swift.h"
        }
      }
EOF
    swiftc -emit-object -wmo \
        -parse-as-library "$SRCS/Foo.swift" \
        -output-file-map "$OUT/swiftc-output.json" \
        -emit-module -module-name Foo \
        -emit-objc-header


    cat > "$OUT/module.modulemap" <<EOF
module Foo {}
module Foo.Swift {
  header "Foo-Swift.h"
}
EOF
    clang "${CLANG_FLAGS[@]}" \
        -c -o "$OUT/main.o" \
        -I "$OUT/" \
        "$SRCS/main.m"

    ld "${LD_SWIFTFLAGS[@]}" \
        -o "$OUT/main" \
        "$OUT/main.o" "$OUT/Foo.o"

    # validation
    nm $OUT/main.o | grep " _main"
    ! nm $OUT/Foo.o | grep " _main"
    "$OUT/main" | grep "42"
}

function buck_build() {
  cd "$SRCS"
  buck build //:main#macosx-x86_64 --config cxx.cflags=-fmodules
}


create_files
create_buckfiles
# manual
buck_build