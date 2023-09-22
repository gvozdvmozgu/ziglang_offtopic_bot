const Bot = @This();

const std = @import("std");
const consts = @import("consts.zig");

const http = std.http;

allocator: std.mem.Allocator,
base: []u8,

pub fn init(allocator: std.mem.Allocator, token: []const u8) !Bot {
    const base = try std.fmt.allocPrint(allocator, "https://api.telegram.org/bot{s}", .{token});
    return Bot{ .allocator = allocator, .base = base };
}

pub fn sendMessage(self: *Bot, text: []const u8) !void {
    var client = http.Client{ .allocator = self.allocator };
    defer client.deinit();

    const url = try std.fmt.allocPrint(self.allocator, "{s}/sendMessage", .{
        self.base,
    });
    defer self.allocator.free(url);

    var uri = try std.Uri.parse(url);
    uri.query = try std.fmt.allocPrint(self.allocator, "chat_id={s}&text={s}", .{ consts.TELEGRAM_CHAT_ID, text });
    defer self.allocator.free(uri.query.?);

    var request = try client.request(.POST, uri, .{ .allocator = self.allocator }, .{});
    defer request.deinit();

    try request.start();
    try request.wait();
}

pub fn deinit(self: *Bot) void {
    self.allocator.free(self.base);
}
