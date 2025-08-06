{ self, nixpkgs, ... }:

let
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};
in {
  # Development shell
  devShells.${system}.default = pkgs.mkShell {
    buildInputs = with pkgs; [
      pkgs.nixos-generators
      nixpkgs-fmt
    ];
    
    shellHook = ''
      echo "Welcome to the NixOS raw-efi development environment!"
      echo "Available commands:"
      echo "  nixos-generate --help    # Show nixos-generators help"
      echo "  nix build .#raw-efi      # Build the raw-efi image"
    '';
  };
}