const std = @import("std");
const mem = std.mem;
const meta = std.meta;
const unicode = std.unicode;
const windows = std.os.windows;
const log = std.log.scoped(.wechat);

gpa: mem.Allocator,
dll_name: []const u8,
off_sets: OffSets,

const WeChat = @This();
const OffSets = struct {
    account_mgr: usize,
    send_msg_mgr: usize,
    send_text_msg: usize,
    free_chat_msg: usize,
    contact_mgr: usize,
    contact_list: usize,
};

pub const Contact = struct {
    id: ?[*:0]const u16,
    name: ?[*:0]const u16,
};

pub const UserInfo = struct {
    user_id: [*:0]const u8,
    nick_name: [*:0]const u8,
    mobile: [*:0]const u8,
};

pub const String = extern struct {
    text: [*c]const windows.WCHAR,
    size: windows.DWORD,
    capacity: windows.DWORD,
    padding: [12]u8 = [1]u8{0} ** 12,

    pub fn init(gpa: mem.Allocator, str: []const u8) !String {
        var text = try unicode.utf8ToUtf16LeWithNull(gpa, str);
        return .{
            .text = text,
            .size = @intCast(text.len),
            .capacity = @intCast(text.len),
        };
    }

    pub fn deinit(self: *String, gpa: mem.Allocator) void {
        if (self.text) |text| gpa.free(mem.span(text));
    }
};

const PointerType = enum {
    account_mgr,
    send_msg_mgr,
    send_text_msg,
    free_chat_msg,
    contact_mgr,
    contact_list,
};

const PointerUnion = union(PointerType) {
    account_mgr: *const fn () callconv(.C) usize,
    send_msg_mgr: *const fn () callconv(.C) usize,
    send_text_msg: *const fn (
        usize,
        usize,
        usize,
        usize,
        usize,
        usize,
        usize,
        usize,
    ) callconv(.C) usize,
    free_chat_msg: *const fn (usize) callconv(.C) usize,
    contact_mgr: *const fn () callconv(.C) usize,
    contact_list: *const fn (
        usize,
        usize,
    ) callconv(.C) usize,
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
    to_user: []const u8,
    message: []const u8,
};

pub fn isLoggedIn(self: *WeChat) bool {
    var ptr = self.getPtrByTag(.account_mgr) catch return false;
    var service_addr = ptr();
    if (service_addr != 0) {
        return @as(*usize, @ptrFromInt(service_addr + 0x7F8)).* != 0;
    }
    return false;
}

pub fn getUserInfo(self: *WeChat) !UserInfo {
    var get_account_mgr = try self.getPtrByTag(.account_mgr);
    var service_addr = get_account_mgr();
    if (service_addr == 0) return error.ServiceManager;

    return .{
        .user_id = blk: {
            if (@as(*usize, @ptrFromInt(service_addr + 0x80 + 0x18)).* == 0xF) {
                break :blk @ptrFromInt(service_addr + 0x80);
            } else {
                var ptr: *[*:0]const u8 = @ptrFromInt(service_addr + 0x80);
                break :blk ptr.*;
            }
        },
        .nick_name = blk: {
            if (@as(*usize, @ptrFromInt(service_addr + 0x168 + 0x18)).* == 0xF) {
                break :blk @ptrFromInt(service_addr + 0x168);
            } else {
                var ptr: *[*:0]const u8 = @ptrFromInt(service_addr + 0x168);
                break :blk ptr.*;
            }
        },
        .mobile = blk: {
            if (@as(*usize, @ptrFromInt(service_addr + 0x128 + 0x18)).* == 0xF) {
                break :blk @ptrFromInt(service_addr + 0x128);
            } else {
                var ptr: *[*:0]const u8 = @ptrFromInt(service_addr + 0x128);
                break :blk ptr.*;
            }
        },
    };
}

const GetContactOptions = struct {
    name: []const u8,
    match: enum { exact, partial },
};

pub fn getContact(self: *WeChat, options: GetContactOptions) ![]const u8 {
    var array: [3]usize = [_]usize{0} ** 3;
    var get_contact_mgr = try self.getPtrByTag(.contact_mgr);
    var get_contact_list = try self.getPtrByTag(.contact_list);
    if (get_contact_list(get_contact_mgr(), @intFromPtr(&array)) != 1) {
        return error.GetContactList;
    }

    var start: usize = array[0];
    var end: usize = array[2];

    while (start < end) : (start += 0x698) {
        var contact: Contact = .{
            .id = @as(*[*:0]u16, @ptrFromInt(start + 0x10)).*,
            .name = @as(*[*:0]u16, @ptrFromInt(start + 0xA0)).*,
        };

        var contact_name = blk: {
            const n = mem.span(contact.name) orelse continue;
            break :blk try unicode.utf16leToUtf8Alloc(self.gpa, n);
        };
        defer self.gpa.free(contact_name);

        switch (options.match) {
            .exact => if (mem.eql(u8, contact_name, options.name)) {
                const id = mem.span(contact.id) orelse continue;
                return try unicode.utf16leToUtf8Alloc(self.gpa, id);
            },
            .partial => if (mem.containsAtLeast(
                u8,
                contact_name,
                1,
                options.name,
            )) {
                const id = mem.span(contact.id) orelse continue;
                return try unicode.utf16leToUtf8Alloc(self.gpa, id);
            },
        }
    }

    return error.ContactNotFound;
}

pub fn sendTextMsg(self: *WeChat, options: SendMsgOptions) !void {
    var tmp: [3]u8 = [_]u8{0} ** 3;
    var chat_msg: [0x460]u8 = [_]u8{0} ** 0x460;

    var get_send_msg_mgr = try self.getPtrByTag(.send_msg_mgr);
    var send_text_msg = try self.getPtrByTag(.send_text_msg);
    var free_chat_msg = try self.getPtrByTag(.free_chat_msg);

    _ = get_send_msg_mgr();

    var to_user = try String.init(self.gpa, options.to_user);
    defer to_user.deinit(self.gpa);
    var message = try String.init(self.gpa, options.message);
    defer message.deinit(self.gpa);

    _ = send_text_msg(
        @intFromPtr(&chat_msg),
        @intFromPtr(&to_user),
        @intFromPtr(&message),
        @intFromPtr(&tmp),
        1,
        1,
        0,
        0,
    );
    _ = free_chat_msg(@intFromPtr(&chat_msg));
}

fn getPtrByTag(self: *WeChat, comptime ptr: PointerType) !TargetType(ptr) {
    var dll_name = try unicode.utf8ToUtf16LeWithNull(
        self.gpa,
        self.dll_name,
    );
    defer self.gpa.free(dll_name);

    var handle = windows.kernel32.GetModuleHandleW(dll_name) orelse
        return error.GetWeChatWinHandle;

    switch (ptr) {
        inline else => |tag| {
            const offset = @field(self.off_sets, @tagName(tag));
            return @ptrFromInt(@intFromPtr(handle) + offset);
        },
    }
}

fn TargetType(comptime tag: PointerType) type {
    return meta.TagPayload(PointerUnion, tag);
}

pub fn deinit(self: *WeChat) void {
    self.* = undefined;
}
