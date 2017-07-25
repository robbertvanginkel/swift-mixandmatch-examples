source common.sh

function create_files() {
    set_up mixed_library_objcswobjc

    cat > "$SRCS/Bar.h" <<EOF
#import <Foundation/Foundation.h>

@interface Box: NSObject
@property (nonatomic, readonly) NSInteger whatevs;
@end

@interface Bar: NSObject
@property (nonatomic, strong, readonly) NSString *message;
@end
EOF
    cat > "$SRCS/Module.h" <<EOF
#import <Module/Bar.h>
EOF
    cat > "$SRCS/Bar.m" <<EOF
#import "Bar.h"
#import <Module/Module-Swift.h>

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

int main(int argc, char *argv[]) {
  @autoreleasepool {
    printf("%s\n", [[[[Bar alloc] init] message] UTF8String]);
  }
  return 0;
}
EOF
    cat > "$SRCS/Foo.swift" <<EOF
import Foundation
@objc public class Foo: Box {
    public func bar() -> Int { return super.whatevs + 1; }
}
EOF
}

function manual() {
    mkdir -p "$OUT/Module"
    cat > "$OUT/swiftc-output.json" <<EOF
{
    "": {
        "object": "$OUT/Foo.o",
        "swiftmodule": "$OUT/Module.swiftmodule",
        "objc-header": "$OUT/Module/Module-Swift.h"
      }
}
EOF
    cat > "$OUT/Module/unextended-module.modulemap" <<EOF
module Module {
    umbrella header "Module.h"
}
module Module.__Swift {
    exclude header "Module-Swift.h"
}
EOF

    cp $SRCS/*.h "$OUT/Module"
    swiftc -emit-object -wmo \
        -import-underlying-module \
        -module-name Module \
        -emit-objc-header \
        -parse-as-library \
        -output-file-map "$OUT/swiftc-output.json" \
        -Xcc -isystem -Xcc "$OUT/" \
        -Xcc -fmodule-map-file="$OUT/Module/unextended-module.modulemap" \
        "$SRCS/Foo.swift"

    cat > "$OUT/Module/clang-module.modulemap" <<EOF
module Module {
    umbrella header "Module.h"
}
module Module.Swift {
    header "Module-Swift.h"
}
EOF

PWD=$(pwd)
    cat > "$OUT/Module/clang.yaml" <<EOF
{
  'version': 0,
  'case-sensitive': 'false',
  'roots': [
    {
      'type': 'directory',
      'name': "$PWD/$OUT/Module",
      'contents': [
        {
          'type': 'file',
          'name': "Bar.h",
          'external-contents': "$PWD/$SRCS/Bar.h"
        },
        {
          'type': 'file',
          'name': "Module-Swift.h",
          'external-contents': "$PWD/$OUT/Module/Module-Swift.h"
        },
        {
          'type': 'file',
          'name': "Module.h",
          'external-contents': "$PWD/$SRCS/Module.h"
        },
        {
          'type': 'file',
          'name': "module.modulemap",
          'external-contents': "$PWD/$OUT/Module/clang-module.modulemap"
        }
      ]
    }
  ]
}
EOF

    clang "${CLANG_FLAGS[@]}" \
        -fmodules \
        -c -o "$OUT/bar.o" \
        -Xclang \
        -fmodule-implementation-of \
        -Xclang \
        Module \
        -isystem "$OUT" \
        -ivfsoverlay "$OUT/Module/clang.yaml" \
        "$SRCS/bar.m"

    ld "${LD_SWIFTFLAGS[@]}" -o "$OUT/main" "$OUT/Foo.o" "$OUT/Bar.o"

    # validation
    nm $OUT/Bar.o | grep " _main"
    ! nm $OUT/Foo.o | grep " _main"
    "$OUT/main" | grep "2"
}

create_files
manual
