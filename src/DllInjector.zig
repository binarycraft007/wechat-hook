const std = @import("std");
const os = std.os;
const mem = std.mem;
const unicode = std.unicode;
const windows = os.windows;
const winapi = @import("winapi");
const log = std.log.scoped(.injector);

target_name: []const u8,
reg_key: []const u8,
reg_value: []const u8,
dll_raw: []const u8,
exe_path: []const u8,
dll_path: []const u8,
child_process: std.ChildProcess,

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
        .child_process = undefined,
        .exe_path = "",
        .dll_path = "",
    };
}

pub fn startProcess(self: *DllInjector, gpa: mem.Allocator) !void {
    var hkey: windows.HKEY = undefined;
    var topkey = try std.unicode.utf8ToUtf16LeWithNull(
        gpa,
        self.reg_key,
    );
    defer gpa.free(topkey);

    if (windows.advapi32.RegOpenKeyExW(
        winapi.HKEY_CURRENT_USER,
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
    log.info("exe_path: {s}", .{self.exe_path});

    self.dll_path = try std.fs.path.join(gpa, &[_][]const u8{
        result_utf8,
        "wechat-helper.dll",
    });
    log.info("dll_path: {s}", .{self.dll_path});

    var dll_file = try std.fs.createFileAbsolute(self.dll_path, .{});
    defer dll_file.close();

    try dll_file.writer().writeAll(self.dll_raw);

    var argv = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, argv);

    var exe_path = try std.cstr.addNullByte(gpa, self.exe_path);
    defer gpa.free(exe_path);

    argv[0] = exe_path;

    self.child_process = std.ChildProcess.init(argv, gpa);

    self.child_process.stdin_behavior = .Close;
    self.child_process.stdout_behavior = .Close;
    self.child_process.stderr_behavior = .Close;
    self.child_process.cwd = result_utf8;
    self.child_process.cwd_dir = null;
    self.child_process.env_map = null;
    self.child_process.expand_arg0 = .no_expand;

    try self.child_process.spawn();
}

pub fn inject(self: *DllInjector, gpa: mem.Allocator) !void {
    const mem_ptr = winapi.VirtualAllocEx(
        self.child_process.id,
        null,
        self.dll_path.len,
        windows.MEM_COMMIT,
        windows.PAGE_READWRITE,
    ) orelse switch (windows.kernel32.GetLastError()) {
        else => |err| return windows.unexpectedError(err),
    };

    var dll_path = try std.cstr.addNullByte(gpa, self.dll_path);
    defer gpa.free(dll_path);

    const len = try windows.WriteProcessMemory(
        self.child_process.id,
        mem_ptr,
        dll_path,
    );
    std.debug.assert(len == dll_path.len);

    var loader = try std.DynLib.open("kernel32.dll");
    defer loader.close();

    const loadLibrary = loader.lookup(
        windows.LPTHREAD_START_ROUTINE,
        "LoadLibraryA",
    ) orelse return error.LookupLoadLibrary;

    _ = winapi.CreateRemoteThread(
        self.child_process.id,
        null,
        0,
        loadLibrary,
        mem_ptr,
        0,
        null,
    ) orelse switch (windows.kernel32.GetLastError()) {
        else => |err| return windows.unexpectedError(err),
    };
    log.info("{s} injection success!", .{self.dll_path});
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

    var process_entry = mem.zeroInit(winapi.PROCESSENTRY32W, .{
        .dwSize = @sizeOf(winapi.PROCESSENTRY32W),
    });

    if (winapi.Process32FirstW(handle, &process_entry) == windows.FALSE) {
        return error.GetFirstProcess;
    }

    while (true) {
        var process_name = try unicode.utf16leToUtf8Alloc(
            gpa,
            &process_entry.szExeFile,
        );
        defer gpa.free(process_name);

        if (mem.containsAtLeast(u8, process_name, 1, self.target_name)) {
            var process_handle = winapi.OpenProcess(
                winapi.PROCESS_TERMINATE,
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

        if (winapi.Process32NextW(handle, &process_entry) != windows.TRUE) {
            break;
        }
    }
}

pub fn deinit(self: *DllInjector, gpa: mem.Allocator) void {
    _ = self.child_process.kill() catch |err| {
        log.err("kill child process: {}", .{err});
    };
    gpa.free(self.exe_path);
    gpa.free(self.dll_path);
    self.* = undefined;
}
