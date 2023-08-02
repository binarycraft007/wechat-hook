#!/bin/sh
zig_pkg=zig-linux-x86_64-$zig_version.tar.xz
if [ -z "$command" ]; then
	command="zig build test --summary all"
fi

wget https://ziglang.org/builds/$zig_pkg \
	> /dev/null 2>&1
mkdir -p $PWD/zig
tar --strip-components=1 -xf $zig_pkg \
	-C $PWD/zig 
export PATH=$PATH:$PWD/zig

eval "$command"
