# shellcheck shell=bash
home="$(getent passwd "$GZ_USER" | cut -d: -f6)"
gz_ensure_line "$home/.bashrc" 'source /usr/share/gentoozinho/default/bash/rc'
chown "$GZ_USER" "$home/.bashrc"
