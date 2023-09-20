const std = @import("std");
const http = std.http;
const json = std.json;

const TELEGRAM_TOKEN = "";
const TELEGRAM_CHAT_ID = "";
const TELEGRAM_API_URL = "https://api.telegram.org/bot" ++ TELEGRAM_TOKEN ++ "/sendMessage";
const COINGECKO_API_ENDPOINT = "https://api.coingecko.com/api/v3/simple/price?ids=the-open-network&vs_currencies=usd";

fn fetch_toncoin_price_from_coingecko(allocator: std.mem.Allocator) !f64 {
    var client = http.Client{ .allocator = allocator };
    defer client.deinit();

    const uri = std.Uri.parse(COINGECKO_API_ENDPOINT) catch unreachable;

    var request = try client.request(.GET, uri, .{ .allocator = allocator }, .{});
    defer request.deinit();

    try request.start();
    try request.wait();

    const responseBody = request.reader().readAllAlloc(allocator, 8192) catch unreachable;
    defer allocator.free(responseBody);

    const json_response = try json.parseFromSlice(json.Value, allocator, responseBody, .{});
    defer json_response.deinit();

    return json_response.value.object.get("the-open-network").?.object.get("usd").?.float;
}

fn send_telegram_message(allocator: std.mem.Allocator, message_text: []const u8) !void {
    var client = http.Client{ .allocator = allocator };
    defer client.deinit();

    var uri = std.Uri.parse(TELEGRAM_API_URL) catch unreachable;
    uri.query = std.fmt.allocPrint(allocator, "chat_id={s}&text={s}", .{ TELEGRAM_CHAT_ID, message_text }) catch unreachable;

    var request = try client.request(.POST, uri, .{ .allocator = allocator }, .{});
    defer request.deinit();

    try request.start();
    try request.wait();
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const toncoin_price = try fetch_toncoin_price_from_coingecko(allocator);
    const formatted_message = try std.fmt.allocPrint(allocator, "The current price of Toncoin (The Open Network) is: ${d}", .{toncoin_price});
    defer allocator.free(formatted_message);

    try send_telegram_message(allocator, formatted_message);
}
