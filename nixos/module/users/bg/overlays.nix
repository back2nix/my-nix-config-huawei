self: super: {
  yandex-browser = self.callPackage ./overlays/yandex-browser.nix { };
  # genymotion = self.callPackage ./overlays/genymotion.nix { };
}
