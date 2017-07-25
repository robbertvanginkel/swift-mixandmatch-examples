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

cat > "$SRCS/main.swift" <<EOF
import Lib

print("\(Foo().bar())")
EOF
}

function manual() {
    PWD=$(pwd)
    mkdir -p "$OUT/lib-headers"
    cat > "$OUT/swiftc-overlay.yaml" <<EOF
{
  'version': 0,
  'case-sensitive': 'false',
  'roots': [
    {
      'type': 'directory',
      'name': "$PWD/$OUT/lib-headers/Lib",
      'contents': [
      {
          'type': 'file',
          'name': "Bar.h",
          'external-contents': "$PWD/$SRCS/Lib/Bar.h"
        },
        {
          'type': 'file',
          'name': "Lib.h",
          'external-contents': "$PWD/$SRCS/Lib/Lib.h"
        },
        {
          'type': 'file',
          'name': "module.modulemap",
          'external-contents': "$PWD/$OUT/swiftc-module.modulemap"
        }
      ]
    }
  ]
}
EOF

cat > "$OUT/swiftc-module.modulemap" <<EOF
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
        -Xcc -isystem -Xcc "$OUT/lib-headers/" \
        -Xcc -ivfsoverlay -Xcc "$OUT/swiftc-overlay.yaml" \
        "$SRCS/Lib/Foo.swift"

cat > "$OUT/clang-module.modulemap" <<EOF
module Lib {
    umbrella header "Lib.h"
}
module Lib.Swift {
    header "Lib-Swift.h"
}
EOF

PWD=$(pwd)
    cat > "$OUT/clang-overlay.yaml" <<EOF
{
  'version': 0,
  'case-sensitive': 'false',
  'roots': [
    {
      'type': 'directory',
      'name': "$PWD/$OUT/lib-headers-with-swift/Lib",
      'contents': [
        {
          'type': 'file',
          'name': "Bar.h",
          'external-contents': "$PWD/$SRCS/Lib/Bar.h"
        },
        {
          'type': 'file',
          'name': "Lib-Swift.h",
          'external-contents': "$OUT/generated/Lib-Swift.h"
        },
        {
          'type': 'file',
          'name': "Lib.h",
          'external-contents': "$PWD/$SRCS/Lib/Lib.h"
        },
        {
          'type': 'file',
          'name': "module.modulemap",
          'external-contents': "$PWD/$OUT/clang-module.modulemap"
        }
      ]
    }
  ]
}
EOF

    clang "${CLANG_FLAGS[@]}" \
            -fmodules \
            -c -o "$OUT/bar.o" \
            -fmodule-name Lib \
            -isystem "$OUT/lib-headers-with-swift" \
            -ivfsoverlay "$OUT/clang-overlay.yaml" \
            "$SRCS/Lib/Bar.m"

    mkdir "$OUT/linkergen/"
    libtool \
        -static \
        -o "$OUT/linkergen/libLib.a" "$OUT/Foo.o" "$OUT/Bar.o"

    
PWD=$(pwd)
    cat > "$OUT/final.yaml" <<EOF
{
  'version': 0,
  'case-sensitive': 'false',
  'roots': [
    {
      'type': 'directory',
      'name': "$PWD/$OUT/lib-public/Lib",
      'contents': [
        {
          'type': 'file',
          'name': "Bar.h",
          'external-contents': "$PWD/$SRCS/Lib/Bar.h"
        },
        {
          'type': 'file',
          'name': "Lib-Swift.h",
          'external-contents': "$OUT/generated/Lib-Swift.h"
        },
        {
          'type': 'file',
          'name': "Lib.swiftmodule",
          'external-contents': "$OUT/generated/Lib.swiftmodule"
        },
        {
          'type': 'file',
          'name': "Lib.h",
          'external-contents': "$PWD/$SRCS/Lib/Lib.h"
        },
        {
          'type': 'file',
          'name': "module.modulemap",
          'external-contents': "$PWD/$OUT/clang-module.modulemap"
        }
      ]
    }
  ]
}
EOF

    # needs a -I to a path containing the swiftmodule. That path also needs 
    # to contain the modulemap and headers for the underlying objc module
    # 
    # either make a dir like this and pass it in with -I
    # or
    # pass in the 
    # -Xcc -isystem -Xcc "$OUT/lib-headers-with-swift" \
    # -Xcc -ivfsoverlay -Xcc "$OUT/clang-overlay.yaml" \
    mkdir -p "$OUT/lib-public/Lib"
    cp "$OUT/clang-module.modulemap" "$OUT/lib-public/Lib/module.modulemap"
    cp $SRCS/Lib/*.h "$OUT/lib-public/Lib/"
    cp "$OUT/generated/Lib-Swift.h" "$OUT/lib-public/Lib/"
    cp "$OUT/generated/Lib.swiftmodule" "$OUT/lib-public/"

    swiftc -emit-object \
        -I "$OUT/lib-public" \
        "$SRCS/main.swift" \
        -o "$OUT/main.o"
        


    ld "${LD_SWIFTFLAGS[@]}" \
        -o "$OUT/main" \
        -L "$OUT/linkergen" \
        -lLib \
        "$OUT/main.o"

    "$OUT/main"
}

create_files
manual
