# Visual Studio Code - Code Editor

## Overview

Visual Studio Code (VS Code) is a free, open-source code editor built by Microsoft. It combines the simplicity of a source code editor with powerful developer tooling like IntelliSense, debugging, and built-in Git support. Its extension marketplace makes it adaptable to virtually any language or workflow.

## Why Use VS Code?

- **Lightweight yet powerful** - Fast startup with IDE-level features
- **Massive extension ecosystem** - 50,000+ extensions for every language and tool
- **Built-in terminal and Git** - No context switching needed
- **Remote development** - Edit code on remote machines, containers, or WSL seamlessly
- **Cross-platform** - Consistent experience on macOS, Linux, and Windows
- **Free and open source** - MIT-licensed core (VS Code OSS)

## Installation

### macOS

```bash
# Via Homebrew (recommended)
brew install --cask visual-studio-code

# Add 'code' to PATH (if not automatic)
# Open Command Palette (Cmd+Shift+P) > "Shell Command: Install 'code' command in PATH"
```

### Linux

```bash
# Debian/Ubuntu
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
sudo apt update && sudo apt install code

# Fedora/RHEL
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo
sudo dnf install code

# Snap
sudo snap install code --classic
```

### Windows

```powershell
# Via winget
winget install Microsoft.VisualStudioCode

# Via Chocolatey
choco install vscode
```

## Essential Extensions

### General Development

| Extension                  | ID                                     | Purpose                          |
|----------------------------|----------------------------------------|----------------------------------|
| GitLens                    | eamodio.gitlens                        | Git supercharged (blame, history)|
| Error Lens                 | usernamehw.errorlens                   | Inline error/warning display     |
| EditorConfig               | editorconfig.editorconfig              | Consistent coding styles         |
| Path Intellisense          | christian-kohler.path-intellisense     | File path autocomplete           |
| Better Comments            | aaron-bond.better-comments             | Colored comment annotations      |
| Todo Tree                  | gruntfuggly.todo-tree                  | Find and list TODO comments      |

### DevOps / Cloud

| Extension                  | ID                                     | Purpose                          |
|----------------------------|----------------------------------------|----------------------------------|
| Docker                     | ms-azuretools.vscode-docker            | Dockerfile, Compose support      |
| Kubernetes                 | ms-kubernetes-tools.vscode-kubernetes-tools | K8s cluster management     |
| HashiCorp Terraform        | hashicorp.terraform                    | Terraform HCL support            |
| YAML                       | redhat.vscode-yaml                     | YAML validation and schemas      |
| Remote - SSH               | ms-vscode-remote.remote-ssh            | Develop on remote machines       |
| GitHub Actions             | github.vscode-github-actions           | Workflow file support            |

### Language-Specific

| Extension                  | ID                                     | Purpose                          |
|----------------------------|----------------------------------------|----------------------------------|
| Python                     | ms-python.python                       | Python IntelliSense, linting     |
| Pylance                    | ms-python.vscode-pylance               | Fast Python language server      |
| ESLint                     | dbaeumer.vscode-eslint                 | JavaScript/TypeScript linting    |
| Prettier                   | esbenp.prettier-vscode                 | Code formatter (JS, CSS, etc.)   |
| Go                         | golang.go                              | Go language support              |
| Rust Analyzer              | rust-lang.rust-analyzer                | Rust language support            |

### AI-Powered

| Extension                  | ID                                     | Purpose                          |
|----------------------------|----------------------------------------|----------------------------------|
| GitHub Copilot             | github.copilot                         | AI code completion               |
| GitHub Copilot Chat        | github.copilot-chat                    | AI chat for code questions       |
| Claude Code (CLI)          | anthropic.claude-code                  | Claude-powered coding assistant  |

```bash
# Install extensions from CLI
code --install-extension eamodio.gitlens
code --install-extension ms-python.python
code --install-extension hashicorp.terraform
```

## Settings Customization

Settings are stored in JSON. Open with `Cmd+,` (macOS) / `Ctrl+,` (Windows/Linux), then click the `{}` icon for JSON view.

### Recommended settings.json

```jsonc
{
  // Editor
  "editor.fontSize": 14,
  "editor.fontFamily": "'JetBrains Mono', 'Fira Code', Menlo, monospace",
  "editor.fontLigatures": true,
  "editor.tabSize": 2,
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "editor.minimap.enabled": false,
  "editor.bracketPairColorization.enabled": true,
  "editor.guides.bracketPairs": "active",
  "editor.inlineSuggest.enabled": true,
  "editor.stickyScroll.enabled": true,
  "editor.wordWrap": "on",
  "editor.rulers": [80, 120],

  // Files
  "files.autoSave": "onFocusChange",
  "files.trimTrailingWhitespace": true,
  "files.insertFinalNewline": true,
  "files.exclude": {
    "**/.git": true,
    "**/.DS_Store": true,
    "**/node_modules": true,
    "**/__pycache__": true
  },

  // Terminal
  "terminal.integrated.fontSize": 13,
  "terminal.integrated.defaultProfile.osx": "zsh",
  "terminal.integrated.scrollback": 10000,

  // Git
  "git.autofetch": true,
  "git.confirmSync": false,
  "git.enableSmartCommit": true,

  // Workbench
  "workbench.colorTheme": "One Dark Pro",
  "workbench.iconTheme": "material-icon-theme",
  "workbench.startupEditor": "none",

  // Language overrides
  "[python]": {
    "editor.defaultFormatter": "ms-python.black-formatter",
    "editor.tabSize": 4
  },
  "[go]": {
    "editor.defaultFormatter": "golang.go",
    "editor.tabSize": 4
  },
  "[markdown]": {
    "editor.wordWrap": "on",
    "editor.quickSuggestions": false
  }
}
```

## Key Keybindings

### Navigation

| Action                    | macOS              | Windows/Linux       |
|---------------------------|--------------------|---------------------|
| Command Palette           | `Cmd+Shift+P`     | `Ctrl+Shift+P`     |
| Quick Open (file)         | `Cmd+P`            | `Ctrl+P`            |
| Go to Symbol              | `Cmd+Shift+O`     | `Ctrl+Shift+O`     |
| Go to Definition          | `F12`              | `F12`               |
| Peek Definition           | `Option+F12`       | `Alt+F12`           |
| Go to Line                | `Ctrl+G`           | `Ctrl+G`            |
| Toggle Sidebar            | `Cmd+B`            | `Ctrl+B`            |
| Toggle Terminal           | `` Ctrl+` ``       | `` Ctrl+` ``        |
| Switch Editor Tab         | `Cmd+1/2/3`        | `Ctrl+1/2/3`        |

### Editing

| Action                    | macOS              | Windows/Linux       |
|---------------------------|--------------------|---------------------|
| Multi-cursor              | `Option+Click`     | `Alt+Click`         |
| Select all occurrences    | `Cmd+Shift+L`     | `Ctrl+Shift+L`     |
| Move line up/down         | `Option+Up/Down`   | `Alt+Up/Down`       |
| Duplicate line            | `Shift+Option+Down`| `Shift+Alt+Down`    |
| Delete line               | `Cmd+Shift+K`     | `Ctrl+Shift+K`     |
| Toggle comment            | `Cmd+/`            | `Ctrl+/`            |
| Rename symbol             | `F2`               | `F2`                |
| Format document           | `Shift+Option+F`   | `Shift+Alt+F`       |
| Quick fix                 | `Cmd+.`            | `Ctrl+.`            |

### Custom Keybindings (keybindings.json)

```jsonc
[
  {
    "key": "cmd+shift+d",
    "command": "editor.action.copyLinesDownAction",
    "when": "editorTextFocus"
  },
  {
    "key": "cmd+k cmd+t",
    "command": "workbench.action.openGlobalKeybindings"
  }
]
```

## Remote Development

VS Code's remote development extensions let you develop as if everything were local while the code runs elsewhere.

### Remote - SSH

```bash
# Install the extension
code --install-extension ms-vscode-remote.remote-ssh

# Configure SSH hosts in ~/.ssh/config
# Host dev-server
#   HostName 10.0.1.50
#   User developer
#   IdentityFile ~/.ssh/id_ed25519
#   ForwardAgent yes

# Connect: Cmd+Shift+P > "Remote-SSH: Connect to Host"
```

### Dev Containers

Develop inside a Docker container with a consistent, reproducible environment.

```jsonc
// .devcontainer/devcontainer.json
{
  "name": "Python Dev",
  "image": "mcr.microsoft.com/devcontainers/python:3.12",
  "features": {
    "ghcr.io/devcontainers/features/node:1": {},
    "ghcr.io/devcontainers/features/aws-cli:1": {}
  },
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-python.python",
        "ms-python.vscode-pylance"
      ],
      "settings": {
        "python.defaultInterpreterPath": "/usr/local/bin/python"
      }
    }
  },
  "postCreateCommand": "pip install -r requirements.txt",
  "forwardPorts": [8000]
}
```

### WSL (Windows Subsystem for Linux)

```bash
# Install the extension
code --install-extension ms-vscode-remote.remote-wsl

# Open a WSL folder from Windows terminal
code --remote wsl+Ubuntu /home/user/project
```

## Debugging Configuration

### launch.json Examples

```jsonc
// .vscode/launch.json
{
  "version": "0.2.0",
  "configurations": [
    // Python
    {
      "name": "Python: Current File",
      "type": "debugpy",
      "request": "launch",
      "program": "${file}",
      "console": "integratedTerminal",
      "env": { "PYTHONPATH": "${workspaceFolder}" }
    },
    // Node.js
    {
      "name": "Node: Current File",
      "type": "node",
      "request": "launch",
      "program": "${file}",
      "runtimeArgs": ["--experimental-modules"]
    },
    // Attach to running process
    {
      "name": "Attach to Process",
      "type": "node",
      "request": "attach",
      "port": 9229
    },
    // Docker
    {
      "name": "Docker: Attach",
      "type": "node",
      "request": "attach",
      "port": 9229,
      "localRoot": "${workspaceFolder}",
      "remoteRoot": "/app"
    }
  ]
}
```

### tasks.json (Build Tasks)

```jsonc
// .vscode/tasks.json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Run Tests",
      "type": "shell",
      "command": "pytest",
      "args": ["-v", "--tb=short"],
      "group": { "kind": "test", "isDefault": true },
      "problemMatcher": []
    },
    {
      "label": "Build Docker Image",
      "type": "shell",
      "command": "docker",
      "args": ["build", "-t", "myapp:latest", "."],
      "group": "build"
    }
  ]
}
```

## Workspace Settings and Multi-Root Workspaces

### Workspace Settings

Settings can be scoped at three levels: User > Workspace > Folder.

```jsonc
// .vscode/settings.json (workspace level)
{
  "python.defaultInterpreterPath": "./venv/bin/python",
  "editor.tabSize": 4,
  "files.associations": {
    "*.tf": "terraform",
    "Jenkinsfile": "groovy"
  },
  "search.exclude": {
    "**/dist": true,
    "**/coverage": true
  }
}
```

### Multi-Root Workspaces

Work with multiple project folders in a single window.

```jsonc
// myproject.code-workspace
{
  "folders": [
    { "path": "./frontend", "name": "Frontend (React)" },
    { "path": "./backend", "name": "Backend (Python)" },
    { "path": "./infra", "name": "Infrastructure (Terraform)" }
  ],
  "settings": {
    "files.exclude": { "**/node_modules": true }
  },
  "extensions": {
    "recommendations": [
      "ms-python.python",
      "dbaeumer.vscode-eslint",
      "hashicorp.terraform"
    ]
  }
}
```

```bash
# Open multi-root workspace
code myproject.code-workspace
```

## Profiles

Profiles let you maintain different sets of settings, extensions, and UI configurations for different workflows.

```bash
# Create a profile via Command Palette:
# "Profiles: Create Profile" > name it (e.g., "Python Dev", "DevOps")

# Export a profile to share
# Command Palette > "Profiles: Export Profile"

# Import a profile
# Command Palette > "Profiles: Import Profile"

# Switch profiles via status bar (bottom-left gear icon)
```

**Example profiles:**

| Profile     | Extensions                               | Theme       | Tab Size |
|-------------|------------------------------------------|-------------|----------|
| Python Dev  | Python, Pylance, Black, Ruff             | One Dark    | 4        |
| Web Dev     | ESLint, Prettier, Tailwind CSS           | Dracula     | 2        |
| DevOps      | Docker, Terraform, Kubernetes, YAML      | GitHub Dark | 2        |
| Writing     | Markdown All-in-One, Spell Checker       | Solarized   | 2        |

## GitHub Copilot

GitHub Copilot provides AI-powered code suggestions directly in the editor.

```jsonc
// settings.json - Copilot configuration
{
  "github.copilot.enable": {
    "*": true,
    "plaintext": false,
    "markdown": true,
    "yaml": true
  },
  "github.copilot.advanced": {}
}
```

**Key features:**
- **Inline suggestions** - Tab to accept, `Esc` to dismiss
- **Copilot Chat** - `Cmd+I` for inline chat, `Cmd+Shift+I` for Chat panel
- **Code explanation** - Select code, ask "Explain this"
- **Test generation** - `/tests` command in Copilot Chat
- **Fix errors** - `/fix` command for suggested fixes

## Claude Code Extension

Claude Code integrates Claude as a coding assistant via the terminal and editor.

```bash
# Install Claude Code CLI
npm install -g @anthropic-ai/claude-code

# Launch in a project
cd /path/to/project
claude

# Common usage patterns
claude "explain this codebase"
claude "find and fix the bug in auth.py"
claude "write tests for the user service"
claude "refactor this function for readability"
```

**Key capabilities:**
- Full codebase understanding via file reading and search
- Multi-file editing with precise diffs
- Terminal command execution for builds and tests
- Git integration for commits and PRs
- Agentic workflow with tool use

## Best Practices

1. **Use workspace settings** - Keep project-specific config in `.vscode/settings.json`
2. **Share recommended extensions** - Add `.vscode/extensions.json` to the repo
3. **Use profiles** - Different tool sets for different projects
4. **Master keyboard shortcuts** - Minimize mouse usage for faster editing
5. **Configure format on save** - Consistent code style without manual effort
6. **Use tasks** - Automate repetitive build/test commands
7. **Leverage multi-root workspaces** - Keep related projects together
8. **Regularly update** - VS Code ships monthly updates with significant improvements
9. **Use `.editorconfig`** - Ensure consistency across different editors on the team
10. **Set up debugging properly** - Breakpoints are faster than print statements

## Resources

- [VS Code Documentation](https://code.visualstudio.com/docs)
- [VS Code Tips and Tricks](https://code.visualstudio.com/docs/getstarted/tips-and-tricks)
- [Extension Marketplace](https://marketplace.visualstudio.com/vscode)
- [Dev Containers Specification](https://containers.dev/)
- [VS Code Keybinding Reference (macOS)](https://code.visualstudio.com/shortcuts/keyboard-shortcuts-macos.pdf)
- [GitHub Copilot Docs](https://docs.github.com/en/copilot)
- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)
