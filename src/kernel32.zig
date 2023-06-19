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
    lpAddress: LPVOID,
    dwSize: SIZE_T,
    flAllocationType: DWORD,
    flProtect: DWORD,
) callconv(WINAPI) LPVOID;

pub extern "kernel32" fn OpenProcess(
    dwDesiredAccess: DWORD,
    bInheritHandle: BOOL,
    dwProcessId: DWORD,
) callconv(WINAPI) HANDLE;
