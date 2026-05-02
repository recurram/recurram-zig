# Recurram (Zig)

Zig implementation of the Recurram wire format and session-aware encoder/decoder.

This repository tracks the Recurram v2 release line.

## What this package provides

- Dynamic encoding/decoding (`encode`, `decode`)
- Schema-aware encoding (`SessionEncoder.encodeWithSchema`)
- Batch encoding (`SessionEncoder.encodeBatch`)
- Session table behavior (key/string interning, shape promotion, reset controls)
- Vector codecs (Simple8b, RLE, FOR/direct bitpack, XOR float, and plain)

## Requirements

- Zig 0.15.2 (minimum `0.15.0`)

## Quick start

```zig
const std = @import("std");
const recurram = @import("recurram");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var entries = try allocator.alloc(recurram.model.ValueMapEntry, 2);
    entries[0] = .{ .key = try allocator.dupe(u8, "id"), .value = .{ .U64 = 1001 } };
    entries[1] = .{ .key = try allocator.dupe(u8, "name"), .value = .{ .String = try allocator.dupe(u8, "alice") } };

    var value = recurram.Value{ .Map = entries };
    defer value.deinit(allocator);

    const bytes = try recurram.encode(allocator, &value);
    defer allocator.free(bytes);

    var decoded = try recurram.decode(allocator, bytes);
    defer decoded.deinit(allocator);

    std.debug.assert(recurram.Value.eql(decoded, value));
}
```

## Development

Run checks locally:

```bash
zig fmt build.zig build.zig.zon src tests
zig build test
```

Rust client interop smoke check (Zig server -> Rust client):

```bash
bash scripts/check-rust-client-interop.sh
```

Zig client interop smoke check (Rust server -> Zig client):

```bash
bash scripts/check-zig-client-interop.sh
```

Run both directions:

```bash
bash scripts/check-interop.sh
```

Note: these scripts expect `../recurram-rust` to exist as a sibling directory.

## CI and release (GitHub Actions)

- CI workflow: `.github/workflows/ci.yml`
  - `zig fmt --check`
  - `zig build test`
- Release workflow: `.github/workflows/publish-release.yml`
  - Triggers on `v*` tags or manual dispatch
  - Verifies tag/version match against `build.zig.zon`
  - Re-runs checks and publishes a GitHub Release

Release steps:

1. Bump `.version` in `build.zig.zon`.
2. Create and push matching tag `v<version>`.

Example:

```bash
git tag v0.1.0
git push origin v0.1.0
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
