# Hardware Configuration Module
#
# Purpose: Configure hardware settings for ChromeOS devices
# Dependencies: linux-firmware, mesa, brightnessctl, thermald
# Related: boot.nix, display.nix
#
# This module:
# - Enables redistributable firmware for ChromeOS compatibility
# - Configures graphics drivers with 32-bit support
# - Enables Bluetooth with power-on-boot
# - Provides brightness control utilities
# - Enables thermal daemon for CPU temperature management
{
  config,
  pkgs,
  lib,
  userConfig,
  ...
}: {
  hardware = {
    # enableRedistributableFirmware = true;
    graphics = {
      enable = true;
      enable32Bit = lib.mkDefault false;
    };
    bluetooth = {
      enable = lib.mkDefault true;
      powerOnBoot = lib.mkDefault true;
    };
  };

  services.thermald = {
    enable = true;
    configFile = pkgs.writeText "thermal-conf.xml" ''
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
    '';
  };

  environment.systemPackages = [
    pkgs.brightnessctl
  ];
}
