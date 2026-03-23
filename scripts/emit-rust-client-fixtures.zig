const std = @import("std");
const gowe = @import("gowe");

const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    var codec = gowe.GoweCodec.init(allocator, .{});
    defer codec.deinit();

    var alpha = gowe.Value{ .String = try allocator.dupe(u8, "alpha") };
    defer alpha.deinit(allocator);
    try emitEncodedValue(stdout, allocator, "codec", "scalar_string", &codec, &alpha);

    var map_small = try idNameMapValue(allocator, 1, "alice");
    defer map_small.deinit(allocator);
    try emitEncodedValue(stdout, allocator, "codec", "map_two_fields_first", &codec, &map_small);
    try emitEncodedValue(stdout, allocator, "codec", "map_two_fields_second", &codec, &map_small);

    var map_shape = try idNameRoleMapValue(allocator, 1, "alice", "admin");
    defer map_shape.deinit(allocator);
    try emitEncodedValue(stdout, allocator, "codec", "map_three_fields_first", &codec, &map_shape);
    try emitEncodedValue(stdout, allocator, "codec", "map_three_fields_second", &codec, &map_shape);

    var i: usize = 0;
    while (i < 8) : (i += 1) {
        const name = try std.fmt.allocPrint(allocator, "user-{d}", .{i});
        defer allocator.free(name);
        var dynamic = try idNameMapValue(allocator, @intCast(10 + i), name);
        defer dynamic.deinit(allocator);
        const label = try std.fmt.allocPrint(allocator, "bulk_map_{d}", .{i});
        defer allocator.free(label);
        try emitEncodedValue(stdout, allocator, "codec", label, &codec, &dynamic);
    }

    const control_payload = [_]u8{ 0, 0, 1, 1, 1, 2, 3, 3, 3, 3, 4 };
    try emitControlStream(stdout, allocator, &codec, "control_stream_bitpack", .Bitpack, &control_payload);
    try emitControlStream(stdout, allocator, &codec, "control_stream_huffman", .Huffman, &control_payload);
    try emitControlStream(stdout, allocator, &codec, "control_stream_fse", .Fse, &control_payload);

    const payload = try allocator.create(gowe.Message);
    payload.* = .{ .Scalar = .{ .I64 = 42 } };
    var base_snapshot = gowe.Message{ .BaseSnapshot = .{
        .base_id = 77,
        .schema_or_shape_ref = 0,
        .payload = payload,
    } };
    defer base_snapshot.deinit(allocator);
    try emitEncodedMessage(stdout, allocator, "codec", "base_snapshot", &codec, &base_snapshot);

    var enc = gowe.SessionEncoder.init(allocator, .{});
    defer enc.deinit();

    const base_values = try makeI64Array(allocator, 100, 0);
    defer freeValues(base_values, allocator);
    var base_array = gowe.Value{ .Array = base_values };
    const base_bytes = try enc.encode(&base_array);
    defer allocator.free(base_bytes);
    try emitFrame(stdout, "session", "session_base_array", base_bytes);

    const one_change_values = try makeI64Array(allocator, 100, 0);
    defer freeValues(one_change_values, allocator);
    one_change_values[0].deinit(allocator);
    one_change_values[0] = .{ .I64 = 10_000 };
    var one_change = gowe.Value{ .Array = one_change_values };
    const one_patch = try enc.encodePatch(&one_change);
    defer allocator.free(one_patch);
    try emitFrame(stdout, "session", "session_patch_one_change", one_patch);

    var patch_step: usize = 0;
    while (patch_step < 4) : (patch_step += 1) {
        const iterative_values = try makeI64Array(allocator, 100, 0);
        defer freeValues(iterative_values, allocator);
        iterative_values[patch_step].deinit(allocator);
        iterative_values[patch_step] = .{ .I64 = @intCast(20_000 + patch_step) };
        var iterative = gowe.Value{ .Array = iterative_values };
        const bytes = try enc.encodePatch(&iterative);
        defer allocator.free(bytes);
        const label = try std.fmt.allocPrint(allocator, "session_patch_iter_{d}", .{patch_step});
        defer allocator.free(label);
        try emitFrame(stdout, "session", label, bytes);
    }

    const many_change_values = try makeI64Array(allocator, 100, 0);
    defer freeValues(many_change_values, allocator);
    for (many_change_values[0..12], 0..) |*slot, idx| {
        slot.deinit(allocator);
        slot.* = .{ .I64 = @intCast(10_000 + idx) };
    }
    var many_change = gowe.Value{ .Array = many_change_values };
    const many_patch = try enc.encodePatch(&many_change);
    defer allocator.free(many_patch);
    try emitFrame(stdout, "session", "session_patch_many_changes", many_patch);

    const rows1 = try makeUserRows(allocator, &[_][]const u8{ "a", "b", "c", "d" });
    defer freeValues(rows1, allocator);
    const micro_first = try enc.encodeMicroBatch(rows1);
    defer allocator.free(micro_first);
    try emitFrame(stdout, "session", "session_micro_batch_first", micro_first);

    const rows2 = try makeUserRows(allocator, &[_][]const u8{ "aa", "bb", "cc", "dd" });
    defer freeValues(rows2, allocator);
    const micro_second = try enc.encodeMicroBatch(rows2);
    defer allocator.free(micro_second);
    try emitFrame(stdout, "session", "session_micro_batch_second", micro_second);

    try stdout.flush();
}

fn emitEncodedValue(writer: anytype, allocator: Allocator, stream: []const u8, label: []const u8, codec: *gowe.GoweCodec, value: *const gowe.Value) !void {
    const bytes = try codec.encodeValue(value);
    defer allocator.free(bytes);
    try emitFrame(writer, stream, label, bytes);
}

fn emitEncodedMessage(writer: anytype, allocator: Allocator, stream: []const u8, label: []const u8, codec: *gowe.GoweCodec, message: *const gowe.Message) !void {
    const bytes = try codec.encodeMessage(message);
    defer allocator.free(bytes);
    try emitFrame(writer, stream, label, bytes);
}

fn emitControlStream(writer: anytype, allocator: Allocator, codec: *gowe.GoweCodec, label: []const u8, stream_codec: gowe.model.ControlStreamCodec, payload: []const u8) !void {
    var msg = gowe.Message{ .ControlStream = .{ .codec = stream_codec, .payload = try allocator.dupe(u8, payload) } };
    defer msg.deinit(allocator);
    try emitEncodedMessage(writer, allocator, "codec", label, codec, &msg);
}

fn emitFrame(writer: anytype, stream: []const u8, label: []const u8, bytes: []const u8) !void {
    try writer.print("{s}|{s}|", .{ stream, label });
    for (bytes) |byte| {
        try writer.print("{x:0>2}", .{byte});
    }
    try writer.writeByte('\n');
}

fn idNameMapValue(allocator: Allocator, id: u64, name: []const u8) !gowe.Value {
    const entries = try allocator.alloc(gowe.model.ValueMapEntry, 2);
    entries[0] = .{ .key = try allocator.dupe(u8, "id"), .value = .{ .U64 = id } };
    entries[1] = .{ .key = try allocator.dupe(u8, "name"), .value = .{ .String = try allocator.dupe(u8, name) } };
    return .{ .Map = entries };
}

fn idNameRoleMapValue(allocator: Allocator, id: u64, name: []const u8, role: []const u8) !gowe.Value {
    const entries = try allocator.alloc(gowe.model.ValueMapEntry, 3);
    entries[0] = .{ .key = try allocator.dupe(u8, "id"), .value = .{ .U64 = id } };
    entries[1] = .{ .key = try allocator.dupe(u8, "name"), .value = .{ .String = try allocator.dupe(u8, name) } };
    entries[2] = .{ .key = try allocator.dupe(u8, "role"), .value = .{ .String = try allocator.dupe(u8, role) } };
    return .{ .Map = entries };
}

fn makeI64Array(allocator: Allocator, len: usize, start: i64) ![]gowe.Value {
    const out = try allocator.alloc(gowe.Value, len);
    for (out, 0..) |*slot, idx| {
        slot.* = .{ .I64 = start + @as(i64, @intCast(idx)) };
    }
    return out;
}

fn makeUserRows(allocator: Allocator, names: []const []const u8) ![]gowe.Value {
    const rows = try allocator.alloc(gowe.Value, names.len);
    for (names, 0..) |name, idx| {
        const entries = try allocator.alloc(gowe.model.ValueMapEntry, 2);
        entries[0] = .{ .key = try allocator.dupe(u8, "id"), .value = .{ .U64 = @intCast(idx + 1) } };
        entries[1] = .{ .key = try allocator.dupe(u8, "name"), .value = .{ .String = try allocator.dupe(u8, name) } };
        rows[idx] = .{ .Map = entries };
    }
    return rows;
}

fn freeValues(values: []gowe.Value, allocator: Allocator) void {
    for (values) |*value| {
        value.deinit(allocator);
    }
    allocator.free(values);
}
