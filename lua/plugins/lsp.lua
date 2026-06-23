return {
	{
		"mason-org/mason.nvim",
		config = function()
			require("mason").setup()
		end,
	},
	{
		"mason-org/mason-lspconfig.nvim",
		config = function()
			require("mason-lspconfig").setup({
				ensure_installed = {
					"lua_ls",
					"ts_ls",
					"html",
					"cssls",
					"tailwindcss",
					"dockerls",
					"sqlls",
					"jsonls",
					"yamlls",
					"pyright",
					"clangd",
				},
				-- Java is driven entirely by nvim-jdtls (see ftplugin/java.lua).
				-- Excluding it here prevents mason-lspconfig from auto-starting a
				-- second, competing jdtls client on every Java buffer.
				automatic_enable = {
					exclude = { "jdtls" },
				},
			})
		end,
	},
	{
		"neovim/nvim-lspconfig",
		config = function()
			local capabilities = require("cmp_nvim_lsp").default_capabilities()

			local servers = {
				lua_ls = {
					settings = {
						Lua = {
							diagnostics = {
								globals = { "vim" },
							},
						},
					},
				},
				ts_ls = {},
				html = {},
				cssls = {},
				tailwindcss = {},
				dockerls = {},
				sqlls = {},
				jsonls = {},
				yamlls = {},
				pyright = {},
				clangd = {},
			}

			for server, cfg in pairs(servers) do
				cfg.capabilities = vim.tbl_deep_extend("force", {}, capabilities, cfg.capabilities or {})
				vim.lsp.config(server, cfg)
				vim.lsp.enable(server)
			end
			vim.keymap.set("n", "K", vim.lsp.buf.hover, {})
			vim.keymap.set("n", "gD", vim.lsp.buf.definition, {})
			vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, {})
		end,
	},
	{
		"mfussenegger/nvim-jdtls",
		ft = { "java" },
		dependencies = {
			"mfussenegger/nvim-dap",
			{
				"rcarriga/nvim-dap-ui",
				dependencies = { "nvim-neotest/nvim-nio" },
				config = function()
					local dap, dapui = require("dap"), require("dapui")
					dapui.setup()
					-- Open/close the debugger UI automatically with the session.
					dap.listeners.before.attach.dapui_config = dapui.open
					dap.listeners.before.launch.dapui_config = dapui.open
					dap.listeners.before.event_terminated.dapui_config = dapui.close
					dap.listeners.before.event_exited.dapui_config = dapui.close
				end,
			},
		},
	},
}
