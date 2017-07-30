source common.sh

function create_files() {
    set_up binobjc_on_mixed_library

    mkdir -p "$SRCS/Lib"
    cat > "$SRCS/Lib/Bar.h" <<EOF
#import <Foundation/Foundation.h>

@interface Box: NSObject
@property (nonatomic, readonly) NSInteger whatevs;
@end

@interface Bar: NSObject
@property (nonatomic, strong, readonly) NSString *message;
@end
EOF
    cat > "$SRCS/Lib/Lib.h" <<EOF
#import <Lib/Bar.h>
EOF
    cat > "$SRCS/Lib/Bar.m" <<EOF
#import "Bar.h"
#import <Lib/Lib-Swift.h>

@implementation Bar
- (NSString *)message {
    return [NSString stringWithFormat:@"%ld", [[Foo new] bar]];
}
@end
@implementation Box
- (NSInteger)whatevs {
    return 1;
}
@end
EOF

cat > "$SRCS/Lib/Foo.swift" <<EOF
import Foundation
@objc public class Foo: Box {
    public func bar() -> Int { return super.whatevs + 1; }
}
EOF

cat > "$SRCS/main.m" <<EOF

#import <Foundation/Foundation.h>
@import Lib;

int main(int argc, char *argv[]) {
  @autoreleasepool {
    printf("%s\n", [[[[Bar alloc] init] message] UTF8String]);
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
    deps = [':Lib']
)
apple_library(
    name = 'Lib',
    srcs = ['Lib/Foo.swift', 'Lib/Bar.m'],
    exported_headers = ['Lib/Lib.h', 'Lib/Bar.h'],
)
EOF
}

function manual() {
    PWD=$(pwd)

    mkdir -p "$OUT/objc-headers/Lib"
    ln -s $(pwd)/$SRCS/Lib/Lib.h "$(pwd)/$OUT/objc-headers/Lib/Lib.h"
    ln -s $(pwd)/$SRCS/Lib/Bar.h "$(pwd)/$OUT/objc-headers/Lib/Bar.h"

cat > "$OUT/objc-headers/Lib/module.modulemap" <<EOF
module Lib {
    umbrella header "Lib.h"
}
EOF

    cat > "$OUT/swiftc-output.json" <<EOF
{
    "": {
        "object": "$OUT/Foo.o",
        "swiftmodule": "$OUT/generated/Lib.swiftmodule",
        "objc-header": "$OUT/generated/Lib-Swift.h"
      }
}
EOF

    mkdir -p "$OUT/generated"
    swiftc -emit-object -wmo \
        -import-underlying-module \
        -module-name Lib \
        -emit-objc-header \
        -parse-as-library \
        -output-file-map "$OUT/swiftc-output.json" \
        -I "$OUT/objc-headers/" \
        "$SRCS/Lib/Foo.swift"

    mkdir -p "$OUT/lib-headers-full/Lib"
    ln -s "$(pwd)/$SRCS/Lib/Lib.h" "$(pwd)/$OUT/lib-headers-full/Lib/Lib.h"
    ln -s "$(pwd)/$SRCS/Lib/Bar.h" "$(pwd)/$OUT/lib-headers-full/Lib/Bar.h"
    ln -s "$(pwd)/$OUT/generated/Lib-Swift.h" "$(pwd)/$OUT/lib-headers-full/Lib/Lib-Swift.h"
    ln -s "$(pwd)/$OUT/generated/Lib.swiftmodule" "$(pwd)/$OUT/lib-headers-full/Lib.swiftmodule"

    cat > "$OUT/lib-headers-full/Lib/module.modulemap" <<EOF
module Lib {
    umbrella header "Lib.h"
}
module Lib.Swift {
    header "Lib-Swift.h"
}
EOF
    clang "${CLANG_FLAGS[@]}" \
            -fmodules \
            -c -o "$OUT/bar.o" \
            -fmodule-name Lib \
            -I "$OUT/lib-headers-full/" \
            "$SRCS/Lib/Bar.m"

    mkdir "$OUT/linkergen/"
    libtool \
        -static \
        -o "$OUT/linkergen/libLib.a" "$OUT/Foo.o" "$OUT/Bar.o"

    clang "${CLANG_FLAGS[@]}" \
        -I "$OUT/lib-headers-full/" \
        -c -o "$OUT/main.o" \
        "$SRCS/main.m"

    ld "${LD_SWIFTFLAGS[@]}" \
        -o "$OUT/main" \
        -L "$OUT/linkergen" \
        -lLib \
        "$OUT/main.o"

    "$OUT/main"
}

function buck_build() {
  cd "$SRCS"
  buck build //:main#macosx-x86_64
}

create_files
create_buckfiles
$@
