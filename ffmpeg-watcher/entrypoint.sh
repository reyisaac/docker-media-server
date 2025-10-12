#!/bin/bash
set -e

# Create group and user with specified PUID/PGID
PUID=${PUID:-1000}
PGID=${PGID:-1000}

# Create group if it doesn't exist
if ! getent group abc > /dev/null 2>&1; then
    groupadd -g "$PGID" abc
fi

# Create user if it doesn't exist
if ! getent passwd abc > /dev/null 2>&1; then
    useradd -u "$PUID" -g "$PGID" -d /home/abc -s /bin/bash abc
fi

# Ensure the user has the correct UID/GID
usermod -o -u "$PUID" abc > /dev/null 2>&1 || true
groupmod -o -g "$PGID" abc > /dev/null 2>&1 || true

# Fix permissions on working directory and create necessary subdirectories
mkdir -p /watch/.locks /watch/.logs
chown -R abc:abc /watch

# Run the transcoding script as the abc user
exec gosu abc /usr/local/bin/transcode.sh

