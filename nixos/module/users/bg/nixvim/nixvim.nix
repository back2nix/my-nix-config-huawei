{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./spell.nix
    ./plugins/persistent-breakpoints.nvim.nix
    ./plugins/git-blame.nvim.nix
    ./utils/buffer.nix
    # ./plugins/dap.nix
    # ./colorscheme.nix
  ];
  programs = {
    nixvim.enable = true;

    nixvim = {
      defaultEditor = true;

      globals = {
        mapleader = " ";
        maplocalleader = ",";
      };

      # colorschemes.gruvbox.enable = true;
      # colorschemes.dracula.enable = true;
      colorschemes.nightfox.enable = true;

      clipboard = {
        register = "unnamedplus";
        # TODO: Make conditional if X11/Wayland enabled
        # providers.wl-copy.enable = true;
        providers.xclip.enable = pkgs.stdenv.isLinux;
        providers.xsel.enable = pkgs.stdenv.isDarwin;
      };

      opts = {
        timeoutlen = 100;
        background = "";
        updatetime = 100;
        spell = true;
        spelllang = [
          "en_us"
          "ru"
        ];
        number = true; # Show line numbers
        relativenumber = true; # Show relative line numbers
        incsearch = true;
        expandtab = true;
        shiftwidth = 2; # Tab width should be 2
        tabstop = 2;
        termguicolors = true;
        ignorecase = true;
        smartcase = true;
        undofile = true;
        swapfile = false;
      };

      extraPlugins = with pkgs.vimPlugins; [
        # nvim-gdb
        vim-nix
        vim-dadbod
        vim-dadbod-ui
        vim-dadbod-completion
        dressing-nvim
      ];
      extraPackages = with pkgs; [
        fd
        ripgrep
        sqls
      ];

      autoCmd = [
        {
          event = "FileType";
          pattern = ["sql" "mysql" "plsql"];
          command = "lua require('cmp').setup.buffer({ sources = {{ name = 'vim-dadbod-completion' }} })";
        }
      ];

      luaLoader.enable = true;

      plugins = {
        dashboard.enable = true;
        dressing = {
          enable = true;
          settings = {
            input = {
              enabled = true;
              mappings = {
                i = {
                  "<C-c>" = "Close";
                  "<CR>" = "Confirm";
                  "<Down>" = "HistoryNext";
                  "<Up>" = "HistoryPrev";
                };
                n = {
                  "<CR>" = "Confirm";
                  "<Esc>" = "Close";
                };
              };
            };
            select = {
              backend = [
                "telescope"
                "fzf_lua"
                "fzf"
                "builtin"
                "nui"
              ];
              builtin = {
                mappings = {
                  "<C-c>" = "Close";
                  "<CR>" = "Confirm";
                  "<Esc>" = "Close";
                };
              };
              enabled = true;
            };
          };
        };

        dap = {
          enable = true;
          extensions = {
            dap-go = {
              enable = true;
              dapConfigurations = [
                {
                  type = "go";
                  name = "Attach remote";
                  mode = "remote";
                  request = "attach";
                }
                # {
                #   type = "go";
                #   name = "Launch Eparser";
                #   request = "launch";
                #   program = "\${workspaceFolder}/cmd/eparser";
                #   # env = {
                #   #   CGO_ENABLED = 0;
                #   # };
                #   args = [
                #     "--local-config-enabled"
                #     "--public-port"
                #     "7080"
                #     "--admin-port"
                #     "7081"
                #     "--grpc-port"
                #     "7082"
                #     "--channelz-port"
                #     "50851"
                #   ];
                #   envFile = "\${workspaceFolder}/.env";
                #   preLaunchTask = "Build eparser";
                #   postDebugTask = "Stop eparser";
                # }
              ];
              delve = {
                path = "dlv";
                initializeTimeoutSec = 20;
                port = "38697";
                # args = [];
                buildFlags = "";
                # buildFlags = ''-ldflags "-X 'gitthub.ru/back2nix/placebo/internal/app.Name=myapp' -tags=debug'';
              };
            };
            dap-python.enable = true;
            dap-ui = {
              enable = true;
              controls.enabled = true;
            };
            dap-virtual-text.enable = true;
          };
        };

        cmp-spell.enable = true;
        barbar.enable = true;
        auto-session = {
          enable = true;
          extraOptions = {
            auto_save_enabled = true;
            auto_restore_enabled = true;
          };
        };

        noice = {
          enable = true;
          lsp.override = {
            "vim.lsp.util.convert_input_to_markdown_lines" = true;
            "vim.lsp.util.stylize_markdown" = true;
            "cmp.entry.get_documentation" = true;
          };
          presets = {
            bottom_search = true;
            command_palette = true;
            long_message_to_split = true;
            inc_rename = true;
            lsp_doc_border = false;
          };
          popupmenu = {
            enabled = true;
            backend = "cmp";
          };
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
          # settings.current_line_blame = true;
        };
        leap.enable = true;
        lsp-format.enable = true;
        markdown-preview = {
          enable = true;
          settings = {
            auto_close = true;
          };
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
              leaveDirsOpen = true;
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
              fuzzy = true;
              overrideGenericSorter = true;
              overrideFileSorter = true;
              caseMode = "smart_case";
            };
          };
          defaults = {
            # file_ignore_patterns = [".git" ".direnv" "target" "node_modules"];
            vimgrep_arguments = [
              "${pkgs.ripgrep}/bin/rg"
              "--hidden"
              "--color=never"
              "--no-heading"
              "--with-filename"
              "--line-number"
              "--column"
              "--smart-case"
            ];
            layout_strategy = "horizontal";
            layout_config.prompt_position = "top";
            sorting_strategy = "ascending";
          };
          extraOptions = {
            pickers = {
              git_files = {
                disable_devicons = true;
              };
              find_files = {
                disable_devicons = true;
              };
              buffers = {
                disable_devicons = true;
              };
              live_grep = {
                disable_devicons = true;
              };
              current_buffer_fuzzy_find = {
                disable_devicons = true;
              };
              lsp_definitions = {
                disable_devicons = true;
              };
              lsp_references = {
                disable_devicons = true;
              };
              diagnostics = {
                disable_devicons = true;
              };
              lsp_dynamic_workspace_symbols = {
                disable_devicons = true;
              };
            };
          };
          keymaps = {
            # "<leader>f" = "git_files";
            # "<leader>F" = "find_files";
            # "gb" = "buffers";
            # "<leader><space>" = "live_grep";
            # "<leader>/" = "current_buffer_fuzzy_find";
            # "gd" = "lsp_definitions";
            # "gr" = "lsp_references";
            # "gi" = "lsp_implementations";
            # "gt" = "lsp_type_definition";
            "<leader>fd" = "diagnostics";
            "<leader>s" = "lsp_dynamic_workspace_symbols";
          };
        };

        yanky = {
          enable = true;
          picker.telescope = {
            enable = true;
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
          ensureInstalled = [
            "rust"
            "python"
            "c"
            "cpp"
            "toml"
            "nix"
            "go"
            "gomod"
            "gotmpl"
            "gosum"
            "gowork"
            "java"
          ];
          grammarPackages = with config.programs.nixvim.plugins.treesitter.package.builtGrammars; [
            c
            go
            gomod
            gosum
            gowork
            gotmpl
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
        which-key = {
          enable = true;
          plugins.spelling.enabled = false;
          triggersNoWait = ["`" "'" "<leader>" "g`" "g'" "\"" "<c-r>" "z=" "<Space>"];
          disable = {
            buftypes = [];
            filetypes = [];
          };
          triggersBlackList = {
            i = ["j" "k"];
            v = ["j" "k"];
          };
        };
        multicursors.enable = true;
        lastplace.enable = true;

        none-ls = {
          enable = true;
          enableLspFormat = true;
          updateInInsert = false;
          sources = {
            code_actions = {
              gitsigns.enable = true;
              statix.enable = true;
            };
            diagnostics = {
              statix.enable = true;
              yamllint.enable = true;
            };
            formatting = {
              golines = {
                enable = true;
                withArgs = ''
                  {
                    extra_args = { "--no-reformat-tags" },
                  }
                '';
              };
              gofumpt.enable = true;
              # goimports.enable = true;
              goimports_reviser.enable = true;

              # Nix
              alejandra.enable = true;

              # Python
              blackd.enable = true;

              black = {
                enable = true;
                withArgs = ''
                  {
                    extra_args = { "--fast" },
                  }
                '';
              };

              # JS
              # prettier = {
              #   enable = true;
              #   disableTsServerFormatter = true;
              #   withArgs = ''
              #     {
              #       extra_args = { "--single-quote" },
              #     }
              #   '';
              # };
              stylua.enable = true;
              # yamlfmt.enable = true;
            };
          };
        };

        # Language server
        lsp = {
          enable = true;

          # diagnostic = {
          #   "]d" = "goto_next";
          #   "[d" = "goto_prev";
          # };

          # keymaps.lspBuf = {
          # K = "hover";
          # gD = "declaration";
          # "<C-k>" = "signature_help";
          # # "<leader>rn" = "lua vim.lsp.buf.rename()";
          # "<leader>ca" = "code_action";
          # K = "hover";
          # gD = "references";
          # gd = "definition";
          # gi = "implementation";
          # gt = "type_definition";
          # };

          # keymaps.extra = [
          # {
          #   key = "gd";
          #   action = "require('telescope.builtin').lsp_definitions";
          #   lua = true;
          # }
          # {
          #   key = "gr";
          #   action = "require('telescope.builtin').lsp_references";
          #   lua = true;
          # }
          # {
          #   key = "gi";
          #   action = "require('telescope.builtin').lsp_implementations";
          #   lua = true;
          # }
          # {
          #   key = "gt";
          #   action = "require('telescope.builtin').lsp_type_definitions";
          #   lua = true;
          # }
          # ];

          servers = {
            # Average webdev LSPs
            gopls = {
              enable = true;
              autostart = true;
              onAttach.function = ''
                if not client.server_capabilities.semanticTokensProvider then
                local semantic = client.config.capabilities.textDocument.semanticTokens
                client.server_capabilities.semanticTokensProvider = {
                  full = true,
                  legend = {
                    tokenTypes = semantic.tokenTypes,
                    tokenModifiers = semantic.tokenModifiers,
                  },
                  range = true,
                }
                end
              '';
              extraOptions = {
                settings = {
                  gopls = {
                    gofumpt = true;
                    codelenses = {
                      gc_details = false;
                      generate = true;
                      regenerate_cgo = true;
                      run_govulncheck = true;
                      test = true;
                      tidy = true;
                      upgrade_dependency = true;
                      vendor = true;
                    };
                    hints = {
                      assignVariableTypes = true;
                      compositeLiteralFields = true;
                      compositeLiteralTypes = true;
                      constantValues = true;
                      functionTypeParameters = true;
                      parameterNames = true;
                      rangeVariableTypes = true;
                    };
                    analyses = {
                      fieldalignment = true;
                      nilness = true;
                      unusedparams = true;
                      unusedwrite = true;
                      useany = true;
                    };
                    usePlaceholders = true;
                    completeUnimported = true;
                    staticcheck = true;
                    directoryFilters = ["-.git" "-.vscode" "-.idea" "-.vscode-test" "-node_modules"];
                    semanticTokens = true;
                  };
                };
              };
            };
            nil_ls.enable = true;
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
            nil-ls.enable = true;
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

        luasnip.enable = true;
        cmp = {
          enable = true;

          settings = {
            snippet.expand = "function(args) require('luasnip').lsp_expand(args.body) end";

            mapping = {
              "<C-Space>" = "cmp.mapping.complete()";
              "<CR>" = "cmp.mapping.confirm()";
              "<ESC>" = "cmp.mapping.close()";
              "<Down>" = "cmp.mapping.select_next_item()";
              "<C-j>" = "cmp.mapping.select_next_item()";
              "<Tab>" = "cmp.mapping.select_next_item()";
              "<Up>" = "cmp.mapping.select_prev_item()";
              "<C-k>" = "cmp.mapping.select_prev_item()";
              "<S-Tab>" = "cmp.mapping.select_prev_item()";
            };

            sources = [
              {name = "path";}
              {name = "nvim_lsp";}
              {name = "cmp_tabby";}
              {name = "luasnip";}
              {
                name = "buffer";
                option.get_bufnrs.__raw = "vim.api.nvim_list_bufs";
              }
              {name = "neorg";}
              {name = "nvim_lsp_signature_help";}
              {name = "treesitter";}
              {name = "dap";}
            ];
          };
        };

        lspkind = {
          enable = true;

          cmp = {
            enable = true;
            menu = {
              nvim_lsp = "[LSP]";
              nvim_lua = "[api]";
              path = "[path]";
              luasnip = "[snip]";
              buffer = "[buffer]";
              dap = "[dap]";
              treesitter = "[treesitter]";
              # neorg = "[neorg]";
              cmp_tabby = "[Tabby]";
            };
          };
        };

        # Dashboard
        # cmp.enable = true;
        cmp-treesitter.enable = true;
        cmp-nvim-lsp.enable = true;
        cmp-path.enable = true;
        cmp-rg.enable = true;
        cmp-nvim-lua.enable = true;
        cmp-dap.enable = true;
        cmp-buffer.enable = true;
        cmp_luasnip.enable = true;
        cmp-cmdline.enable = false;
        cmp-nvim-lsp-signature-help.enable = true;
        # cmp-tabby.host = "http://127.0.0.1:8080";
        # vim-lspconfig.enable = true;
        nvim-cmp = {
          enable = true;
        };
        conform-nvim = {
          enable = true;

          formattersByFt = {
            "*" = ["codespell"];
            "_" = ["trim_whitespace"];
            go = [
              # "goimports"
              "goimports_reviser"
              # "golines"
              # "gofmt"
              "gofumpt"
            ];
            javascript = [["prettierd" "prettier"]];
            json = ["jq"];
            lua = ["stylua"];
            nix = ["alejandra"];
            python = ["isort" "black"];
            rust = ["rustfmt"];
            sh = ["shfmt"];
            terraform = ["terraform_fmt"];
          };

          formatOnSave = ''
            function(bufnr)
            local ignore_filetypes = { "helm" }
            if vim.tbl_contains(ignore_filetypes, vim.bo[bufnr].filetype) then
            return
            end

            -- Disable with a global or buffer-local variable
            if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
            return
            end

            -- Disable autoformat for files in a certain path
            local bufname = vim.api.nvim_buf_get_name(bufnr)
            if bufname:match("/node_modules/") then
            return
            end
            return { timeout_ms = 1000, lsp_fallback = true }
            end
          '';
        };
      };

      extraConfigLua = ''
        vim.api.nvim_create_user_command("Pwd", 'let @+=expand("%:p") | echo expand("%:p")', {})

        local function myRepl(t)
          if t.range ~= 0 then
            vim.cmd "'<,'>s/null/nil/ge | '<,'>s/\\[/\\{/ge | '<,'>s/\\]/\\}/ge"
          else
            vim.cmd "%s/null/nil/ge | %s/\\[/\\{/ge | %s/\\]/\\}/ge"
          end
        end
        vim.api.nvim_create_user_command("MyRepl", function(t) myRepl(t) end, { range = true })

        local function myReplQu(t)
          if t.range ~= 0 then
            vim.cmd "'<,'>s/\"/'/ge"
          else
            vim.cmd "%s/\"/'/ge"
          end
        end
        vim.api.nvim_create_user_command("MyReplQu", function(t) myReplQu(t) end, { range = true })

        vim.api.nvim_set_keymap("x", "<C-t>", ":po<CR>", { noremap = true })

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

      keymaps =
        [
          {
            mode = ["n" "v"];
            key = "<Leader>m";
            action = "<cmd>MCstart<cr>";
            options = {
              desc = "Create a selection for selected text or word under the cursor";
              silent = true;
            };
          }
          # autocomplite
          # {
          #   key = "<Tab>";
          #   action = "lua require('cmp').mapping(function(fallback) if require('cmp').visible() then require('cmp').select_next_item() elseif require('luasnip').expand_or_jumpable() then require('luasnip').expand_or_jump() else fallback() end end, { 'i', 's' })";
          #   options = { desc = "Выбрать следующий элемент автокомплита"; silent = true; };
          # }
          # {
          #   key = "<S-Tab>";
          #   action = "lua require('cmp').mapping(function(fallback) if require('cmp').visible() then require('cmp').select_prev_item() elseif require('luasnip').jumpable(-1) then require('luasnip').jump(-1) else fallback() end end, { 'i', 's' })";
          #   options = { desc = "Выбрать предыдущий элемент автокомплита"; silent = true; };
          # }
          # {
          #   key = "<C-d>";
          #   action = "lua require('cmp').mapping.scroll_docs(-4)";
          #   options = { desc = "Прокрутка автокомплит документации вверх"; silent = true; };
          # }
          # {
          #   key = "<C-f>";
          #   action = "lua require('cmp').mapping.scroll_docs(4)";
          #   options = { desc = "Прокрутка автокомплит документации вниз"; silent = true; };
          # }
          {
            key = "<C-Space>";
            action = "lua require('cmp').mapping.complete()";
            options = {
              desc = "Вызвать меню автокомплита";
              silent = true;
            };
          }
          {
            key = "<C-e>";
            action = "lua require('cmp').mapping.close()";
            options = {
              desc = "Закрыть меню автокомплита";
              silent = true;
            };
          }
          {
            key = "<CR>";
            action = "lua require('cmp').mapping.confirm({ select = true })";
            options = {
              desc = "Подтвердить выбор автокомплита";
              silent = true;
            };
          }
          # astronvim keymaps from chat-gpt4
          {
            action = ":HopWord<CR>";
            options = {
              desc = "прыгать по буквам";
              silent = true;
            };
            key = "s";
          }
          {
            action = ":HopLine<CR>";
            options = {
              desc = "прыгать по буквам";
              silent = true;
            };
            key = "S";
          }
          # General Mappings
          {
            key = "<C-Up>";
            action = ":resize +2<CR>";
            options = {
              desc = "Увеличить размер окна вверх";
              silent = true;
            };
          }
          {
            key = "<C-Down>";
            action = ":resize -2<CR>";
            options = {
              desc = "Уменьшить размер окна вниз";
              silent = true;
            };
          }
          {
            key = "<C-Left>";
            action = ":vertical resize -2<CR>";
            options = {
              desc = "Уменьшить размер окна влево";
              silent = true;
            };
          }
          {
            key = "<C-Right>";
            action = ":vertical resize +2<CR>";
            options = {
              desc = "Увеличить размер окна вправо";
              silent = true;
            };
          }
          {
            key = "<C-k>";
            action = "<C-w>k";
            options = {
              desc = "Переместиться в окно сверху";
              silent = true;
            };
          }
          {
            key = "<C-j>";
            action = "<C-w>j";
            options = {
              desc = "Переместиться в окно снизу";
              silent = true;
            };
          }
          {
            key = "<C-h>";
            action = "<C-w>h";
            options = {
              desc = "Переместиться в окно слева";
              silent = true;
            };
          }
          {
            key = "<C-l>";
            action = "<C-w>l";
            options = {
              desc = "Переместиться в окно справа";
              silent = true;
            };
          }
          {
            key = "<C-s>";
            action = ":w!<CR>";
            options = {
              desc = "Принудительное сохранение";
              silent = true;
            };
          }
          # {
          #   key = "<C-q>";
          #   action = ":q!<CR>";
          #   options = { desc = "Принудительное закрытие";  silent = true; };
          # }
          {
            key = "<leader>n";
            action = ":enew<CR>";
            options = {
              desc = "Создать новый файл";
              silent = true;
            };
          }
          {
            key = "<leader>c";
            action = "<cmd>lua buffer_close()<cr>";
            options = {
              desc = "Закрыть буфер";
              silent = true;
            };
          }
          {
            key = "<leader>C";
            action = "<cmd>lua buffer_close(0, true)<cr>";
            options = {
              desc = "Закрыть буфер принудительно";
              silent = true;
            };
          }
          {
            key = "]t";
            action = ":tabnext<CR>";
            options = {
              desc = "Следующая вкладка";
              silent = true;
            };
          }
          {
            key = "[t";
            action = ":tabprevious<CR>";
            options = {
              desc = "Предыдущая вкладка";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>/";
            action = "gcc";
            options.remap = true;
            options = {
              desc = "Закомментить строку";
              silent = true;
            };
          }
          {
            mode = "v";
            key = "<leader>/";
            action = "gc";
            options.remap = true;
            options = {
              desc = "Закомментить";
              silent = true;
            };
          }
          {
            key = "\\";
            action = ":split<CR>";
            options = {
              desc = "Горизонтальное разделение";
              silent = true;
            };
          }
          {
            key = "|";
            action = ":vsplit<CR>";
            options = {
              desc = "Вертикальное разделение";
              silent = true;
            };
          }
          # Buffers
          {
            mode = ["n" "v"];
            key = "<leader>b";
            action = "+buffers";
            options = {desc = "📄 Buffers";};
          }
          {
            key = "]b";
            action = ":bnext<CR>";
            options = {
              desc = "Следующий буфер";
              silent = true;
            };
          }
          {
            key = "[b";
            action = ":bprevious<CR>";
            options = {
              desc = "Предыдущий буфер";
              silent = true;
            };
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
            options = {
              desc = "Перейти к буферу с помощью интерактивного выбора";
              silent = true;
            };
          }
          {
            key = "<leader>bc";
            action = "<cmd>lua buffer_close_all(true)<cr>";
            options = {
              desc = "Закрыть все буферы, кроме текущего";
              silent = true;
            };
          }
          {
            key = "<leader>bC";
            action = ":BufferCloseAll<CR>";
            options = {
              desc = "Закрыть все буферы";
              silent = true;
            };
          }
          {
            key = "<leader>bd";
            action = "<cmd>lua buffer_close_all()<cr>";
            options = {
              desc = "Удалить буфер с помощью интерактивного выбора";
              silent = true;
            };
          }
          {
            key = "<leader>bl";
            action = ":BufferCloseBuffersLeft<CR>";
            options = {
              desc = "Закрыть все буферы слева от текущего";
              silent = true;
            };
          }
          {
            key = "<leader>bp";
            action = ":bprevious<CR>";
            options = {
              desc = "Перейти к предыдущему буферу";
              silent = true;
            };
          }
          {
            key = "<leader>br";
            action = ":BufferCloseBuffersRight<CR>";
            options = {
              desc = "Закрыть все буферы справа от текущего";
              silent = true;
            };
          }
          {
            key = "<leader>bse";
            action = ":BufferOrderByExtension<CR>";
            options = {
              desc = "Сортировать буферы по расширению";
              silent = true;
            };
          }
          {
            key = "<leader>bsi";
            action = ":BufferOrderByBufferNumber<CR>";
            options = {
              desc = "Сортировать буферы по номеру";
              silent = true;
            };
          }
          {
            key = "<leader>bsm";
            action = ":BufferOrderByLastModification<CR>";
            options = {
              desc = "Сортировать буферы по последней модификации";
              silent = true;
            };
          }
          {
            key = "<leader>bsp";
            action = ":BufferOrderByFullPath<CR>";
            options = {
              desc = "Сортировать буферы по полному пути";
              silent = true;
            };
          }
          {
            key = "<leader>bsr";
            action = ":BufferOrderByRelativePath<CR>";
            options = {
              desc = "Сортировать буферы по относительному пути";
              silent = true;
            };
          }
          {
            key = "<leader>b\\";
            action = ":split | Telescope buffers<CR>";
            options = {
              desc = "Открыть буфер в новом горизонтальном разделе с помощью интерактивного выбора";
              silent = true;
            };
          }
          {
            key = "<leader>b|";
            action = ":vsplit | Telescope buffers<CR>";
            options = {
              desc = "Открыть буфер в новом вертикальном разделе с помощью интерактивного выбора";
              silent = true;
            };
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
            options = {
              desc = "Открыть меню автодополнения";
              silent = true;
            };
          }
          {
            key = "<CR>";
            action = ":lua vim.fn['compe#confirm']('<CR>')<CR>";
            options = {
              desc = "Выбрать автодополнение";
              silent = true;
            };
          }
          {
            key = "<Tab>";
            action = ":lua vim.fn  ? '<Plug>(vsnip-jump-next)' : '<Tab>'<CR>";
            options = {
              desc = "Следующее положение фрагмента";
              silent = true;
            };
          }
          {
            key = "<S-Tab>";
            action = ":lua vim.fn['vsnip#jumpable'](-1) ? '<Plug>(vsnip-jump-prev)' : '<S-Tab>'<CR>";
            options = {
              desc = "Предыдущее положение фрагмента";
              silent = true;
            };
          }
          {
            key = "<Down>";
            action = ":lua vim.fn['compe#scroll']({ 'delta': +4 })<CR>";
            options = {
              desc = "Следующее автодополнение (вниз)";
              silent = true;
            };
          }
          {
            key = "<C-n>";
            action = ":lua vim.fn['compe#scroll']({ 'delta': +4 })<CR>";
            options = {
              desc = "Следующее автодополнение (вниз)";
              silent = true;
            };
          }
          {
            key = "<C-j>";
            action = ":lua vim.fn['compe#scroll']({ 'delta': +4 })<CR>";
            options = {
              desc = "Следующее автодополнение (вниз)";
              silent = true;
            };
          }
          {
            key = "<Up>";
            action = ":lua vim.fn['compe#scroll']({ 'delta': -4 })<CR>";
            options = {
              desc = "Предыдущее автодополнение (вверх)";
              silent = true;
            };
          }
          # {
          #   key = "<C-p>";
          #   action = ":lua vim.fn['compe#scroll']({ 'delta': -4 })<CR>";
          #   options = { desc = "Предыдущее автодополнение (вверх)"; silent = true; };
          # }
          # {
          #   key = "<C-k>";
          #   action = ":lua vim.fn['compe#scroll']({ 'delta': -4 })<CR>";
          #   options = { desc = "Предыдущее автодополнение (вверх)"; silent = true; };
          # }
          # {
          #   key = "<C-e>";
          #   action = ":lua vim.fn['compe#close']('<C-e>')<CR>";
          #   options = { desc = "Отменить автодополнение"; silent = true; };
          # }
          # {
          #   key = "<C-u>";
          #   action = ":lua vim.fn['compe#scroll']({ 'delta': -4 })<CR>";
          #   options = { desc = "Прокрутка вверх в документации автодополнения"; silent = true; };
          # }
          # {
          #   key = "<C-d>";
          #   action = ":lua vim.fn['compe#scroll']({ 'delta': +4 })<CR>";
          #   options = { desc = "Прокрутка вниз в документации автодополнения"; silent = true; };
          # }
          # Dashboard Mappings
          # {
          #   key = "<leader>h";
          #   action = ":Dashboard<CR>";
          # }
          # Neo-Tree
          {
            key = "<leader>e";
            action = ":Neotree toggle<CR>";
            options = {
              desc = "Переключить Neotree";
              silent = true;
            };
          }
          {
            key = "<leader>o";
            action = ":Neotree focus<CR>";
            options = {
              desc = "Фокус на Neotree";
              silent = true;
            };
          }
          # Session Manager Mappings
          {
            mode = ["n" "v"];
            key = "<leader>S";
            action = "+Session";
            options = {desc = "📄 Session";};
          }
          {
            key = "<leader>Ss";
            action = ":SessionSave<CR>";
            options = {
              desc = "Сохранить сессию";
              silent = true;
            };
          }
          {
            key = "<leader>Sr";
            action = ":SessionRestore<CR>";
            options = {
              desc = "Восстановить сессию";
              silent = true;
            };
          }
          # {
          #   key = "<leader>Ss";
          #   action = ":SessionSave<CR>";
          #   options = { desc = "Сохранить сессию";  silent = true; };
          # }
          # {
          #   key = "<leader>Sl";
          #   action = ":SessionLoad<CR>";
          #   options = { desc = "Загрузить сессию";  silent = true; };
          # }
          # {
          #   key = "<leader>Sd";
          #   action = ":SessionDelete<CR>";
          #   options = { desc = "Удалить сессию";  silent = true; };
          # }
          # {
          #   key = "<leader>SD";
          #   action = ":SessionDeleteDirectory<CR>";
          #   options = { desc = "Удалить сессию директории";  silent = true; };
          # }
          # {
          #   key = "<leader>Sf";
          #   action = ":SessionSearch<CR>";
          #   options = { desc = "Поиск сессии";  silent = true; };
          # }
          # {
          #   key = "<leader>SF";
          #   action = ":SessionSearchDirectory<CR>";
          #   options = { desc = "Поиск сессий директории";  silent = true; };
          # }
          # {
          #   key = "<leader>S.";
          #   action = ":SessionLoadCurrentDirectory<CR>";
          #   options = { desc = "Загрузить сессию текущей директории";  silent = true; };
          # }
          # Package Management Mappings
          # {
          #   key = "<leader>pa";
          #   action = ":Lazy sync<CR>";
          #   options = { desc = "Синхронизировать пакеты";  silent = true; };
          # }
          # {
          #   key = "<leader>pi";
          #   action = ":Lazy install<CR>";
          #   options = { desc = "Установить пакеты";  silent = true; };
          # }
          # {
          #   key = "<leader>pm";
          #   action = ":Mason<CR>";
          #   options = { desc = "Открыть Mason";  silent = true; };
          # }
          # {
          #   key = "<leader>pM";
          #   action = ":MasonUpdate<CR>";
          #   options = { desc = "Обновить Mason";  silent = true; };
          # }
          # {
          #   key = "<leader>ps";
          #   action = ":Lazy check<CR>";
          #   options = { desc = "Проверить пакеты";  silent = true; };
          # }
          # {
          #   key = "<leader>pS";
          #   action = ":Lazy sync<CR>";
          #   options = { desc = "Синхронизировать пакеты";  silent = true; };
          # }
          # {
          #   key = "<leader>pu";
          #   action = ":Lazy update<CR>";
          #   options = { desc = "Обновить пакеты";  silent = true; };
          # }
          # {
          #   key = "<leader>pU";
          #   action = ":Lazy update<CR>";
          #   options = { desc = "Обновить пакеты";  silent = true; };
          # }
          # LSP Mappings
          # {
          #   key = "gD";
          #   action = ":lua vim.lsp.buf.declaration()<CR>";
          #   action = "<cmd>lsp_references<cr>";
          #   options = {
          #     desc = "Перейти к объявлению";
          #     silent = true;
          #   };
          # }
          {
            key = "gt";
            # action = ":lua vim.lsp.buf.type_definition()<CR>";
            action.__raw = ''function() require("telescope.builtin").lsp_type_definitions { reuse_win = true } end'';
            options = {
              desc = "Перейти к определению типа";
              silent = true;
            };
          }
          {
            key = "gd";
            # action = ":lua vim.lsp.buf.definition()<CR>";
            action.__raw = ''function() require("telescope.builtin").lsp_definitions { reuse_win = true } end'';
            options = {
              desc = "Перейти к определению";
              silent = true;
            };
          }
          {
            key = "gi";
            # action = ":lua vim.lsp.buf.implementation()<CR>";
            action.__raw = ''function() require("telescope.builtin").lsp_implementations { reuse_win = true } end'';
            options = {
              desc = "Перейти к реализации";
              silent = true;
            };
          }
          {
            key = "gr";
            # action = ":lua vim.lsp.buf.references()<CR>";
            # action = "require('telescope.builtin').lsp_references";
            action.__raw = ''function() require("telescope.builtin").lsp_references() end'';
            options = {
              desc = "Найти ссылки";
              silent = true;
            };
          }
          # {
          #   key = "<leader>lR";
          #   action = ":lua vim.lsp.buf.references()<CR>";
          #   options = { desc = "Найти ссылки"; silent = true; };
          # }
          {
            key = "<leader>li";
            action = ":LspInfo<CR>";
            options = {
              desc = "Информация о LSP";
              silent = true;
            };
          }
          # {
          #   key = "<leader>lI";
          #   action = ":NullLsInfo<CR>";
          #   options = { desc = "Информация о Null-LS"; silent = true; };
          # }
          {
            key = "K";
            action = ":lua vim.lsp.buf.hover()<CR>";
            options = {
              desc = "Показать описание";
              silent = true;
            };
          }
          # {
          #   key = "<leader>lf";
          #   action = ":lua vim.lsp.buf.formatting()<CR>";
          #   options = { desc = "Форматировать документ"; silent = true; };
          # }
          # {
          #   key = "<leader>lS";
          #   action = ":Telescope lsp_document_symbols<CR>";
          #   options = { desc = "Показать символы"; silent = true; };
          # }
          # {
          #   key = "gl";
          #   action = ":lua vim.diagnostic.open_float()<CR>";
          #   options = { desc = "Показать диагностику"; silent = true; };
          # }
          # {
          #   key = "<leader>ld";
          #   action = ":lua vim.diagnostic.open_float()<CR>";
          #   options = { desc = "Показать диагностику"; silent = true; };
          # }
          # {
          #   key = "<C-W>d";
          #   action = ":lua vim.diagnostic.open_float()<CR>";
          #   options = { desc = "Показать диагностику"; silent = true; };
          # }
          # {
          #   key = "<leader>lD";
          #   action = ":lua vim.diagnostic.setloclist()<CR>";
          #   options = { desc = "Добавить диагностику в список локаций"; silent = true; };
          # }
          # {
          #   key = "gra";
          #   action = ":lua vim.lsp.buf.code_action()<CR>";
          #   options = { desc = "Предложить действия с кодом"; silent = true; };
          # }
          # {
          #   key = "<leader>la";
          #   action = ":lua vim.lsp.buf.code_action()<CR>";
          #   options = { desc = "Предложить действия с кодом"; silent = true; };
          # }
          # {
          #   key = "<leader>lh";
          #   action = ":lua vim.lsp.buf.signature_help()<CR>";
          #   options = { desc = "Помощь с сигнатурами"; silent = true; };
          # }
          {
            key = "gn";
            action = "<CMD>lua vim.lsp.buf.rename()<CR>";
            options = {
              desc = "Переименовать символ";
              silent = true;
            };
          }
          {
            key = "<leader>lr";
            action = "<CMD>lua vim.lsp.buf.rename()<CR>";
            options = {
              desc = "Переименовать символ";
              silent = true;
            };
          }
          {
            key = "<leader>ls";
            action = ":lua vim.lsp.buf.document_symbol()<CR>";
            options = {
              desc = "Показать символы документа";
              silent = true;
            };
          }
          {
            key = "<leader>lG";
            action = "workspace_symbol";
            options = {
              desc = "Показать символы рабочей области";
              silent = true;
            };
          }
          {
            key = "]d";
            action = ":lua vim.diagnostic.goto_next()<CR>";
            options = {
              desc = "Перейти к следующей диагностике";
              silent = true;
            };
          }
          {
            key = "[d";
            action = ":lua vim.diagnostic.goto_prev()<CR>";
            options = {
              desc = "Перейти к предыдущей диагностике";
              silent = true;
            };
          }
          # Debugger Mappings
          {
            mode = ["n" "v"];
            key = "<leader>d";
            action = "+debug";
            options = {
              desc = "🛠️ Debug";
              silent = true;
            };
          }
          # {
          #   key = "<leader>d?";
          #   action = ":lua require('dapui').eval(nil, { enter = true })<cr>";
          #   options = { desc = "Оценить выражение"; silent = true; };
          # }
          {
            key = "<leader>dc";
            action = ":lua require('dap').continue()<CR>";
            options = {
              desc = "Запустить/продолжить отладку";
              silent = true;
            };
          }
          {
            key = "<F5>";
            action = ":lua require('dap').continue()<CR>";
            options = {
              desc = "Запустить/продолжить отладку";
              silent = true;
            };
          }
          {
            key = "<leader>dp";
            action = ":lua require('dap').pause()<CR>";
            options = {
              desc = "Пауза отладки";
              silent = true;
            };
          }
          {
            key = "<F6>";
            action = ":lua require('dap').pause()<CR>";
            options = {
              desc = "Пауза отладки";
              silent = true;
            };
          }
          {
            key = "<leader>dr";
            action = ":lua require('dap').restart()<CR>";
            options = {
              desc = "Перезапустить отладку";
              silent = true;
            };
          }
          {
            key = "<C-F5>";
            action = ":lua require('dap').restart()<CR>";
            options = {
              desc = "Перезапустить отладку";
              silent = true;
            };
          }
          {
            key = "<leader>ds";
            action = ":lua require('dap').run_to_cursor()<CR>";
            options = {
              desc = "Выполнить до курсора";
              silent = true;
            };
          }
          {
            key = "<leader>dq";
            action = ":lua require('dap').close()<CR>";
            options = {
              desc = "Закрыть отладку";
              silent = true;
            };
          }
          {
            key = "<leader>dQ";
            action = ":lua require('dap').terminate()<CR>";
            options = {
              desc = "Завершить отладку";
              silent = true;
            };
          }
          {
            key = "<S-F5>";
            action = ":lua require('dap').terminate()<CR>";
            options = {
              desc = "Завершить отладку";
              silent = true;
            };
          }
          # {
          #   key = "<leader>db";
          #   action = ":lua require('dap').toggle_breakpoint()<CR>";
          #   options = { desc = "Переключить точку останова"; silent = true; };
          # }
          {
            key = "<F9>";
            action = ":lua require('dap').toggle_breakpoint()<CR>";
            options = {
              desc = "Переключить точку останова";
              silent = true;
            };
          }
          # {
          #   key = "<leader>dC";
          #   action = ":lua require('dap').set_breakpoint(vim.fn.input('Breakpoint condition: '))<CR>";
          #   options = { desc = "Установить условную точку останова"; silent = true; };
          # }
          {
            key = "<S-F9>";
            action = ":lua require('dap').set_breakpoint(vim.fn.input('Breakpoint condition: '))<CR>";
            options = {
              desc = "Установить условную точку останова";
              silent = true;
            };
          }
          # {
          #   key = "<leader>dB";
          #   action = ":lua require('dap').clear_breakpoints()<CR>";
          #   options = { desc = "Очистить точки останова"; silent = true; };
          # }
          {
            key = "<leader>do";
            action = ":lua require('dap').step_over()<CR>";
            options = {
              desc = "Шаг с обходом";
              silent = true;
            };
          }
          {
            key = "<F10>";
            action = ":lua require('dap').step_over()<CR>";
            options = {
              desc = "Шаг с обходом";
              silent = true;
            };
          }
          {
            key = "<leader>di";
            action = ":lua require('dap').step_into()<CR>";
            options = {
              desc = "Шаг с заходом";
              silent = true;
            };
          }
          {
            key = "<F11>";
            action = ":lua require('dap').step_into()<CR>";
            options = {
              desc = "Шаг с заходом";
              silent = true;
            };
          }
          {
            key = "<leader>dO";
            action = ":lua require('dap').step_out()<CR>";
            options = {
              desc = "Шаг с выходом";
              silent = true;
            };
          }
          {
            key = "<S-F11>";
            action = ":lua require('dap').step_out()<CR>";
            options = {
              desc = "Шаг с выходом";
              silent = true;
            };
          }
          # {
          #   key = "<leader>dE";
          #   action = ":lua require('dap.ui).widgets'.hover()<CR>";
          #   options = { desc = "Оценить выражение"; silent = true; };
          # }
          {
            key = "<leader>dR";
            action = ":lua require('dap').repl.toggle()<CR>";
            options = {
              desc = "Переключить REPL";
              silent = true;
            };
          }
          {
            key = "<leader>du";
            action = ":lua require'dapui'.toggle()<CR>";
            options = {
              desc = "Переключить UI отладчика";
              silent = true;
            };
          }
          {
            key = "<leader>dh";
            action = ":lua require'dap.ui.widgets'.hover()<CR>";
            options = {
              desc = "Подсказка отладчика";
              silent = true;
            };
          }
          # Telescope Mappings
          {
            key = "<leader>f";
            action = "+find";
            options = {
              desc = "Telescope/Find";
              silent = true;
            };
          }
          {
            key = "<leader>fy";
            action = "<cmd>Telescope yank_history<cr>";
            options = {
              desc = "История yank";
              silent = true;
            };
          }
          {
            key = "<leader><CR>";
            action = ":Telescope resume<CR>";
            options = {
              desc = "Возобновить предыдущий поиск";
              silent = true;
            };
          }
          {
            key = "<leader>f'";
            action = ":Telescope marks<CR>";
            options = {
              desc = "Показать закладки";
              silent = true;
            };
          }
          {
            key = "<leader>fb";
            action = ":Telescope buffers<CR>";
            options = {
              desc = "Показать буферы";
              silent = true;
            };
          }
          {
            key = "<leader>fc";
            action = ":Telescope grep_string<CR>";
            options = {
              desc = "Поиск слова под курсором";
              silent = true;
            };
          }
          {
            key = "<leader>fC";
            action = ":Telescope commands<CR>";
            options = {
              desc = "Показать команды";
              silent = true;
            };
          }
          {
            key = "<leader>ff";
            action = ":Telescope find_files<CR>";
            options = {
              desc = "Найти файлы";
              silent = true;
            };
          }
          {
            key = "<leader>fF";
            action = ":Telescope find_files hidden=true<CR>";
            options = {
              desc = "Найти файлы (включая скрытые)";
              silent = true;
            };
          }
          {
            key = "<leader>fh";
            action = ":Telescope help_tags<CR>";
            options = {
              desc = "Показать справочные теги";
              silent = true;
            };
          }
          {
            key = "<leader>fk";
            action = ":Telescope keymaps<CR>";
            options = {
              desc = "Показать сочетания клавиш";
              silent = true;
            };
          }
          {
            key = "<leader>fm";
            action = ":Telescope man_pages<CR>";
            options = {
              desc = "Показать страницы man";
              silent = true;
            };
          }
          {
            key = "<leader>fn";
            action = ":Telescope notify<CR>";
            options = {
              desc = "Показать уведомления";
              silent = true;
            };
          }
          {
            key = "<leader>fo";
            action = ":Telescope oldfiles<CR>";
            options = {
              desc = "Показать недавно открытые файлы";
              silent = true;
            };
          }
          {
            key = "<leader>fr";
            action = ":Telescope registers<CR>";
            options = {
              desc = "Показать регистры";
              silent = true;
            };
          }
          {
            key = "<leader>ft";
            action = ":Telescope colorscheme<CR>";
            options = {
              desc = "Показать цветовые схемы";
              silent = true;
            };
          }
          {
            key = "<leader>fw";
            action = ":Telescope live_grep<CR>";
            options = {
              desc = "Поиск по тексту";
              silent = true;
            };
          }
          {
            key = "<leader>fW";
            action = ":Telescope live_grep hidden=true<CR>";
            options = {
              desc = "Поиск по тексту (включая скрытые файлы)";
              silent = true;
            };
          }
          {
            key = "<leader>g";
            action = "+git";
            options = {
              desc = " Git";
              silent = true;
            };
          }
          {
            # key = "<leader>gb";
            # action = ":Telescope git_branches<CR>";
            # options = { desc = "Показать ветки Git"; silent = true; };
            mode = "n";
            key = "<leader>gb";
            action = "<cmd>BlameToggle<CR>";
            options = {
              desc = "GitBlame";
              silent = true;
            };
          }
          {
            key = "<leader>gc";
            action = ":Telescope git_commits<CR>";
            options = {
              desc = "Показать коммиты Git";
              silent = true;
            };
          }
          {
            key = "<leader>gC";
            action = ":Telescope git_bcommits<CR>";
            options = {
              desc = "Показать коммиты текущего файла";
              silent = true;
            };
          }
          # {
          #   key = "<leader>gt";
          #   action = ":Telescope git_status<CR>";
          #   options = {
          #     desc = "Показать статус Git";
          #     silent = true;
          #   };
          # }
          {
            key = "<leader>l";
            action = "+lsp";
            options = {
              desc = "LSP";
              silent = true;
            };
          }
          {
            key = "<leader>ls";
            action = ":Telescope lsp_document_symbols<CR>";
            options = {
              desc = "Показать символы документа";
              silent = true;
            };
          }
          {
            key = "<leader>lG";
            action = ":Telescope lsp_workspace_symbols<CR>";
            options = {
              desc = "Показать символы рабочей области";
              silent = true;
            };
          }
          # {
          #   key = "gd";
          #   action.__raw = "lsp_definitions";
          #   options = {
          #     desc = "Показать определение";
          #     silent = true;
          #   };
          # }
          # {
          #   key = "gr";
          #   # action.__raw = "require('telescope.builtin').lsp_references";
          #   action = "lsp_references";
          #   options = {
          #     desc = "Показать ссылки";
          #     silent = true;
          #   };
          # }
          # {
          #   key = "gi";
          #   # action.__raw = "require('telescope.builtin').lsp_implementations";
          #   action = "implementation";
          #   options = {
          #     desc = "К имплементации";
          #     silent = true;
          #   };
          # }
          # {
          #   key = "gt";
          #   # action.__raw = "require('telescope.builtin').lsp_type_definitions";
          #   action = "lsp_type_definitions";
          #   options = {
          #     desc = "К определению типа";
          #     silent = true;
          #   };
          # }
          # Terminal Mappings
          {
            key = "<leader>t";
            action = "+terminal";
            options = {
              desc = "Terminal";
              silent = true;
            };
          }
          {
            key = "<leader>tf";
            action = ":FloatermNew<CR>";
            options = {
              desc = "Открыть плавающий терминал";
              silent = true;
            };
          }
          {
            key = "<F7>";
            action = ":FloatermNew<CR>";
            options = {
              desc = "Открыть плавающий терминал";
              silent = true;
            };
          }
          {
            key = "<leader>th";
            action = ":split | terminal<CR>";
            options = {
              desc = "Открыть горизонтальный терминал";
              silent = true;
            };
          }
          {
            key = "<leader>tv";
            action = ":vsplit | terminal<CR>";
            options = {
              desc = "Открыть вертикальный терминал";
              silent = true;
            };
          }
          {
            key = "<leader>tl";
            action = ":FloatermNew lazygit<CR>";
            options = {
              desc = "Открыть плавающий терминал с lazygit";
              silent = true;
            };
          }
          {
            key = "<leader>tn";
            action = ":FloatermNew node<CR>";
            options = {
              desc = "Открыть плавающий терминал с node";
              silent = true;
            };
          }
          {
            key = "<leader>tp";
            action = ":FloatermNew python<CR>";
            options = {
              desc = "Открыть плавающий терминал с python";
              silent = true;
            };
          }
          {
            key = "<leader>tt";
            action = ":FloatermNew btm<CR>";
            options = {
              desc = "Открыть плавающий терминал с btm";
              silent = true;
            };
          }
          # UI/UX Mappings
          {
            key = "<leader>u";
            action = "+UI/UX";
            options = {
              desc = "UI/UX";
              silent = true;
            };
          }
          {
            key = "<leader>ua";
            action = ":lua require('nvim-autopairs').toggle()<CR>";
            options = {
              desc = "Переключить автопары";
              silent = true;
            };
          }
          {
            key = "<leader>uA";
            action = ":lua require('rooter').toggle()<CR>";
            options = {
              desc = "Переключить автоматическое определение корневой директории";
              silent = true;
            };
          }
          {
            key = "<leader>ub";
            action = ":lua require('toggle-bg').toggle()<CR>";
            options = {
              desc = "Переключить фон";
              silent = true;
            };
          }
          {
            key = "<leader>uc";
            action = ":lua require('completion').toggle_buffer()<CR>";
            options = {
              desc = "Переключить автодополнение (буфер)";
              silent = true;
            };
          }
          {
            key = "<leader>uC";
            action = ":lua require('completion').toggle_global()<CR>";
            options = {
              desc = "Переключить автодополнение (глобально)";
              silent = true;
            };
          }
          {
            key = "<leader>ud";
            action = ":lua require('diagnostics').toggle()<CR>";
            options = {
              desc = "Переключить диагностику";
              silent = true;
            };
          }
          {
            key = "<leader>uD";
            action = ":lua require('notify').dismiss()<CR>";
            options = {
              desc = "Отклонить уведомления";
              silent = true;
            };
          }
          {
            key = "<leader>uf";
            action = ":lua require('formatting').toggle_buffer()<CR>";
            options = {
              desc = "Переключить автоформатирование (буфер)";
              silent = true;
            };
          }
          {
            key = "<leader>uF";
            action = ":lua require('formatting').toggle_global()<CR>";
            options = {
              desc = "Переключить автоформатирование (глобально)";
              silent = true;
            };
          }
          {
            key = "<leader>ug";
            action = ":lua require('signcolumn').toggle()<CR>";
            options = {
              desc = "Переключить колонку знаков";
              silent = true;
            };
          }
          {
            key = "<leader>u>";
            action = ":lua require('foldcolumn').toggle()<CR>";
            options = {
              desc = "Переключить колонку сворачивания";
              silent = true;
            };
          }
          {
            key = "<leader>uh";
            action = ":lua require('lsp_inlay_hints').toggle_buffer()<CR>";
            options = {
              desc = "Переключить подсказки LSP (буфер)";
              silent = true;
            };
          }
          {
            key = "<leader>uH";
            action = ":lua require('lsp_inlay_hints').toggle_global()<CR>";
            options = {
              desc = "Переключить подсказки LSP (глобально)";
              silent = true;
            };
          }
          {
            key = "<leader>ui";
            action = ":lua require('indent_setting').toggle()<CR>";
            options = {
              desc = "Переключить настройку отступов";
              silent = true;
            };
          }
          {
            key = "<leader>u|";
            action = ":lua require('indent_guides').toggle()<CR>";
            options = {
              desc = "Переключить направляющие отступов";
              silent = true;
            };
          }
          {
            key = "<leader>ul";
            action = ":lua require('statusline').toggle()<CR>";
            options = {
              desc = "Переключить строку состояния";
              silent = true;
            };
          }
          {
            key = "<leader>uL";
            action = ":lua require('codelens').toggle()<CR>";
            options = {
              desc = "Переключить CodeLens";
              silent = true;
            };
          }
          {
            key = "<leader>un";
            action = ":lua require('line_numbering').change()<CR>";
            options = {
              desc = "Изменить нумерацию строк";
              silent = true;
            };
          }
          {
            key = "<leader>uN";
            action = ":lua require('notify').toggle()<CR>";
            options = {
              desc = "Переключить уведомления";
              silent = true;
            };
          }
          {
            key = "<leader>up";
            action = ":lua require('paste_mode').toggle()<CR>";
            options = {
              desc = "Переключить режим вставки";
              silent = true;
            };
          }
          {
            key = "<leader>ur";
            action = ":lua require('reference_highlighting').toggle_buffer()<CR>";
            options = {
              desc = "Переключить выделение ссылок (буфер)";
              silent = true;
            };
          }
          {
            key = "<leader>uR";
            action = ":lua require('reference_highlighting').toggle_global()<CR>";
            options = {
              desc = "Переключить выделение ссылок (глобально)";
              silent = true;
            };
          }
          {
            key = "<leader>us";
            action = ":lua require('spellcheck').toggle()<CR>";
            options = {
              desc = "Переключить проверку орфографии";
              silent = true;
            };
          }
          {
            key = "<leader>uS";
            action = ":lua require('conceal').toggle()<CR>";
            options = {
              desc = "Переключить скрытие текста";
              silent = true;
            };
          }
          {
            key = "<leader>ut";
            action = ":lua require('tabline').toggle()<CR>";
            options = {
              desc = "Переключить табы";
              silent = true;
            };
          }
          {
            key = "<leader>uu";
            action = ":lua require('url_highlighting').toggle()<CR>";
            options = {
              desc = "Переключить выделение URL";
              silent = true;
            };
          }
          {
            key = "<leader>uw";
            action = ":lua require('wrap').toggle()<CR>";
            options = {
              desc = "Переключить перенос строк";
              silent = true;
            };
          }
          {
            key = "<leader>uy";
            action = ":lua require('syntax_highlighting').toggle_buffer()<CR>";
            options = {
              desc = "Переключить подсветку синтаксиса (буфер)";
              silent = true;
            };
          }
          {
            key = "<leader>uY";
            action = ":lua require('lsp_semantic_tokens').toggle_buffer()<CR>";
            options = {
              desc = "Переключить LSP семантические токены (буфер)";
              silent = true;
            };
          }
          {
            key = "<leader>uz";
            action = ":lua require('color_highlighting').toggle()<CR>";
            options = {
              desc = "Переключить подсветку цвета";
              silent = true;
            };
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
        ]
        ++ lib.optionals config.programs.nixvim.plugins.dap.extensions.dap-ui.enable [
          {
            mode = "n";
            key = "<leader>d?";
            action.__raw = ''
              function()
              vim.ui.input({ prompt = "Expression: " }, function(expr)
              if expr then require("dapui").eval(expr, { enter = true }) end
              end)
              end
            '';
            options = {
              desc = "Оценить выражение";
              silent = true;
            };
          }
          # {
          #   mode = "n";
          #   key = "<Leader>dC";
          #   action.__raw =
          #   ''
          #   function()
          #     vim.ui.input({ prompt = "Expression: " }, function(expr)
          #     if condition then require("dap").set_breakpoint(condition) end
          #     end)
          #   end
          #   '';
          #   options = {
          #     desc = "Оценить выражение";
          #     silent = true;
          #   };
          # }
        ];
    };
  };
}
