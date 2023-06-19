const std = @import("std");
const DllInjector = @import("DllInjector.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(
        std.heap.page_allocator,
    );
    defer arena.deinit();

    var injector = DllInjector.init(.{
        .target_name = "WeChat.exe",
        .reg_key = "Software\\Tencent\\WeChat",
        .reg_value = "InstallPath",
        .dll_raw = @embedFile("wechat_hook"),
    });
    defer injector.deinit(arena.allocator());

    try injector.closeProcess(arena.allocator());
    try injector.startProcess(arena.allocator());
}
