const std = @import("std");
const os = std.os;
const mem = std.mem;
const windows = os.windows;
const kernel32 = @import("kernel32.zig");
const winint = @import("winint.zig");
const winreg = @import("winreg.zig");
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
    var hkey: windows.HKEY = undefined;
    const topkey = try std.unicode.utf8ToUtf16LeWithNull(
        gpa,
        self.reg_key,
    );
    defer gpa.free(topkey);

    if (windows.advapi32.RegOpenKeyExW(
        winreg.HKEY_CURRENT_USER,
        topkey,
        windows.KEY_ALL_ACCESS,
        0,
        &hkey,
    ) != 0) {
        return error.OpenRegKey;
    }
    errdefer _ = windows.advapi32.RegCloseKey(hkey);
    defer _ = windows.advapi32.RegCloseKey(hkey);

    var result: [windows.MAX_PATH]windows.BYTE = undefined;
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
        &result[0],
        @constCast(&@intCast(u32, result.len)),
    ) != 0) {
        return error.QueryRegKey;
    }

    self.exe_path = try std.fs.path.join(gpa, &[_][]const u8{
        &result,
        self.target_name,
    });
    injector_log.info("exe_path: {s}", .{self.exe_path});

    self.dll_path = try std.fs.path.join(gpa, &[_][]const u8{
        &result,
        "wechat-helper.dll",
    });
    injector_log.info("dll_path: {s}", .{self.exe_path});
}

pub fn closeProcess(self: *DllInjector) !void {
    const handle = windows.kernel32.CreateToolhelp32Snapshot(
        windows.TH32CS_SNAPPROCESS,
        0,
    );

    if (handle == windows.INVALID_HANDLE_VALUE) {
        switch (windows.kernel32.GetLastError()) {
            else => |err| return windows.unexpectedError(err),
        }
    }
    defer windows.CloseHandle(handle);

    var process_id: windows.DWORD = 0;
    var process_entry: kernel32.PROCESSENTRY32 = undefined;
    while (kernel32.Process32Next(handle, &process_entry) == windows.TRUE) {
        if (mem.eql(u8, &process_entry.szExeFile, self.target_name)) {
            process_id = process_entry.th32ProcessID;
        }
    }

    if (process_id != 0) {
        var process_handle = kernel32.OpenProcess(
            winint.PROCESS_TERMINATE,
            windows.FALSE,
            process_id,
        );
        if (handle == windows.INVALID_HANDLE_VALUE) {
            switch (windows.kernel32.GetLastError()) {
                else => |err| return windows.unexpectedError(err),
            }
        }
        defer windows.CloseHandle(process_handle);

        if (process_handle == windows.INVALID_HANDLE_VALUE) {
            switch (windows.kernel32.GetLastError()) {
                else => |err| return windows.unexpectedError(err),
            }
        }

        try windows.TerminateProcess(process_handle, 0);
    }
}

pub fn deinit(self: *DllInjector, gpa: mem.Allocator) void {
    gpa.free(self.exe_path);
    gpa.free(self.dll_path);
    self.* = undefined;
}
