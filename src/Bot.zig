const Bot = @This();

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

pub fn run(self: Bot, comptime Command: type, comptime process: fn (Bot, Command, Message) void) !void {
    var offset: i64 = 0;

    var client = http.Client{ .allocator = self.allocator };
    defer client.deinit();

    while (true) {
        const url = try std.fmt.allocPrint(self.allocator, "{s}/getUpdates?offset={d}&limit=100&timeout=10", .{ self.base, offset });
        defer self.allocator.free(url);

        const uri = try std.Uri.parse(url);

        var buffer: [8096]u8 = undefined;
        var request = try client.open(.GET, uri, .{ .server_header_buffer = &buffer });
        defer request.deinit();

        try request.send();
        try request.wait();

        const body = request.reader().readAllAlloc(self.allocator, std.math.maxInt(usize)) catch unreachable;
        defer self.allocator.free(body);

        const parsed = json.parseFromSlice(Response, self.allocator, body, .{ .ignore_unknown_fields = true }) catch {
            unreachable;
        };
        defer parsed.deinit();

        for (parsed.value.result) |update| {
            offset = update.update_id + 1;

            if (update.message) |message| {
                var args = std.mem.splitSequence(u8, message.text orelse "", " ");

                const command = parse(Command, &args) catch continue;
                process(self, command, message);
            }
        }
    }
}

pub fn sendMessage(self: Bot, chat_id: i64, text: []const u8) !void {
    var client = http.Client{ .allocator = self.allocator };
    defer client.deinit();

    const url = try std.fmt.allocPrint(self.allocator, "{s}/sendMessage", .{self.base});
    defer self.allocator.free(url);

    var uri = try std.Uri.parse(url);
    const query = try std.fmt.allocPrint(self.allocator, "chat_id={d}&text={s}", .{ chat_id, text });
    uri.query = .{ .percent_encoded = query };
    defer self.allocator.free(query);

    var buffer: [8096]u8 = undefined;
    var request = try client.open(.POST, uri, .{ .server_header_buffer = &buffer });
    defer request.deinit();

    try request.send();
    try request.wait();
}

pub fn deinit(self: Bot) void {
    self.allocator.free(self.base);
}

const ArgIterator = *std.mem.SplitIterator(u8, .sequence);

fn parse(comptime Command: type, args: ArgIterator) !Command {
    return switch (@typeInfo(Command)) {
        .@"union" => try parseCommand(Command, args),
        else => comptime unreachable,
    };
}

fn parseCommand(comptime Command: type, args: ArgIterator) !Command {
    const first_arg = args.next() orelse "";

    inline for (comptime std.meta.fields(Command)) |field| {
        if (std.mem.eql(u8, first_arg, field.name)) {
            return @unionInit(Command, field.name, try parseArgs(
                field.type,
                args,
            ));
        }
    }

    return @unionInit(Command, "unknown", {});
}

fn parseArgs(
    comptime Args: type,
    args: ArgIterator,
) !Args {
    var result: Args = undefined;
    if (Args == void) {
        return {};
    }

    inline for (std.meta.fields(Args)) |field| {
        const arg = args.next() orelse "";
        @field(result, field.name) = try parseArg(field.type, arg);
    }

    return result;
}

fn parseArg(comptime T: type, arg: []const u8) !T {
    if (T == []const u8) {
        return arg;
    }

    switch (@typeInfo(T)) {
        .Int => {
            return std.fmt.parseInt(T, arg, 10);
        },
        else => {
            comptime unreachable;
        },
    }
}

pub const User = struct {
    id: i64,
    is_bot: bool,
    first_name: ?[]const u8 = null,
    language_code: ?[]const u8 = null,
};

pub const Chat = struct {
    id: i64,
    title: ?[]const u8 = null,
    username: ?[]const u8 = null,
    type: []const u8,
};

pub const Message = struct {
    message_id: i64,
    from: ?User = null,
    chat: Chat,
    date: i64,
    text: ?[]const u8 = null,
};

pub const Update = struct {
    update_id: i64,
    message: ?Message = null,
};

pub const Response = struct {
    ok: bool,
    result: []const Update,
};

test "parse" {
    const Command = union(enum) {
        const Command = @This();

        start,
        move: struct { x: usize, y: usize },
        unknown,

        fn assert(self: Command, input: []const u8) !void {
            var args = std.mem.splitSequence(u8, input, " ");
            const actual = parseCommand(Command, &args) catch unreachable;

            try std.testing.expectEqualDeep(self, actual);
        }
    };

    try (Command{ .start = {} }).assert("start");
    try (Command{ .move = .{ .x = 40, .y = 42 } }).assert("move 40 42");
    try (Command{ .unknown = {} }).assert("2B");
}
