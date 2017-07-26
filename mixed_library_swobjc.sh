source common.sh
set -x
function create_files() {
    set_up mixed_library_swobjc

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
class Thing {
    let x = Bar()    
}
EOF
}

function create_buckfiles() {
    touch "$SRCS/.buckconfig"
    cat > "$SRCS/BUCK" <<EOF
apple_library(
    name = 'Bar',
    srcs = ['main.swift', 'Bar.m'],
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
        -I "$OUT" \
        -parse-as-library \
        -module-name Bar \
        -import-underlying-module
        
    clang "${CLANG_FLAGS[@]}" \
        -c -o "$OUT/bar.o" \
        "$SRCS/bar.m"

    libtool -static \
        -o "$OUT/libLib.a" \
        "$OUT/main.o" "$OUT/Bar.o"
    
    ! nm $OUT/main.o | grep " _main"
    ! nm $OUT/Bar.o | grep " _main"
}

function buck_build_static() {
  cd "$SRCS"
  buck build //:Bar#static,macosx-x86_64
}

function buck_build_shared() {
  cd "$SRCS"
  buck build //:Bar#shared,macosx-x86_64
}

create_files
create_buckfiles
# manual
buck_build_shared