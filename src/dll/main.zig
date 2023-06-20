const std = @import("std");
const os = std.os;
const windows = os.windows;
const log_root = @import("log.zig");
const log = std.log.scoped(.dll_main);
const testing = std.testing;

const CallReason = enum(windows.DWORD) {
    process_detach = 0,
    process_attach = 1,
    thread_attach = 2,
    thread_detach = 3,
};

pub const std_options = struct {
    pub const log_level = .info;
    pub const logFn = log_root.logFn;
};

var thread: std.Thread = undefined;

pub export fn DllMain(
    hinstDLL: windows.HINSTANCE,
    fdwReason: windows.DWORD,
    lpReserved: windows.LPVOID,
) callconv(windows.WINAPI) windows.BOOL {
    _ = hinstDLL;
    _ = lpReserved;

    log_root.FileLogger.init("wechat.log");

    switch (@intToEnum(CallReason, fdwReason)) {
        .process_attach => {
            thread = std.Thread.spawn(
                .{},
                testThreading,
                .{},
            ) catch |err| {
                log.err("{}", .{err});
                return windows.FALSE;
            };
        },
        .process_detach => {
            thread.join(); // release thread
        },
        inline else => |tag| {
            log.info("{s}", .{@tagName(tag)});
        },
    }

    return windows.TRUE;
}

fn testThreading() void {
    defer log_root.file_logger.deinit();
    while (true) {
        log.info("this runs in thread", .{});
        std.time.sleep(1 * std.time.ns_per_s);
    }
}

test "basic add functionality" {}
