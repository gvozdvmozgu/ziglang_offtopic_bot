const Bot = @This();

const coingecko = @import("coingecko.zig");
const consts = @import("consts.zig");
const std = @import("std");

const http = std.http;
const json = std.json;

allocator: std.mem.Allocator,
base: []u8,

pub fn init(allocator: std.mem.Allocator, token: []const u8) !Bot {
    const base = try std.fmt.allocPrint(allocator, "https://api.telegram.org/bot{s}", .{token});
    return Bot{ .allocator = allocator, .base = base };
}

pub fn run(self: *Bot) !void {
    var offset: i64 = 0;

    var client = http.Client{ .allocator = self.allocator };
    defer client.deinit();

    while (true) {
        const url = try std.fmt.allocPrint(self.allocator, "{s}/getUpdates?offset={d}&limit=100&timeout=10", .{
            self.base,
            offset,
        });
        defer self.allocator.free(url);

        const uri = try std.Uri.parse(url);

        var buffer: [8096]u8 = undefined;
        var request = try client.open(
            .GET,
            uri,
            .{ .server_header_buffer = &buffer },
        );
        defer request.deinit();

        try request.send(.{});
        try request.wait();

        const body = request.reader().readAllAlloc(self.allocator, std.math.maxInt(usize)) catch unreachable;
        defer self.allocator.free(body);

        const parsed = json.parseFromSlice(Response, self.allocator, body, .{ .ignore_unknown_fields = true }) catch unreachable;
        defer parsed.deinit();

        for (parsed.value.result) |update| {
            offset = update.update_id + 1;

            const message = update.message;
            if (std.mem.eql(u8, message.text, "/toncoin")) {
                const toncoin_price = coingecko.fetchToncoinPrice(self.allocator) catch {
                    try self.sendMessage(message.chat.id, try std.fmt.allocPrint(self.allocator, "Failed to execute the request to retrieve the cost of Toncoin", .{}));
                    continue;
                };

                try self.sendMessage(message.chat.id, try std.fmt.allocPrint(self.allocator, "The current price of Toncoin (The Open Network) is: ${d}", .{toncoin_price}));
            }
        }
    }
}

pub fn sendMessage(self: *Bot, chat_id: i64, text: []const u8) !void {
    var client = http.Client{ .allocator = self.allocator };
    defer client.deinit();

    const url = try std.fmt.allocPrint(self.allocator, "{s}/sendMessage", .{
        self.base,
    });
    defer self.allocator.free(url);

    var uri = try std.Uri.parse(url);
    uri.query = try std.fmt.allocPrint(self.allocator, "chat_id={d}&text={s}", .{ chat_id, text });
    defer self.allocator.free(uri.query.?);

    var buffer: [8096]u8 = undefined;
    var request = try client.open(
        .POST,
        uri,
        .{ .server_header_buffer = &buffer },
    );
    defer request.deinit();

    try request.send(.{});
    try request.wait();
}

pub fn deinit(self: *Bot) void {
    self.allocator.free(self.base);
}

pub const User = struct {
    id: i64,
    is_bot: bool,
    first_name: []const u8,
    language_code: []const u8,
};

pub const Chat = struct {
    id: i64,
    title: ?[]const u8 = null,
    username: ?[]const u8 = null,
    type: []const u8,
};

pub const Message = struct {
    message_id: i64,
    from: User,
    chat: Chat,
    date: i64,
    text: []const u8,
};

pub const Update = struct {
    update_id: i64,
    message: Message,
};

pub const Response = struct {
    ok: bool,
    result: []const Update,
};
