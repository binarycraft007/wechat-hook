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
const LSTATUS = windows.LSTATUS;
const REGSAM = windows.REGSAM;
const HKEY = windows.HKEY;

pub extern "advapi32" fn RegOpenCurrentUser(
    samDesired: REGSAM,
    phkResult: ?*HKEY,
) LSTATUS;
