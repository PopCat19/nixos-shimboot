{
  # Import inputs from inputs module
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  
  description = "NixOS configuration for raw-efi image generation";

  # Combine all outputs from modules
  outputs = { self, nixpkgs, nixos-generators, ... }:
    # Import and combine all module outputs
    (import ./flake_modules/raw-efi-image.nix { inherit self nixpkgs nixos-generators; }) //
    (import ./flake_modules/system-configuration.nix { inherit self nixpkgs; }) //
    (import ./flake_modules/development-environment.nix { inherit self nixpkgs; }) //
    (import ./flake_modules/initramfs-patching.nix { inherit self nixpkgs; }) //
    (import ./flake_modules/chromeos-sources.nix { inherit self nixpkgs; });
}