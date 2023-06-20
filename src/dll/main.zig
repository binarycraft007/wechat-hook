const std = @import("std");
const os = std.os;
const windows = os.windows;
const log_root = @import("log.zig");
const FileLogger = log_root.FileLogger;
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

    switch (@intToEnum(CallReason, fdwReason)) {
        .process_attach => {
            log_root.file_logger = FileLogger.init(
                "wechat.log",
            ) orelse return windows.FALSE;

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
            log_root.file_logger.deinit();
            thread.join(); // release thread
        },
        else => {},
    }

    return windows.TRUE;
}

fn testThreading() void {
    while (true) {
        log.info("this runs in thread", .{});
        std.time.sleep(1 * std.time.ns_per_s);
    }
}

test "basic add functionality" {}
