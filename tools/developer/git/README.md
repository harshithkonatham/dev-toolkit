# Git - Version Control System

## Overview

Git is a distributed version control system designed for speed, data integrity, and support for distributed, non-linear workflows. Created by Linus Torvalds in 2005 for Linux kernel development, it has become the de facto standard for source code management.

## Why Use Git?

- **Distributed architecture** - Every clone is a full repository with complete history
- **Branching and merging** - Lightweight branches enable parallel development
- **Data integrity** - SHA-1 hashing ensures content integrity
- **Speed** - Most operations are local and near-instantaneous
- **Staging area** - Fine-grained control over what gets committed
- **Open source** - Free, widely supported, massive ecosystem

## Architecture

Git stores data as snapshots of a file system, not as a list of file-based changes.

```
Working Directory  -->  Staging Area (Index)  -->  Local Repository  -->  Remote Repository
      |                       |                          |                       |
   git add              git commit                  git push               (GitHub, etc.)
      |                       |                          |                       |
   git restore          git restore --staged        git fetch / git pull        |
```

**Key objects:**

| Object   | Description                                    |
|----------|------------------------------------------------|
| Blob     | Stores file content                            |
| Tree     | Stores directory structure (references blobs)   |
| Commit   | Points to a tree + metadata (author, message)   |
| Tag      | Named reference to a specific commit            |

## Installation

### macOS

```bash
# Via Homebrew (recommended)
brew install git

# Via Xcode Command Line Tools
xcode-select --install
```

### Linux

```bash
# Debian/Ubuntu
sudo apt update && sudo apt install git

# RHEL/CentOS/Fedora
sudo dnf install git

# Arch
sudo pacman -S git
```

### Windows

```powershell
# Via winget
winget install Git.Git

# Via Chocolatey
choco install git

# Or download from https://git-scm.com/download/win
```

## Global Configuration

```bash
# Identity
git config --global user.name "Your Name"
git config --global user.email "you@example.com"

# Default branch name
git config --global init.defaultBranch main

# Editor
git config --global core.editor "code --wait"   # VS Code
git config --global core.editor "vim"            # Vim

# Line endings
git config --global core.autocrlf input   # macOS/Linux
git config --global core.autocrlf true    # Windows

# Useful aliases
git config --global alias.st status
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.lg "log --oneline --graph --all --decorate"

# Credential caching
git config --global credential.helper osxkeychain   # macOS
git config --global credential.helper cache          # Linux (15-min default)

# View all config
git config --list --show-origin
```

## Branching Strategies

### Git Flow

Best for projects with scheduled releases.

```
main ─────────────────────────────────────────────►
  │                              ▲
  └── develop ───────────────────┤
        │        ▲               │
        └─ feature/xyz ──┘      │
        │        ▲               │
        └─ release/1.0 ─────────┘
  │                              ▲
  └── hotfix/urgent ─────────────┘
```

```bash
# Feature branch
git checkout develop
git checkout -b feature/user-auth
# ... work ...
git checkout develop && git merge --no-ff feature/user-auth

# Release branch
git checkout develop
git checkout -b release/1.0
# ... final fixes ...
git checkout main && git merge --no-ff release/1.0
git tag -a v1.0 -m "Release 1.0"
```

### GitHub Flow

Simpler model for continuous deployment.

```bash
# 1. Branch from main
git checkout -b feature/add-search

# 2. Commit changes
git add . && git commit -m "Add search functionality"

# 3. Push and open PR
git push -u origin feature/add-search
gh pr create --title "Add search" --body "Implements search feature"

# 4. Review, approve, merge via PR
# 5. Deploy from main
```

### Trunk-Based Development

Rapid integration, best for experienced teams with strong CI/CD.

```bash
# Short-lived branches (< 1 day)
git checkout -b fix/typo-header
git commit -am "Fix header typo"
git push -u origin fix/typo-header
# Merge PR immediately after review
# Feature flags for incomplete features
```

## Advanced Commands

### Interactive Rebase

```bash
# Rewrite last 3 commits
git rebase -i HEAD~3

# Commands in the editor:
# pick   - keep commit as is
# reword - change commit message
# edit   - pause to amend commit
# squash - merge into previous commit
# fixup  - like squash but discard message
# drop   - remove commit
```

### Cherry-Pick

```bash
# Apply a specific commit to current branch
git cherry-pick <commit-sha>

# Cherry-pick without committing (stage only)
git cherry-pick --no-commit <commit-sha>

# Cherry-pick a range
git cherry-pick A..B
```

### Bisect

Find the commit that introduced a bug using binary search.

```bash
git bisect start
git bisect bad                 # Current commit is broken
git bisect good v1.0           # v1.0 was working
# Git checks out a middle commit - test it
git bisect good                # or git bisect bad
# Repeat until the offending commit is found
git bisect reset               # Return to original state

# Automated bisect with a test script
git bisect start HEAD v1.0
git bisect run ./test.sh
```

### Stash

```bash
git stash                          # Stash tracked changes
git stash -u                       # Include untracked files
git stash save "work in progress"  # Named stash
git stash list                     # List stashes
git stash pop                      # Apply and remove latest stash
git stash apply stash@{2}          # Apply specific stash (keep it)
git stash drop stash@{0}           # Remove a stash
git stash branch new-branch        # Create branch from stash
```

### Reflog

```bash
# View history of HEAD movements
git reflog

# Recover a deleted branch
git reflog
git checkout -b recovered-branch <sha-from-reflog>

# Undo a bad rebase
git reflog
git reset --hard HEAD@{5}
```

### Worktrees

```bash
# Check out a branch in a separate directory
git worktree add ../feature-branch feature/new-ui
git worktree list
git worktree remove ../feature-branch
```

## Git Hooks

Hooks live in `.git/hooks/` (local) or can be shared via a hooks directory.

```bash
# Share hooks via repository
mkdir .githooks
git config core.hooksPath .githooks
```

### Common Hooks

| Hook              | Trigger                       | Use Case                        |
|-------------------|-------------------------------|---------------------------------|
| pre-commit        | Before commit is created      | Linting, formatting, tests      |
| commit-msg        | After message is entered      | Enforce message format          |
| pre-push          | Before push to remote         | Run test suite                  |
| post-merge        | After a merge completes       | Install dependencies            |
| pre-rebase        | Before rebase starts          | Prevent rebase on shared branch |

### Example: pre-commit Hook

```bash
#!/bin/bash
# .githooks/pre-commit

# Run linter
echo "Running linter..."
npm run lint
if [ $? -ne 0 ]; then
  echo "Lint failed. Fix errors before committing."
  exit 1
fi

# Check for secrets
if git diff --cached --name-only | xargs grep -l "API_KEY\|SECRET\|PASSWORD" 2>/dev/null; then
  echo "Potential secrets detected. Aborting commit."
  exit 1
fi
```

### Example: commit-msg Hook (Conventional Commits)

```bash
#!/bin/bash
# .githooks/commit-msg
PATTERN="^(feat|fix|docs|style|refactor|perf|test|chore|ci|build)(\(.+\))?: .{1,72}$"
if ! grep -qE "$PATTERN" "$1"; then
  echo "Invalid commit message format."
  echo "Expected: type(scope): description"
  echo "Example:  feat(auth): add OAuth2 login support"
  exit 1
fi
```

## .gitignore Patterns

```gitignore
# OS files
.DS_Store
Thumbs.db

# IDE / editors
.vscode/
.idea/
*.swp
*.swo

# Dependencies
node_modules/
vendor/
__pycache__/
*.pyc

# Build output
dist/
build/
*.o
*.class

# Environment and secrets
.env
.env.local
*.pem
*.key
credentials.json

# Logs
*.log
logs/

# Terraform
.terraform/
*.tfstate
*.tfstate.backup

# Negation - track a specific file
!.gitkeep
!config/.env.example
```

**Useful commands:**

```bash
# Check why a file is ignored
git check-ignore -v path/to/file

# List all ignored files
git status --ignored

# Remove tracked file that is now in .gitignore
git rm --cached path/to/file
```

## Collaboration Workflows

### Pull Request Workflow

```bash
# 1. Sync with upstream
git checkout main && git pull origin main

# 2. Create feature branch
git checkout -b feature/new-api

# 3. Make changes and commit
git add -A && git commit -m "feat(api): add user endpoint"

# 4. Push and create PR
git push -u origin feature/new-api
gh pr create --title "Add user API endpoint" --body "Description here"

# 5. Address review comments, push more commits
git add . && git commit -m "fix: address review feedback"
git push

# 6. After approval - squash merge via GitHub UI or:
gh pr merge --squash
```

### Fork Workflow (Open Source)

```bash
# 1. Fork via GitHub UI, then clone your fork
git clone https://github.com/YOUR-USER/project.git
cd project

# 2. Add upstream remote
git remote add upstream https://github.com/ORIGINAL/project.git

# 3. Keep fork updated
git fetch upstream
git checkout main
git merge upstream/main
git push origin main

# 4. Create branch, work, push to your fork, open PR to upstream
```

## Signing Commits with GPG

```bash
# Generate GPG key
gpg --full-generate-key   # Choose RSA 4096

# List keys
gpg --list-secret-keys --keyid-format=long

# Get key ID (after "sec rsa4096/")
# Example output: sec rsa4096/ABC123DEF456 2024-01-01

# Configure Git
git config --global user.signingkey ABC123DEF456
git config --global commit.gpgsign true
git config --global tag.gpgsign true

# Export public key for GitHub
gpg --armor --export ABC123DEF456
# Paste output into GitHub > Settings > SSH and GPG keys

# Sign a commit manually
git commit -S -m "signed commit"

# Verify signatures
git log --show-signature
```

## Modern Git Features

### Sparse Checkout

Work with a subset of files in a large monorepo.

```bash
# Enable sparse checkout
git clone --filter=blob:none --sparse https://github.com/org/monorepo.git
cd monorepo

# Add directories you need
git sparse-checkout set services/auth libs/common
git sparse-checkout add services/payments

# List sparse checkout patterns
git sparse-checkout list

# Disable (get everything back)
git sparse-checkout disable
```

### Scalar

Optimize Git for large repositories (developed by Microsoft).

```bash
# Install scalar (included with Git 2.38+)
scalar clone https://github.com/org/large-repo.git

# Register an existing repo for background maintenance
scalar register

# Features scalar enables:
# - Filesystem monitor (fsmonitor)
# - Commit graph
# - Multi-pack index
# - Sparse checkout
# - Background prefetch and maintenance
```

### Other Useful Modern Features

```bash
# Partial clone (reduce clone time for large repos)
git clone --filter=blob:none https://github.com/org/repo.git

# Maintenance (background optimization)
git maintenance start

# git switch / git restore (clearer alternatives to checkout)
git switch feature-branch          # switch branches
git switch -c new-branch           # create and switch
git restore file.txt               # discard working directory changes
git restore --staged file.txt      # unstage
```

## Best Practices

1. **Write meaningful commit messages** - Use imperative mood, explain why not what
2. **Commit often, push regularly** - Small atomic commits are easier to review and revert
3. **Never commit secrets** - Use `.gitignore` and tools like `git-secrets` or `gitleaks`
4. **Use branches** - Keep `main` deployable at all times
5. **Review before merging** - Code review catches bugs and spreads knowledge
6. **Rebase feature branches** - Keep history clean with `git rebase main` before merging
7. **Tag releases** - Use semantic versioning (`v1.2.3`)
8. **Use `.gitattributes`** - Define line endings and merge strategies per file type
9. **Keep repos focused** - One project per repository; use monorepo tools if needed
10. **Clean up stale branches** - `git branch --merged | xargs git branch -d`

## Resources

- [Pro Git Book (free)](https://git-scm.com/book/en/v2)
- [Git Reference Manual](https://git-scm.com/docs)
- [GitHub Skills](https://skills.github.com/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Git Flight Rules](https://github.com/k88hudson/git-flight-rules)
- [Learn Git Branching (interactive)](https://learngitbranching.js.org/)
- [Scalar Documentation](https://github.com/microsoft/scalar)
