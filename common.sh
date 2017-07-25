set -e

CLANG_FLAGS=(
    -arch x86_64
    -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.12.sdk
    -fmodules
)

LD_SWIFTFLAGS=(
    -lswiftFoundation # 0.o this swiftFoundation
    -force_load /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/arc/libarclite_macosx.a
    -rpath /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx
    -macosx_version_min 10.12.0
    -L/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx
    -framework CoreFoundation
    -syslibroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.12.sdk
    -lobjc
    -lSystem
    -arch x86_64
)

function set_up() {
    rm -rf "gen/$1"
    mkdir -p "gen/$1"
    mkdir -p "gen/$1/out"
    SRCS="gen/$1"
    OUT="gen/$1/out"
}
