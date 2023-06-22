const std = @import("std");
const windows = std.os.windows;
const DWORD = windows.DWORD;
const ULONG_PTR = windows.ULONG_PTR;
const LONG = windows.LONG;
const WCHAR = windows.WCHAR;
const MAX_PATH = windows.MAX_PATH;
const BOOL = windows.BOOL;
const WINAPI = windows.WINAPI;
const HANDLE = windows.HANDLE;
const LPVOID = windows.LPVOID;
const SIZE_T = windows.SIZE_T;
const HKEY = windows.HKEY;
const SECURITY_ATTRIBUTES = windows.SECURITY_ATTRIBUTES;
const LPTHREAD_START_ROUTINE = windows.LPTHREAD_START_ROUTINE;

pub const PROCESSENTRY32W = extern struct {
    dwSize: DWORD,
    cntUsage: DWORD,
    th32ProcessID: DWORD,
    th32DefaultHeapID: ULONG_PTR,
    th32ModuleID: DWORD,
    cntThreads: DWORD,
    th32ParentProcessID: DWORD,
    pcPriClassBase: LONG,
    dwFlags: DWORD,
    szExeFile: [MAX_PATH]WCHAR,
};

pub extern "kernel32" fn Process32FirstW(
    hSnapshot: HANDLE,
    lppe: ?*PROCESSENTRY32W,
) callconv(WINAPI) BOOL;

pub extern "kernel32" fn Process32NextW(
    hSnapshot: HANDLE,
    lppe: ?*PROCESSENTRY32W,
) callconv(WINAPI) BOOL;

pub extern "kernel32" fn VirtualAllocEx(
    hProcess: HANDLE,
    lpAddress: ?LPVOID,
    dwSize: SIZE_T,
    flAllocationType: DWORD,
    flProtect: DWORD,
) callconv(WINAPI) ?LPVOID;

pub extern "kernel32" fn VirtualFreeEx(
    hProcess: HANDLE,
    lpAddress: LPVOID,
    dwSize: SIZE_T,
    dwFreeType: DWORD,
) callconv(WINAPI) BOOL;

pub extern "kernel32" fn OpenProcess(
    dwDesiredAccess: DWORD,
    bInheritHandle: BOOL,
    dwProcessId: DWORD,
) callconv(WINAPI) HANDLE;

pub extern "kernel32" fn CreateRemoteThread(
    hProcess: HANDLE,
    lpThreadAttributes: ?*SECURITY_ATTRIBUTES,
    dwStackSize: SIZE_T,
    lpStartAddress: LPTHREAD_START_ROUTINE,
    lpParameter: LPVOID,
    dwCreationFlags: DWORD,
    lpThreadId: ?*DWORD,
) callconv(WINAPI) ?HANDLE;

pub extern "kernel32" fn ResumeThread(
    hThread: HANDLE,
) callconv(WINAPI) DWORD;

pub const PROCESS_TERMINATE = 0x0001;
pub const PROCESS_CREATE_THREAD = 0x0002;
pub const PROCESS_SET_SESSIONID = 0x0004;
pub const PROCESS_VM_OPERATION = 0x0008;
pub const PROCESS_VM_READ = 0x0010;
pub const PROCESS_VM_WRITE = 0x0020;
pub const PROCESS_DUP_HANDLE = 0x0040;
pub const PROCESS_CREATE_PROCESS = 0x0080;
pub const PROCESS_SET_QUOTA = 0x0100;
pub const PROCESS_SET_INFORMATION = 0x0200;
pub const PROCESS_QUERY_INFORMATION = 0x0400;
pub const PROCESS_SUSPEND_RESUME = 0x0800;
pub const PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;

pub const HKEY_CLASSES_ROOT = @ptrFromInt(HKEY, 0x80000000);
pub const HKEY_CURRENT_USER = @ptrFromInt(HKEY, 0x80000001);
pub const HKEY_LOCAL_MACHINE = @ptrFromInt(HKEY, 0x80000002);
pub const HKEY_USERS = @ptrFromInt(HKEY, 0x80000003);
pub const HKEY_PERFORMANCE_DATA = @ptrFromInt(HKEY, 0x80000004);
pub const HKEY_PERFORMANCE_TEXT = @ptrFromInt(HKEY, 0x80000050);
pub const HKEY_PERFORMANCE_NLSTEXT = @ptrFromInt(HKEY, 0x80000060);

pub const CREATE_SUSPENDED = 0x4;
