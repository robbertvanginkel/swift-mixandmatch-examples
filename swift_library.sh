source common.sh

function create_files() {
    set_up swift_library
    cat > "$SRCS/foo.swift" <<EOF
import Foundation
struct Foo {}
EOF
}

function create_buckfiles() {
    touch "$SRCS/.buckconfig"
    cat > "$SRCS/BUCK" <<EOF
swift_library(
    name = 'foo',
    srcs = ['foo.swift']
)
EOF
}

function manual() {
    swiftc \
      -emit-object \
      -parse-as-library \
      "$SRCS/foo.swift" \
      -o "$OUT/main.o"

    # validation
    ! nm $OUT/main.o | grep " _main"
}

function buck_static() {
  cd "$SRCS"
  buck build //:foo#static,macosx-x86_64
}

function buck_shared() {
  cd "$SRCS"
  buck build //:foo#shared,macosx-x86_64
}

create_files
create_buckfiles
manual