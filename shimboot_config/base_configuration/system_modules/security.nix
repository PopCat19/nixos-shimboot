{ config, pkgs, lib, ... }:

{
  security.polkit.enable = true; # Enables polkit for authorization
}