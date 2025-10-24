# Zen Browser Module
#
# Purpose: Configure Zen Browser with privacy extensions and PWA support
# Dependencies: zen-browser, firefoxpwa
# Related: None
#
# This module:
# - Enables Zen Browser with privacy-focused policies
# - Installs essential extensions (uBlock Origin, Dark Reader, etc.)
# - Configures dark theme and compact mode
# - Enables PWA support

{
  pkgs,
  config,
  lib,
  zen-browser,
  userConfig,
  ...
}: {
  imports = [zen-browser.homeModules.twilight];

  programs.zen-browser = {
    enable = true;

    nativeMessagingHosts = [pkgs.firefoxpwa];

    policies = {
      DisableAppUpdate = true;
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DisableFeedbackCommands = true;
      DontCheckDefaultBrowser = true;
      NoDefaultBookmarks = true;
      OfferToSaveLogins = false;
      AutofillAddressEnabled = false;
      AutofillCreditCardEnabled = false;

      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
      };

      ExtensionSettings = {
        "uBlock0@raymondhill.net" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          installation_mode = "force_installed";
        };

        "addon@darkreader.org" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi";
          installation_mode = "force_installed";
        };

        "sponsorBlocker@ajay.app" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/sponsorblock/latest.xpi";
          installation_mode = "force_installed";
        };

        "{762f9885-5a13-4abd-9c77-433d12138f26}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/return-youtube-dislikes/latest.xpi";
          installation_mode = "force_installed";
        };

        "youtube-nonstop@eliasfox" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/youtube-nonstop/latest.xpi";
          installation_mode = "force_installed";
        };
      };

      Preferences = {
        "browser.tabs.warnOnClose" = {
          Value = true;
          Status = "locked";
        };
        "browser.startup.page" = {
          Value = 3;
          Status = "locked";
        };
        "browser.compactmode.show" = {
          Value = true;
          Status = "locked";
        };
        "zen.theme.mode" = {
          Value = "dark";
          Status = "locked";
        };
        "zen.view.compact" = {
          Value = true;
          Status = "locked";
        };
      };
    };
  };
}
