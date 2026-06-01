FROM node:22-slim

RUN apt-get update && apt-get install -y \
    curl ca-certificates git expect python3 \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
        https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code

# Godot 4 headless (ARM64)
RUN apt-get update && apt-get install -y unzip libgl1 libgles2 \
    && rm -rf /var/lib/apt/lists/* \
    && curl -L "https://github.com/godotengine/godot/releases/download/4.4.1-stable/Godot_v4.4.1-stable_linux.arm64.zip" \
       -o /tmp/godot.zip \
    && unzip /tmp/godot.zip -d /tmp/godot \
    && mv /tmp/godot/Godot_v4.4.1-stable_linux.arm64 /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && rm -rf /tmp/godot.zip /tmp/godot

# Non-root user — --dangerously-skip-permissions is blocked for root
RUN useradd -m -s /bin/bash worker && chmod 777 /home/worker \
    && mkdir -p /home/worker/.claude && chown worker:worker /home/worker/.claude

COPY .claude/worker-container.sh /worker.sh
COPY .claude/entrypoint.sh /entrypoint.sh
RUN chmod +x /worker.sh /entrypoint.sh

USER worker

CMD ["/entrypoint.sh"]
