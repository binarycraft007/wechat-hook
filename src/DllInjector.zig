const std = @import("std");
const os = std.os;
const mem = std.mem;
const unicode = std.unicode;
const windows = os.windows;
const kernel32 = @import("kernel32.zig");
const advapi32 = @import("advapi32.zig");
const winreg = @import("winreg.zig");
const winint = @import("winint.zig");
const injector_log = std.log.scoped(.injector);

target_name: []const u8,
reg_key: []const u8,
reg_value: []const u8,
dll_raw: []const u8,
exe_path: []const u8,
dll_path: []const u8,

const DllInjector = @This();

const InitOptions = struct {
    target_name: []const u8,
    reg_key: []const u8,
    reg_value: []const u8,
    dll_raw: []const u8,
};

pub fn init(options: InitOptions) DllInjector {
    return .{
        .target_name = options.target_name,
        .reg_key = options.reg_key,
        .reg_value = options.reg_value,
        .dll_raw = options.dll_raw,
        .exe_path = "",
        .dll_path = "",
    };
}

pub fn startProcess(self: *DllInjector, gpa: mem.Allocator) !void {
    var current_user: windows.HKEY = undefined;
    var hkey: windows.HKEY = undefined;
    var topkey = try std.unicode.utf8ToUtf16LeWithNull(
        gpa,
        self.reg_key,
    );
    defer gpa.free(topkey);

    if (advapi32.RegOpenCurrentUser(
        windows.KEY_READ,
        &current_user,
    ) != 0) {
        return error.OpenCurrentUser;
    }
    errdefer _ = windows.advapi32.RegCloseKey(current_user);
    defer _ = windows.advapi32.RegCloseKey(current_user);

    if (windows.advapi32.RegOpenKeyExW(
        current_user,
        topkey,
        0,
        windows.KEY_QUERY_VALUE,
        &hkey,
    ) != 0) {
        return error.OpenRegKey;
    }
    errdefer _ = windows.advapi32.RegCloseKey(hkey);
    defer _ = windows.advapi32.RegCloseKey(hkey);

    var result = try gpa.alloc(windows.BYTE, windows.MAX_PATH);
    defer gpa.free(result);

    const query = try std.unicode.utf8ToUtf16LeWithNull(
        gpa,
        self.reg_value,
    );
    defer gpa.free(query);

    if (windows.advapi32.RegQueryValueExW(
        hkey,
        query,
        null,
        null,
        @ptrCast(*windows.BYTE, result.ptr),
        @constCast(&@intCast(u32, result.len)),
    ) != 0) {
        return error.QueryRegValue;
    }

    var result_utf8 = try unicode.utf16leToUtf8Alloc(
        gpa,
        mem.span(@ptrCast(
            [*:0]u16,
            @alignCast(@alignOf([*:0]u16), result.ptr),
        )),
    );
    defer gpa.free(result_utf8);

    self.exe_path = try std.fs.path.join(gpa, &[_][]const u8{
        result_utf8,
        self.target_name,
    });
    injector_log.info("exe_path: {s}", .{self.exe_path});

    self.dll_path = try std.fs.path.join(gpa, &[_][]const u8{
        result_utf8,
        "wechat-helper.dll",
    });
    injector_log.info("dll_path: {s}", .{self.exe_path});
}

pub fn closeProcess(self: *DllInjector, gpa: mem.Allocator) !void {
    const handle = windows.kernel32.CreateToolhelp32Snapshot(
        windows.TH32CS_SNAPPROCESS,
        0,
    );

    if (handle == windows.INVALID_HANDLE_VALUE) {
        switch (windows.kernel32.GetLastError()) {
            else => |err| return windows.unexpectedError(err),
        }
    }
    errdefer windows.CloseHandle(handle);
    defer windows.CloseHandle(handle);

    var process_entry = mem.zeroInit(kernel32.PROCESSENTRY32W, .{
        .dwSize = @sizeOf(kernel32.PROCESSENTRY32W),
    });

    if (kernel32.Process32FirstW(handle, &process_entry) == windows.FALSE) {
        return error.FailedToGetFirstProcess;
    }

    while (true) {
        var process_name = try unicode.utf16leToUtf8Alloc(
            gpa,
            &process_entry.szExeFile,
        );
        defer gpa.free(process_name);

        if (mem.containsAtLeast(u8, process_name, 1, self.target_name)) {
            var process_handle = kernel32.OpenProcess(
                winint.PROCESS_TERMINATE,
                windows.FALSE,
                process_entry.th32ProcessID,
            );
            if (process_handle == windows.INVALID_HANDLE_VALUE) {
                switch (windows.kernel32.GetLastError()) {
                    else => |err| return windows.unexpectedError(err),
                }
            }
            defer windows.CloseHandle(process_handle);

            try windows.TerminateProcess(process_handle, 0);
        }

        if (kernel32.Process32NextW(handle, &process_entry) != windows.TRUE) {
            break;
        }
    }
}

pub fn deinit(self: *DllInjector, gpa: mem.Allocator) void {
    gpa.free(self.exe_path);
    gpa.free(self.dll_path);
    self.* = undefined;
}
