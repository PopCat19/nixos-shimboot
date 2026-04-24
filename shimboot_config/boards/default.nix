# ChromeOS Board Hardware Database
#
# Purpose: Define hardware characteristics for each ChromeOS board
#
# This module provides board-specific configuration for:
# - WiFi kernel modules
# - CPU type (intel/amd/arm)
# - GPU type for graphics drivers
# - Thermal management approach
#
# Reference: https://cros.download/ for board recovery images
{
  lib,
  ...
}:
{
  # Intel boards (Jasper Lake / Apollo Lake / Alder Lake / Gemini Lake)
  # All use Intel WiFi (AX201/AX210), Intel GPU, require intel_pstate

  dedede = {
    cpu = "intel";
    gpu = "intel";
    wifi = "intel";
    wifiModules = [
      "iwlmvm" # Intel WiFi MVM driver
      "ccm" # CCM encryption module for Intel WiFi
    ];
    kernel = "5.4+";
    audio = false; # No speaker driver currently
    touchscreen = true;
    powerManagement = "intel_pstate";
    thermal = "thermald";
  };

  octopus = {
    cpu = "intel";
    gpu = "intel";
    wifi = "intel";
    wifiModules = [ "iwlmvm" "ccm" ];
    kernel = "4.14"; # Older kernel, some features may lack
    audio = true;
    touchscreen = true;
    powerManagement = "intel_pstate";
    thermal = "thermald";
  };

  nissa = {
    cpu = "intel";
    gpu = "intel";
    wifi = "intel";
    wifiModules = [ "iwlmvm" "ccm" ];
    kernel = "5.10+";
    audio = false;
    touchscreen = true;
    powerManagement = "intel_pstate";
    thermal = "thermald";
  };

  hatch = {
    cpu = "intel";
    gpu = "intel";
    wifi = "intel";
    wifiModules = [ "iwlmvm" "ccm" ];
    kernel = "5.4";
    audio = false;
    # Note: 5GHz WiFi networks may have connectivity issues
    powerManagement = "intel_pstate";
    thermal = "thermald";
  };

  brya = {
    cpu = "intel";
    gpu = "intel";
    wifi = "intel";
    wifiModules = [ "iwlmvm" "ccm" ];
    kernel = "5.10+";
    audio = false;
    touchscreen = false;
    powerManagement = "intel_pstate";
    thermal = "thermald";
  };

  snappy = {
    cpu = "intel";
    gpu = "intel";
    wifi = "intel";
    wifiModules = [ "iwlmvm" "ccm" ];
    kernel = "5.4";
    audio = true;
    touchscreen = true;
    powerManagement = "intel_pstate";
    thermal = "thermald";
  };

  # AMD boards (Ryzen / Stoney Ridge)
  # Use AMD GPU, MediaTek or Realtek WiFi, different power management

  zork = {
    cpu = "amd";
    gpu = "amd";
    wifi = "mediatek"; # MT7921E
    wifiModules = [
      "mt7921e" # MediaTek MT7921E WiFi driver
    ];
    kernel = "5.4";
    audio = false;
    powerManagement = "amd-pstate"; # Newer AMD
    thermal = null; # thermald not for AMD
  };

  grunt = {
    cpu = "amd";
    gpu = "amd";
    wifi = "realtek"; # May require manual driver compilation
    wifiModules = [ ]; # Board-specific, check documentation
    kernel = "4.14"; # Older kernel
    audio = false;
    powerManagement = "amd-pstate"; # Or cpufreq
    thermal = null;
  };

  # ARM boards (MediaTek / Qualcomm)
  # Use Mali/Adreno GPU, ARM-specific power management

  jacuzzi = {
    cpu = "arm";
    gpu = "mali"; # ARM Mali GPU
    wifi = "mediatek";
    wifiModules = [ ]; # Built-in or board-specific
    kernel = "5.4";
    audio = false;
    powerManagement = "cpufreq"; # ARM uses cpufreq governors
    thermal = null; # ARM uses different thermal subsystem
  };

  corsola = {
    cpu = "arm";
    gpu = "mali";
    wifi = "mediatek";
    wifiModules = [ ];
    kernel = "5.15";
    audio = false;
    powerManagement = "cpufreq";
    thermal = null;
  };

  hana = {
    cpu = "arm";
    gpu = "mali";
    wifi = "mediatek";
    wifiModules = [ ];
    kernel = "5.4";
    audio = false;
    touchscreen = false;
    webcam = false;
    powerManagement = "cpufreq";
    thermal = null;
  };

  trogdor = {
    cpu = "arm"; # Qualcomm Snapdragon SC7180
    gpu = "adreno"; # Qualcomm Adreno GPU
    wifi = "qualcomm"; # ath10k
    wifiModules = [
      "ath10k_pci"
      "ath10k_core"
    ];
    kernel = "5.4";
    audio = false;
    # Note: WiFi connectivity may have issues per shimboot README
    powerManagement = "cpufreq";
    thermal = null;
  };
}