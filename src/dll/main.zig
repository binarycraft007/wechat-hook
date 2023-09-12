const std = @import("std");
const os = std.os;
const mem = std.mem;
const httpz = @import("httpz");
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

    switch (@as(CallReason, @enumFromInt(fdwReason))) {
        .process_attach => {
            log_root.file_logger = FileLogger.init(
                "wechat.log",
            ) orelse return windows.FALSE;

            wechat = WeChat.init(.{
                .gpa = std.heap.c_allocator,
                .dll_name = "WeChatWin.dll",
                .off_sets = .{
                    .account_mgr = 0x8c1230,
                    .send_msg_mgr = 0x8c00e0,
                    .send_text_msg = 0xfcd8d0,
                    .free_chat_msg = 0x8aaa00,
                    .contact_mgr = 0x8ae3d0,
                    .contact_list = 0xeab270,
                },
            });

            thread = std.Thread.spawn(
                .{},
                botMainThread,
                .{std.heap.c_allocator},
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

fn botMainThread(allocator: mem.Allocator) void {
    log.info("bot started in dll main", .{});

    while (!wechat.isLoggedIn()) {
        std.time.sleep(1 * std.time.ns_per_s);
    }

    var user_info = wechat.getUserInfo() catch null;

    if (user_info) |info| {
        log.info("user_id: {s}", .{info.user_id});
        //log.info("nick_name: {s}", .{info.nick_name});
        //log.info("mobile: {s}", .{info.mobile});
    }

    var server = httpz.Server().init(
        allocator,
        .{ .port = 8080, .address = "0.0.0.0" },
    ) catch |err| {
        log.err("init http server {}", .{err});
        return;
    };

    server.errorHandler(errorHandler);

    var router = server.router();
    router.post("/api/sendmsg", sendMsg);
    router.get("/api/healthcheck", healthCheck);
    server.listen() catch |err| {
        log.err("http server listen {}", .{err});
        return;
    };
}

fn sendMsg(req: *httpz.Request, res: *httpz.Response) !void {
    var sendmsg_req_maybe = try req.json(struct {
        TextMsg: []const u8,
        NickName: []const u8,
    });

    var sendmsg_req = sendmsg_req_maybe orelse return error.ParseRequest;

    var name = blk: {
        if (sendmsg_req.NickName.len > 0) break :blk sendmsg_req.NickName;
        return error.EmptyNickName;
    };

    var msg = blk: {
        if (sendmsg_req.TextMsg.len > 0) break :blk sendmsg_req.TextMsg;
        return error.EmptyTextMsg;
    };

    var id = try wechat.getContact(.{ .name = name, .match = .partial });
    defer wechat.gpa.free(id);

    try wechat.sendTextMsg(.{ .to_user = id, .message = msg });
    try res.json(.{ .message = "success" }, .{});
}

fn healthCheck(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    try res.json(.{ .message = "success" }, .{});
}

// note that the error handler return `void` and not `!void`
fn errorHandler(req: *httpz.Request, res: *httpz.Response, err: anyerror) void {
    switch (err) {
        error.EmptyTextMsg, error.EmptyNickName, error.ParseRequest => {
            res.status = 400; // user input parameter releated error
        },
        error.ContactNotFound => {
            res.status = 404; // failed to find contacts in getcontact step
        },
        else => {
            res.status = 500; // internal server error, mem allocation, etc
        },
    }
    res.json(.{ .message = @errorName(err) }, .{}) catch unreachable;
    std.log.warn("request: {s}, Err: {}", .{ req.url.raw, err });
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    @setCold(true);
    std.log.scoped(.panic).err("{s}", .{msg});
    while (true) @breakpoint();
}
