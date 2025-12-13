# Noctalia Settings Configuration
#
# Purpose: Contains the complete Noctalia settings configuration
# Source: Adapted from user's personalized settings for shimboot
#
# This module:
# - Provides complete Noctalia settings as Nix attribute set
# - Simplified configuration for shimboot environment
# - Can be imported by the main Noctalia home manager module
{ pkgs, ... }:

let
  # Complete Noctalia settings based on user's configuration
  settings = {
    settingsVersion = 26;
    
    # Bar configuration with user's custom layout
    bar = {
      position = "top";
      backgroundOpacity = 0.64;
      monitors = [ ];
      density = "default";
      showCapsule = true;
      capsuleOpacity = 1;
      floating = true;
      marginVertical = 0.25;
      marginHorizontal = 0.25;
      outerCorners = true;
      exclusive = true;
      
      widgets = {
        left = [
          {
            icon = "rocket";
            id = "CustomButton";
            leftClickExec = "noctalia-shell ipc call launcher toggle";
            hideMode = "alwaysExpanded";
            showIcon = true;
            textCollapse = "";
            textCommand = "";
            textIntervalMs = 3000;
            textStream = false;
            maxTextLength.horizontal = 10;
            maxTextLength.vertical = 10;
            leftClickUpdateText = false;
            middleClickExec = "";
            middleClickUpdateText = false;
            parseJson = false;
            rightClickExec = "";
            rightClickUpdateText = false;
            wheelDownExec = "";
            wheelDownUpdateText = false;
            wheelExec = "";
            wheelMode = "unified";
            wheelUpExec = "";
            wheelUpUpdateText = false;
            wheelUpdateText = false;
          }
          {
            id = "Workspace";
            hideUnoccupied = false;
            labelMode = "name";
            characterCount = 2;
            followFocusedScreen = false;
          }
          {
            id = "SystemMonitor";
            diskPath = "/";
            showCpuTemp = true;
            showCpuUsage = false;
            showDiskUsage = false;
            showMemoryAsPercent = false;
            showMemoryUsage = true;
            showNetworkStats = false;
            usePrimaryColor = false;
          }
          {
            id = "MediaMini";
            hideMode = "hidden";
            hideWhenIdle = false;
            maxWidth = 256;
            scrollingMode = "hover";
            showAlbumArt = false;
            showArtistFirst = true;
            showProgressRing = true;
            showVisualizer = false;
            useFixedWidth = false;
            visualizerType = "linear";
          }
        ];
        
        center = [ ];
        
        right = [
          {
            id = "Tray";
            blacklist = [ ];
            colorizeIcons = false;
            drawerEnabled = true;
            hidePassive = false;
            pinned = [ ];
          }
          {
            id = "NotificationHistory";
            hideWhenZero = true;
            showUnreadBadge = true;
          }
          {
            id = "Battery";
            displayMode = "alwaysShow";
            showNoctaliaPerformance = false;
            showPowerProfiles = false;
            warningThreshold = 20;
          }
          {
            id = "Volume";
            displayMode = "alwaysShow";
          }
          {
            id = "WiFi";
            displayMode = "onhover";
          }
          {
            id = "Bluetooth";
            displayMode = "onhover";
          }
          {
            id = "Clock";
            formatHorizontal = "HH:mm ddd, MMM dd";
            formatVertical = "HH mm - dd MM";
            useCustomFont = false;
            customFont = "";
            usePrimaryColor = false;
          }
          {
            id = "ControlCenter";
            icon = "noctalia";
            colorizeDistroLogo = false;
            colorizeSystemIcon = "none";
            customIconPath = "";
            enableColorization = false;
            useDistroLogo = false;
          }
        ];
      };
    };
    
    # General appearance settings
    general = {
      avatarImage = "${pkgs.writeText "face" ""}/.face";
      dimmerOpacity = 0.4;
      showScreenCorners = false;
      forceBlackScreenCorners = false;
      scaleRatio = 1;
      radiusRatio = 1;
      iRadiusRatio = 1;
      boxRadiusRatio = 1;
      screenRadiusRatio = 1;
      animationSpeed = 1.2;
      animationDisabled = false;
      compactLockScreen = false;
      lockOnSuspend = false;
      showSessionButtonsOnLockScreen = true;
      showHibernateOnLockScreen = false;
      enableShadows = false;
      shadowDirection = "bottom_right";
      shadowOffsetX = 2;
      shadowOffsetY = 3;
      language = "";
      allowPanelsOnScreenWithoutBar = true;
    };
    
    # UI settings
    ui = {
      fontDefault = "Rounded Mplus 1c Medium";
      fontFixed = "Fira Mono";
      fontDefaultScale = 1;
      fontFixedScale = 1;
      tooltipsEnabled = true;
      panelBackgroundOpacity = 1;
      panelsAttachedToBar = true;
      settingsPanelAttachToBar = false;
    };
    
    # Location settings
    location = {
      name = "New York";
      weatherEnabled = false;
      weatherShowEffects = true;
      useFahrenheit = false;
      use12hourFormat = false;
      showWeekNumberInCalendar = false;
      showCalendarEvents = true;
      showCalendarWeather = true;
      analogClockInCalendar = false;
      firstDayOfWeek = -1;
    };
    
    # Calendar configuration
    calendar = {
      cards = [
        {
          enabled = true;
          id = "calendar-header-card";
        }
        {
          enabled = true;
          id = "calendar-month-card";
        }
        {
          enabled = true;
          id = "timer-card";
        }
        {
          enabled = false;
          id = "weather-card";
        }
      ];
    };
    
    # Screen recorder settings
    screenRecorder = {
      directory = "";
      frameRate = 60;
      audioCodec = "opus";
      videoCodec = "hevc";
      quality = "very_high";
      colorRange = "full";
      showCursor = true;
      audioSource = "default_output";
      videoSource = "portal";
    };
    
    # Wallpaper configuration
    wallpaper = {
      enabled = true;
      overviewEnabled = false;
      directory = "\${home.homeDirectory}/wallpaper";
      monitorDirectories = [ ];
      enableMultiMonitorDirectories = false;
      recursiveSearch = false;
      setWallpaperOnAllMonitors = true;
      fillMode = "crop";
      fillColor = "#000000";
      randomEnabled = false;
      randomIntervalSec = 300;
      transitionDuration = 1500;
      transitionType = "fade";
      transitionEdgeSmoothness = 0.05;
      panelPosition = "follow_bar";
      hideWallpaperFilenames = false;
      useWallhaven = false;
      wallhavenQuery = "";
      wallhavenSorting = "relevance";
      wallhavenOrder = "desc";
      wallhavenCategories = "111";
      wallhavenPurity = "100";
      wallhavenResolutionMode = "atleast";
      wallhavenResolutionWidth = "";
      wallhavenResolutionHeight = "";
    };
    
    # App launcher settings
    appLauncher = {
      enableClipboardHistory = true;
      enableClipPreview = true;
      position = "center";
      pinnedExecs = [ ];
      useApp2Unit = false;
      sortByMostUsed = true;
      terminalCommand = "xterm -e";
      customLaunchPrefixEnabled = false;
      customLaunchPrefix = "";
      viewMode = "list";
      showCategories = true;
    };
    
    # Control center configuration
    controlCenter = {
      position = "close_to_bar_button";
      shortcuts = {
        left = [
          {
            id = "WiFi";
          }
          {
            id = "Bluetooth";
          }
          {
            id = "ScreenRecorder";
          }
          {
            id = "WallpaperSelector";
          }
        ];
        right = [
          {
            id = "Notifications";
          }
          {
            id = "PowerProfile";
          }
          {
            id = "KeepAwake";
          }
          {
            id = "NightLight";
          }
        ];
      };
      cards = [
        {
          enabled = true;
          id = "profile-card";
        }
        {
          enabled = true;
          id = "shortcuts-card";
        }
        {
          enabled = true;
          id = "audio-card";
        }
        {
          enabled = false;
          id = "weather-card";
        }
        {
          enabled = true;
          id = "media-sysmon-card";
        }
      ];
    };
    
    # System monitor settings
    systemMonitor = {
      cpuWarningThreshold = 80;
      cpuCriticalThreshold = 90;
      tempWarningThreshold = 80;
      tempCriticalThreshold = 90;
      memWarningThreshold = 80;
      memCriticalThreshold = 90;
      diskWarningThreshold = 80;
      diskCriticalThreshold = 90;
      cpuPollingInterval = 3000;
      tempPollingInterval = 3000;
      memPollingInterval = 1750;
      diskPollingInterval = 3000;
      networkPollingInterval = 3000;
      useCustomColors = false;
      warningColor = "#31748f";
      criticalColor = "#eb6f92";
    };
    
    # Dock configuration (disabled)
    dock = {
      enabled = false;
      displayMode = "auto_hide";
      backgroundOpacity = 1;
      floatingRatio = 1;
      size = 1;
      onlySameOutput = true;
      monitors = [ ];
      pinnedApps = [ ];
      colorizeIcons = false;
      pinnedStatic = false;
      inactiveIndicators = false;
      deadOpacity = 0.6;
    };
    
    # Network configuration
    network = {
      wifiEnabled = true;
    };
    
    # Session menu settings
    sessionMenu = {
      enableCountdown = true;
      countdownDuration = 10000;
      position = "center";
      showHeader = true;
      powerOptions = [
        {
          action = "lock";
          enabled = true;
          command = "";
          countdownEnabled = true;
        }
        {
          action = "suspend";
          enabled = true;
          command = "";
          countdownEnabled = true;
        }
        {
          action = "reboot";
          enabled = true;
          command = "";
          countdownEnabled = true;
        }
        {
          action = "logout";
          enabled = true;
          command = "";
          countdownEnabled = true;
        }
        {
          action = "shutdown";
          enabled = true;
          command = "";
          countdownEnabled = true;
        }
      ];
    };
    
    # Notifications settings
    notifications = {
      enabled = true;
      monitors = [ ];
      location = "top_right";
      overlayLayer = true;
      backgroundOpacity = 0.8;
      respectExpireTimeout = false;
      lowUrgencyDuration = 3;
      normalUrgencyDuration = 8;
      criticalUrgencyDuration = 15;
      enableKeyboardLayoutToast = true;
      sounds = {
        enabled = false;
        volume = 0.5;
        separateSounds = false;
        criticalSoundFile = "";
        normalSoundFile = "";
        lowSoundFile = "";
        excludedApps = "discord,firefox,chrome,chromium,edge";
      };
    };
    
    # OSD settings
    osd = {
      enabled = true;
      location = "top";
      autoHideMs = 2000;
      overlayLayer = true;
      backgroundOpacity = 0.8;
      enabledTypes = [ 0 1 2 ];
      monitors = [ ];
    };
    
    # Audio settings
    audio = {
      volumeStep = 4;
      volumeOverdrive = true;
      cavaFrameRate = 30;
      visualizerType = "linear";
      visualizerQuality = "high";
      mprisBlacklist = [ ];
      preferredPlayer = "";
      externalMixer = "pwvucontrol || pavucontrol";
    };
    
    # Brightness settings
    brightness = {
      brightnessStep = 10;
      enforceMinimum = true;
      enableDdcSupport = false;
    };
    
    # Color schemes
    colorSchemes = {
      useWallpaperColors = false;
      predefinedScheme = "Rose Pine";
      darkMode = true;
      schedulingMode = "off";
      manualSunrise = "06:30";
      manualSunset = "18:30";
      matugenSchemeType = "scheme-fruit-salad";
      generateTemplatesForPredefined = true;
    };
    
    # Templates (all disabled)
    templates = {
      gtk = false;
      qt = false;
      kcolorscheme = false;
      alacritty = false;
      kitty = false;
      ghostty = false;
      foot = false;
      wezterm = false;
      fuzzel = false;
      discord = false;
      pywalfox = false;
      vicinae = false;
      walker = false;
      code = false;
      spicetify = false;
      telegram = false;
      cava = false;
      emacs = false;
      niri = false;
      enableUserTemplates = false;
    };
    
    # Night light (disabled)
    nightLight = {
      enabled = false;
      forced = false;
      autoSchedule = false;
      nightTemp = "4000";
      dayTemp = "6500";
      manualSunrise = "06:30";
      manualSunset = "18:30";
    };
    
    # Hooks (disabled)
    hooks = {
      enabled = false;
      wallpaperChange = "";
      darkModeChange = "";
    };
  };
in {
  inherit settings;
}