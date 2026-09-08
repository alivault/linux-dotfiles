# Independent ARM64 static QEMU packages

These are locally maintained Arch packages, repackaging Debian's static ARM64
QEMU binaries and upstream QEMU's binfmt generator. No Omarchy repository,
package archive, helper or signing key is needed to build them.

```sh
bash bootstrap/build-qemu-static.sh  # normal user; builds, never installs
```

Review the printed package paths and install the TWO matching packages together
with `pkexec pacman -U <qemu-user-static archive> <binfmt archive>`.
Normal pacman binfmt hooks will re-register the interpreters. Test explicitly:

```sh
pkexec bash bootstrap/check-qemu-static.sh
```

The test pulls a small digest-pinned amd64 BusyBox image and runs one disposable
container with no networking, mounts, published ports or capabilities. Pulling
the image uses the host network; the container itself has --network=none.

## Pins and verification
- QEMU 10.0.11, Debian build 10.0.11+ds-0+deb13u1+b1, architecture ARM64.
- Official Debian .deb SHA256:
  6c9483063bf60f37fe181ead911251deabe40c893ea5829bc34b0b7b88913b6a.
- Upstream QEMU v10.0.0 generator SHA256:
  5e12ef484b8364e1ba7bae4acda837d2e6320ffbeb7fab341034124553cdb137.
- Both source URLs and hashes are in PKGBUILD. makepkg validates hashes before
  unpacking/running source. The complete upstream generator was reviewed.
- Uses default Arch stripping of the already-stripped Debian static PIE files.
  Skipping that normalization changes ELF section metadata; the final build was
  compared against the original installed packages after normal stripping.
- All 40 executables, the license file and 32 binfmt files matched byte-for-byte.
- Installed local packaging revision 10.0.11-2. Successful amd64-on-ARM64 container
  execution confirms the active PF registration still works.

This reproduces the existing emulator version; it is NOT an update to the latest
Debian security release. For updates, review a supported Debian qemu-user release,
obtain and verify its archive hash, update _debver/pkgver and reset pkgrel, build
both packages, compare layout/registration changes and retest emulation. Keep the
downloaded verified source archive if upstream eventually rotates the old URL.
On other architectures use the appropriate official packages or a separately
reviewed recipe; this recipe deliberately refuses non-ARM64 hosts.

Debian's full copyright/license file is installed with the binary package. Build
outputs and downloaded archives remain in ~/.cache, not in the dotfiles repo.
