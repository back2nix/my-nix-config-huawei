{
  pkgs,
  pkgs-master,
  ...
}: {
  home.packages = with pkgs; [
    alejandra
    nix-init # <- generate nix package expressions from url
    nix-inspect # <- configuration inspector
    nix-melt # <- flake.lock explorer
    nixfmt-rfc-style
    nixpkgs-review
    nvd # <- diff package changes between versions
  ];
}
