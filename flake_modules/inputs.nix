{
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  nixos-generators = {
    url = "github:nix-community/nixos-generators";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  # Added to support shimboot Zen Browser home module import
  zen-browser = {
    url = "github:0xc000022070/zen-browser-flake";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  # Home Manager is typically required for Home modules
  home-manager = {
    url = "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
