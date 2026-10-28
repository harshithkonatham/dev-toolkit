# macOS Setup Essentials

This guide will help you set up your new macOS system with essential tools and configurations for development and productivity.

## System Preferences

1. **Dock & Menu Bar**
   - Minimize windows using: Scale effect
   - Automatically hide and show the Dock: Enabled

2. **Trackpad**
   - Tap to click: Enabled
   - Tracking speed: Fast

3. **Keyboard**
   - Key Repeat: Fast
   - Delay Until Repeat: Short

4. **Finder**
   - Show all filename extensions: Enabled
   - Show Path Bar: Enabled
   - Show Status Bar: Enabled

## Applications

### Homebrew

Homebrew is a package manager for macOS. Install it by running the following command in the Terminal:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Development Tools

1. **iTerm2**: A better terminal for macOS.
   ```sh
   brew install --cask iterm2
   ```

2. **Visual Studio Code**: A powerful code editor.
   ```sh
   brew install --cask visual-studio-code
   ```

3. **Git**: Version control system.
   ```sh
   brew install git
   ```

4. **Node.js & npm**: JavaScript runtime and package manager.
   ```sh
   brew install node
   ```

5. **Docker**: Container platform.
   ```sh
   brew install --cask docker
   ```

### Productivity Tools

1. **Google Chrome**: Web browser.
   ```sh
   brew install --cask google-chrome
   ```

2. **Slack**: Team communication.
   ```sh
   brew install --cask slack
   ```

3. **Zoom**: Video conferencing.
   ```sh
   brew install --cask zoom
   ```

4. **Alfred**: Productivity application.
   ```sh
   brew install --cask alfred
   ```

5. **Rectangle**: Window management.
   ```sh
   brew install --cask rectangle
   ```

## Terminal Customization

1. **Oh My Zsh**: Framework for managing Zsh configuration.
   ```sh
   sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
   ```

2. **Powerlevel10k**: Theme for Zsh.
   ```sh
   git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
   ```
   Set `ZSH_THEME="powerlevel10k/powerlevel10k"` in your `~/.zshrc`.

3. **Zsh Plugins**:
   - zsh-syntax-highlighting:
     ```sh
     brew install zsh-syntax-highlighting
     ```
   - zsh-autosuggestions:
     ```sh
     brew install zsh-autosuggestions
     ```

## Additional Configurations

1. **Git Configuration**
   ```sh
   git config --global user.name "Your Name"
   git config --global user.email "you@example.com"
   ```

2. **SSH Key Generation**
   ```sh
   ssh-keygen -t rsa -b 4096 -C "you@example.com"
   ```

3. **Set macOS Defaults**
   ```sh
   # Show hidden files in Finder
   defaults write com.apple.finder AppleShowAllFiles -bool true

   # Restart Finder to apply changes
   killall Finder
   ```

## Conclusion

With these tools and configurations, your macOS system will be set up for development and productivity. Customize further based on your specific needs and preferences.
```` ▋