const std = @import("std");
const consts = @import("consts.zig");

const http = std.http;
const json = std.json;

pub fn fetchToncoinPrice(allocator: std.mem.Allocator) !f64 {
    var client = http.Client{ .allocator = allocator };
    defer client.deinit();

    var buffer: [8096]u8 = undefined;
    var request = try client.open(.GET, consts.COINGECKO_API, .{ .server_header_buffer = &buffer });
    defer request.deinit();

    try request.send(.{});
    try request.wait();

    const body = request.reader().readAllAlloc(allocator, 8192) catch unreachable;
    defer allocator.free(body);

    const parsed_json = try json.parseFromSlice(json.Value, allocator, body, .{});
    defer parsed_json.deinit();

    return parsed_json.value.object.get("the-open-network").?.object.get("usd").?.float;
}
