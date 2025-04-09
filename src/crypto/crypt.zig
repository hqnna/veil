const Crypt = @This();
const std = @import("std");
const Identity = @import("identity.zig");
const Aegis256X4 = std.crypto.aead.aegis.Aegis256X4;
const Base64 = std.base64.standard;

allocator: std.mem.Allocator,

// Possible errors that can occur during encryption
pub const Error = Identity.Error || std.crypto.errors.AuthenticationError;

/// Initialize a new encryption algorithm instance
pub fn init(allocator: std.mem.Allocator) Crypt {
    return Crypt{ .allocator = allocator };
}

/// Encrypt data using the specified sender and receiver identities
pub fn encrypt(c: Crypt, s: Identity, r: Identity, d: []const u8) Error![]const u8 {
    var tag: [Aegis256X4.tag_length]u8 = undefined;
    var nonce: [Aegis256X4.nonce_length]u8 = undefined;
    const data = try c.allocator.alloc(u8, d.len);
    defer c.allocator.free(data);
    std.crypto.random.bytes(&nonce);

    Aegis256X4.encrypt(data, &tag, d, "", nonce, try s.scalar(r));
    const msg = try std.mem.concat(c.allocator, u8, &.{ &tag, &nonce, data });
    defer c.allocator.free(msg);

    const size = Base64.Encoder.calcSize(msg.len);
    const buffer = try c.allocator.alloc(u8, size);
    errdefer c.allocator.free(buffer);

    return Base64.Encoder.encode(buffer, msg);
}

/// Decrypt data using the specified receiver identity
pub fn decrypt(c: Crypt, r: Identity, d: []const u8) Error![]const u8 {
    const size = try Base64.Decoder.calcSizeForSlice(d);
    const buffer = try c.allocator.alloc(u8, size);
    defer c.allocator.free(buffer);

    try Base64.Decoder.decode(buffer, d);
    const tag = buffer[0..Aegis256X4.tag_length];
    const nonce = buffer[tag.len .. tag.len + Aegis256X4.nonce_length];
    const data = buffer[tag.len + nonce.len ..];

    const raw = try c.allocator.alloc(u8, data.len);
    errdefer c.allocator.free(raw);

    try Aegis256X4.decrypt(raw, data, tag.*, "", nonce.*, try r.scalar(r));
    return raw;
}
