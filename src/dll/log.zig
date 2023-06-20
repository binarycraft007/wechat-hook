const std = @import("std");

var file_logger: FileLogger = undefined;

pub const FileLogger = struct {
    name: []const u8,
    file: std.fs.File,

    pub fn init(name: []const u8) void {
        file_logger = .{
            .name = name,
            .file = std.fs.cwd().createFile(name, .{}) catch return,
        };
    }
};

pub fn logFn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const scope_prefix = "(" ++ @tagName(scope) ++ "): ";
    const prefix = "[" ++ comptime level.asText() ++ "] " ++ scope_prefix;
    file_logger.file.writer().print(prefix ++ format, args) catch return;
}
