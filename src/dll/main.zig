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

    switch (@enumFromInt(CallReason, fdwReason)) {
        .process_attach => {
            log_root.file_logger = FileLogger.init(
                "wechat.log",
            ) orelse return windows.FALSE;

            wechat = WeChat.init(.{
                .gpa = std.heap.c_allocator,
                .dll_name = "WeChatWin.dll",
                .off_sets = .{
                    .send_msg = 0x521D30,
                    .nick_name = 0x23660F4,
                    .user_id = 0x236607C,
                    .mobile = 0x2366128,
                    .logged_in = 0x2366538,
                    .contact_base = 0x23668F4,
                    .contact_head = 0x4C,
                    .contact_id = 0x30,
                    .contact_code = 0x44,
                    .contact_remark = 0x78,
                    .contact_name = 0x8C,
                    .contact_gender = 0x184,
                    .contact_country = 0x1D0,
                    .contact_province = 0x1E4,
                    .contact_city = 0x1F8,
                },
            });

            thread = std.Thread.spawn(
                .{},
                botMainThread,
                .{},
            ) catch |err| {
                log.err("spawn wechat bot {}", .{err});
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

fn botMainThread() void {
    log.info("thread started in dll main", .{});

    while (!wechat.isLoggedIn()) {
        std.time.sleep(1 * std.time.ns_per_s);
    }

    var user_info = wechat.getUserInfo() catch null;

    if (user_info) |info| {
        log.info("user_id: {s}", .{info.user_id});
        log.info("nick_name: {s}", .{info.nick_name});
        log.info("mobile: {s}", .{info.mobile});
    }

    while (true) {
        std.time.sleep(3 * std.time.ns_per_s);
        var id = wechat.getContactByName("Emma") catch
            continue;
        defer wechat.gpa.free(id);

        wechat.sendTextMsg(.{
            .at_users = &[_][]const u8{""},
            .to_user = id,
            .message = "hello from wechat bot",
        }) catch |err| {
            log.err("send msg: {}", .{err});
            continue;
        };
    }
}
