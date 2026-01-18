# Environment Variables Module
#
# Purpose: Configure system-wide environment variables for applications.
# Dependencies: vars
# Related: home/environment.nix
#
# This module:
# - Sets environment variables for default applications
# - Configures WebKit compositing mode
{ vars, ... }:
{
  environment.variables = {
    BROWSER = vars.defaultApps.browser.package;
    TERMINAL = vars.defaultApps.terminal.command;
    FILE_MANAGER = vars.defaultApps.fileManager.package;
    WEBKIT_DISABLE_COMPOSITING_MODE = "1";
  };
}
