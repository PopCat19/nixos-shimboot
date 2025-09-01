{ config, pkgs, lib, ... }:

{
  # Power Management
  powerManagement.enable = true;
  services.thermald.enable = true; # Intel thermal management
}