# Claude Neovim Plugins Comparison

A comprehensive comparison of Neovim plugins for integrating Claude AI into your development workflow.

## Overview

This document compares four main approaches to integrating Claude AI with Neovim:

1. **greggh/claude-code.nvim** - Terminal-based Claude Code integration
 **coder/claudecode.nvim** - WebSocket-based MCP protocol implementation
3. **pasky/claude.vim** - Direct API integration with pair programming focus
4. **IntoTheNull/claude.nvim** - Chat interface with code assistance

---

## Quick Comparison Matrix

| Feature | greggh/claude-code.nvim | coder/claudecode.nvim | pasky/claude.vim | IntoTheNull/claude.nvim |
|---------|-------------------------|----------------------|------------------|------------------------|
| **Integration Type** | Terminal wrapper | WebSocket/MCP | Direct API | Direct API |
| **Claude Code CLI** | Required | Required | Not needed | Not needed |
| **API Key Required** | Via Claude Code | Via Claude Code | Yes | Yes |
| **Max Plan Support** | Yes (via CLI) | Yes (via CLI) | No | No |
| **Zero Dependencies** | No (needs plenary) | Yes | Yes | No (needs curl) |
| **Vim Support** | Neovim only | Neovim only | Vim + Neovim | Neovim only |
| **Min Neovim Version** | 0.7.0+ | 0.8.0+ | Any | 0.7.0+ |
| **Chat Interface** | Terminal-based | Terminal-based | Built-in | Built-in |
| **Code Completion** | Via Claude Code | Via Claude Code | Manual | Manual |
| **Diff Support** | Via Claude Code | Native | No | No |
| **Real-time Context** | Via Claude Code | Yes | Limited | Limited |

---

## Detailed Analysis

### 1. greggh/claude-code.nvim

**Best for:** Users who want to use official Claude Code within Neovim

#### Strengths
- ✅ Official Claude Code integration
- ✅ Supports Max plan subscription
- ✅ Automatic file reload detection
- ✅ Git project root detection
- ✅ Customizable terminal positioning
- ✅ Built entirely with Claude Code (dogfooding)

#### Weaknesses
- ❌ Requires Claude Code CLI installation
- ❌ Depends on plenary.nvim
- ❌ Terminal-based interface only
- ❌ Limited to Claude Code capabilities

#### Installation
```lua
{
  "greggh/claude-code.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = true,
  keys = {
    { "<C-,>", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude Code" },
    { "<leader>cC", "<cmd>ClaudeCodeContinue<cr>", desc = "Continue conversation" },
  }
}
```

#### Key Commands
- `:ClaudeCode` - Toggle terminal window
- `:ClaudeCodeContinue` - Resume conversation
- `:ClaudeCodeVerbose` - Enable verbose logging

---

### 2. coder/claudecode.nvim

**Best for:** Advanced users wanting native Claude Code integration with MCP protocol

#### Strengths
- ✅ Zero external dependencies (pure Lua)
- ✅ WebSocket-based MCP implementation
- ✅ Native diff support
- ✅ Real-time context tracking
- ✅ Same protocol as VS Code extension
- ✅ Supports Max plan (via Claude Code CLI)

#### Weaknesses
- ❌ Requires Claude Code CLI
- ❌ More complex setup
- ❌ Newer codebase (potentially less stable)
- ❌ Requires Neovim 0.8.0+

#### Installation
```lua
{
  "coder/claudecode.nvim",
  dependencies = { "folke/snacks.nvim" }, -- optional
  config = true,
  keys = {
    { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude" },
    { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send to Claude" }
  }
}
```

#### Key Commands
- `:ClaudeCode` - Toggle Claude terminal
- `:ClaudeCodeSend` - Send visual selection
- `:ClaudeCodeDiffAccept` - Accept changes
- `:ClaudeCodeDiffDeny` - Reject changes

---

### 3. pasky/claude.vim

**Best for:** Direct API integration with traditional Vim/Neovim compatibility

#### Strengths
- ✅ Works with both Vim and Neovim
- ✅ Direct API integration (no CLI dependency)
- ✅ Sees all open buffers
- ✅ Shell command execution
- ✅ Web search integration
- ✅ Python expression evaluation
- ✅ AWS Bedrock support

#### Weaknesses
- ❌ Requires API key (no Max plan support)
- ❌ Early alpha software
- ❌ No built-in diff support
- ❌ Limited context compared to Claude Code
- ❌ May rapidly change (unstable API)

#### Installation
```bash
# Vim
mkdir -p ~/.vim/pack/pasky/start
cd ~/.vim/pack/pasky/start
git clone https://github.com/pasky/claude.vim.git

# Neovim
mkdir -p ~/.config/nvim/pack/pasky/start
cd ~/.config/nvim/pack/pasky/start
git clone https://github.com/pasky/claude.vim.git
```

#### Configuration
```vim
let g:claude_api_key = 'your_api_key_here'
let g:claude_use_bedrock = 1  " Optional AWS Bedrock
```

#### Key Bindings
- `<Leader>ci` - ClaudeImplement
- `<Leader>cc` - Open Claude chat
- `<C-]>` - Send chat message
- `<Leader>cx` - Cancel response

---

### 4. IntoTheNull/claude.nvim

**Best for:** Interactive chat interface with code assistance features

#### Strengths
- ✅ Clean chat interface
- ✅ Token usage monitoring
- ✅ Code refactoring capabilities
- ✅ Visual selection processing
- ✅ MIT license
- ✅ Comprehensive documentation
- ✅ Adaptive UI

#### Weaknesses
- ❌ Requires API key (no Max plan support)
- ❌ Limited context compared to Claude Code
- ❌ No diff support
- ❌ Depends on curl
- ❌ Manual code application

#### Installation
```lua
{
  "IntoTheNull/claude.nvim",
  config = function()
    require("claude").setup({
      api_key_cmd = "cat ~/.config/claude/api_key", -- or your preferred method
      model = "claude-3-5-sonnet-20241022",
    })
  end,
  keys = {
    { "<leader>cc", "<cmd>Claude<cr>", desc = "Open Claude Chat" },
  }
}
```

#### Key Commands
- `:Claude` - Open chat interface
- `:ClaudeSubmitLine` - Submit current line
- `:ClaudeSubmitRange` - Submit range
- `:ClaudeContinue` - Continue response

---

## Recommendations

### Choose **greggh/claude-code.nvim** if:
- You want to use official Claude Code within Neovim
- You have a Max plan subscription
- You prefer terminal-based interaction
- You want the most complete Claude integration

### Choose **coder/claudecode.nvim** if:
- You want cutting-edge MCP protocol integration
- You need native diff support
- You prefer zero external dependencies
- You're comfortable with newer, evolving software

### Choose **pasky/claude.vim** if:
- You use both Vim and Neovim
- You want direct API control
- You need web search and shell execution
- You're okay with early alpha software

### Choose **IntoTheNull/claude.nvim** if:
- You want a clean chat interface
- You prefer visual code selection workflows
- You need token usage monitoring
- You want stable, well-documented software

---

## Installation Prerequisites

### For Claude Code-based plugins (greggh, coder):
1. Install Claude Code CLI:
   ```bash
   # Via npm
   npm install -g @anthropic/claude-code
   
   # Or download binary from GitHub releases
   ```
2. Authenticate with Max plan or API key:
   ```bash
   claude auth login
   ```

### For Direct API plugins (pasky, IntoTheNull):
1. Get Anthropic API key from [console.anthropic.com](https://console.anthropic.com)
2. Store securely (environment variable, config file, etc.)

---

## Conclusion

The choice depends on your specific needs:

- **Maximum features & official support**: greggh/claude-code.nvim
- **Cutting-edge integration**: coder/claudecode.nvim  
- **Traditional Vim compatibility**: pasky/claude.vim
- **Clean chat experience**: IntoTheNull/claude.nvim

All plugins are actively maintained and provide valuable Claude AI integration for different use cases.
