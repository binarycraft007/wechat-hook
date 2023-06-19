const std = @import("std");

var file_logger: FileLogger = undefined;

pub const FileLogger = struct {
    name: []const u8,
    atomic_file: std.fs.AtomicFile,

    pub fn init(name: []const u8) void {
        file_logger = .{
            .name = name,
            .atomic_file = std.fs.cwd().atomicFile(name, .{}) catch return,
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
    const log_writer = file_logger.atomic_file.file.writer();
    log_writer.print(prefix ++ format, args) catch return;
}
