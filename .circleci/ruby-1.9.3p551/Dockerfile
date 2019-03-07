FROM alpine

RUN mkdir -p /usr/local/etc \
      && { \
        echo 'install: --no-document'; \
          echo 'update: --no-document'; \
      } >> /usr/local/etc/gemrc

ENV RUBY_MAJOR 1.9
ENV RUBY_VERSION 1.9.3-p551
ENV RUBYGEMS_VERSION 1.8.23.2
ENV BUNDLER_VERSION 1.16.6

RUN set -ex \
    && apk add --no-cache --virtual .ruby-builddeps \
      autoconf \
      bison \
      bzip2 \
      bzip2-dev \
      ca-certificates \
      coreutils \
      curl \
      gcc \
      gdbm-dev \
      glib-dev \
      libc-dev \
      libffi-dev \
      libxml2-dev \
      libxslt-dev \
      linux-headers \
      make \
      ncurses-dev \
      openssl-dev \
      procps \
      readline-dev \
      ruby \
      yaml-dev \
      zlib-dev \
    && curl -fSL -o ruby.tar.gz "http://cache.ruby-lang.org/pub/ruby/$RUBY_MAJOR/ruby-$RUBY_VERSION.tar.gz" \
    && mkdir -p /usr/src \
    && tar -xzf ruby.tar.gz -C /usr/src \
    && rm ruby.tar.gz \
    && cd /usr/src/ruby-$RUBY_VERSION \
    && { echo '#define ENABLE_PATH_CHECK 0'; echo; cat file.c; } > file.c.new && mv file.c.new file.c \
    && { echo '#include <asm/ioctl.h>'; echo; cat io.c; } > io.c.new && mv io.c.new io.c \
    && autoconf \
    && ac_cv_func_isnan=yes ac_cv_func_isinf=yes ./configure --disable-install-doc \
    && make \
    && make install \
    && runDeps="$( \
      scanelf --needed --nobanner --recursive /usr/local \
      | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
      | sort -u \
      | xargs -r apk info --installed \
      | sort -u \
      )" \
    && apk add --virtual .ruby-rundeps $runDeps \
      bzip2 \
      ca-certificates \
      curl \
      libffi-dev \
      openssl-dev \
      yaml-dev \
      procps \
      zlib-dev \
    && apk del .ruby-builddeps \
    && gem update --system $RUBYGEMS_VERSION \
    && rm -r /usr/src/ruby-$RUBY_VERSION

RUN apk add --no-cache git nano build-base

RUN gem update --system 2.7.9

RUN gem install bundler --version "$BUNDLER_VERSION" --force

ENV GEM_HOME /usr/local/bundle
ENV BUNDLE_PATH="$GEM_HOME" BUNDLE_BIN="$GEM_HOME/bin" BUNDLE_SILENCE_ROOT_WARNING=1 BUNDLE_APP_CONFIG="$GEM_HOME"
ENV PATH $BUNDLE_BIN:$PATH
RUN mkdir -p "$GEM_HOME" "$BUNDLE_BIN" && chmod 777 "$GEM_HOME" "$BUNDLE_BIN"
CMD [ "irb" ]
