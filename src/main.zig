const std = @import("std");
const http = std.http;
const json = std.json;

const TELEGRAM_TOKEN = "";
const TELEGRAM_CHAT_ID = "";
const TELEGRAM_API_URL = std.Uri.parse("https://api.telegram.org/bot" ++ TELEGRAM_TOKEN ++ "/sendMessage") catch unreachable;
const COINGECKO_API_ENDPOINT = std.Uri.parse("https://api.coingecko.com/api/v3/simple/price?ids=the-open-network&vs_currencies=usd") catch unreachable;

fn fetchToncoinPriceFromCoingecko(allocator: std.mem.Allocator) !f64 {
    var client = http.Client{ .allocator = allocator };
    defer client.deinit();

    var request = try client.request(.GET, COINGECKO_API_ENDPOINT, .{ .allocator = allocator }, .{});
    defer request.deinit();

    try request.start();
    try request.wait();

    const body = request.reader().readAllAlloc(allocator, 8192) catch unreachable;
    defer allocator.free(body);

    const value = try json.parseFromSlice(json.Value, allocator, body, .{});
    defer value.deinit();

    return value.value.object.get("the-open-network").?.object.get("usd").?.float;
}

fn sendTelegramMessage(allocator: std.mem.Allocator, text: []const u8) !void {
    var client = http.Client{ .allocator = allocator };

    var uri = TELEGRAM_API_URL;
    uri.query = std.fmt.allocPrint(allocator, "chat_id={s}&text={s}", .{ TELEGRAM_CHAT_ID, text }) catch unreachable;

    var request = try client.request(.POST, uri, .{ .allocator = allocator }, .{});

    try request.start();
    try request.wait();

    defer client.deinit();
    defer request.deinit();
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const toncoin_price = try fetchToncoinPriceFromCoingecko(allocator);
    const text = try std.fmt.allocPrint(allocator, "The current price of Toncoin (The Open Network) is: ${d}", .{toncoin_price});
    try sendTelegramMessage(allocator, text);

    defer allocator.free(text);
}
