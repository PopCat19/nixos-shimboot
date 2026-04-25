# Hardware Configuration Module
#
# Purpose: Configure hardware settings for ChromeOS devices
# Dependencies: linux-firmware, mesa, brightnessctl, thermald (Intel only)
# Related: boot.nix, display.nix
#
# This module:
# - Enables redistributable firmware for ChromeOS compatibility
# - Configures graphics drivers with 32-bit support
# - Enables Bluetooth with power-on-boot
# - Provides brightness control utilities
# - Enables thermal daemon for Intel CPUs (x86_pkg_temp)
#
# CPU-specific configuration:
# - Intel: thermald with x86_pkg_temp sensor configuration
# - AMD/ARM: No thermald (different thermal management)
{
  pkgs,
  lib,
  config,
  ...
}:
let
  # Import board database and get current board's config
  boards = import ../../boards/default.nix { inherit lib; };
  inherit (config.shimboot) board;
  boardConfig = boards.${board};
in
{
  hardware = {
    # enableRedistributableFirmware = true;
    graphics = {
      enable = lib.mkDefault true;
      enable32Bit = lib.mkDefault false;
    };
    bluetooth = {
      enable = lib.mkDefault true;
      powerOnBoot = lib.mkDefault true;
    };
  };

  # Intel boards: thermald monitors x86_pkg_temp and reduces frequency on overheat
  # AMD/ARM: thermald not applicable (different thermal subsystems)
  services.thermald = lib.mkIf (boardConfig.cpu == "intel") {
    enable = lib.mkForce true;
    configFile = lib.mkForce (
      pkgs.writeText "thermal-conf.xml" ''
        <ThermalConfiguration>
          <ThermalZones>
            <ThermalZone>
              <Type>x86_pkg_temp</Type>
              <TripPoints>
                <TripPoint>
                  <SensorType>B0D4</SensorType>
                  <Temperature>80000</Temperature>
                  <type>passive</type>
                  <CoolingDevice>
                    <Type>processor</Type>
                    <Path>/sys/devices/system/cpu</Path>
                    <MinState>0</MinState>
                    <MaxState>10</MaxState>
                  </CoolingDevice>
                </TripPoint>
              </TripPoints>
            </ThermalZone>
          </ThermalZones>
        </ThermalConfiguration>
      ''
    );
  };

  environment.systemPackages = lib.mkDefault [
    pkgs.brightnessctl
  ];
}
