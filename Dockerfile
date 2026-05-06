# syntax=docker/dockerfile:1

ARG FROM_IMAGE=ubuntu:0.1
ARG SERVER_USER=dev
ARG ORGANIZATION="foo"
ARG VERSION="Unknown"
ARG PP_DEV_USE_VIM=false

# ============================================================
# base
# ============================================================
FROM ${FROM_IMAGE} AS base

ARG FROM_IMAGE
ARG SERVER_USER
ARG ORGANIZATION="foo"
ARG VERSION="Unknown"

ARG DEBIAN_FRONTEND=noninteractive

COPY ./docker/assets/build/system/opt/ddf/run-ddf-build-hooks.sh /opt/ddf/run-ddf-build-hooks.sh
RUN chmod 755 /opt/ddf/run-ddf-build-hooks.sh

RUN if [ "$FROM_IMAGE" = "ubuntu:0.1" ]; then \
      echo "ERROR: FROM_IMAGE not set; pass --build-arg FROM_IMAGE=..."; \
      exit 1; \
    fi

ENV TZ=America/New_York
LABEL org.opencontainers.image.title="DDF Development Framework" \
      org.opencontainers.image.description="Multi-stage dev/prod container framework" \
      org.opencontainers.image.vendor="${ORGANIZATION}" \
      org.opencontainers.image.version="${VERSION}"
WORKDIR /opt

# basic packages
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo "$TZ" > /etc/timezone \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        iproute2 \
        make \
        perl \
        openssh-client \
        tzdata \
        wget \
    && rm -rf /var/lib/apt/lists/*

# user setup
RUN useradd -m -G dialout,video,plugdev -s /bin/bash ${SERVER_USER}

# workspace
RUN mkdir -p /workspace \
    && chown ${SERVER_USER}:${SERVER_USER} /workspace

COPY .generated/ddf-build-hooks/base/ /opt/ddf/build-hooks/base/
RUN /opt/ddf/run-ddf-build-hooks.sh base

# ============================================================
# dev-core
# ============================================================
FROM base AS dev-core

ARG SERVER_USER
ARG PP_DEV_USE_VIM

WORKDIR /opt

# dev-core packages
RUN apt-get update && apt-get install -y --no-install-recommends \
        autoconf \
        automake \
        build-essential \
        ccache \
        cmake \
        gdb \
        git \
        less \
        libbz2-dev \
        libncurses-dev \
        libtool \
        nano \
        ninja-build \
        pkg-config \
        python3 \
        python3-dev \
        python3-pip \
        python3-venv \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

COPY .generated/ddf-build-hooks/dev-core/ /opt/ddf/build-hooks/dev-core/
RUN /opt/ddf/run-ddf-build-hooks.sh dev-core

# ============================================================
# dev-tooling
# ============================================================
FROM dev-core AS dev-tooling

ARG SERVER_USER
ENV SERVER_USER=${SERVER_USER}
ENV SERVER_GROUP=${SERVER_USER}
ARG PP_DEV_USE_VIM

WORKDIR /opt

# system scripts
COPY ./docker/assets/dev/system/sbin/ /sbin
RUN chmod 755 /sbin/docker-*

# dev-tooling packages
RUN apt-get update && apt-get install -y --no-install-recommends \
        debconf-utils \
        fzf \
        man-db \
        neovim \
        ripgrep \
        sudo \
        xauth \
    && rm -rf /var/lib/apt/lists/*

# user files
COPY ./docker/assets/dev/user /home/${SERVER_USER}
RUN mkdir -p /home/${SERVER_USER}/bin \
    && printf '%s\n' \
      'case ":$PATH:" in' \
      '  *:"$HOME/bin":*) ;;' \
      '  *) export PATH="$HOME/bin:$PATH" ;;' \
      'esac' \
      >> /home/${SERVER_USER}/.bashrc \
    && chown -R ${SERVER_USER}:${SERVER_USER} /home/${SERVER_USER}
# keyboard config
COPY ./docker/assets/selections.conf /opt/selections.conf
RUN apt-get update \
    && debconf-set-selections < /opt/selections.conf \
    && apt-get install -y --no-install-recommends keyboard-configuration \
    && rm -rf /var/lib/apt/lists/*

# sudo + shell setup
RUN usermod -a -G sudo ${SERVER_USER} \
    && echo "\n# developer setup\nif [ -f ~/.bashrc_dev ]; then\n    . ~/.bashrc_dev\nfi" >> /home/${SERVER_USER}/.bashrc

# system config
COPY ./docker/assets/dev/system/etc /etc
RUN chmod 0440 /etc/sudoers.d/sudoers-custom \
    && visudo -cf /etc/sudoers.d/sudoers-custom

# extra bashrc includes - uncomment if needed
# COPY bashrc_include* /home/${SERVER_USER}/
# RUN for incfile in /home/${SERVER_USER}/bashrc_include*; do \
#       if [ -f "${incfile}" ]; then \
#         cat "${incfile}" >> /home/${SERVER_USER}/.bashrc; \
#       fi; \
#     done

COPY .generated/ddf-build-hooks/dev-tooling/ /opt/ddf/build-hooks/dev-tooling/
RUN /opt/ddf/run-ddf-build-hooks.sh dev-tooling

ENTRYPOINT ["/sbin/docker-start-container.sh"]

# ============================================================
# dev-gui
# ============================================================
FROM dev-tooling AS dev-gui

ARG SERVER_USER
ARG PP_DEV_USE_VIM

WORKDIR /opt

# dev-gui packages
RUN apt-get update && apt-get install -y --no-install-recommends \
        feh \
        meld \
        libcanberra-gtk3-module \
        libgl1 \
        libegl1 \
        libdrm2 \
        libx11-xcb1 \
        libxcb-dri3-0 \
        fonts-liberation \
        fontconfig \
        x11-apps \
    && fc-cache -fv \
    && rm -rf /var/lib/apt/lists/*


# VS Code environment & installation
# ENV LIBGL_ALWAYS_SOFTWARE=1

# RUN wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
#       | gpg --dearmor > /usr/share/keyrings/microsoft-vscode.gpg \
#     && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-vscode.gpg] https://packages.microsoft.com/repos/code stable main" \
#       > /etc/apt/sources.list.d/vscode.list

# RUN apt-get update \
#     && echo "code code/add-microsoft-repo boolean true" | debconf-set-selections \
#     && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends code \
#     && rm -rf /var/lib/apt/lists/*

# RUN echo "export DONT_PROMPT_WSL_INSTALL=1" >> /home/${SERVER_USER}/.bashrc

# # Create default VS Code settings (valid JSON)
# RUN <<EOF
# if [ ! -f /home/${SERVER_USER}/.config/Code/User/settings.json ]; then
#     mkdir -p /home/${SERVER_USER}/.config/Code/User
#     cat > /home/${SERVER_USER}/.config/Code/User/settings.json <<'SETTINGS'
# {
#     "workbench.colorTheme": "Abyss"
# }
# SETTINGS
#     chown -R ${SERVER_USER}:${SERVER_USER} /home/${SERVER_USER}/.config
# fi
# EOF

# # Wrap code to run reliably in containers
# RUN <<WRAPPER
# mv /usr/bin/code /usr/bin/code.real
# cat > /usr/bin/code <<'CODE'
# #!/usr/bin/env bash
# exec /usr/bin/code.real \
#     --no-sandbox \
#     --disable-gpu \
#     --disable-software-rasterizer \
#     --disable-dev-shm-usage \
#     --disable-features=UseOzonePlatform,Vulkan \
#     "$@"
# CODE
# chmod +x /usr/bin/code
# WRAPPER

COPY .generated/ddf-build-hooks/dev-gui/ /opt/ddf/build-hooks/dev-gui/
RUN /opt/ddf/run-ddf-build-hooks.sh dev-gui

ENTRYPOINT ["/sbin/docker-start-container.sh"]

# ============================================================
# prod (placeholder)
# ============================================================
FROM base AS prod

ARG SERVER_USER

WORKDIR /app

# Placeholder only.
# Later this stage should:
#   1. copy in built artifacts from a separate build stage
#   2. install only runtime dependencies
#   3. set a real ENTRYPOINT/CMD for the service

USER ${SERVER_USER}
CMD ["bash", "-lc", "echo 'prod stage placeholder'; exit 1"]

COPY .generated/ddf-build-hooks/prod/ /opt/ddf/build-hooks/prod/
RUN /opt/ddf/run-ddf-build-hooks.sh prod
