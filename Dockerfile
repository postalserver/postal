# ---------------------------------------------------------------------------
# base: the runtime image. Only what is needed to *run* Postal lives here, so
# nothing in this stage (or the targets built on it) contains compilers or
# other build tooling.
# ---------------------------------------------------------------------------
FROM ruby:3.4.13-slim-trixie AS base

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Runtime libraries only:
#   libmariadb3     - used by the mysql2 gem
#   libyaml-0-2     - used by the psych gem
#   netcat-openbsd  - used by docker-entrypoint (wait-for.sh)
# libcap2-bin is only needed for setcap and is removed again afterwards (the
# file capability stays on the binary).
RUN apt-get update \
  && apt-get upgrade -y \
  && apt-get install --no-install-recommends -y \
    libcap2-bin \
    libmariadb3 \
    libyaml-0-2 \
    netcat-openbsd \
  && setcap 'cap_net_bind_service=+ep' /usr/local/bin/ruby \
  && apt-get purge -y libcap2-bin \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Configure 'postal' to work everywhere (when the binary exists
# later in this process)
ENV PATH="/opt/postal/app/bin:${PATH}"

# Setup an application
RUN useradd -r -d /opt/postal -m -s /bin/bash -u 999 postal
USER postal
RUN mkdir -p /opt/postal/app /opt/postal/config
WORKDIR /opt/postal/app

# ---------------------------------------------------------------------------
# build: compilers for installing gems and Node for compiling assets. Nothing
# from this stage is shipped except the files that are copied out of it below.
# ---------------------------------------------------------------------------
FROM base AS build

USER root
RUN apt-get update \
  && apt-get install --no-install-recommends -y \
    build-essential \
    libmariadb-dev \
    libyaml-dev \
    nodejs \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*
USER postal

# Install bundler
RUN gem install bundler -v 2.7.2 --no-doc

# Install the latest and active gem dependencies and re-run
# the appropriate commands to handle installs.
COPY --chown=postal Gemfile Gemfile.lock ./
RUN bundle install \
  && rm -rf /usr/local/bundle/cache \
  && find /usr/local/bundle -name '*.o' -delete

# Copy the application (and set permissions)
COPY --chown=postal . .

# ---------------------------------------------------------------------------
# assets: compile the asset pipeline output (needs Node via execjs)
# ---------------------------------------------------------------------------
FROM build AS assets

RUN RAILS_GROUPS=assets bundle exec rake assets:precompile

# ---------------------------------------------------------------------------
# ci target - use --target=ci to skip asset compilation
# ---------------------------------------------------------------------------
FROM base AS ci

COPY --from=build --chown=postal /usr/local/bundle /usr/local/bundle
COPY --from=build --chown=postal /opt/postal/app /opt/postal/app
COPY ./docker/wait-for.sh /docker-entrypoint.sh

# Export the version
ARG VERSION
ARG BRANCH
RUN if [ "$VERSION" != "" ]; then echo $VERSION > VERSION; fi \
  && if [ "$BRANCH" != "" ]; then echo $BRANCH > BRANCH; fi

# Set paths for when running in a container
ENV POSTAL_CONFIG_FILE_PATH=/config/postal.yml

# Set the CMD
ENTRYPOINT [ "/docker-entrypoint.sh" ]
CMD ["postal"]

# ---------------------------------------------------------------------------
# full target - default if no --target option is given
# ---------------------------------------------------------------------------
FROM ci AS full

COPY --from=assets --chown=postal /opt/postal/app/public/assets /opt/postal/app/public/assets
RUN touch /opt/postal/app/public/assets/.prebuilt
