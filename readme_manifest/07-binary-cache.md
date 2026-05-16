
## Binary Cache

Patched systemd and NixOS closures are cached on Cachix. The cache is auto-configured when importing `nixosModules.chromeos`.

<details>
<summary>Manual cache setup</summary>

- Substituter: `https://shimboot-systemd-nixos.cachix.org`
- Public key: `shimboot-systemd-nixos.cachix.org-1:vCWmEtJq7hA2UOLN0s3njnGs9/EuX06kD7qOJMo2kAA=`

```bash
cachix use shimboot-systemd-nixos
```

</details>

### CI Cache Strategy

CI uses Cachix daemon mode (post-build hook). Only locally-compiled derivations are pushed -- substituted paths from cache.nixos.org are never re-uploaded.

A cache-hit check runs before each build. If the toplevel closure already exists on Cachix, the build is skipped entirely. On cache miss, daemon mode pushes each derivation as it finishes compiling, naturally excluding Hydra-cached dependencies from the upload.

