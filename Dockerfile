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
ARG SERVER_UID=1000
ARG SERVER_GID=1000

RUN set -eux; \
    existing_user="$(getent passwd "${SERVER_UID}" | cut -d: -f1 || true)"; \
    existing_group="$(getent group "${SERVER_GID}" | cut -d: -f1 || true)"; \
    \
    if [ -n "${existing_group}" ] && [ "${existing_group}" != "${SERVER_USER}" ]; then \
        groupmod -n "${SERVER_USER}" "${existing_group}"; \
    elif [ -z "${existing_group}" ]; then \
        groupadd -g "${SERVER_GID}" "${SERVER_USER}"; \
    fi; \
    \
    if [ -n "${existing_user}" ] && [ "${existing_user}" != "${SERVER_USER}" ]; then \
        usermod -l "${SERVER_USER}" -d "/home/${SERVER_USER}" -m "${existing_user}"; \
        usermod -g "${SERVER_GID}" "${SERVER_USER}"; \
    elif id -u "${SERVER_USER}" >/dev/null 2>&1; then \
        usermod -u "${SERVER_UID}" -g "${SERVER_GID}" "${SERVER_USER}"; \
    else \
        useradd -m -u "${SERVER_UID}" -g "${SERVER_GID}" -s /bin/bash "${SERVER_USER}"; \
    fi; \
    \
    usermod -a -G dialout,video,plugdev "${SERVER_USER}"
        
# /projects directory
RUN mkdir -p /projects \
    && chown ${SERVER_USER}:${SERVER_USER} /projects

RUN cat >>/etc/bash.bashrc <<'EOF'

# Execute DDF profile snippets (only for interactive shells, prevent double-sourcing)
if [ -n "$PS1" ] && [ -z "$DDF_PROFILE_SOURCED" ]; then
  export DDF_PROFILE_SOURCED=1
  if [ -d /etc/profile.d ]; then
    for f in /etc/profile.d/ddf-*.sh; do
      [ -f "$f" ] && . "$f"
    done
  fi
fi
EOF

COPY .generated/ddf-build-hooks/base/ /opt/ddf/build-hooks/base/
RUN --mount=type=bind,source=.generated/ddf-libs,target=/libs,readonly \
    /opt/ddf/run-ddf-build-hooks.sh base

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
RUN --mount=type=bind,source=.generated/ddf-libs,target=/libs,readonly \
    /opt/ddf/run-ddf-build-hooks.sh dev-core

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

RUN cat >>/etc/bash.bashrc <<'EOF'

# DDF customizations
if [ -n "$PS1" ]; then
  # Helpful message for interactive shells
  echo "Run ddf-rosdep-install to install ROS package dependencies."
  
  # Add ~/bin to PATH if it exists and isn't already there
  if [ -d "$HOME/bin" ]; then
    case ":$PATH:" in
      *:"$HOME/bin":*) ;;
      *) export PATH="$HOME/bin:$PATH" ;;
    esac
  fi
fi
EOF

RUN cat >> "/home/${SERVER_USER}/.bashrc" <<'EOF'

# DDF custom prompt color via HOST_COLOR and PATH_COLOR
# See: https://robotmoon.com/256-colors/
if [ -n "${HOST_COLOR:-}" ] && [ -n "${PATH_COLOR:-}" ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[38;5;'"${HOST_COLOR}"'m\]\u@\h\[\033[0m\]:\[\033[38;5;'"${PATH_COLOR}"'m\]\w\[\033[0m\]\$ '
fi
EOF

COPY .generated/ddf-build-hooks/dev-tooling/ /opt/ddf/build-hooks/dev-tooling/
RUN --mount=type=bind,source=.generated/ddf-libs,target=/libs,readonly \
    /opt/ddf/run-ddf-build-hooks.sh dev-tooling

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

# VS Code should be installed outside of Docker now.

COPY .generated/ddf-build-hooks/dev-gui/ /opt/ddf/build-hooks/dev-gui/
RUN --mount=type=bind,source=.generated/ddf-libs,target=/libs,readonly \
    /opt/ddf/run-ddf-build-hooks.sh dev-gui

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
RUN --mount=type=bind,source=.generated/ddf-libs,target=/libs,readonly \
    /opt/ddf/run-ddf-build-hooks.sh prod
