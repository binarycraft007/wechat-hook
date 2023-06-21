const std = @import("std");
const windows = std.os.windows;

base_addr: usize,
dll_handle: std.DynLib,
sendMsgFn: SendMsgCall,

const WeChat = @This();

pub const String = extern struct {
    text: [*:0]windows.WCHAR,
    size: windows.DWORD,
    capacity: windows.DWORD,
    padding: [8]u8 = [1]u8{0} ** 8,
};

const SendMsgCall = *const fn (
    at_users: [*c]const String,
    num: usize,
    msg: *const String,
    to_user: *const String,
    buffer: [*c]const u8,
) callconv(.C) void;

const InitOptions = struct {
    dll_name: []const u8,
    sendmsg_offset: usize,
};

pub fn init(options: InitOptions) !WeChat {
    var wechat: WeChat = .{
        .base_addr = undefined,
        .sendMsgFn = undefined,
        .dll_handle = try std.DynLib.open(options.dll_name),
    };

    wechat.base_addr = @ptrToInt(wechat.dll_handle.dll);
    wechat.sendMsgFn = @intToPtr(
        SendMsgCall,
        wechat.base_addr + options.sendmsg_offset,
    );

    return wechat;
}

pub fn deinit(self: *WeChat) void {
    self.dll_handle.close();
}
