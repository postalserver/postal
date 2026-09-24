FROM ruby:4.0.7-slim-trixie AS base

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN apt-get update \
  && apt-get install --no-install-recommends -y curl \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN (curl -sL https://deb.nodesource.com/setup_20.x | bash -)

# Optional runtime libraries. jemalloc ships as a build variant rather than in
# the default image: libjemalloc2 is ~900KB and only useful when preloaded.
# Declaration order matters only for caching; the postal user is created
# below, and everything apt-related stays in these root steps.
ARG JEMALLOC=0
ARG JEMALLOC_PROFILE=""

# Install main dependencies
RUN apt-get update && \
  apt-get install -y --no-install-recommends \
    build-essential  \
    netcat-openbsd \
    libmariadb-dev \
    libpq-dev \
    libcap2-bin \
    nano \
    libyaml-dev \
    nodejs \
  $([ "$JEMALLOC" = "1" ] && echo libjemalloc2) \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN setcap 'cap_net_bind_service=+ep' /usr/local/bin/ruby

# Configure 'postal' to work everywhere (when the binary exists
# later in this process)
ENV PATH="/opt/postal/app/bin:${PATH}"

# Setup an application
RUN useradd -r -d /opt/postal -m -s /bin/bash -u 999 postal

# File-capped binaries ignore LD_PRELOAD (glibc AT_SECURE), so the jemalloc
# variant preloads through /etc/ld.so.preload instead -- the one mechanism
# that survives setcap. The file is created empty (a no-op for ld.so) and
# handed to the postal user only in this variant; the default image has
# neither the library nor the file. Tradeoff, stated plainly: in the jemalloc
# variant the app user can write the system preload list, so that variant
# trusts the app user with process startup. The entrypoint only writes the
# jemalloc path there when JEMALLOC_PROFILE is set.
RUN if [ "$JEMALLOC" = "1" ]; then \
      touch /etc/ld.so.preload \
      && chown postal:postal /etc/ld.so.preload; \
    fi

USER postal
RUN mkdir -p /opt/postal/app /opt/postal/config
WORKDIR /opt/postal/app

# Install bundler. Pinned to the BUNDLED WITH version in Gemfile.lock via
# build arg so the two cannot drift silently; override with
# --build-arg BUNDLER_VERSION=x.y.z if the lockfile moves first.
ARG BUNDLER_VERSION=4.0.20
RUN gem install bundler -v "${BUNDLER_VERSION}" --no-doc

# Install the latest and active gem dependencies and re-run
# the appropriate commands to handle installs.
COPY --chown=postal Gemfile Gemfile.lock ./
RUN bundle install

# Copy the application (and set permissions)
COPY ./docker/wait-for.sh /docker-entrypoint.sh
COPY --chown=postal . .

# Export the version
ARG VERSION
ARG BRANCH
RUN if [ "$VERSION" != "" ]; then echo $VERSION > VERSION; fi \
  && if [ "$BRANCH" != "" ]; then echo $BRANCH > BRANCH; fi

# YJIT switch. Verified against the ruby:4.0.7 runtime: YJIT is compiled in,
# needs no native toolchain at runtime (codegen is in-process), and only the
# value "1" enables it -- "0", empty and unset all leave it off. Default is
# off; pass --build-arg YJIT=1 (or -e RUBY_YJIT_ENABLE=1 at run time) to
# enable it.
ARG YJIT=0
ENV RUBY_YJIT_ENABLE=${YJIT}

# jemalloc activation (installation is in the root apt step above). The build
# arg controls whether the library ships; the runtime JEMALLOC_PROFILE
# (empty = off) controls whether the entrypoint preloads it. Build with
# --build-arg JEMALLOC=1 to ship the library, then -e
# JEMALLOC_PROFILE=balanced (or =aggressive) to use it. See
# lib/postal/jemalloc.rb for the profiles and the architecture-independent
# library lookup.
ENV JEMALLOC_PROFILE=${JEMALLOC_PROFILE}

# Set paths for when running in a container
ENV POSTAL_CONFIG_FILE_PATH=/config/postal.yml

# Set the CMD
ENTRYPOINT [ "/docker-entrypoint.sh" ]
CMD ["postal"]

# ci target - use --target=ci to skip asset compilation
FROM base AS ci

# optional target - adds the optional dependency groups on top of ci. These are
# not part of the default build: the duckdb gem needs the DuckDB C library, and
# redis-client is only needed when the Valkey live-stats store is used.
FROM ci AS optional

USER root
RUN apt-get update \
  && apt-get install --no-install-recommends -y curl unzip \
  && curl -sSL -o /tmp/libduckdb.zip \
       https://github.com/duckdb/duckdb/releases/download/v1.5.5/libduckdb-linux-amd64.zip \
  && unzip -q /tmp/libduckdb.zip -d /tmp/libduckdb \
  && install -m 0644 /tmp/libduckdb/duckdb.h /tmp/libduckdb/duckdb.hpp /usr/local/include/ \
  && install -m 0755 /tmp/libduckdb/libduckdb.so /usr/local/lib/libduckdb.so \
  && rm -rf /tmp/libduckdb /tmp/libduckdb.zip \
  && ldconfig \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*
USER postal

RUN bundle config set --local with 'analytics redis aerospike sqlite s3 acme foundationdb' && bundle install

# full target - default if no --target option is given
FROM base AS full

RUN RAILS_GROUPS=assets bundle exec rake assets:precompile
RUN touch /opt/postal/app/public/assets/.prebuilt
