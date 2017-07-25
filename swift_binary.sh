source common.sh

function create_files() {
    set_up swift_binary

    cat > "$SRCS/main.swift" <<EOF
print("Hey")
EOF
}

function create_buckfiles() {
    touch "$SRCS/.buckconfig"
    cat > "$SRCS/BUCK" <<EOF
swift_binary(
    name = 'foo',
    srcs = ['main.swift']
)
EOF
}

function manual() {
    swiftc -emit-object "$SRCS/main.swift" -o "$OUT/main.o"
    ld -o "$OUT/main" "$OUT/main.o" "${LD_SWIFTFLAGS[@]}"

    # validation
    nm $OUT/main.o | grep " _main"
    "$OUT/main" | grep "Hey"
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
