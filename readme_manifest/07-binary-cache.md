
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


