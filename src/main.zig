const Bot = @import("Bot.zig");
const coingecko = @import("coingecko.zig");
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

    bot.run(Command, process) catch unreachable;
}

const Command = union(enum) {
    @"/start",
    @"/price": struct {
        name: []const u8,
    },
    unknown,
};

fn process(bot: *Bot, command: Command, message: Bot.Message) void {
    switch (command) {
        .@"/start" => {
            bot.sendMessage(message.chat.id, "Hello :3") catch return;
        },
        .@"/price" => {
            if (std.mem.eql(u8, command.@"/price".name, "toncoin")) {
                const toncoin_price = coingecko.fetchToncoinPrice(bot.allocator) catch {
                    const text = std.fmt.allocPrint(bot.allocator, "Failed to execute the request to retrieve the cost of Toncoin", .{}) catch return;
                    defer bot.allocator.free(text);
                    bot.sendMessage(message.chat.id, text) catch return;
                    return;
                };

                const text = std.fmt.allocPrint(bot.allocator, "The current price of Toncoin (The Open Network) is: ${d}", .{toncoin_price}) catch return;
                defer bot.allocator.free(text);
                bot.sendMessage(message.chat.id, text) catch return;
            }
        },
        .unknown => {},
    }
}
