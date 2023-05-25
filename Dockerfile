FROM centos:centos7 as build

# Ensure updated base
RUN yum update -y

# Enable extra repos
RUN rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
RUN rpm -Uvh https://repo.ius.io/ius-release-el7.rpm
RUN yum install -y centos-release-scl centos-release-scl-rh
RUN yum-config-manager --add-repo=https://copr.fedorainfracloud.org/coprs/carlwgeorge/ripgrep/repo/epel-7/carlwgeorge-ripgrep-epel-7.repo

# Install core tools
RUN yum install -y ack \
                   bind-utils \
                   curl \
                   devtoolset-11-gcc \
                   devtoolset-11-gcc-c++ \
                   fasd \
                   git236 \
                   iputils \
                   openssl11 \
                   openssl11-devel \
                   make \
                   ncurses-devel \
                   ripgrep \
                   telnet \
                   unzip \
                   wget

# Use devtoolset 11 for compiling, etc
ENV PATH=/opt/rh/devtoolset-11/root/usr/bin${PATH:+:${PATH}}
ENV MANPATH=/opt/rh/devtoolset-11/root/usr/share/man${MANPATH:+:${MANPATH}}
ENV INFOPATH=/opt/rh/devtoolset-11/root/usr/share/info${INFOPATH:+:${INFOPATH}}
ENV PCP_DIR=/opt/rh/devtoolset-11/root
ENV LD_LIBRARY_PATH=/opt/rh/devtoolset-11/root$rpmlibdir/dyninst$dynpath64$dynpath32${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
ENV LD_LIBRARY_PATH=/opt/rh/devtoolset-11/root$rpmlibdir$rpmlibdir64$rpmlibdir32${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
ENV PKG_CONFIG_PATH=/opt/rh/devtoolset-11/root/usr/lib64/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}

RUN curl -L https://sourceforge.net/projects/zsh/files/zsh/5.9/zsh-5.9.tar.xz/download -o zsh-5.9.tar.xz && \
    tar xf zsh-5.9.tar.xz && \
    pushd zsh-5.9 && \
    ./configure --with-tcsetpgrp && \
    make && \
    make install && \
    popd && \
    rm -rf zsh-5.9.tar.xz zsh-5.9

# Install neovim
RUN curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim.appimage
RUN chmod u+x nvim.appimage
RUN ./nvim.appimage --appimage-extract && \
    rm ./nvim.appimage && \
    mv /squashfs-root /opt/neovim
RUN ln -s /opt/neovim/AppRun /usr/bin/nvim

# Install Python 3.11
RUN yum install -y rh-python38-python-pip rh-python38
ENV PATH=/opt/rh/rh-python38/root/usr/local/bin:/opt/rh/rh-python38/root/usr/bin${PATH:+:${PATH}}
ENV LD_LIBRARY_PATH=/opt/rh/rh-python38/root/usr/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
ENV MANPATH=/opt/rh/rh-python38/root/usr/share/man:$MANPATH
ENV PKG_CONFIG_PATH=/opt/rh/rh-python38/root/usr/lib64/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}
ENV XDG_DATA_DIRS="/opt/rh/rh-python38/root/usr/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3
RUN pip3 install neovim

# Install golang
RUN yum install -y golang

# Install Ruby build deps
RUN yum install -y zlib-devel openssl-devel readline-devel zlib-devel libffi-devel libyaml-devel


## CREATE USER
RUN useradd -m jason.barnett -s /usr/local/bin/zsh
USER jason.barnett
WORKDIR /home/jason.barnett
ENV HOME=/home/jason.barnett

## Install Oh My Zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

## Install fzf
RUN git clone --depth 1 https://github.com/junegunn/fzf.git $HOME/.fzf && \
    $HOME/.fzf/install --all

## Install powerlevel10k
RUN git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $HOME/.oh-my-zsh/custom/themes/powerlevel10k
RUN sed -ri 's@^ZSH_THEME=.*@ZSH_THEME="powerlevel10k/powerlevel10k"@g' $HOME/.zshrc
RUN curl -LO https://github.com/romkatv/gitstatus/releases/download/v1.5.4/gitstatusd-linux-x86_64.tar.gz && \
    mkdir -p $HOME/.cache/gitstatus && \
    tar zxf gitstatusd-linux-x86_64.tar.gz -C $HOME/.cache/gitstatus && \
    rm gitstatusd-linux-x86_64.tar.gz

## Drop .zshrc
COPY --chown=jason.barnett:jason.barnett --chmod=0644 .zshrc $HOME/.zshrc
COPY --chown=jason.barnett:jason.barnett --chmod=0644 .p10k.zsh $HOME/.p10k.zsh

## lay down custom configs
RUN curl -L https://raw.githubusercontent.com/jasonwbarnett/dotfiles/master/bash/aliases.sh -o $HOME/.oh-my-zsh/custom/aliases.zsh
RUN curl -L https://raw.githubusercontent.com/jasonwbarnett/dotfiles/master/git/gitconfig -o $HOME/.gitconfig
RUN curl -L https://raw.githubusercontent.com/jasonwbarnett/dotfiles/master/git/gitignore -o $HOME/.gitignore
RUN curl -L https://raw.githubusercontent.com/jasonwbarnett/dotfiles/master/zsh/fasd.zsh -o $HOME/.oh-my-zsh/custom/fasd.zsh

# Install rustc, a Ruby 3.2 dependency
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH=$HOME/.cargo/bin${PATH:+:${PATH}}

# Install Ruby 3.1
RUN git clone https://github.com/rbenv/rbenv.git $HOME/.rbenv
RUN echo 'eval "$($HOME/.rbenv/bin/rbenv init - bash)"' >> $HOME/.oh-my-zsh/custom/rbenv.zsh
RUN git clone https://github.com/rbenv/ruby-build.git $HOME/.rbenv/plugins/ruby-build
ENV PATH /home/jason.barnett/.rbenv/shims:/home/jason.barnett/.rbenv/bin:$PATH
RUN RUBY_CONFIGURE_OPTS='--with-openssl-dir=/usr/include/openssl11 --with-openssl-lib=/usr/lib64/openssl11 --with-openssl-include=/usr/include/openssl11' rbenv install $(rbenv install -l | grep -v -- - | grep '^3.2')
RUN rbenv global $(rbenv install -l | grep -v -- - | grep '^3.2')
RUN echo 'gem: --no-document' >> $HOME/.gemrc
RUN gem install neovim

# Install fd
RUN cargo install fd-find

# Install nvim config
RUN mkdir -p $HOME/.config
COPY --chown=jason.barnett:jason.barnett --chmod=0644 init.lua $HOME/.config/nvim/init.lua
COPY --chown=jason.barnett:jason.barnett --chmod=0755 lua $HOME/.config/nvim/lua
RUN nvim --headless "+Lazy! sync" +qa

# Install LSPs
RUN nvim --headless "+LspInstall lua_ls solargraph terraformls tflint gopls" +qa

FROM scratch
COPY --from=build / /

USER jason.barnett
WORKDIR /home/jason.barnett
ENV HOME=/home/jason.barnett

ENV PATH=/opt/rh/rh-python38/root/usr/local/bin:/opt/rh/rh-python38/root/usr/bin${PATH:+:${PATH}}
ENV PATH=$HOME/.cargo/bin${PATH:+:${PATH}}
ENV LD_LIBRARY_PATH=/opt/rh/rh-python38/root/usr/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
ENV MANPATH=/opt/rh/rh-python38/root/usr/share/man:$MANPATH
ENV PKG_CONFIG_PATH=/opt/rh/rh-python38/root/usr/lib64/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}
ENV XDG_DATA_DIRS="/opt/rh/rh-python38/root/usr/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

ENTRYPOINT ["/usr/local/bin/zsh"]
CMD ["-l"]
