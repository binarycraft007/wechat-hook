const std = @import("std");
const mem = std.mem;
const meta = std.meta;
const windows = std.os.windows;
const log = std.log.scoped(.wechat);

gpa: mem.Allocator,
dll_name: []const u8,
off_sets: OffSets,

const WeChat = @This();
const OffSets = struct {
    send_msg: usize,
    nick_name: usize,
    logged_in: usize,
};

pub const String = extern struct {
    text: [*:0]windows.WCHAR,
    size: windows.DWORD,
    capacity: windows.DWORD,
    padding: [8]u8 = [1]u8{0} ** 8,

    pub fn init(gpa: mem.Allocator, str: []const u8) !String {
        return .{
            .text = try std.unicode.utf8ToUtf16LeWithNull(gpa, str),
            .size = str.len,
            .capacity = str.len,
        };
    }

    pub fn deinit(self: *String, gpa: mem.Allocator) void {
        gpa.free(mem.span(self.text));
    }
};

const PointerUnion = union(enum) {
    send_msg: *const fn (
        buffer: [*c]const u8,
        to_user: [*c]const String,
        msg: [*c]const String,
        at_users: [*c]const String,
        num: usize,
    ) callconv(.C) void,
    nick_name: [*:0]const u8,
    logged_in: *bool,
};

const InitOptions = struct {
    gpa: mem.Allocator,
    dll_name: []const u8,
    off_sets: OffSets,
};

pub fn init(options: InitOptions) WeChat {
    return .{
        .dll_name = options.dll_name,
        .gpa = options.gpa,
        .off_sets = options.off_sets,
    };
}

const SendMsgOptions = struct {
    at_users: []const []const u8,
    to_user: []const u8,
    message: []const u8,
};

pub fn isLoggedIn(self: *WeChat) bool {
    var ptr = self.getPtrByTag(.{ .logged_in = undefined }) catch
        return false;
    return ptr.*;
}

pub fn sendTextMsg(self: *WeChat, options: SendMsgOptions) !void {
    var buf: [0x3B0:0]u8 = [1:0]u8{0} ** 0x3B0;

    var func_ptr = try self.getPtrByTag(.{ .send_msg = undefined });
    log.info("function ptr: {p}", .{func_ptr});

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

    func_ptr(&buf, &to_user, &message, at_users.ptr, 0x01);
}

fn getPtrByTag(self: *WeChat, comptime ptr: PointerUnion) !ActiveType(ptr) {
    var dll_name = try std.unicode.utf8ToUtf16LeWithNull(
        self.gpa,
        self.dll_name,
    );
    defer self.gpa.free(dll_name);

    var dll_handle = blk: {
        if (windows.kernel32.GetModuleHandleW(dll_name)) |handle| {
            break :blk handle;
        }
        return error.GetWeChatWinHandle;
    };

    switch (ptr) {
        inline else => |p, tag| {
            const offset = @field(self.off_sets, @tagName(tag));
            return @intToPtr(@TypeOf(p), @ptrToInt(dll_handle) + offset);
        },
    }
}

fn ActiveType(comptime u: anytype) type {
    return meta.TagPayload(@TypeOf(u), meta.activeTag(u));
}

pub fn deinit(self: *WeChat) void {
    self.* = undefined;
}
