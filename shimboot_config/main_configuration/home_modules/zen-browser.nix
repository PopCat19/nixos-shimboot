# Zen Browser Configuration Module
# Configures Zen Browser twilight with default extensions and PWA support

{
  pkgs,
  config,
  lib,
  inputs,
  userConfig,
  ...
}:

{
  # Import the Zen Browser Home Manager module
  imports = [ inputs.zen-browser.homeModules.twilight ];

  # Enable Zen Browser with configuration
  programs.zen-browser = {
    enable = true;
    
    # Add PWA support via firefoxpwa
    nativeMessagingHosts = [ pkgs.firefoxpwa ];
    
    # Configure browser policies and extensions
    policies = {
      # Basic browser policies
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
      
      # Enhanced tracking protection
      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
      };
      
      # Default extensions
      ExtensionSettings = {
        # uBlock Origin
        "uBlock0@raymondhill.net" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          installation_mode = "force_installed";
        };
        
        # Dark Reader
        "addon@darkreader.org" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi";
          installation_mode = "force_installed";
        };
        
        # SponsorBlock
        "sponsorBlocker@ajay.app" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/sponsorblock/latest.xpi";
          installation_mode = "force_installed";
        };
        
        # Return YouTube Dislikes
        "{762f9885-5a13-4abd-9c77-433d12138f26}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/return-youtube-dislikes/latest.xpi";
          installation_mode = "force_installed";
        };
        
        # YouTube NonStop
        "youtube-nonstop@eliasfox" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/youtube-nonstop/latest.xpi";
          installation_mode = "force_installed";
        };
      };
      
      # Browser preferences
      Preferences = {
        "browser.tabs.warnOnClose" = {
          Value = true;
          Status = "locked";
        };
        "browser.startup.page" = {
          Value = 3; # Restore previous session
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
