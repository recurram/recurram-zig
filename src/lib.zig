pub const codec = @import("codec.zig");
pub const errors = @import("error.zig");
pub const model = @import("model.zig");
pub const protocol = @import("protocol.zig");
pub const session = @import("session.zig");
pub const wire = @import("wire.zig");

const std = @import("std");

pub const RecurramError = errors.RecurramError;
pub const Value = model.Value;
pub const Schema = model.Schema;
pub const Message = model.Message;
pub const RecurramCodec = protocol.RecurramCodec;
pub const SessionEncoder = protocol.SessionEncoder;
pub const SessionOptions = session.SessionOptions;
pub const UnknownReferencePolicy = session.UnknownReferencePolicy;

pub fn encode(allocator: std.mem.Allocator, value: *const Value) ![]u8 {
    var c = RecurramCodec.init(allocator, .{});
    defer c.deinit();
    return c.encodeValue(value);
}

pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !Value {
    var c = RecurramCodec.init(allocator, .{});
    defer c.deinit();
    return c.decodeValue(bytes);
}

pub fn encodeWithSchema(allocator: std.mem.Allocator, schema: Schema, value: *const Value) ![]u8 {
    var enc = SessionEncoder.init(allocator, .{});
    defer enc.deinit();
    return enc.encodeWithSchema(schema, value);
}

pub fn encodeBatch(allocator: std.mem.Allocator, values: []const Value) ![]u8 {
    var enc = SessionEncoder.init(allocator, .{});
    defer enc.deinit();
    return enc.encodeBatch(values);
}

pub fn createSessionEncoder(allocator: std.mem.Allocator, options: SessionOptions) SessionEncoder {
    return SessionEncoder.init(allocator, options);
}

test "roundtrip dynamic value" {
    const allocator = std.testing.allocator;
    var map_entries = try allocator.alloc(model.ValueMapEntry, 2);
    map_entries[0] = .{ .key = try allocator.dupe(u8, "id"), .value = .{ .U64 = 1001 } };
    map_entries[1] = .{ .key = try allocator.dupe(u8, "name"), .value = .{ .String = try allocator.dupe(u8, "alice") } };
    var value = Value{ .Map = map_entries };
    defer value.deinit(allocator);

    var codec_impl = RecurramCodec.init(allocator, .{});
    defer codec_impl.deinit();

    const encoded = try codec_impl.encodeValue(&value);
    defer allocator.free(encoded);
    var decoded = try codec_impl.decodeValue(encoded);
    defer decoded.deinit(allocator);
    try std.testing.expect(Value.eql(decoded, value));
}
