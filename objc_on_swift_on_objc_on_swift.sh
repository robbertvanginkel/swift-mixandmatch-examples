source common.sh

function create_files() {
    set_up obcj_on_objc_on_swift

cat > "$SRCS/Bar.swift" <<EOF
import Foundation
@objc open class Bar: NSObject {
    public func box() -> Int { return 42; }
}
EOF


    cat > "$SRCS/Foo.h" <<EOF
@import Foundation;
@import Bar;
@interface Foo: NSObject
- (Bar *)bar;
@end
EOF
    cat > "$SRCS/Foo.m" <<EOF
@import Foundation;
#import "Foo.h"

@implementation Foo
- (Bar *)bar {
  return [Bar new];
}
@end
EOF

    cat > "$SRCS/FooBar.swift" <<EOF
import Foo
@objc open class FooBar: Foo {
    public func box() -> Int { return super.bar().box(); }
}
EOF

    cat >"$SRCS/main.m" <<EOF
#import <Foundation/Foundation.h>
@import FooBar;

int main(int argc, char *argv[]) {
  @autoreleasepool {
    printf("%s", [[NSString stringWithFormat:@"%ld", [[FooBar new] box]] UTF8String]);
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
    deps = [':FooBar']
)
swift_library(
    name = 'FooBar',
    srcs = ['FooBar.swift'],
    deps = [':Foo']
)
apple_library(
    name = 'Foo',
    srcs = ['Foo.m'],
    exported_headers = ['Foo.h'],
    modular = True,
    deps = [':Bar']
)
swift_library(
    name = 'Bar',
    srcs = ['Bar.swift'],
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
$@