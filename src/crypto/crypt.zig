const Crypt = @This();
const std = @import("std");
const Identity = @import("identity.zig");
const Aegis256X4 = std.crypto.aead.aegis.Aegis256X4;
const Blake3 = std.crypto.hash.Blake3;
const Base64 = std.base64.standard;

allocator: std.mem.Allocator,

// Possible errors that can occur during encryption
pub const Error = Identity.Error || std.crypto.errors.AuthenticationError || error{InvalidLength};

/// Type of encoding used for encrypted data
pub const Encoding = enum(u2) { b64, hex };

/// Initialize a new encryption algorithm instance
pub fn init(allocator: std.mem.Allocator) Crypt {
    return Crypt{ .allocator = allocator };
}

/// Encrypt data using an identity's symmetric encryption token
pub fn encrypt(c: Crypt, id: *Identity, d: []const u8, e: Encoding) Error![]const u8 {
    var tag: [Aegis256X4.tag_length]u8 = undefined;
    var nonce: [Aegis256X4.nonce_length]u8 = undefined;
    const data = try c.allocator.alloc(u8, d.len);
    defer c.allocator.free(data);
    std.crypto.random.bytes(&nonce);

    Aegis256X4.encrypt(data, &tag, d, "", nonce, try id.token());
    const msg = try std.mem.concat(c.allocator, u8, &.{ &tag, &nonce, data });
    defer c.allocator.free(msg);

    var buffer: []u8 = undefined;

    switch (e) {
        .b64 => {
            const size = Base64.Encoder.calcSize(msg.len);
            buffer = try c.allocator.alloc(u8, size);
            errdefer c.allocator.free(buffer);
            _ = Base64.Encoder.encode(buffer, msg);
        },
        .hex => {
            buffer = try std.fmt.allocPrint(c.allocator, "{s}", .{std.fmt.fmtSliceHexLower(msg)});
            errdefer c.allocator.free(buffer);
        },
    }

    return buffer;
}

/// Decrypt data using the specified receiver identity
pub fn decrypt(c: Crypt, id: *Identity, d: []const u8, e: Encoding) Error![]const u8 {
    var buffer: []u8 = undefined;

    switch (e) {
        .b64 => {
            const size = try Base64.Decoder.calcSizeForSlice(d);
            buffer = try c.allocator.alloc(u8, size);
            errdefer c.allocator.free(buffer);
            try Base64.Decoder.decode(buffer, d);
        },
        .hex => {
            buffer = try c.allocator.alloc(u8, d.len / 2);
            errdefer c.allocator.free(buffer);
            _ = try std.fmt.hexToBytes(buffer, d);
        },
    }

    const tag = buffer[0..Aegis256X4.tag_length];
    const nonce = buffer[tag.len .. tag.len + Aegis256X4.nonce_length];
    const data = buffer[tag.len + nonce.len ..];
    const raw = try c.allocator.alloc(u8, data.len);
    errdefer c.allocator.free(raw);

    try Aegis256X4.decrypt(raw, data, tag.*, "", nonce.*, try id.token());
    c.allocator.free(buffer);
    return raw;
}

/// Return a hash using Blake3 and the Identity's symmetric token
pub fn hash(c: Crypt, id: *Identity, data: []const u8) Error![]const u8 {
    var buffer: [Blake3.digest_length * 2]u8 = undefined;
    Blake3.hash(data, &buffer, .{ .key = try id.token() });
    buffer = std.fmt.bytesToHex(buffer[0..Blake3.digest_length], .lower);
    const hash_copy = try c.allocator.alloc(u8, buffer.len);
    errdefer c.allocator.free(hash_copy);
    @memcpy(hash_copy, &buffer);
    return hash_copy;
}
