{ config
, ...
}:
{
  programs = {
    nixvim.enable = true;

    nixvim = {
      globals = {
        mapleader = " ";
        maplocalleader = ",";
      };

      # colorschemes.gruvbox.enable = true;
      colorschemes.dracula.enable = true;

      clipboard = {
        register = "unnamedplus";
        # TODO: Make conditional if X11/Wayland enabled
        # providers.wl-copy.enable = true;
        providers.xclip.enable = true;
        #providers.xsel.enable = false;
      };

      opts = {
        number = true; # Show line numbers
        relativenumber = true; # Show relative line numbers
        incsearch = true;
        expandtab = true;
        shiftwidth = 2; # Tab width should be 2
        tabstop = 2;
        termguicolors = true;
        ignorecase = true;
        smartcase = true;
      };

      # extraPlugins = with pkgs.vimPlugins; [
      #   nvim-gdb
      # ];

      luaLoader.enable = true;

      #extraPlugins = [ pkgs.vimPlugins.hop-nvim ];

      plugins = {
        # lightline.enable = true;
        dap = {
          enable = true;
          extensions = {
            dap-go.enable = true;
            dap-python.enable = true;
            dap-ui = {
              enable = true;
              controls.enabled = false;
            };
            dap-virtual-text.enable = true;
          };
        };

        noice = {
          enable = true;
        };

        airline = {
          enable = true;
          settings = {
            powerline_fonts = true;
          };
        };
        alpha = {
          enable = true;
          theme = "dashboard";
          iconsEnabled = true;
        };

        bufferline = {
          enable = true;
          diagnostics = "nvim_lsp";
          numbers = "ordinal";
        };

        #comment.enable = true;
        #comment-nvim.enable = true;
        commentary.enable = true;
        diffview.enable = true;
        fugitive.enable = true;
        gitsigns = {
          enable = true;
          settings.current_line_blame = true;
        };
        leap.enable = true;
        lsp-format.enable = true;
        markdown-preview = {
          enable = true;
          autoClose = true;
        };

        # mini.enable = true;
        navbuddy.enable = true;
        # neorg.enable = true;
        # File tree
        # nvim-tree = {
        #   enable = true;
        #   diagnostics.enable = true;
        #   git.enable = true;
        # };
        neo-tree = {
          enable = true;
          enableDiagnostics = true;
          enableGitStatus = true;
          enableModifiedMarkers = true;
          enableRefreshOnWrite = true;
          closeIfLastWindow = true;
          popupBorderStyle = "rounded"; # Type: null or one of “NC”, “double”, “none”, “rounded”, “shadow”, “single”, “solid” or raw lua code
          buffers = {
            bindToCwd = false;
            followCurrentFile = {
              enabled = true;
            };
          };
          window = {
            width = 40;
            height = 15;
            autoExpandWidth = false;
            mappings = {
              "<space>" = "none";
            };
          };
        };

        nix = {
          enable = true;
        };

        notify.enable = true;
        sniprun.enable = true;
        surround.enable = true;
        hop = {
          enable = true;
          settings = {
            keys = "srtnyeiafg";
          };
        };

        telescope = {
          enable = true;
          extensions = {
            fzf-native = {
              enable = true;
            };
          };
        };

        todo-comments = {
          enable = true;
          colors = {
            error = ["DiagnosticError" "ErrorMsg" "#DC2626"];
            warning = ["DiagnosticWarn" "WarningMsg" "#FBBF24"];
            info = ["DiagnosticInfo" "#2563EB"];
            hint = ["DiagnosticHint" "#10B981"];
            default = ["Identifier" "#7C3AED"];
            test = ["Identifier" "#FF00FF"];
          };
        };

        floaterm.enable = true;
        # https://github.com/jackyliu16/home-manager/blob/f792c1c57e240d24064850c6221719ad758c6c6b/vimAndNeovim/nixvim.nix#L97
        treesitter = {
          enable = true;
          indent = true;
          ensureInstalled = [ "rust" "python" "c" "cpp" "toml" "nix" "go" "java" ];
          grammarPackages = with config.programs.nixvim.plugins.treesitter.package.builtGrammars; [
            c
            go
            cpp
            nix
            bash
            html
            # help
            latex
            python
            rust
          ];
        };
        treesitter-context.enable = true;
        trouble.enable = true;
        which-key.enable = true;

        # Language server
        lsp = {
          enable = true;
          servers = {
            # Average webdev LSPs
            gopls = {
              enable = true;
              autostart = true;
            };

            svelte.enable = false; # Svelte
            vuels.enable = false; # Vue
            tsserver.enable = true; # TS/JS
            cssls.enable = true; # CSS
            tailwindcss.enable = true; # TailwindCSS
            html.enable = true; # HTML
            astro.enable = true; # AstroJS
            phpactor.enable = true; # PHP

            # Python
            pyright.enable = true;
            # Markdown
            marksman.enable = true;
            # Nix
            nil_ls.enable = true;
            # Docker
            dockerls.enable = true;
            # Bash
            bashls.enable = true;
            # C/C++
            clangd.enable = true;
            # C#
            csharp-ls.enable = true;
            # Lua
            lua-ls = {
              enable = true;
              settings.telemetry.enable = false;
            };
            # Rust
            # rust-analyzer = {
            #   enable = true;
            #   installRustc = true;
            #   installCargo = true;
            # };
          };
        };

        # lsp = {
        #   enable = true;
        #   # keymaps = {
        #   #   silent = false;
        #   #   lspBuf = {
        #       # d = "debug";
        #         # K = "hover";
        #         # gD = "references";
        #         # gd = "definition";
        #         # gi = "implementation";
        #         # gt = "type_definition";
        #         # ca = "code_action";
        #         # ff = "format";
        #   #   };
        #   # };
        #   servers = {
        #     gopls = {
        #       enable = true;
        #       autostart = true;
        #     };
        #
        #     bashls = {
        #       enable = true;
        #       autostart = true;
        #     };
        #     html = {
        #       enable = true;
        #       autostart = true;
        #     };
        #     nil-ls = {
        #       enable = true;
        #       autostart = true;
        #     };
        #     pyright = {
        #       enable = true;
        #       autostart = true;
        #     };
        #   };
        # };
        # Dashboard
        cmp.enable = true;
        cmp-nvim-lsp.enable = true;
        cmp-path.enable = true;
        cmp-rg.enable = true;
        cmp-nvim-lua.enable = true;
        cmp-dap.enable = true;
        cmp-buffer.enable = true;
        cmp_luasnip.enable = true;
        cmp-cmdline.enable = false;
        # vim-lspconfig.enable = true;
      };

      extraConfigLua = ''
      local dap, dapui = require("dap"), require("dapui")
      dap.listeners.before.attach.dapui_config = function()
      dapui.open()
      end
      dap.listeners.before.launch.dapui_config = function()
      dapui.open()
      end
      dap.listeners.before.event_terminated.dapui_config = function()
      dapui.close()
      end
      dap.listeners.before.event_exited.dapui_config = function()
      dapui.close()
      end

      require('dap-python').test_runner = "pytest"
      '';

      keymaps = [
        # astronvim keymaps from chat-gpt4
        {
          action = ":HopWord<CR>";
          options = { desc = "прыгать по буквам";  silent = true; };
          key = "s";
        }
        {
          action = ":HopLine<CR>";
          options = { desc = "прыгать по буквам";  silent = true; };
          key = "S";
        }
        # General Mappings
        {
          key = "<C-Up>";
          action = ":resize +2<CR>";
          options = { desc = "Увеличить размер окна вверх";  silent = true; };
        }
        {
          key = "<C-Down>";
          action = ":resize -2<CR>";
          options = { desc = "Уменьшить размер окна вниз";  silent = true; };
        }
        {
          key = "<C-Left>";
          action = ":vertical resize -2<CR>";
          options = { desc = "Уменьшить размер окна влево";  silent = true; };
        }
        {
          key = "<C-Right>";
          action = ":vertical resize +2<CR>";
          options = { desc = "Увеличить размер окна вправо";  silent = true; };
        }
        {
          key = "<C-k>";
          action = "<C-w>k";
          options = { desc = "Переместиться в окно сверху";  silent = true; };
        }
        {
          key = "<C-j>";
          action = "<C-w>j";
          options = { desc = "Переместиться в окно снизу";  silent = true; };
        }
        {
          key = "<C-h>";
          action = "<C-w>h";
          options = { desc = "Переместиться в окно слева";  silent = true; };
        }
        {
          key = "<C-l>";
          action = "<C-w>l";
          options = { desc = "Переместиться в окно справа";  silent = true; };
        }
        {
          key = "<C-s>";
          action = ":w!<CR>";
          options = { desc = "Принудительное сохранение";  silent = true; };
        }
        # {
        #   key = "<C-q>";
        #   action = ":q!<CR>";
        #   options = { desc = "Принудительное закрытие";  silent = true; };
        # }
        {
          key = "<leader>n";
          action = ":enew<CR>";
          options = { desc = "Создать новый файл";  silent = true; };
        }
        {
          key = "<leader>c";
          action = ":lua buffer_close()<CR>";
          options = { desc = "Закрыть буфер";  silent = true; };
        }
        {
          key = "]t";
          action = ":tabnext<CR>";
          options = { desc = "Следующая вкладка";  silent = true; };
        }
        {
          key = "[t";
          action = ":tabprevious<CR>";
          options = { desc = "Предыдущая вкладка";  silent = true; };
        }
        {
          mode = "n";
          key = "<leader>/";
          action = "gcc";
          options.remap = true;
          options = { desc = "Закомментить строку";  silent = true; };
        }
        {
          mode = "v";
          key = "<leader>/";
          action = "gc";
          options.remap = true;
          options = { desc = "Закомментить";  silent = true; };
        }
        {
          key = "\\";
          action = ":split<CR>";
          options = { desc = "Горизонтальное разделение";  silent = true; };
        }
        {
          key = "|";
          action = ":vsplit<CR>";
          options = { desc = "Вертикальное разделение";  silent = true; };
        }
        # Buffers
        {
          mode = ["n" "v"];
          key = "<leader>b";
          action = "+buffers";
          options = { desc = "📄 Buffers"; };
        }
        {
          key = "]b";
          action = ":bnext<CR>";
          options = { desc = "Следующий буфер";  silent = true; };
        }
        {
          key = "[b";
          action = ":bprevious<CR>";
          options = { desc = "Предыдущий буфер";  silent = true; };
        }
        # {
        #   key = ">b";
        #   action = ":BufferMoveNext<CR>";
        #   options = { desc = "Переместить буфер вправо";  silent = true; };
        # }
        # {
        #   key = "<b";
        #   action = ":BufferMovePrevious<CR>";
        #   options = { desc = "Переместить буфер влево";  silent = true; };
        # }
        {
          key = "<leader>bb";
          action = ":Telescope buffers<CR>";
          options = { desc = "Перейти к буферу с помощью интерактивного выбора";  silent = true; };
        }
        {
          key = "<leader>bc";
          action = ":lua buffer_close_all(true)<CR>";
          options = { desc = "Закрыть все буферы, кроме текущего";  silent = true; };
        }
        {
          key = "<leader>bC";
          action = ":lua buffer_close_all()<CR>";
          options = { desc = "Закрыть все буферы";  silent = true; };
        }
        {
          key = "<leader>bd";
          action = ":bdelete<CR>";
          options = { desc = "Удалить буфер с помощью интерактивного выбора";  silent = true; };
        }
        {
          key = "<leader>bl";
          action = ":BufferCloseBuffersLeft<CR>";
          options = { desc = "Закрыть все буферы слева от текущего";  silent = true; };
        }
        {
          key = "<leader>bp";
          action = ":bprevious<CR>";
          options = { desc = "Перейти к предыдущему буферу";  silent = true; };
        }
        {
          key = "<leader>br";
          action = ":BufferCloseBuffersRight<CR>";
          options = { desc = "Закрыть все буферы справа от текущего";  silent = true; };
        }
        {
          key = "<leader>bse";
          action = ":BufferOrderByExtension<CR>";
          options = { desc = "Сортировать буферы по расширению";  silent = true; };
        }
        {
          key = "<leader>bsi";
          action = ":BufferOrderByBufferNumber<CR>";
          options = { desc = "Сортировать буферы по номеру";  silent = true; };
        }
        {
          key = "<leader>bsm";
          action = ":BufferOrderByLastModification<CR>";
          options = { desc = "Сортировать буферы по последней модификации";  silent = true; };
        }
        {
          key = "<leader>bsp";
          action = ":BufferOrderByFullPath<CR>";
          options = { desc = "Сортировать буферы по полному пути";  silent = true; };
        }
        {
          key = "<leader>bsr";
          action = ":BufferOrderByRelativePath<CR>";
          options = { desc = "Сортировать буферы по относительному пути";  silent = true; };
        }
        {
          key = "<leader>b\\";
          action = ":split | Telescope buffers<CR>";
          options = { desc = "Открыть буфер в новом горизонтальном разделе с помощью интерактивного выбора";  silent = true; };
        }
        {
          key = "<leader>b|";
          action = ":vsplit | Telescope buffers<CR>";
          options = { desc = "Открыть буфер в новом вертикальном разделе с помощью интерактивного выбора";  silent = true; };
        }
        # Better Escape
        # {
        #   key = "jj";
        #   action = ":<C-u>normal! <Esc><CR>";
        # # }
        # {
        #   key = "jk";
        #   action = ":<C-u>normal! <Esc><CR>";
        # }
        # Completion
        {
          key = "<C-Space>";
          action = ":lua vim.fn.complete(vim.fn.col('.'), vim.fn['compe#complete']())<CR>";
          options = { desc = "Открыть меню автодополнения";  silent = true; };
        }
        {
          key = "<CR>";
          action = ":lua vim.fn['compe#confirm']('<CR>')<CR>";
          options = { desc = "Выбрать автодополнение";  silent = true; };
        }
        {
          key = "<Tab>";
          action = ":lua vim.fn  ? '<Plug>(vsnip-jump-next)' : '<Tab>'<CR>";
          options = { desc = "Следующее положение фрагмента";  silent = true; };
        }
        {
          key = "<S-Tab>";
          action = ":lua vim.fn['vsnip#jumpable'](-1) ? '<Plug>(vsnip-jump-prev)' : '<S-Tab>'<CR>";
          options = { desc = "Предыдущее положение фрагмента";  silent = true; };
        }
        {
          key = "<Down>";
          action = ":lua vim.fn['compe#scroll']({ 'delta': +4 })<CR>";
          options = { desc = "Следующее автодополнение (вниз)";  silent = true; };
        }
        {
          key = "<C-n>";
          action = ":lua vim.fn['compe#scroll']({ 'delta': +4 })<CR>";
          options = { desc = "Следующее автодополнение (вниз)";  silent = true; };
        }
        {
          key = "<C-j>";
          action = ":lua vim.fn['compe#scroll']({ 'delta': +4 })<CR>";
          options = { desc = "Следующее автодополнение (вниз)";  silent = true; };
        }
        {
          key = "<Up>";
          action = ":lua vim.fn['compe#scroll']({ 'delta': -4 })<CR>";
          options = { desc = "Предыдущее автодополнение (вверх)";  silent = true; };
        }
        {
          key = "<C-p>";
          action = ":lua vim.fn['compe#scroll']({ 'delta': -4 })<CR>";
          options = { desc = "Предыдущее автодополнение (вверх)";  silent = true; };
        }
        {
          key = "<C-k>";
          action = ":lua vim.fn['compe#scroll']({ 'delta': -4 })<CR>";
          options = { desc = "Предыдущее автодополнение (вверх)";  silent = true; };
        }
        {
          key = "<C-e>";
          action = ":lua vim.fn['compe#close']('<C-e>')<CR>";
          options = { desc = "Отменить автодополнение";  silent = true; };
        }
        {
          key = "<C-u>";
          action = ":lua vim.fn['compe#scroll']({ 'delta': -4 })<CR>";
          options = { desc = "Прокрутка вверх в документации автодополнения";  silent = true; };
        }
        {
          key = "<C-d>";
          action = ":lua vim.fn['compe#scroll']({ 'delta': +4 })<CR>";
          options = { desc = "Прокрутка вниз в документации автодополнения";  silent = true; };
        }
        # Dashboard Mappings
        # {
        #   key = "<leader>h";
        #   action = ":Dashboard<CR>";
        # }
        # Neo-Tree
        {
          key = "<leader>e";
          action = ":Neotree toggle<CR>";
          options = { desc = "Переключить Neotree";  silent = true; };
        }
        {
          key = "<leader>o";
          action = ":Neotree focus<CR>";
          options = { desc = "Фокус на Neotree";  silent = true; };
        }
        # Session Manager Mappings
        {
          mode = ["n" "v"];
          key = "<leader>S";
          action = "+Session";
          options = { desc = "📄 Buffers"; };
        }
        {
          key = "<leader>Ss";
          action = ":SessionSave<CR>";
          options = { desc = "Сохранить сессию";  silent = true; };
        }
        {
          key = "<leader>Sl";
          action = ":SessionLoad<CR>";
          options = { desc = "Загрузить сессию";  silent = true; };
        }
        {
          key = "<leader>Sd";
          action = ":SessionDelete<CR>";
          options = { desc = "Удалить сессию";  silent = true; };
        }
        {
          key = "<leader>SD";
          action = ":SessionDeleteDirectory<CR>";
          options = { desc = "Удалить сессию директории";  silent = true; };
        }
        {
          key = "<leader>Sf";
          action = ":SessionSearch<CR>";
          options = { desc = "Поиск сессии";  silent = true; };
        }
        {
          key = "<leader>SF";
          action = ":SessionSearchDirectory<CR>";
          options = { desc = "Поиск сессий директории";  silent = true; };
        }
        {
          key = "<leader>S.";
          action = ":SessionLoadCurrentDirectory<CR>";
          options = { desc = "Загрузить сессию текущей директории";  silent = true; };
        }
        # Package Management Mappings
        {
          key = "<leader>pa";
          action = ":Lazy sync<CR>";
          options = { desc = "Синхронизировать пакеты";  silent = true; };
        }
        {
          key = "<leader>pi";
          action = ":Lazy install<CR>";
          options = { desc = "Установить пакеты";  silent = true; };
        }
        {
          key = "<leader>pm";
          action = ":Mason<CR>";
          options = { desc = "Открыть Mason";  silent = true; };
        }
        {
          key = "<leader>pM";
          action = ":MasonUpdate<CR>";
          options = { desc = "Обновить Mason";  silent = true; };
        }
        {
          key = "<leader>ps";
          action = ":Lazy check<CR>";
          options = { desc = "Проверить пакеты";  silent = true; };
        }
        {
          key = "<leader>pS";
          action = ":Lazy sync<CR>";
          options = { desc = "Синхронизировать пакеты";  silent = true; };
        }
        {
          key = "<leader>pu";
          action = ":Lazy update<CR>";
          options = { desc = "Обновить пакеты";  silent = true; };
        }
        {
          key = "<leader>pU";
          action = ":Lazy update<CR>";
          options = { desc = "Обновить пакеты";  silent = true; };
        }
        # LSP Mappings
        {
          key = "gD";
          action = ":lua vim.lsp.buf.declaration()<CR>";
          options = { desc = "Перейти к объявлению";  silent = true; };
        }
        {
          key = "gy";
          action = ":lua vim.lsp.buf.type_definition()<CR>";
          options = { desc = "Перейти к определению типа";  silent = true; };
        }
        {
          key = "gd";
          action = ":lua vim.lsp.buf.definition()<CR>";
          options = { desc = "Перейти к определению";  silent = true; };
        }
        {
          key = "gI";
          action = ":lua vim.lsp.buf.implementation()<CR>";
          options = { desc = "Перейти к реализации";  silent = true; };
        }
        {
          key = "grr";
          action = ":lua vim.lsp.buf.references()<CR>";
          options = { desc = "Найти ссылки";  silent = true; };
        }
        {
          key = "<leader>lR";
          action = ":lua vim.lsp.buf.references()<CR>";
          options = { desc = "Найти ссылки";  silent = true; };
        }
        {
          key = "<leader>li";
          action = ":LspInfo<CR>";
          options = { desc = "Информация о LSP";  silent = true; };
        }
        {
          key = "<leader>lI";
          action = ":NullLsInfo<CR>";
          options = { desc = "Информация о Null-LS";  silent = true; };
        }
        {
          key = "K";
          action = ":lua vim.lsp.buf.hover()<CR>";
          options = { desc = "Показать описание";  silent = true; };
        }
        {
          key = "<leader>lf";
          action = ":lua vim.lsp.buf.formatting()<CR>";
          options = { desc = "Форматировать документ";  silent = true; };
        }
        {
          key = "<leader>lS";
          action = ":SymbolsOutline<CR>";
          options = { desc = "Показать символы";  silent = true; };
        }
        {
          key = "gl";
          action = ":lua vim.diagnostic.open_float()<CR>";
          options = { desc = "Показать диагностику";  silent = true; };
        }
        {
          key = "<leader>ld";
          action = ":lua vim.diagnostic.open_float()<CR>";
          options = { desc = "Показать диагностику";  silent = true; };
        }
        {
          key = "<C-W>d";
          action = ":lua vim.diagnostic.open_float()<CR>";
          options = { desc = "Показать диагностику";  silent = true; };
        }
        {
          key = "<leader>lD";
          action = ":lua vim.diagnostic.setloclist()<CR>";
          options = { desc = "Добавить диагностику в список локаций";  silent = true; };
        }
        {
          key = "gra";
          action = ":lua vim.lsp.buf.code_action()<CR>";
          options = { desc = "Предложить действия с кодом";  silent = true; };
        }
        {
          key = "<leader>la";
          action = ":lua vim.lsp.buf.code_action()<CR>";
          options = { desc = "Предложить действия с кодом";  silent = true; };
        }
        {
          key = "<leader>lh";
          action = ":lua vim.lsp.buf.signature_help()<CR>";
          options = { desc = "Помощь с сигнатурами";  silent = true; };
        }
        {
          key = "grn";
          action = ":lua vim.lsp.buf.rename()<CR>";
          options = { desc = "Переименовать символ";  silent = true; };
        }
        {
          key = "<leader>lr";
          action = ":lua vim.lsp.buf.rename()<CR>";
          options = { desc = "Переименовать символ";  silent = true; };
        }
        {
          key = "<leader>ls";
          action = ":lua vim.lsp.buf.document_symbol()<CR>";
          options = { desc = "Показать символы документа";  silent = true; };
        }
        {
          key = "<leader>lG";
          action = ":lua vim.lsp.buf.workspace_symbol()<CR>";
          options = { desc = "Показать символы рабочей области";  silent = true; };
        }
        {
          key = "]d";
          action = ":lua vim.diagnostic.goto_next()<CR>";
          options = { desc = "Перейти к следующей диагностике";  silent = true; };
        }
        {
          key = "[d";
          action = ":lua vim.diagnostic.goto_prev()<CR>";
          options = { desc = "Перейти к предыдущей диагностике";  silent = true; };
        }
        # Debugger Mappings
        {
          mode = ["n" "v"];
          key = "<leader>d";
          action = "+debug";
          options = { desc = "🛠️ Debug"; };
        }
        {
          key = "<leader>d?";
          action = ":lua require('dapui').eval(nil, { enter = true })<cr>";
          options = { desc = "Оценить выражение";  silent = true; };
        }
        {
          key = "<leader>dc";
          action = ":lua require'dap'.continue()<CR>";
          options = { desc = "Запустить/продолжить отладку";  silent = true; };
        }
        {
          key = "<F5>";
          action = ":lua require'dap'.continue()<CR>";
          options = { desc = "Запустить/продолжить отладку";  silent = true; };
        }
        {
          key = "<leader>dp";
          action = ":lua require'dap'.pause()<CR>";
          options = { desc = "Пауза отладки";  silent = true; };
        }
        {
          key = "<F6>";
          action = ":lua require'dap'.pause()<CR>";
          options = { desc = "Пауза отладки";  silent = true; };
        }
        {
          key = "<leader>dr";
          action = ":lua require'dap'.restart()<CR>";
          options = { desc = "Перезапустить отладку";  silent = true; };
        }
        {
          key = "<C-F5>";
          action = ":lua require'dap'.restart()<CR>";
          options = { desc = "Перезапустить отладку";  silent = true; };
        }
        {
          key = "<leader>ds";
          action = ":lua require'dap'.run_to_cursor()<CR>";
          options = { desc = "Выполнить до курсора";  silent = true; };
        }
        {
          key = "<leader>dq";
          action = ":lua require'dap'.close()<CR>";
          options = { desc = "Закрыть отладку";  silent = true; };
        }
        {
          key = "<leader>dQ";
          action = ":lua require'dap'.terminate()<CR>";
          options = { desc = "Завершить отладку";  silent = true; };
        }
        {
          key = "<S-F5>";
          action = ":lua require'dap'.terminate()<CR>";
          options = { desc = "Завершить отладку";  silent = true; };
        }
        {
          key = "<leader>db";
          action = ":lua require'dap'.toggle_breakpoint()<CR>";
          options = { desc = "Переключить точку останова";  silent = true; };
        }
        {
          key = "<F9>";
          action = ":lua require'dap'.toggle_breakpoint()<CR>";
          options = { desc = "Переключить точку останова";  silent = true; };
        }
        {
          key = "<leader>dC";
          action = ":lua require'dap'.set_breakpoint(vim.fn.input('Breakpoint condition: '))<CR>";
          options = { desc = "Установить условную точку останова";  silent = true; };
        }
        {
          key = "<S-F9>";
          action = ":lua require'dap'.set_breakpoint(vim.fn.input('Breakpoint condition: '))<CR>";
          options = { desc = "Установить условную точку останова";  silent = true; };
        }
        {
          key = "<leader>dB";
          action = ":lua require'dap'.clear_breakpoints()<CR>";
          options = { desc = "Очистить точки останова";  silent = true; };
        }
        {
          key = "<leader>do";
          action = ":lua require'dap'.step_over()<CR>";
          options = { desc = "Шаг с обходом";  silent = true; };
        }
        {
          key = "<F10>";
          action = ":lua require'dap'.step_over()<CR>";
          options = { desc = "Шаг с обходом";  silent = true; };
        }
        {
          key = "<leader>di";
          action = ":lua require'dap'.step_into()<CR>";
          options = { desc = "Шаг с заходом";  silent = true; };
        }
        {
          key = "<F11>";
          action = ":lua require'dap'.step_into()<CR>";
          options = { desc = "Шаг с заходом";  silent = true; };
        }
        {
          key = "<leader>dO";
          action = ":lua require'dap'.step_out()<CR>";
          options = { desc = "Шаг с выходом";  silent = true; };
        }
        {
          key = "<S-F11>";
          action = ":lua require'dap'.step_out()<CR>";
          options = { desc = "Шаг с выходом";  silent = true; };
        }
        {
          key = "<leader>dE";
          action = ":lua require'dap.ui.widgets'.hover()<CR>";
          options = { desc = "Оценить выражение";  silent = true; };
        }
        {
          key = "<leader>dR";
          action = ":lua require'dap'.repl.toggle()<CR>";
          options = { desc = "Переключить REPL";  silent = true; };
        }
        {
          key = "<leader>du";
          action = ":lua require'dapui'.toggle()<CR>";
          options = { desc = "Переключить UI отладчика";  silent = true; };
        }
        {
          key = "<leader>dh";
          action = ":lua require'dap.ui.widgets'.hover()<CR>";
          options = { desc = "Подсказка отладчика";  silent = true; };
        }
        # Telescope Mappings
        {
          key = "<leader><CR>";
          action = ":Telescope resume<CR>";
          options = { desc = "Возобновить предыдущий поиск";  silent = true; };
        }
        {
          key = "<leader>f'";
          action = ":Telescope marks<CR>";
          options = { desc = "Показать закладки";  silent = true; };
        }
        {
          key = "<leader>fb";
          action = ":Telescope buffers<CR>";
          options = { desc = "Показать буферы";  silent = true; };
        }
        {
          key = "<leader>fc";
          action = ":Telescope grep_string<CR>";
          options = { desc = "Поиск слова под курсором";  silent = true; };
        }
        {
          key = "<leader>fC";
          action = ":Telescope commands<CR>";
          options = { desc = "Показать команды";  silent = true; };
        }
        {
          key = "<leader>ff";
          action = ":Telescope find_files<CR>";
          options = { desc = "Найти файлы";  silent = true; };
        }
        {
          key = "<leader>fF";
          action = ":Telescope find_files hidden=true<CR>";
          options = { desc = "Найти файлы (включая скрытые)";  silent = true; };
        }
        {
          key = "<leader>fh";
          action = ":Telescope help_tags<CR>";
          options = { desc = "Показать справочные теги";  silent = true; };
        }
        {
          key = "<leader>fk";
          action = ":Telescope keymaps<CR>";
          options = { desc = "Показать сочетания клавиш";  silent = true; };
        }
        {
          key = "<leader>fm";
          action = ":Telescope man_pages<CR>";
          options = { desc = "Показать страницы man";  silent = true; };
        }
        {
          key = "<leader>fn";
          action = ":Telescope notify<CR>";
          options = { desc = "Показать уведомления";  silent = true; };
        }
        {
          key = "<leader>fo";
          action = ":Telescope oldfiles<CR>";
          options = { desc = "Показать недавно открытые файлы";  silent = true; };
        }
        {
          key = "<leader>fr";
          action = ":Telescope registers<CR>";
          options = { desc = "Показать регистры";  silent = true; };
        }
        {
          key = "<leader>ft";
          action = ":Telescope colorscheme<CR>";
          options = { desc = "Показать цветовые схемы";  silent = true; };
        }
        {
          key = "<leader>fw";
          action = ":Telescope live_grep<CR>";
          options = { desc = "Поиск по тексту";  silent = true; };
        }
        {
          key = "<leader>fW";
          action = ":Telescope live_grep hidden=true<CR>";
          options = { desc = "Поиск по тексту (включая скрытые файлы)";  silent = true; };
        }
        {
          key = "<leader>gb";
          action = ":Telescope git_branches<CR>";
          options = { desc = "Показать ветки Git";  silent = true; };
        }
        {
          key = "<leader>gc";
          action = ":Telescope git_commits<CR>";
          options = { desc = "Показать коммиты Git";  silent = true; };
        }
        {
          key = "<leader>gC";
          action = ":Telescope git_bcommits<CR>";
          options = { desc = "Показать коммиты текущего файла";  silent = true; };
        }
        {
          key = "<leader>gt";
          action = ":Telescope git_status<CR>";
          options = { desc = "Показать статус Git";  silent = true; };
        }
        {
          key = "<leader>ls";
          action = ":Telescope lsp_document_symbols<CR>";
          options = { desc = "Показать символы документа";  silent = true; };
        }
        {
          key = "<leader>lG";
          action = ":Telescope lsp_workspace_symbols<CR>";
          options = { desc = "Показать символы рабочей области";  silent = true; };
        }
        # Terminal Mappings
        {
          key = "<leader>tf";
          action = ":FloatermNew<CR>";
          options = { desc = "Открыть плавающий терминал";  silent = true; };
        }
        {
          key = "<F7>";
          action = ":FloatermNew<CR>";
          options = { desc = "Открыть плавающий терминал";  silent = true; };
        }
        {
          key = "<leader>th";
          action = ":split | terminal<CR>";
          options = { desc = "Открыть горизонтальный терминал";  silent = true; };
        }
        {
          key = "<leader>tv";
          action = ":vsplit | terminal<CR>";
          options = { desc = "Открыть вертикальный терминал";  silent = true; };
        }
        {
          key = "<leader>tl";
          action = ":FloatermNew lazygit<CR>";
          options = { desc = "Открыть плавающий терминал с lazygit";  silent = true; };
        }
        {
          key = "<leader>tn";
          action = ":FloatermNew node<CR>";
          options = { desc = "Открыть плавающий терминал с node";  silent = true; };
        }
        {
          key = "<leader>tp";
          action = ":FloatermNew python<CR>";
          options = { desc = "Открыть плавающий терминал с python";  silent = true; };
        }
        {
          key = "<leader>tt";
          action = ":FloatermNew btm<CR>";
          options = { desc = "Открыть плавающий терминал с btm";  silent = true; };
        }
        # UI/UX Mappings
        {
          key = "<leader>ua";
          action = ":lua require('nvim-autopairs').toggle()<CR>";
          options = { desc = "Переключить автопары";  silent = true; };
        }
        {
          key = "<leader>uA";
          action = ":lua require('rooter').toggle()<CR>";
          options = { desc = "Переключить автоматическое определение корневой директории";  silent = true; };
        }
        {
          key = "<leader>ub";
          action = ":lua require('toggle-bg').toggle()<CR>";
          options = { desc = "Переключить фон";  silent = true; };
        }
        {
          key = "<leader>uc";
          action = ":lua require('completion').toggle_buffer()<CR>";
          options = { desc = "Переключить автодополнение (буфер)";  silent = true; };
        }
        {
          key = "<leader>uC";
          action = ":lua require('completion').toggle_global()<CR>";
          options = { desc = "Переключить автодополнение (глобально)";  silent = true; };
        }
        {
          key = "<leader>ud";
          action = ":lua require('diagnostics').toggle()<CR>";
          options = { desc = "Переключить диагностику";  silent = true; };
        }
        {
          key = "<leader>uD";
          action = ":lua require('notify').dismiss()<CR>";
          options = { desc = "Отклонить уведомления";  silent = true; };
        }
        {
          key = "<leader>uf";
          action = ":lua require('formatting').toggle_buffer()<CR>";
          options = { desc = "Переключить автоформатирование (буфер)";  silent = true; };
        }
        {
          key = "<leader>uF";
          action = ":lua require('formatting').toggle_global()<CR>";
          options = { desc = "Переключить автоформатирование (глобально)";  silent = true; };
        }
        {
          key = "<leader>ug";
          action = ":lua require('signcolumn').toggle()<CR>";
          options = { desc = "Переключить колонку знаков";  silent = true; };
        }
        {
          key = "<leader>u>";
          action = ":lua require('foldcolumn').toggle()<CR>";
          options = { desc = "Переключить колонку сворачивания";  silent = true; };
        }
        {
          key = "<leader>uh";
          action = ":lua require('lsp_inlay_hints').toggle_buffer()<CR>";
          options = { desc = "Переключить подсказки LSP (буфер)";  silent = true; };
        }
        {
          key = "<leader>uH";
          action = ":lua require('lsp_inlay_hints').toggle_global()<CR>";
          options = { desc = "Переключить подсказки LSP (глобально)";  silent = true; };
        }
        {
          key = "<leader>ui";
          action = ":lua require('indent_setting').toggle()<CR>";
          options = { desc = "Переключить настройку отступов";  silent = true; };
        }
        {
          key = "<leader>u|";
          action = ":lua require('indent_guides').toggle()<CR>";
          options = { desc = "Переключить направляющие отступов";  silent = true; };
        }
        {
          key = "<leader>ul";
          action = ":lua require('statusline').toggle()<CR>";
          options = { desc = "Переключить строку состояния";  silent = true; };
        }
        {
          key = "<leader>uL";
          action = ":lua require('codelens').toggle()<CR>";
          options = { desc = "Переключить CodeLens";  silent = true; };
        }
        {
          key = "<leader>un";
          action = ":lua require('line_numbering').change()<CR>";
          options = { desc = "Изменить нумерацию строк";  silent = true; };
        }
        {
          key = "<leader>uN";
          action = ":lua require('notify').toggle()<CR>";
          options = { desc = "Переключить уведомления";  silent = true; };
        }
        {
          key = "<leader>up";
          action = ":lua require('paste_mode').toggle()<CR>";
          options = { desc = "Переключить режим вставки";  silent = true; };
        }
        {
          key = "<leader>ur";
          action = ":lua require('reference_highlighting').toggle_buffer()<CR>";
          options = { desc = "Переключить выделение ссылок (буфер)";  silent = true; };
        }
        {
          key = "<leader>uR";
          action = ":lua require('reference_highlighting').toggle_global()<CR>";
          options = { desc = "Переключить выделение ссылок (глобально)";  silent = true; };
        }
        {
          key = "<leader>us";
          action = ":lua require('spellcheck').toggle()<CR>";
          options = { desc = "Переключить проверку орфографии";  silent = true; };
        }
        {
          key = "<leader>uS";
          action = ":lua require('conceal').toggle()<CR>";
          options = { desc = "Переключить скрытие текста";  silent = true; };
        }
        {
          key = "<leader>ut";
          action = ":lua require('tabline').toggle()<CR>";
          options = { desc = "Переключить табы";  silent = true; };
        }
        {
          key = "<leader>uu";
          action = ":lua require('url_highlighting').toggle()<CR>";
          options = { desc = "Переключить выделение URL";  silent = true; };
        }
        {
          key = "<leader>uw";
          action = ":lua require('wrap').toggle()<CR>";
          options = { desc = "Переключить перенос строк";  silent = true; };
        }
        {
          key = "<leader>uy";
          action = ":lua require('syntax_highlighting').toggle_buffer()<CR>";
          options = { desc = "Переключить подсветку синтаксиса (буфер)";  silent = true; };
        }
        {
          key = "<leader>uY";
          action = ":lua require('lsp_semantic_tokens').toggle_buffer()<CR>";
          options = { desc = "Переключить LSP семантические токены (буфер)";  silent = true; };
        }
        {
          key = "<leader>uz";
          action = ":lua require('color_highlighting').toggle()<CR>";
          options = { desc = "Переключить подсветку цвета";  silent = true; };
        }

        # {
        #   key = "<esc>";
        #   action = ":noh<CR>";
        #   options = {
        #     silent = true;
        #   };
        # }
        # {
        #   key = "<leader>k";
        #   action = "<cmd>bdelete<cr>";
        # }
        # {
        #   key = "<leader>f";
        #   action = "<cmd>Telescope find_files<cr>";
        # }
        # {
        #   key = "<leader>g";
        #   action = "<cmd>Telescope live_grep<cr>";
        # }
        # {
        #   key = "<leader>b";
        #   action = "<cmd>Telescope buffers<cr>";
        # }
        # {
        #   key = "<leader>t";
        #   action = "<cmd>Telescope help_tags<cr>";
        # }
        # {
        #   key = "<leader>e";
        #   action = "<cmd>Neotree<cr>";
        # }
        # {
        #   key = "<leader>nb";
        #   action = "<cmd>Neotree buffers<cr>";
        # }
        # {
        #   key = "<leader>ng";
        #   action = "<cmd>Neotree float git_status<cr>";
        # }
        # {
        #   key = "<leader>nc";
        #   action = "<cmd>Neotree close<cr>";
        # }
        # {
        #   key = "<leader>sr";
        #   action = "<cmd>SnipRun<cr>";
        # }
        # {
        #   key = "<leader>ss";
        #   action = "<cmd>'<,'>SnipRun<cr>";
        # }
        # {
        #   key = "<leader>sd";
        #   action = "<cmd>SnipReset<cr>";
        # }
        # {
        #   key = "<leader>sc";
        #   action = "<cmd>SnipClose<cr>";
        # }
      ];
    };
  };
}
