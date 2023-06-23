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
    logged_in: usize,
    user_id: usize,
    nick_name: usize,
    mobile: usize,
    contact_base: usize,
    contact_head: usize,
    contact_id: usize,
    contact_code: usize,
    contact_remark: usize,
    contact_name: usize,
    contact_country: usize,
    contact_province: usize,
    contact_city: usize,
    contact_gender: usize,
};

pub const Contact = struct {
    id: [*:0]const u16,
    code: [*:0]const u16,
    remark: [*:0]const u16,
    name: [*:0]const u16,
    country: [*:0]const u16,
    province: [*:0]const u16,
    city: [*:0]const u16,
    gender: *usize,
};

pub const UserInfo = struct {
    user_id: [*:0]const u8,
    nick_name: [*:0]const u8,
    mobile: [*:0]const u8,
};

const SendTextMessageOptions = extern struct {
    id: [*c]const windows.WCHAR,
    msg: [*c]const windows.WCHAR,
    addr: windows.DWORD,
};

extern fn sendTextMessage(options: SendTextMessageOptions) void;

pub const String = extern struct {
    text: [*c]const windows.WCHAR,
    size: windows.DWORD,
    capacity: windows.DWORD,
    padding: [8]u8 = [1]u8{0} ** 8,

    pub fn init(gpa: mem.Allocator, str: []const u8) !String {
        return .{
            .text = try std.unicode.utf8ToUtf16LeWithNull(gpa, str),
            .size = str.len,
            .capacity = str.len * 2,
        };
    }

    pub fn deinit(self: *String, gpa: mem.Allocator) void {
        if (self.text) |text| gpa.free(mem.span(text));
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
    logged_in: *bool,
    user_id: *usize,
    nick_name: [*:0]const u8,
    mobile: [*:0]const u8,
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

pub fn getUserInfo(self: *WeChat) !UserInfo {
    var ptr = try self.getPtrByTag(.{ .user_id = undefined });
    return .{
        .user_id = @ptrFromInt([*:0]const u8, ptr.*),
        .nick_name = try self.getPtrByTag(.{ .nick_name = undefined }),
        .mobile = try self.getPtrByTag(.{ .mobile = undefined }),
    };
}

const GetContactOptions = struct {
    name: []const u8,
    match: enum {
        exact,
        partial,
    },
};

pub fn getContact(self: *WeChat, options: GetContactOptions) ![]const u8 {
    var base_ptr = try self.getAddrByTag(.{ .contact_base = .active });
    var base = @ptrFromInt(*usize, base_ptr).*;
    var head = @ptrFromInt(*usize, base + self.off_sets.contact_head).*;
    var index = @ptrFromInt(*usize, head).*;

    while (index != head) {
        defer index = @ptrFromInt(*usize, index).*;

        var contact: Contact = undefined;
        inline for (@typeInfo(@TypeOf(contact)).Struct.fields) |field| {
            const FieldType = @TypeOf(@field(contact, field.name));
            var ptr = @ptrFromInt(
                *usize,
                index + @field(self.off_sets, "contact_" ++ field.name),
            );
            @field(contact, field.name) = @ptrFromInt(FieldType, ptr.*);
        }

        var contact_name = blk: {
            const n = mem.span(contact.name);
            break :blk try std.unicode.utf16leToUtf8Alloc(self.gpa, n);
        };
        defer self.gpa.free(contact_name);

        switch (options.match) {
            .exact => if (mem.eql(u8, contact_name, options.name)) {
                const id = mem.span(contact.id);
                return try std.unicode.utf16leToUtf8Alloc(self.gpa, id);
            },
            .partial => if (mem.containsAtLeast(
                u8,
                contact_name,
                1,
                options.name,
            )) {
                const id = mem.span(contact.id);
                return try std.unicode.utf16leToUtf8Alloc(self.gpa, id);
            },
        }
    }

    return error.ContactNotFound;
}

pub fn sendTextMsg(self: *WeChat, options: SendMsgOptions) !void {
    var func_addr = try self.getAddrByTag(.{ .send_msg = undefined });

    var to_user: [*c]windows.WCHAR = undefined;
    defer self.gpa.free(mem.span(to_user));

    var message: [*c]windows.WCHAR = undefined;
    defer self.gpa.free(mem.span(message));

    sendTextMessage(.{
        .id = blk: {
            to_user = try std.unicode.utf8ToUtf16LeWithNull(
                self.gpa,
                options.to_user,
            );
            break :blk to_user;
        },
        .msg = blk: {
            message = try std.unicode.utf8ToUtf16LeWithNull(
                self.gpa,
                options.message,
            );
            break :blk message;
        },
        .addr = func_addr,
    });
}

fn getAddrByTag(self: *WeChat, fields: anytype) !usize {
    var dll_name = try std.unicode.utf8ToUtf16LeWithNull(
        self.gpa,
        self.dll_name,
    );
    defer self.gpa.free(dll_name);

    var handle = blk: {
        if (windows.kernel32.GetModuleHandleW(dll_name)) |handle| {
            break :blk handle;
        }
        return error.GetWeChatWinHandle;
    };

    const handle_addr = @intFromPtr(handle);
    inline for (@typeInfo(@TypeOf(fields)).Struct.fields) |field| {
        return handle_addr + @field(self.off_sets, field.name);
    }
}

fn getPtrByTag(self: *WeChat, comptime ptr: PointerUnion) !ActiveType(ptr) {
    var dll_name = try std.unicode.utf8ToUtf16LeWithNull(
        self.gpa,
        self.dll_name,
    );
    defer self.gpa.free(dll_name);

    var handle = blk: {
        if (windows.kernel32.GetModuleHandleW(dll_name)) |handle| {
            break :blk handle;
        }
        return error.GetWeChatWinHandle;
    };

    switch (ptr) {
        inline else => |p, tag| {
            const offset = @field(self.off_sets, @tagName(tag));
            return @ptrFromInt(@TypeOf(p), @intFromPtr(handle) + offset);
        },
    }
}

fn ActiveType(comptime u: anytype) type {
    return meta.TagPayload(@TypeOf(u), meta.activeTag(u));
}

pub fn deinit(self: *WeChat) void {
    self.* = undefined;
}
