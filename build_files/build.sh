#!/bin/bash

set -ouex pipefail

# region setup

install() {
    dnf5 install -y "$@"
}

install-from-copr() {
    copr="$1"
    shift
    dnf5 copr enable "$copr" -y
    dnf5 install "$@" -y
    dnf5 copr disable "$copr" -y
}

install-from-obs-repo() {
    repo="$1"
    shift
    release="Fedora_$(awk -F= '/VERSION_ID/ {print $2}' /etc/os-release)"
    dnf5 config-manager addrepo -y \
        --from-repofile="https://download.opensuse.org/repositories/$repo/$release/$repo.repo"
    dnf5 install "$@" -y
    rm "/etc/yum.repos.d/$repo.repo"
}

set-os-release() {
    for arg in "$@"; do
        sed -i "$arg" /usr/lib/os-release
    done
}

# endregion
# region branding

# This section adapted from:
#    https://github.com/winblues/blue95/blob/main/files/scripts/00-image-info.sh
# Authors:
#    jahinzee, ledif
# Changes:
#    + added metis-iii/Metis III branding
#    + custom hostname
#    + added generic logos
#    + added ID_LIKE fixes
#    + refactored into bash functions

IMAGE_VENDOR="jahinzee"
IMAGE_NAME="metis-iii"
IMAGE_PRETTY_NAME="Metis III"
IMAGE_LIKE="fedora"
HOME_URL="https://github.com/jahinzee/metis-iii"
DOCUMENTATION_URL="https://github.com/jahinzee/metis-iii/blob/main/README.md"
SUPPORT_URL="https://github.com/jahinzee/metis-iii/issues"
BUG_SUPPORT_URL="https://github.com/jahinzee/metis-iii/issues"

IMAGE_INFO="/usr/share/ublue-os/image-info.json"
IMAGE_REF="ostree-image-signed:docker://ghcr.io/$IMAGE_VENDOR/$IMAGE_NAME"

FEDORA_MAJOR_VERSION=$(awk -F= '/VERSION_ID/ {print $2}' /etc/os-release)
BASE_IMAGE_NAME="Kinoite $FEDORA_MAJOR_VERSION"
BASE_IMAGE="ghcr.io/ublue-os/kinoite-main"

DEFAULT_HOSTNAME="localhost"

cat >$IMAGE_INFO <<EOF
{
  "image-name": "$IMAGE_NAME",
  "image-vendor": "$IMAGE_VENDOR",
  "image-ref": "$IMAGE_REF",
  "image-tag":"latest",
  "base-image-name": "$BASE_IMAGE",
  "fedora-version": "$FEDORA_MAJOR_VERSION"
}
EOF

# Customise /etc/os-release
set-os-release \
    "s/^VARIANT_ID=.*/VARIANT_ID=$IMAGE_NAME/" \
    "s/^PRETTY_NAME=.*/PRETTY_NAME=\"${IMAGE_PRETTY_NAME} (FROM Fedora ${BASE_IMAGE_NAME^})\"/" \
    "s/^NAME=.*/NAME=\"$IMAGE_PRETTY_NAME\"/" \
    "s/^ID=.*/ID=\"$IMAGE_NAME\"/" \
    "s|^HOME_URL=.*|HOME_URL=\"$HOME_URL\"|" \
    "s|^DOCUMENTATION_URL=.*|DOCUMENTATION_URL=\"$DOCUMENTATION_URL\"|" \
    "s|^SUPPORT_URL=.*|SUPPORT_URL=\"$SUPPORT_URL\"|" \
    "s|^BUG_REPORT_URL=.*|BUG_REPORT_URL=\"$BUG_SUPPORT_URL\"|" \
    "s|^CPE_NAME=\"cpe:/o:fedoraproject:fedora|CPE_NAME=\"cpe:/o:winblues:${IMAGE_PRETTY_NAME,}|" \
    "s/^DEFAULT_HOSTNAME=.*/DEFAULT_HOSTNAME=\"${DEFAULT_HOSTNAME,}\"/" \
    "s/^ID=fedora/ID=${IMAGE_PRETTY_NAME,}\nID_LIKE=\"${IMAGE_LIKE}\"/" \

# Add ID_LIKE tag to allow external apps to properly identify that this is based on Fedora Atomic
echo "ID_LIKE=\"${IMAGE_LIKE}\"" >> /usr/lib/os-release

# Fix issues caused by ID no longer being fedora
sed -i "s/^EFIDIR=.*/EFIDIR=\"fedora\"/" /usr/sbin/grub2-switch-to-blscfg

# Switch to generic logos, because why not
dnf swap fedora-logos generic-logos -y

# endregion

#  ··· Packages: Graphical applications
#      + install KDE utilities for multimedia and system maintenance
#
install elisa \
        gwenview \
        haruna \
        kalk \
        kclock \
        kcm_systemd \
        kcolorchooser \
        kolourpaint \
        krdc \
        ksystemlog \
        merkuro \
        okular \
        plasma-browser-integration \
        yakuake \

#  ··· Packages: CLI utilities
#      + install cli tweaks and utilities
#
install bat \
        btop \
        distrobox \
        fastfetch \
        fd \
        fish \
        helix \
        pipx \
        podman-docker \
        podman-compose \
        qalculate \
        ripgrep \
        vim \
        zoxide

# See: <https://github.com/eza-community/eza/blob/main/INSTALL.md#fedora>
install-from-copr dturner/eza \
                  eza
install-from-copr lilay/topgrade \
                  topgrade
install-from-copr atim/starship \
                  starship

#  ··· Packages: Virtualisation
#      + install the libvirt/QEMU/KVM virtualisation stack
#
install @virtualization

# ··· Packages: IMEs
#     + install IMEs for Japanese (fcitx) and Bengali (openbangla)
#
install fcitx5 \
        fcitx5-mozc \
        kcm-fcitx5
install-from-copr badshah/openbangla-keyboard \
                  fcitx-openbangla

#  ··· Homebrew support packages
#      + install Homebrew support packages
#
# Since Homebrew is a user-level tool, integrating it on the system layer doesn't make a lot of
# sense, but installing the dependencies is fine.
install @development-tools \
        procps-ng \
        curl \
        file

#  ··· Packages: Syncthing
#      + install Syncthing and Syncthing-Tray and KDE integrations (Plasmoid, KIO and CLI)
#
install syncthing
install-from-obs-repo home:mkittler \
                      syncthingplasmoid-qt6 \
                      syncthingfileitemaction-qt6 \
                      syncthingctl-qt6

#  ··· Packages: Printer drivers
#      + install Brother laser printer drivers
#
install printer-driver-brlaser

# # copr-pkg: ghostty
# install-from-copr scottames/ghostty \
#                   ghostty

# copr-pkg: Zen Browser
# FIX: The zen-browser package needs to throw some stuff in /opt, which doesn't exist, so we'll make
#      /var/opt (which is already symlinked to /opt) so the package will install properly.
rm /opt && mkdir /opt
install-from-copr sneexy/zen-browser \
                  zen-browser

# # ext-pkg: Librewolf (extern repo)
# curl -fsSL https://repo.librewolf.net/librewolf.repo | tee /etc/yum.repos.d/librewolf.repo
# install librewolf

# # setup: Native messaging support for Plasma integration.
# # NOTE: The instructions from the Librewolf FAQ don't work for Fedora, since Fedora's Firefox
# #       package installs the hosts at /usr/lib64 instead of /usr/lib. 
# #       See: https://codeberg.org/librewolf/issues/issues/2383
# #
# # FIXME: still does not work '-'
# mkdir /usr/lib/librewolf
# ln -s /usr/lib64/mozilla/native-messaging-hosts /usr/lib/librewolf/native-messaging-hosts