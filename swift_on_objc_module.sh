source common.sh

function create_files() {
    set_up swift_on_objc_module

    cat > "$SRCS/Bar.h" <<EOF
#import <Foundation/Foundation.h>

@interface Bar: NSObject
@property (nonatomic, retain, readonly) NSString *message;
@end
EOF
    cat > "$SRCS/Bar.m" <<EOF
#import "Bar.h"

@implementation Bar
- (NSString *)message {
    return @"Hello from ObjC";
}
@end
EOF
      cat > "$SRCS/main.swift" <<EOF
import Bar

let x = Bar()
print(x.message)
EOF
}

function create_buckfiles() {
    touch "$SRCS/.buckconfig"
    cat > "$SRCS/BUCK" <<EOF
apple_binary(
    name = 'main',
    srcs = ['main.swift'],
    deps = [':Bar']
)
apple_library(
    name = 'Bar',
    srcs = ['Bar.m'],
    exported_headers = ['Bar.h'],
)
EOF
}

function manual() {
    cat > "$OUT/module.modulemap" <<EOF
module Bar {
    header "../Bar.h"
}
EOF

    swiftc -emit-object \
        "$SRCS/main.swift" \
        -o "$OUT/main.o" \
        -I "$OUT"

    clang "${CLANG_FLAGS[@]}" \
        -c -o "$OUT/bar.o" \
        "$SRCS/bar.m"

    ld "${LD_SWIFTFLAGS[@]}" \
        -o "$OUT/main" \
        "$OUT/main.o" "$OUT/Bar.o"

    nm $OUT/main.o | grep " _main"
    ! nm $OUT/Foo.o | grep " _main"
    "$OUT/main" | grep "Hello from ObjC"
}

function buck_build() {
  cd "$SRCS"
  buck build //:main#macosx-x86_64
}

create_files
create_buckfiles
# manual
$@