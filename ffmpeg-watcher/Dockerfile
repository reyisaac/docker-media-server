FROM jrottenberg/ffmpeg:6.1-nvidia

# Install inotify-tools for folder watching and bc for calculations
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    inotify-tools \
    bash \
    coreutils \
    gosu \
    bc \
    && rm -rf /var/lib/apt/lists/*

# Set default PUID and PGID
ENV PUID=1000 \
    PGID=1000

# Copy transcoding script and entrypoint
COPY transcode.sh /usr/local/bin/transcode.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/transcode.sh /usr/local/bin/entrypoint.sh

# Create working directory
WORKDIR /watch

# Run the entrypoint script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

