const Identity = @This();
const std = @import("std");
const Ed25519 = std.crypto.sign.Ed25519;
const X25519 = std.crypto.dh.X25519;
const Base64 = std.base64.standard;

allocator: std.mem.Allocator,
secret: ?Ed25519.SecretKey,
public: Ed25519.PublicKey,

/// A scalar used for symmetric encryption
pub const Scalar = [X25519.shared_length]u8;

/// The type of identity that is being loaded
pub const KeyType = enum(u1) { secret, public };

/// Combination of different Identity errors
pub const Error =
    std.base64.Error ||
    std.mem.Allocator.Error ||
    error{
        IdentityElementError,
        InvalidEncoding,
        IdentityElement,
        EncodingError,
        NonCanonical,
    };

/// Generate a new user identity
pub fn generate(allocator: std.mem.Allocator) Identity {
    const keys = Ed25519.KeyPair.generate();

    return Identity{
        .secret = keys.secret_key,
        .public = keys.public_key,
        .allocator = allocator,
    };
}

/// Load a public or private key and create an identity
pub fn load(comptime kind: KeyType, data: []const u8) Error!Identity {
    var identity = Identity{ .secret = undefined, .public = undefined };

    switch (kind) {
        .secret => {
            var buffer: [Ed25519.SecretKey.encoded_length]u8 = undefined;
            try Base64.Decoder.decode(&buffer, data);
            const keys = try Ed25519.KeyPair.fromSecretKey(buffer);
            identity.secret = keys.secret_key;
            identity.public = keys.public_key;
        },
        .public => {
            var buffer: [Ed25519.PublicKey.encoded_length]u8 = undefined;
            try Base64.Decoder.decode(&buffer, data);
            identity.public = try Ed25519.PublicKey.fromBytes(buffer);
            identity.secret = null;
        },
    }

    return identity;
}

/// Get a scalar from an identity's public key
pub fn scalar(id: Identity, out: Identity) Error!Scalar {
    const spair = try Ed25519.KeyPair.fromSecretKey(id.secret.?);
    const rid = try X25519.publicKeyFromEd25519(out.public);
    const sid = try X25519.KeyPair.fromEd25519(spair);
    return X25519.scalarmult(sid.secret_key, rid);
}

/// Base64 encode an Identity's public or secret key for storage
pub fn encode(id: Identity, comptime kind: KeyType) Error![]const u8 {
    switch (kind) {
        .secret => {
            const size = Base64.Encoder.calcSize(id.secret.?.bytes.len);
            const buffer = try id.allocator.alloc(u8, size);
            errdefer id.allocator.free(buffer);
            _ = Base64.Encoder.encode(buffer, &id.secret.?.toBytes());
            return buffer;
        },
        .public => {
            const size = Base64.Encoder.calcSize(id.public.bytes.len);
            const buffer = try id.allocator.alloc(u8, size);
            errdefer id.allocator.free(buffer);
            _ = Base64.Encoder.encode(buffer, &id.public.toBytes());
            return buffer;
        },
    }
}
