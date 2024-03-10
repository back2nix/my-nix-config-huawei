{pkgs, ...}: let
  wordpress-language-ru = pkgs.stdenv.mkDerivation {
    name = "wordpress-${pkgs.wordpress.version}-language-ru";
    src = pkgs.fetchurl {
      url = "https://ru.wordpress.org/wordpress-${pkgs.wordpress.version}-ru_RU.tar.gz";
      hash = "sha256-6YPLK1ZiHqn3rG7WEehCalcDONLA5fXTdtOMTpCWQvU=";
    };
    installPhase = "mkdir -p $out; cp -r ./wp-content/languages/* $out/";
  };
in {
  systemd.services."wordpress-mkdir-uploads" = {
    enable = true;
    description = "bar";
    after = ["wordpress-init-localhost.service"];
    unitConfig = {
      Type = "simple";
    };
    serviceConfig = {
      ExecStart = "/etc/nixos/module/wordpress-mkdir-uploads.sh";
    };
    wantedBy = ["multi-user.target"];
  };

  services.wordpress.sites."localhost" = {
    languages = [wordpress-language-ru];
    package = pkgs.wordpress6_4;
    settings = {
      WP_DEBUG = true;
      WP_DEBUG_LOG = true;
    };
    # sudo su
    # cd /var/lib/wordpress/localhost
    # ln -s wp-content/uploads uploads
    extraConfig = ''
      define('FS_METHOD', 'direct');
      define('WP_CONTENT_DIR', '/var/lib/wordpress/localhost/wp-content');
      define('WP_CONTENT_URL', 'http://' . $_SERVER['SERVER_NAME'] . '/wp-content');
      define('WP_THEME_DIR', '/var/lib/wordpress/localhost/wp-content/themes');
      define('WP_PLUGIN_DIR', '/var/lib/wordpress/localhost/wp-content/plugins');
      define('WP_PLUGIN_URL', 'http://' . $_SERVER['SERVER_NAME'] . '/wp-content/plugins');
      ini_set( 'error_log', '/var/lib/wordpress/localhost/debug.log' );
    '';
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/wordpress/localhost 0750 wordpress wwwrun - -"
    "d /var/lib/wordpress/localhost/wp-content 0750 wordpress wwwrun - -"
    "d /var/lib/wordpress/localhost/wp-content/plugins 0750 wordpress wwwrun - -"
    "d /var/lib/wordpress/localhost/wp-content/themes 0750 wordpress wwwrun - -"
    "d /var/lib/wordpress/localhost/wp-content/upgrade 0750 wordpress wwwrun - -"
  ];
}
