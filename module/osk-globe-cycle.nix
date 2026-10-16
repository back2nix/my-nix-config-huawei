# File: module/osk-globe-cycle.nix
#
# Расширение gnome-shell с тремя доработками экранной клавиатуры:
#
#   * кнопка-глобус сразу переключает раскладку вместо открытия меню выбора
#     языка (меню не реагирует на касания в модальных диалогах — Alt+F2,
#     экран блокировки — потому что лежит вне поддерева, захваченного
#     Main.pushModal);
#   * ru-extended.json для полей ввода с purpose = TERMINAL, где иначе
#     всегда подставлялась us-extended;
#   * extended-раскладка (стрелки, Tab, Ctrl, Alt) во всех полях ввода, а не
#     только в терминальных;
#   * ввод слов ведением пальца по клавишам (свайп), как на телефоне.
#
# Подробности реализации — в комментариях внутри gnome-extensions/.
{pkgs, ...}: let
  uuid = "osk-globe-cycle@back2nix";

  # Частотные списки hermitdave/FrequencyWords: «слово частота» по строке.
  # Ревизия зафиксирована — master в этом репозитории переписывается.
  frequencyWordsRev = "f8a65e6ddc17e0baa2e366a909986798d8dbe55b";

  fetchFrequencyList = {
    language,
    hash,
  }:
    pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/hermitdave/FrequencyWords/${frequencyWordsRev}/content/2018/${language}/${language}_50k.txt";
      inherit hash;
    };

  # Словари для распознавания свайпа. Из исходных списков остаются только
  # слова, набираемые одними буквенными клавишами: цифры, дефисы и латиница
  # в русском списке всё равно не имеют клавиш на раскладке.
  #
  # «ё» сводится к «е» с суммированием частот: на раскладке ru эта буква
  # доступна только долгим нажатием, то есть провести по ней пальцем нельзя.
  dictionaries =
    pkgs.runCommand "osk-swipe-dictionaries" {
      ruList = fetchFrequencyList {
        language = "ru";
        hash = "sha256-YJX1B8wWdIjsZq2lqFrFBDNQOgitJKB8bqvfVDUsTn8=";
      };
      enList = fetchFrequencyList {
        language = "en";
        hash = "sha256-U1H/QFsRJu9VV5HdTZeYpI4+mlAan8SBqdqVd1LPtFg=";
      };
      nativeBuildInputs = [pkgs.gawk];
    } ''
      export LC_ALL=C.UTF-8
      mkdir -p "$out"

      normalize() {
        gawk -v allowed="$2" '
          {
            word = tolower($1)
            frequency = $2 + 0
            gsub(/ё/, "е", word)
            if (word ~ allowed && length(word) >= 2 && length(word) <= 20)
              total[word] += frequency
          }
          END {
            for (word in total)
              print word, total[word]
          }
        ' "$1" | sort -k2,2nr -k1,1
      }

      normalize "$ruList" '^[а-я]+$' > "$out/ru.txt"
      normalize "$enList" '^[a-z]+$' > "$out/en.txt"

      for file in "$out"/*.txt; do
        test -s "$file" || { echo "пустой словарь: $file" >&2; exit 1; }
      done
    '';

  # us-extended.json из того gnome-shell, с которым собирается система.
  # Кладётся в наш GResource под именем us.json — см. ниже.
  usExtended =
    pkgs.runCommand "osk-us-extended" {
      nativeBuildInputs = [pkgs.glib];
    } ''
      gresource extract \
        "${pkgs.gnome-shell}/share/gnome-shell/gnome-shell-osk-layouts.gresource" \
        /org/gnome/shell/osk-layouts/us-extended.json > "$out"
    '';

  extension = pkgs.stdenvNoCC.mkDerivation {
    pname = "gnome-shell-extension-osk-globe-cycle";
    version = "2.0";
    src = ./gnome-extensions/osk-globe-cycle;

    nativeBuildInputs = [pkgs.glib];

    buildPhase = ''
      runHook preBuild

      # Стрелки, Tab, Ctrl и Alt есть только в «*-extended» раскладках, а их
      # gnome-shell берёт лишь для purpose = TERMINAL. Регистрируем те же
      # раскладки под обычными именами — тогда extended работает везде.
      cp ru-extended.json ru.json
      cp ${usExtended}    us.json

      glib-compile-resources \
        --target=osk-layouts.gresource \
        --sourcedir=. \
        osk-layouts.gresource.xml

      glib-compile-schemas schemas

      # Помощник захвата клавиатуры запускается из gnome-shell, а там в PATH
      # питона может не быть вовсе — прописываем абсолютный путь и в шебанге,
      # и в командной строке Gio.Subprocess.
      patchShebangs helpers
      substituteInPlace lib/kbdLock.js \
        --replace-fail "'python3'" "'${pkgs.python3}/bin/python3'"

      runHook postBuild
    '';

    installPhase = let
      target = "$out/share/gnome-shell/extensions/${uuid}";
    in ''
      runHook preInstall

      install -Dm444 metadata.json         -t "${target}"
      install -Dm444 extension.js          -t "${target}"
      install -Dm444 osk-layouts.gresource -t "${target}"

      cp -r lib     "${target}/lib"
      cp -r schemas "${target}/schemas"
      cp -r helpers "${target}/helpers"
      cp -r ${dictionaries} "${target}/dictionaries"

      chmod -R a-w,a+rX "${target}/lib" "${target}/schemas" "${target}/dictionaries"

      # Помощнику нужен бит исполнения: его запускают как отдельный процесс.
      chmod -R a-w,a+rX "${target}/helpers"
      chmod a+x "${target}/helpers/kbd-grab.py"

      runHook postInstall
    '';

    passthru = {
      extensionUuid = uuid;
      inherit dictionaries;
    };
  };
in {
  environment.systemPackages = [extension];
}
