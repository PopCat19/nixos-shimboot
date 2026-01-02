# Vesktop Configuration Module
#
# Purpose: Configure Vesktop (Discord client with Vencord) with user preferences
# Dependencies: vesktop package, stylix (for theming)
# Related: packages.nix, window-rules.nix, stylix.nix
#
# This module:
# - Enables Vesktop with custom settings
# - Configures application preferences and appearance
# - Sets up Vencord integration and plugins
# - Integrates with Stylix for automatic theming
_: {
  # Enable Vesktop with custom settings
  programs.vesktop = {
    enable = true;

    # Vesktop settings written to $XDG_CONFIG_HOME/vesktop/settings.json
    # Configuration imported from backup, excluding theme settings (handled by Stylix)
    # See https://github.com/Vencord/Vesktop/blob/main/src/shared/settings.d.ts
    # for available options
    settings = {
      # Application behavior (from backup)
      appBadge = false;
      arRPC = true;
      checkUpdates = false;
      customTitleBar = false;
      disableMinSize = true;
      minimizeToTray = false;
      tray = false;
      staticTitle = true;
      hardwareAcceleration = true;
      notifyAboutUpdates = true;
      autoUpdate = true;
      autoUpdateNotification = true;
      useQuickCss = true;
      enableReactDevtools = false;
      frameless = false;
      transparent = false;
      winCtrlQ = false;
      macosTranslucency = false;
      winNativeTitleBar = false;

      # Discord branch
      discordBranch = "stable";

      # Splash screen theming
      splashBackground = "#000000";
      splashColor = "#ffffff";
      splashTheming = true;

      # Window appearance is handled by Stylix theming

      # Vencord plugin configurations (from backup, filtered)
      plugins = {
        # Core APIs
        BadgeAPI = {enabled = true;};
        CommandsAPI = {enabled = true;};
        ContextMenuAPI = {enabled = true;};
        MessageAccessoriesAPI = {enabled = true;};
        MessageEventsAPI = {enabled = true;};
        NoticesAPI = {enabled = true;};
        ServerListAPI = {enabled = true;};

        # Utility plugins
        NoTrack = {
          enabled = true;
          disableAnalytics = true;
        };
        Settings = {
          enabled = true;
          settingsLocation = "aboveActivity";
        };
        CrashHandler = {enabled = true;};
        Experiments = {
          enabled = true;
          enableIsStaff = false;
          forceStagingBanner = false;
          toolbarDevMenu = false;
        };
        SupportHelper = {enabled = true;};

        # Content enhancement
        BetterNotesBox = {
          enabled = true;
          hide = false;
          noSpellCheck = false;
        };
        BiggerStreamPreview = {enabled = true;};
        BlurNSFW = {
          enabled = true;
          blurAmount = 10;
        };
        ColorSighted = {enabled = true;};
        ForceOwnerCrown = {enabled = true;};
        GifPaste = {enabled = true;};
        ImageZoom = {
          enabled = true;
          size = 750;
          zoom = 2.2;
          nearestNeighbour = false;
          square = false;
          saveZoomValues = true;
          invertScroll = true;
          zoomSpeed = 0.5;
          preventCarouselFromClosingOnClick = true;
        };
        MemberCount = {
          enabled = true;
          memberList = true;
          toolTip = true;
          voiceActivity = true;
        };
        MessageClickActions = {
          enabled = true;
          enableDeleteOnClick = true;
          enableDoubleClickToEdit = true;
          enableDoubleClickToReply = true;
          requireModifier = false;
        };
        MessageTags = {
          enabled = true;
          clyde = true;
          tagsList = {};
        };
        MoreKaomoji = {enabled = true;};
        petpet = {enabled = true;};
        ReadAllNotificationsButton = {enabled = true;};
        RevealAllSpoilers = {enabled = true;};
        ReverseImageSearch = {enabled = true;};
        ReviewDB = {
          enabled = true;
          notifyReviews = true;
          reviewsDropdownState = false;
          showWarning = true;
          hideBlockedUsers = true;
        };
        SilentTyping = {
          enabled = true;
          showIcon = false;
          isEnabled = true;
          contextMenu = true;
        };
        SpotifyControls = {
          enabled = true;
          hoverControls = false;
        };
        SpotifyCrack = {
          enabled = true;
          noSpotifyAutoPause = true;
          keepSpotifyActivityOnIdle = false;
        };
        TypingIndicator = {
          enabled = true;
          includeMutedChannels = false;
          includeBlockedUsers = false;
          includeCurrentChannel = true;
          indicatorMode = 3;
        };
        TypingTweaks = {
          enabled = true;
          showAvatars = true;
          showRoleColors = true;
          alternativeFormatting = true;
        };
        USRBG = {
          enabled = true;
          voiceBackground = true;
          nitroFirst = true;
        };
        ValidUser = {enabled = true;};
        WebContextMenus = {
          enabled = true;
          addBack = false;
        };
        GreetStickerPicker = {enabled = true;};
        WhoReacted = {enabled = true;};
        VoiceMessages = {
          enabled = true;
          noiseSuppression = false;
          echoCancellation = false;
        };
        PictureInPicture = {enabled = true;};
        "AI Noise Suppression" = {enabled = true;};
        NoTypingAnimation = {enabled = true;};
        WebKeybinds = {enabled = true;};
        ChatInputButtonAPI = {enabled = true;};
        NewGuildSettings = {
          enabled = true;
          guild = true;
          everyone = true;
          role = true;
          events = true;
          highlights = true;
          messages = 3;
          showAllChannels = true;
        };
        UserSettingsAPI = {enabled = true;};
        UserMessagesPronouns = {
          enabled = true;
          showInMessages = true;
          showSelf = true;
          pronounSource = 0;
          showInProfile = true;
          pronounsFormat = "LOWERCASE";
        };
        FixYoutubeEmbeds = {enabled = true;};
        YoutubeAdblock = {enabled = true;};
        DisableDeepLinks = {enabled = true;};

        # Enhanced functionality
        FakeNitro = {
          enabled = true;
          enableEmojiBypass = true;
          enableStickerBypass = true;
          enableStreamQualityBypass = true;
          transformStickers = true;
          transformEmojis = true;
          transformCompoundSentence = false;
          emojiSize = 64;
          stickerSize = 256;
          hyperLinkText = "{{NAME}}";
          useHyperLinks = true;
          disableEmbedPermissionCheck = false;
        };
        PinDMs = {
          enabled = true;
          pinOrder = 0;
          dmSectionCollapsed = false;
          canCollapseDmSection = false;
          userBasedCategoryList = {};
        };
        NoProfileThemes = {enabled = true;};
        NoReplyMention = {
          enabled = true;
          userList = "";
          shouldPingListed = true;
          inverseShiftReply = false;
        };
      };

      # Vencord settings
      vencord = {
        enable = true;
        settings = {
          notifyAboutUpdates = true;
          autoUpdate = true;
          autoUpdateNotification = true;
          useQuickCss = true;
        };
        plugins = {
          # Core functionality plugins
          BadgeAPI = true;
          CommandsAPI = true;
          ContextMenuAPI = true;
          MessageAccessoriesAPI = true;
          MessageEventsAPI = true;
          NoticesAPI = true;
          ServerListAPI = true;
          SettingsStoreAPI = false;

          # Utility plugins
          NoTrack = true;
          Settings = true;
          CrashHandler = true;
          Experiments = true;
          SupportHelper = true;

          # Enhanced features
          FakeNitro = true;
          BetterNotesBox = true;
          BiggerStreamPreview = true;
          BlurNSFW = true;
          ColorSighted = true;
          ForceOwnerCrown = true;
          GifPaste = true;
          ImageZoom = true;
          MemberCount = true;
          MessageClickActions = true;
          MessageTags = true;
          MoreKaomoji = true;
          petpet = true;
          PinDMs = true;
          ReadAllNotificationsButton = true;
          RevealAllSpoilers = true;
          ReverseImageSearch = true;
          ReviewDB = true;
          SilentTyping = true;
          SpotifyControls = true;
          SpotifyCrack = true;
          TypingIndicator = true;
          TypingTweaks = true;
          USRBG = true;
          ValidUser = true;
          WebContextMenus = true;
          GreetStickerPicker = true;
          WhoReacted = true;
          VoiceMessages = true;
          PictureInPicture = true;
          "AI Noise Suppression" = true;
          NoTypingAnimation = true;
          WebKeybinds = true;
          ChatInputButtonAPI = true;
          NewGuildSettings = true;
          UserSettingsAPI = true;
          UserMessagesPronouns = true;
          FixYoutubeEmbeds = true;
          YoutubeAdblock = true;
          DisableDeepLinks = true;
        };
      };

      # Additional settings from backup
      notifications = {
        timeout = 5000;
        position = "top-right";
        useNative = "not-focused";
        logLimit = 50;
      };
    };
  };
}
