const Bot = @import("Bot.zig");
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) unreachable else {}
    }

    const token = std.process.getEnvVarOwned(allocator, "TELEGRAM_TOKEN") catch unreachable;
    defer allocator.free(token);

    var bot = try Bot.init(allocator, token);
    defer bot.deinit();

    bot.run() catch unreachable;
}
