const std = @import("std");
const os = std.os;
const windows = os.windows;
const log_root = @import("log.zig");
const WeChat = @import("WeChat.zig");
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
var wechat: WeChat = undefined;

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

            wechat = WeChat.init(.{
                .gpa = std.heap.c_allocator,
                .sendmsg_offset = 0x521D30,
            }) catch |err| {
                log.err("init wechat {}", .{err});
                return windows.FALSE;
            };

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
            wechat.deinit();
            thread.join(); // release thread
            log_root.file_logger.deinit();
        },
        else => {},
    }

    return windows.TRUE;
}

fn testThreading() void {
    log.info("thread started in dll main", .{});
    while (true) {
        std.time.sleep(120 * std.time.ns_per_s);
        log.info("send msg start", .{});
        wechat.sendTextMsg(.{
            .at_users = &[_][]const u8{""},
            .to_user = "filehelper",
            .message = "hello from wechat bot",
        }) catch |err| {
            log.err("send msg: {}", .{err});
            continue;
        };
        log.info("send msg end", .{});
    }
}

test "basic add functionality" {}
