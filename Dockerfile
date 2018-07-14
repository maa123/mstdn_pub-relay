FROM ruby:2.5-slim-stretch

ARG UID=991
ARG GID=991

ARG TINI_VERSION=0.18.0

EXPOSE 3000 4000

WORKDIR /pub-relay

COPY Gemfile Gemfile.lock /pub-relay/

RUN apt-get update \
    && apt-get -y install --no-install-recommends curl build-essential git libicu-dev libidn11-dev libtool libpq-dev libprotobuf-dev python \
    && apt-get -y install --no-install-recommends ca-certificates ffmpeg file libicu57 imagemagick libidn11 libpq5 libprotobuf10 openssl protobuf-compiler tzdata \
    && curl -L https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini_${TINI_VERSION}-amd64.deb > tini_${TINI_VERSION}-amd64.deb \
    && dpkg -i tini_${TINI_VERSION}-amd64.deb \
    && rm tini_${TINI_VERSION}-amd64.deb \
    && bundle install -j$(getconf _NPROCESSORS_ONLN) \
    && apt-get -y remove --purge curl build-essential git libicu-dev libidn11-dev libtool libpq-dev libprotobuf-dev python \
    && apt-get -y autoremove --purge \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -g ${GID} mastodon && useradd -d /pub-relay -s /bin/sh -g mastodon -u ${UID} mastodon \
    && chown mastodon:mastodon /pub-relay

COPY --chown=mastodon:mastodon . /pub-relay

VOLUME /pub-relay/config

USER mastodon

ENTRYPOINT ["/usr/bin/tini", "--"]
