const std = @import("std");
const Bot = @import("Bot.zig");
const consts = @import("consts.zig");
const coingecko = @import("coingecko.zig");

const http = std.http;
const json = std.json;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) unreachable else {}
    }

    var bot = try Bot.init(allocator, consts.TELEGRAM_TOKEN);
    defer bot.deinit();

    const toncoin_price = try coingecko.fetchToncoinPrice(allocator);
    const text = try std.fmt.allocPrint(allocator, "The current price of Toncoin (The Open Network) is: ${d}", .{toncoin_price});
    try bot.sendMessage(text);
    allocator.free(text);
}
