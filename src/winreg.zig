const windows = @import("std").os.windows;
const HKEY = windows.HKEY;

pub const HKEY_CLASSES_ROOT = @intToPtr(HKEY, 0x80000000);
pub const HKEY_CURRENT_USER: HKEY = @intToPtr(HKEY, 0x80000001);
pub const HKEY_LOCAL_MACHINE = @intToPtr(HKEY, 0x80000002);
pub const HKEY_USERS = @intToPtr(HKEY, 0x80000003);
pub const HKEY_PERFORMANCE_DATA = @intToPtr(HKEY, 0x80000004);
pub const HKEY_PERFORMANCE_TEXT = @intToPtr(HKEY, 0x80000050);
pub const HKEY_PERFORMANCE_NLSTEXT = @intToPtr(HKEY, 0x80000060);
