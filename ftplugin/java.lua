local jdtls = require("jdtls")

-- find_root returns the CLOSEST ancestor containing any marker, so per-module
-- build files (build.gradle/build.gradle.kts) are deliberately excluded: in a
-- multi-module Gradle/Maven build a submodule has its own build.gradle.kts, and
-- rooting there hides the wrapper + settings at the real project root. jdtls
-- would then fall back to its bundled Gradle instead of the project's wrapper.
-- These markers only exist at the true build root.
local root_dir = require("jdtls.setup").find_root({
	"settings.gradle.kts",
	"settings.gradle",
	"gradlew",
	"mvnw",
	"pom.xml",
	".git",
})

if root_dir == nil then
	return
end

-- A separate workspace per project so jdtls keeps each project's index isolated.
local workspace_dir = vim.fn.stdpath("data") .. "/jdtls-workspace/" .. vim.fn.fnamemodify(root_dir, ":p:h:t")

-- Advertise the same completion capabilities the rest of the LSPs use (cmp).
local capabilities = require("cmp_nvim_lsp").default_capabilities()

-- jdtls-specific client capabilities: enables code actions like "organize
-- imports", generate getters/setters, hashCode/equals, etc.
local extendedClientCapabilities = jdtls.extendedClientCapabilities
extendedClientCapabilities.resolveAdditionalTextEditsSupport = true

-- Collect the debug + test bundles installed via Mason so DAP and the test
-- runner work. Globbed by pattern so a version bump doesn't break the path.
local mason = vim.fn.stdpath("data") .. "/mason/packages"
local bundles = {}
vim.list_extend(
	bundles,
	vim.split(vim.fn.glob(mason .. "/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar"), "\n")
)
vim.list_extend(bundles, vim.split(vim.fn.glob(mason .. "/java-test/extension/server/*.jar"), "\n"))

-- jdtls needs a real JDK on disk for every JavaSE-XX execution environment a
-- project's toolchain targets, otherwise the JRE classpath container is
-- "unbound" and even java.lang fails to resolve. Gradle toolchains auto-download
-- JDKs under ~/.gradle/jdks; discover any of those plus the system JDKs and
-- register each by its release version so the right one binds per project.
local function jdk_version(home)
	for line in io.lines(home .. "/release") do
		local v = line:match('^JAVA_VERSION="(%d+)')
		if v then
			return v
		end
	end
end

local runtimes = {}
local jdk_homes = {}
vim.list_extend(jdk_homes, vim.fn.glob(vim.fn.expand("~") .. "/.gradle/jdks/*", true, true))
vim.list_extend(jdk_homes, vim.fn.glob("/usr/lib/jvm/*", true, true))
local seen = {}
for _, home in ipairs(jdk_homes) do
	if vim.fn.executable(home .. "/bin/java") == 1 then
		local ok, major = pcall(jdk_version, home)
		if ok and major and not seen[major] then
			seen[major] = true
			table.insert(runtimes, { name = "JavaSE-" .. major, path = home })
		end
	end
end

local on_attach = function(_, bufnr)
	local opts = { buffer = bufnr }
	-- Java-only refactorings provided by jdtls beyond the generic LSP keymaps.
	vim.keymap.set("n", "<leader>oi", jdtls.organize_imports, opts)
	vim.keymap.set("n", "<leader>ev", jdtls.extract_variable, opts)
	vim.keymap.set("n", "<leader>ec", jdtls.extract_constant, opts)
	vim.keymap.set("v", "<leader>em", function()
		jdtls.extract_method(true)
	end, opts)
	-- Run/debug the current test class or nearest test method.
	vim.keymap.set("n", "<leader>tc", jdtls.test_class, opts)
	vim.keymap.set("n", "<leader>tm", jdtls.test_nearest_method, opts)

	-- Wire jdtls into nvim-dap so the bundles above can launch debug sessions.
	jdtls.setup_dap({ hotcodereplace = "auto" })
end

jdtls.start_or_attach({
	cmd = { "jdtls", "-data", workspace_dir },
	root_dir = root_dir,
	capabilities = capabilities,
	on_attach = on_attach,
	init_options = {
		bundles = bundles,
		extendedClientCapabilities = extendedClientCapabilities,
	},
	settings = {
		java = {
			configuration = {
				runtimes = runtimes,
			},
			-- Quality-of-life: static import favorites for tests, signature help,
			-- decompiler for class files, and parameter-name inlay hints.
			completion = {
				favoriteStaticMembers = {
					"org.junit.jupiter.api.Assertions.*",
					"org.mockito.Mockito.*",
				},
			},
			signatureHelp = { enabled = true },
			contentProvider = { preferred = "fernflower" },
			sources = {
				organizeImports = {
					starThreshold = 9999,
					staticStarThreshold = 9999,
				},
			},
			inlayHints = {
				parameterNames = { enabled = "all" },
			},
		},
	},
})
