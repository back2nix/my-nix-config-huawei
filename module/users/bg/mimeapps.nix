{pkgs, config, ...}: let
  mailApp = "thunderbird.desktop";
  browser = "${config.programs.google-chrome.finalPackage}/bin/google-chrome-stable";
  linkHandler = pkgs.writeScriptBin "open-browser-link" ''
    #!${pkgs.python3}/bin/python3
    import os
    import sys
    from urllib.parse import urlsplit

    urls = []
    for url in sys.argv[1:]:
        try:
            parsed = urlsplit(url)
            host = (parsed.hostname or "").lower().rstrip(".")
        except ValueError:
            continue
        # Match the hostname, rather than text in the path or query string.
        if parsed.scheme.lower() in ("http", "https") and (
            host == "claude.ai" or host.endswith(".claude.ai")
        ):
            continue
        urls.append(url)

    if urls:
        os.execv("${browser}", ["${browser}", "--", *urls])
  '';
in {
  home.packages = [linkHandler];
  home.sessionVariables.BROWSER = "${linkHandler}/bin/open-browser-link";

  xdg = {
    enable = true;
    desktopEntries.open-browser-link = {
      name = "Chrome (filtered links)";
      exec = "${linkHandler}/bin/open-browser-link %U";
      icon = "google-chrome";
      terminal = false;
      noDisplay = true;
      mimeType = ["x-scheme-handler/http" "x-scheme-handler/https"];
    };
    mimeApps = {
      enable = true;
      defaultApplications = {
        "application/pdf" = ["org.gnome.Evince.desktop"];
        "text/html" = "google-chrome.desktop";
        "x-scheme-handler/http" = "open-browser-link.desktop";
        "x-scheme-handler/https" = "open-browser-link.desktop";
        "x-scheme-handler/about" = "google-chrome.desktop";
        "x-scheme-handler/unknown" = "google-chrome.desktop";
        "image/jpeg" = ["org.gnome.Loupe.desktop"];
        "image/png" = ["org.gnome.Loupe.desktop"];
        "image/gif" = ["org.gnome.Loupe.desktop"];
        "text/*" = "nvim.desktop";
        "video/*" = "vlc.desktop";
        "x-scheme-handler/msteams" = "teams-for-linux.desktop";
      };
      associations = {
        added = {
          "application/zip" = "org.gnome.FileRoller.desktop";
          "x-scheme-handler/jetbrains" = "jetbrains-toolbox.desktop";
          "application/x-extension-ics" = mailApp;
          "x-scheme-handler/mailto" = mailApp;
          "x-scheme-handler/mid" = mailApp;
          "x-scheme-handler/webcal" = mailApp;
          "x-scheme-handler/webcals" = mailApp;
          "x-scheme-handler/msteams" = "teams-for-linux.desktop";
        };
        removed = {
          "image/jpeg" = [
            "gimp.desktop"
            "org.gnome.eog.desktop"
          ];
          "image/png" = [
            "gimp.desktop"
            "org.gnome.eog.desktop"
          ];
          "image/gif" = [
            "gimp.desktop"
            "org.gnome.eog.desktop"
          ];
        };
      };
    };
  };
}
