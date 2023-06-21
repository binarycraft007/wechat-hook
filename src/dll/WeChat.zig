const std = @import("std");
const mem = std.mem;
const windows = std.os.windows;

gpa: mem.Allocator,
base_addr: usize,
dll_handle: windows.HMODULE,
sendMsgFn: SendMsgCall,

const WeChat = @This();

pub const String = extern struct {
    text: [*:0]windows.WCHAR,
    size: windows.DWORD,
    capacity: windows.DWORD,
    padding: [8]u8 = [1]u8{0} ** 8,

    pub fn init(gpa: mem.Allocator, str: []const u8) !String {
        return .{
            .text = try std.unicode.utf8ToUtf16LeWithNull(gpa, str),
            .size = str.len + 1,
            .capacity = (str.len + 1) * 2,
        };
    }

    pub fn deinit(self: *String, gpa: mem.Allocator) void {
        gpa.free(mem.span(self.text));
    }
};

const SendMsgCall = *const fn (
    at_users: [*c]const String,
    num: usize,
    msg: [*c]const String,
    to_user: [*c]const String,
    buffer: [*c]const u8,
) callconv(.C) void;

const InitOptions = struct {
    gpa: mem.Allocator,
    dll_name: []const u8,
    sendmsg_offset: usize,
};

pub fn init(options: InitOptions) !WeChat {
    var dll_name = try std.unicode.utf8ToUtf16LeWithNull(
        options.gpa,
        options.dll_name,
    );
    defer options.gpa.free(dll_name);

    var wechat: WeChat = .{
        .base_addr = undefined,
        .sendMsgFn = undefined,
        .gpa = options.gpa,
        .dll_handle = blk: {
            if (windows.kernel32.GetModuleHandleW(dll_name)) |handle| {
                break :blk handle;
            }
            return error.GetWeChatWinHandle;
        },
    };

    wechat.base_addr = @ptrToInt(wechat.dll_handle);
    wechat.sendMsgFn = @intToPtr(
        SendMsgCall,
        wechat.base_addr + options.sendmsg_offset,
    );

    return wechat;
}

const SendMsgOptions = struct {
    at_users: []const []const u8,
    to_user: []const u8,
    message: []const u8,
};

pub fn sendTextMsg(self: *WeChat, options: SendMsgOptions) !void {
    var buf: [0x3B0:0]u8 = [1:0]u8{0} ** 0x3B0;

    var at_users = blk: {
        var list = std.ArrayList(String).init(self.gpa);
        for (options.at_users) |user| {
            var str = try String.init(self.gpa, user);
            defer str.deinit(self.gpa);
            try list.append(str);
        }
        break :blk try list.toOwnedSlice();
    };
    defer self.gpa.free(at_users);

    var to_user = try String.init(self.gpa, options.to_user);
    defer to_user.deinit(self.gpa);

    var message = try String.init(self.gpa, options.message);
    defer message.deinit(self.gpa);

    self.sendMsgFn(at_users.ptr, 0x1, &message, &to_user, &buf);
}

pub fn deinit(self: *WeChat) void {
    _ = self;
}
