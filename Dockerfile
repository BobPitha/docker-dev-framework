# syntax=docker/dockerfile:1

ARG FROM_IMAGE=ubuntu:0.1
ARG SERVER_USER=dev
ARG PP_DEV_USE_VIM=false

# ============================================================
# base
# ============================================================
FROM ${FROM_IMAGE} AS base

ARG FROM_IMAGE
ARG SERVER_USER

ARG DEBIAN_FRONTEND=noninteractive
RUN sed -i 's|http://|https://|g' /etc/apt/sources.list.d/ubuntu.sources || true

RUN if [ "$FROM_IMAGE" = "ubuntu:0.1" ]; then \
      echo "ERROR: FROM_IMAGE not set; pass --build-arg FROM_IMAGE=..."; \
      exit 1; \
    fi

ENV TZ=America/New_York
WORKDIR /opt

# basic packages
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        apt-utils \
        apt \
        ca-certificates \
        coinor-clp \
        curl \
        dialog \
        gnupg \
        iproute2 \
        libxkbcommon0 \
        libgbm1 \
        make \
        net-tools \
        perl \
        software-properties-common \
        ssh \
        tzdata \
        wget \
        debconf-utils

# user setup
RUN mkdir -p /opt \
    && useradd -m -G dialout,video,plugdev -p ${SERVER_USER} -s /bin/bash ${SERVER_USER} \
    && echo "${SERVER_USER}:${SERVER_USER}" | chpasswd

# workspace
RUN mkdir -p /workspace \
    && chown ${SERVER_USER}:${SERVER_USER} /workspace

# clean
RUN apt-get -y autoremove \
    && apt-get clean autoclean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


# ============================================================
# dev
# ============================================================
FROM base AS dev

ARG SERVER_USER
ARG PP_DEV_USE_VIM

WORKDIR /opt

RUN yes | unminimize

# system scripts
COPY ./docker/assets/dev/system/sbin/ /sbin
RUN chmod 755 /sbin/docker-*

# dev/build packages
RUN apt-get update && apt-get install -y --no-install-recommends \
        autoconf \
        automake \
        build-essential \
        ccache \
        coinor-libclp-dev \
        feh \
        gdb \
        git \
        git-core \
        git-man \
        influxdb-client \
        less \
        libcanberra-gtk-module \
        libz-dev \
        libbz2-dev \
        libncurses5-dev \
        libncursesw5-dev \
        libtool \
        libx11-6 \
        libxi6 \
        libxcursor1 \
        libxinerama1 \
        libxrandr2 \
        man-db \
        maven \
        meld \
        nano \
        netcat \
        openjdk-11-jdk \
        openssh-client \
        openssl \
        pkg-config \
        python3 \
        python3-dev \
        python3-pip \
        rsync \
        sudo \
        udev \
        unzip \
        vim \
        x11-apps \
        zlib1g-dev \
    && pkg-config --cflags --libs clp

RUN pip3 install --no-cache-dir --upgrade pip setuptools wheel

# user files
COPY ./docker/assets/dev/user /home/${SERVER_USER}
RUN mkdir -p /home/${SERVER_USER}/bin \
    && echo "PATH=/home/${SERVER_USER}/bin:${PATH}" >> /home/${SERVER_USER}/.bashrc

# keyboard config
COPY ./docker/assets/selections.conf /opt/selections.conf
RUN debconf-set-selections < /opt/selections.conf \
    && apt-get install -y --no-install-recommends keyboard-configuration

# sudo + shell setup
RUN usermod -a -G sudo ${SERVER_USER} \
    && echo "\n# developer setup\nif [ -f ~/.bashrc_dev ]; then\n    . ~/.bashrc_dev\nfi" >> /home/${SERVER_USER}/.bashrc

# system config
COPY ./docker/assets/dev/system/etc /etc
RUN chmod 755 /etc/sudoers.d/sudoers-custom

# startup script config
RUN chmod 755 /sbin/docker-* \
    && sed -i "6iexport SERVER_USER=\"${SERVER_USER}\"\nexport SERVER_GROUP=\"${SERVER_USER}\"" /sbin/docker-start-container.sh

# optional vim PPA setup
RUN if [ "$PP_DEV_USE_VIM" = "true" ]; then \
      add-apt-repository ppa:jonathonf/vim && \
      apt-get update && \
      apt-get install -y vim && \
      curl -s -fLo /home/${SERVER_USER}/.vim/autoload/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim && \
      vim -u /home/${SERVER_USER}/.vim/autoload/plug.vim \
        --not-a-term \
        +'so /home/${SERVER_USER}/.vimrc' \
        +'autocmd VimEnter * PlugInstall --sync | source $MYVIMRC' \
        +qa > /dev/null && \
      mkdir -m 777 /home/${SERVER_USER}/.vim/plugged; \
    fi

# VS Code
RUN apt-get update \
    && apt-get install -y --no-install-recommends debconf-utils apt-transport-https \
    && rm -rf /var/lib/apt/lists/*

RUN wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
      | gpg --dearmor > /usr/share/keyrings/microsoft-vscode.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-vscode.gpg] https://packages.microsoft.com/repos/code stable main" \
      > /etc/apt/sources.list.d/vscode.list

RUN apt-get update \
    && echo "code code/add-microsoft-repo boolean true" | debconf-set-selections \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends code \
    && rm -rf /var/lib/apt/lists/*

RUN echo "export DONT_PROMPT_WSL_INSTALL=1" >> /home/${SERVER_USER}/.bashrc

RUN if [ ! -f /home/${SERVER_USER}/.config/Code/User/settings.json ]; then \
      mkdir -p /home/${SERVER_USER}/.config/Code/User \
      && echo '{\n    "workbench.colorTheme": "Abyss"\n}' > /home/${SERVER_USER}/.config/Code/User/settings.json; \
    fi

# Wrap code to disable sandbox in containers
RUN mv /usr/bin/code /usr/bin/code.real && \
    printf '%s\n' \
    '#!/usr/bin/env bash' \
    'exec /usr/bin/code.real --no-sandbox "$@"' \
    > /usr/bin/code && \
    chmod +x /usr/bin/code

# extra bashrc includes - uncomment if needed
# COPY bashrc_include* /home/${SERVER_USER}/
# RUN for incfile in /home/${SERVER_USER}/bashrc_include*; do \
#       if [ -f "${incfile}" ]; then \
#         cat "${incfile}" >> /home/${SERVER_USER}/.bashrc; \
#       fi; \
#     done

RUN chown -R ${SERVER_USER}:${SERVER_USER} /home/${SERVER_USER}

# clean
RUN apt-get -y autoremove \
    && apt-get clean autoclean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

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