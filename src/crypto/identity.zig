const Identity = @This();
const std = @import("std");
const Ed25519 = std.crypto.sign.Ed25519;
const X25519 = std.crypto.dh.X25519;
const Base64 = std.base64.standard;

secret: Ed25519.SecretKey,
public: Ed25519.PublicKey,

/// A scalar used for symmetric encryption
pub const Scalar = [X25519.shared_length]u8;

/// The different types of encryption keys
pub const Key = enum(u1) { secret, public };

/// Combination of different Identity errors
pub const Error =
    std.base64.Error ||
    std.mem.Allocator.Error ||
    Ed25519.Verifier.VerifyError ||
    error{
        IdentityElementError,
        NonCanonicalError,
        KeyMismatchError,
        InvalidEncoding,
        EncodingError,
        NonCanonical,
        KeyMismatch,
    };

/// Create a new identity
pub fn create() Identity {
    const keypair = Ed25519.KeyPair.generate();

    return Identity{
        .secret = keypair.secret_key,
        .public = keypair.public_key,
    };
}

/// Load an identity from its encoded secret key
pub fn load(encoded: []const u8) Error!Identity {
    var buffer: [Ed25519.SecretKey.encoded_length]u8 = undefined;
    try Base64.Decoder.decode(&buffer, encoded);

    const secret = try Ed25519.SecretKey.fromBytes(buffer);
    const keypair = try Ed25519.KeyPair.fromSecretKey(secret);

    return Identity{
        .secret = keypair.secret_key,
        .public = keypair.public_key,
    };
}

/// Get the symmetric encryption token
pub fn token(i: Identity) Error!Scalar {
    const keypair = try Ed25519.KeyPair.fromSecretKey(i.secret);
    const x25519 = try X25519.KeyPair.fromEd25519(keypair);
    return X25519.scalarmult(x25519.secret_key, x25519.public_key);
}

/// Sign data using the identity's keypair for verification
pub fn sign(i: Identity, a: std.mem.Allocator, d: []const u8) Error![]const u8 {
    const keypair = try Ed25519.KeyPair.fromSecretKey(i.secret);
    var noise: [Ed25519.noise_length]u8 = undefined;
    std.crypto.random.bytes(&noise);

    const signature = try keypair.sign(d, noise);
    const size = Base64.Encoder.calcSize(signature.toBytes().len);
    const buffer = try a.alloc(u8, size);
    errdefer a.free(buffer);

    return Base64.Encoder.encode(buffer, &signature.toBytes());
}

/// Verify the signature for data using an identity's keypair
pub fn verify(i: Identity, data: []const u8, raw: []const u8) Error!void {
    var sig: [Ed25519.Signature.encoded_length]u8 = undefined;
    try Base64.Decoder.decode(&sig, raw);

    try Ed25519.Signature.fromBytes(sig).verify(data, i.public);
}

/// Encode an identity's secret or public key in Base64 for storage
pub fn encode(i: Identity, allocator: std.mem.Allocator, key: Key) Error![]const u8 {
    const buffer = try allocator.alloc(u8, switch (key) {
        .secret => Base64.Encoder.calcSize(i.secret.bytes.len),
        .public => Base64.Encoder.calcSize(i.public.bytes.len),
    });

    errdefer allocator.free(buffer);

    return Base64.Encoder.encode(buffer, switch (key) {
        .secret => &i.secret.toBytes(),
        .public => &i.public.toBytes(),
    });
}
