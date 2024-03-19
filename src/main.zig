const Bot = @import("Bot.zig");
const coingecko = @import("coingecko.zig");
const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    _ = try stdout.write("Launched :3\n");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const token = std.process.getEnvVarOwned(allocator, "TELEGRAM_TOKEN") catch unreachable;
    const bot = try Bot.init(allocator, token);

    allocator.free(token);

    bot.run(Command, process) catch unreachable;
    bot.deinit();

    std.debug.assert(gpa.deinit() == .ok);
}

const Command = union(enum) {
    @"/start",
    @"/price": struct {
        name: []const u8,
    },
    unknown,
};

fn process(bot: Bot, command: Command, message: Bot.Message) void {
    switch (command) {
        .@"/start" => {
            bot.sendMessage(message.chat.id, "Hello :3") catch return;
        },
        .@"/price" => |options| {
            if (std.mem.eql(u8, options.name, "toncoin")) {
                const toncoin_price = coingecko.fetchToncoinPrice(bot.allocator) catch {
                    const text = std.fmt.allocPrint(bot.allocator, "Failed to execute the request to retrieve the cost of Toncoin", .{}) catch return;
                    bot.sendMessage(message.chat.id, text) catch return;
                    bot.allocator.free(text);
                    return;
                };

                const text = std.fmt.allocPrint(bot.allocator, "The current price of Toncoin (The Open Network) is: ${d}", .{toncoin_price}) catch return;
                bot.sendMessage(message.chat.id, text) catch return;
                bot.allocator.free(text);
            }
        },
        .unknown => {},
    }
}

test {
    std.testing.refAllDecls(@This());
}
