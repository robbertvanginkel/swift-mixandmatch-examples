source common.sh

function create_files() {
    set_up mixed_binary_objcsw

    cat > "$SRCS/Bar.h" <<EOF
#import <Foundation/Foundation.h>

@interface Bar: NSObject
@property (nonatomic, strong, readonly) NSString *message;
@end
EOF
    cat > "$SRCS/Bar.m" <<EOF
#import "Bar.h"
#import "Module-Swift.h"

@implementation Bar
- (NSString *)message {
    return [NSString stringWithFormat:@"%ld", [[Foo new] bar]];
}
@end

int main(int argc, char *argv[]) {
  @autoreleasepool {
    printf("%s\n", [[[[Bar alloc] init] message] UTF8String]);
  }
  return 0;
}
EOF
    cat > "$SRCS/Foo.swift" <<EOF
import Foundation
@objc public class Foo: NSObject {
    public func bar() -> Int { return 42; }
}
EOF
}

function manual() {
    cat > "$OUT/swiftc-output.json" <<EOF
{
    "": {
        "object": "$OUT/Foo.o",
        "objc-header": "$OUT/Module-Swift.h"
      }
}
EOF
    
    swiftc -emit-object -wmo \
        -import-objc-header "$SRCS/Bar.h" \
        -module-name Module \
        -emit-objc-header \
        -parse-as-library \
        -output-file-map "$OUT/swiftc-output.json" \
        "$SRCS/Foo.swift"
        
    clang "${CLANG_FLAGS[@]}" \
        -fmodules \
        -c -o "$OUT/bar.o" \
        -iquote "$OUT" \
        "$SRCS/bar.m"

    ld "${LD_SWIFTFLAGS[@]}" \
        -o "$OUT/main" \
        "$OUT/Foo.o" "$OUT/Bar.o"

    # validation
    ! grep '#import "gen/mixed_binary_swobjc/Bar.h"' "$OUT/Module-Swift.h"
    nm $OUT/Bar.o | grep " _main"
    ! nm $OUT/Foo.o | grep " _main"
    "$OUT/main" | grep "42"
}

create_files
manual
