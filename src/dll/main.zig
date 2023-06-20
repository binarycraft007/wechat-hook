const std = @import("std");
const os = std.os;
const windows = os.windows;
const log_root = @import("log.zig");
const testing = std.testing;

const CallReason = enum(windows.DWORD) {
    process_attach = 0,
    process_detach = 1,
    thread_attach = 2,
    thread_detach = 3,
};

pub const std_options = struct {
    pub const log_level = .info;
    pub const logFn = log_root.logFn;
};

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
            const attach_log = std.log.scoped(.attach);
            attach_log.info("process attached", .{});
        },
        else => {},
    }

    return windows.TRUE;
}

test "basic add functionality" {}
