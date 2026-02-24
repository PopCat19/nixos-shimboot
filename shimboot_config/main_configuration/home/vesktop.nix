# vesktop.nix
#
# Purpose: Configure Vesktop (Discord client with Vencord) with user preferences
#
# This module:
# - Enables Vesktop with custom settings
# - Configures Vencord integration and plugins
_: {
  programs.vesktop = {
    enable = true;

    settings = {
      appBadge = false;
      arRPC = true;
      autoUpdate = true;
      autoUpdateNotification = true;
      checkUpdates = false;
      customTitleBar = false;
      disableMinSize = true;
      discordBranch = "stable";
      enableReactDevtools = false;
      frameless = false;
      hardwareAcceleration = true;
      macosTranslucency = false;
      minimizeToTray = false;
      notifyAboutUpdates = true;
      staticTitle = true;
      tray = false;
      transparent = false;
      useQuickCss = true;
      winCtrlQ = false;
      winNativeTitleBar = false;

      splashBackground = "#000000";
      splashColor = "#ffffff";
      splashTheming = true;
    };

    vencord.settings = {
      autoUpdate = true;
      autoUpdateNotification = true;
      notifyAboutUpdates = true;
      useQuickCss = true;

      notifications = {
        logLimit = 50;
        position = "top-right";
        timeout = 5000;
        useNative = "not-focused";
      };

      plugins = {
        "AI Noise Suppression".enabled = true;
        BadgeAPI.enabled = true;
        BetterNotesBox = {
          enabled = true;
          hide = false;
          noSpellCheck = false;
        };
        BiggerStreamPreview.enabled = true;
        BlurNSFW = {
          enabled = true;
          blurAmount = 10;
        };
        ChatInputButtonAPI.enabled = true;
        ColorSighted.enabled = true;
        CommandsAPI.enabled = true;
        ContextMenuAPI.enabled = true;
        CrashHandler.enabled = true;
        DisableDeepLinks.enabled = true;
        Experiments = {
          enabled = true;
          enableIsStaff = false;
          forceStagingBanner = false;
          toolbarDevMenu = false;
        };
        FakeNitro = {
          enabled = true;
          disableEmbedPermissionCheck = false;
          emojiSize = 64;
          enableEmojiBypass = true;
          enableStickerBypass = true;
          enableStreamQualityBypass = true;
          hyperLinkText = "{{NAME}}";
          stickerSize = 256;
          transformCompoundSentence = false;
          transformEmojis = true;
          transformStickers = true;
          useHyperLinks = true;
        };
        FixYoutubeEmbeds.enabled = true;
        ForceOwnerCrown.enabled = true;
        GifPaste.enabled = true;
        GreetStickerPicker.enabled = true;
        ImageZoom = {
          enabled = true;
          invertScroll = true;
          nearestNeighbour = false;
          preventCarouselFromClosingOnClick = true;
          saveZoomValues = true;
          size = 750;
          square = false;
          zoom = 2.2;
          zoomSpeed = 0.5;
        };
        MemberCount = {
          enabled = true;
          memberList = true;
          toolTip = true;
          voiceActivity = true;
        };
        MessageAccessoriesAPI.enabled = true;
        MessageClickActions = {
          enabled = true;
          enableDeleteOnClick = true;
          enableDoubleClickToEdit = true;
          enableDoubleClickToReply = true;
          requireModifier = false;
        };
        MessageEventsAPI.enabled = true;
        MessageTags = {
          enabled = true;
          clyde = true;
          tagsList = { };
        };
        MoreKaomoji.enabled = true;
        NewGuildSettings = {
          enabled = true;
          everyone = true;
          events = true;
          guild = true;
          highlights = true;
          messages = 3;
          role = true;
          showAllChannels = true;
        };
        NoProfileThemes.enabled = true;
        NoReplyMention = {
          enabled = true;
          inverseShiftReply = false;
          shouldPingListed = true;
          userList = "";
        };
        NoTrack = {
          enabled = true;
          disableAnalytics = true;
        };
        NoTypingAnimation.enabled = true;
        NoticesAPI.enabled = true;
        PictureInPicture.enabled = true;
        PinDMs = {
          enabled = true;
          canCollapseDmSection = false;
          dmSectionCollapsed = false;
          pinOrder = 0;
          userBasedCategoryList = { };
        };
        ReadAllNotificationsButton.enabled = true;
        ReverseImageSearch.enabled = true;
        RevealAllSpoilers.enabled = true;
        ReviewDB = {
          enabled = true;
          hideBlockedUsers = true;
          notifyReviews = true;
          reviewsDropdownState = false;
          showWarning = true;
        };
        ServerListAPI.enabled = true;
        Settings = {
          enabled = true;
          settingsLocation = "aboveActivity";
        };
        SilentTyping = {
          enabled = true;
          contextMenu = true;
          isEnabled = true;
          showIcon = false;
        };
        SpotifyControls = {
          enabled = true;
          hoverControls = false;
        };
        SpotifyCrack = {
          enabled = true;
          keepSpotifyActivityOnIdle = false;
          noSpotifyAutoPause = true;
        };
        SupportHelper.enabled = true;
        TypingIndicator = {
          enabled = true;
          includeBlockedUsers = false;
          includeCurrentChannel = true;
          includeMutedChannels = false;
          indicatorMode = 3;
        };
        TypingTweaks = {
          enabled = true;
          alternativeFormatting = true;
          showAvatars = true;
          showRoleColors = true;
        };
        USRBG = {
          enabled = true;
          nitroFirst = true;
          voiceBackground = true;
        };
        UserMessagesPronouns = {
          enabled = true;
          pronounSource = 0;
          pronounsFormat = "LOWERCASE";
          showInMessages = true;
          showInProfile = true;
          showSelf = true;
        };
        UserSettingsAPI.enabled = true;
        ValidUser.enabled = true;
        VoiceMessages = {
          enabled = true;
          echoCancellation = false;
          noiseSuppression = false;
        };
        WebContextMenus = {
          enabled = true;
          addBack = false;
        };
        WebKeybinds.enabled = true;
        WhoReacted.enabled = true;
        YoutubeAdblock.enabled = true;
        petpet.enabled = true;
      };
    };
  };
}
