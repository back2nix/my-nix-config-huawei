{ ... }: let
  mailApp = "thunderbird.desktop";
in {
  xdg = {
    enable = true;
    mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = "google-chrome.desktop";
        "x-scheme-handler/http" = "google-chrome.desktop";
        "x-scheme-handler/https" = "google-chrome.desktop";
        "x-scheme-handler/about" = "google-chrome.desktop";
        "x-scheme-handler/unknown" = "google-chrome.desktop";
        "image/jpeg" = ["org.gnome.eog.desktop"];
        "image/png" = ["org.gnome.eog.desktop"];
        "image/gif" = ["org.gnome.eog.desktop"];
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
          "image/jpeg" = ["gimp.desktop"];
          "image/png" = ["gimp.desktop"];
          "image/gif" = ["gimp.desktop"];
        };
      };
    };
  };
}
