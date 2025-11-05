# Environment Variables Module
#
# Purpose: Configure system-wide environment variables for applications.
# Dependencies: userConfig
# Related: home_modules/environment.nix
#
# This module:
# - Sets environment variables for default applications
# - Configures WebKit compositing mode
{
  config,
  userConfig,
  ...
}: {
  environment.variables = {
    BROWSER = userConfig.defaultApps.browser.package;
    TERMINAL = userConfig.defaultApps.terminal.command;
    FILE_MANAGER = userConfig.defaultApps.fileManager.package;
    WEBKIT_DISABLE_COMPOSITING_MODE = "1";
  };
}