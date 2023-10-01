#!/usr/bin/env bash
#
#  - Bootstrap script for Linux machines
#
# Usage:
#
#  ./bootstrap.sh
#
# Based on a template by BASH3 Boilerplate v2.3.0
# http://bash3boilerplate.sh/#authors

# Exit on error. Append "|| true" if you expect an error.
set -o errexit
# Exit on error inside any functions or subshells.
set -o errtrace
# Do not allow use of undefined vars. Use ${VAR:-} to use an undefined VAR
set -o nounset
# Catch the error in case mysqldump fails (but gzip succeeds) in `mysqldump |gzip`
set -o pipefail
# Turn on traces, useful while debugging but commented out by default
# set -o xtrace

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source="./logging.sh"
source "./logging.sh"

pause() {
    read -r -p "Press Enter to continue or Ctrl-C to terminate..."
}

backup_file() {
    if [ -f "${HOME}/$1" ] || [ -h "${HOME}/$1" ]; then
        mv "${HOME}/$1" "${HOME}/${1}-$(date +%Y%m%d%H%M%S).bak"
        info "${HOME}/$1 backed up."
    fi

    # If second argument is true, create a symbolic link
    if [ "$2" = true ]; then
        ln -s "${BASE_DIR}/$1" "${HOME}/$1"
        info "Symbolic link created:"
        ls -al "${HOME}/$1"
    fi
}

backup_dotfiles() {
    backup_file .alias true
    backup_file .bashrc true
    backup_file .gitconfig true
    backup_file .p10k.zsh true
    backup_file .zshrc true
    backup_file .vimrc true
    backup_file .tmux.conf true
    backup_file .ssh/config false
}

generate_git_ssh_key() {
    local IDENTITY_FILE="id_ed25519_github"
    local GITHUB_USER="romankhar"
    eval "$(ssh-agent -s)"

    if [[ ! -f ~/.ssh/${IDENTITY_FILE} ]]; then
        info "Generating SSH key..."
        ssh-keygen -t ed25519 -C "kharkovski@gmail.com" -f ~/.ssh/${IDENTITY_FILE}
        # ssh-keygen -t rsa -C "${GITHUB_USER}@users.noreply.github.com" -f ~/.ssh/${IDENTITY_FILE} -N ""
        info "##### Add this public SSH key to your GitHub account:"
        cat ~/.ssh/${IDENTITY_FILE}.pub

        # Add SSH key to the keychain
        touch ~/.ssh/config
        # Append key to the ssh config file and keychain
        echo "Host github.com
        Host *.github.com
        IdentityFile ~/.ssh/${IDENTITY_FILE}
        AddKeysToAgent yes
        UseKeychain yes
        " >> ~/.ssh/config

        # Make sure MacOS automatically adds new ssh key to the keychain
        ssh-add --apple-use-keychain ~/.ssh/${IDENTITY_FILE}

        info "##### Follow step 4 to complete: https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account"
        info "##### After you added SSH key to your GitHub account, you can run 'ssh -T git@github.com' to verify your configuration."
        pause
    else
        info "SSH key already exists. Skipping..."
    fi
}

bootstrap_projects() {
    info "Bootstrapping projects..."
    mkdir -p "${HOME}/projects"
    info "Project Workspace bootstrap completed."
}

##############################################################################
# Runtime
##############################################################################
main() {
    info "Bootstrap starting. You may be asked for your password (for sudo)."
    backup_dotfiles
    generate_git_ssh_key
    bootstrap_projects

    # Debian/Ubuntu based systems
    if [ -f "/etc/debian_version" ]; then
        if grep -q "Raspbian" /etc/os-release; then
            info "Raspbian systems found. Bootstrapping system..."
            source ./bootstrap-raspbian.sh
        else
            info "Debian/Ubuntu based systems found. Bootstrapping system..."
            source ./bootstrap-debian.sh
        fi
    fi

    # Redhat/CentOS based systems
    if [ -f "/etc/redhat-release" ]; then
        info "Redhat/CentOS based systems found."
        error "Redhat/CentOS based systems are not supported yet."
        exit 1
    fi

    # MacOS
    if [ -f "/usr/bin/sw_vers" ]; then
        info "macOS found. Bootstrapping system..."
        source ./bootstrap-macos.sh
    fi

    info "System bootstrap complete."
}

main
