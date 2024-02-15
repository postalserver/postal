FROM ruby:3.2.2-bullseye AS base

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  software-properties-common dirmngr apt-transport-https \
  && (curl -sL https://deb.nodesource.com/setup_20.x | bash -) \
  && rm -rf /var/lib/apt/lists/*

# Install main dependencies
RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  build-essential  \
  netcat \
  curl \
  libmariadb-dev \
  libcap2-bin \
  nano \
  nodejs

RUN setcap 'cap_net_bind_service=+ep' /usr/local/bin/ruby

# Configure 'postal' to work everywhere (when the binary exists
# later in this process)
ENV PATH="/opt/postal/app/bin:${PATH}"

# Setup an application
RUN useradd -r -d /opt/postal -m -s /bin/bash -u 999 postal
USER postal
RUN mkdir -p /opt/postal/app /opt/postal/config
WORKDIR /opt/postal/app

# Install bundler
RUN gem install bundler -v 2.4.9 --no-doc

# Install the latest and active gem dependencies and re-run
# the appropriate commands to handle installs.
COPY Gemfile Gemfile.lock ./
RUN bundle config set force_ruby_platform true && bundle install -j 4

# Copy the application (and set permissions)
COPY ./docker/wait-for.sh /docker-entrypoint.sh
COPY --chown=postal . .

# Export the version
ARG VERSION=unspecified
RUN echo $VERSION > VERSION

# Set the path to the config
ENV POSTAL_CONFIG_ROOT=/config

# Set the CMD
ENTRYPOINT [ "/docker-entrypoint.sh" ]
CMD ["postal"]

# ci target - use --target=ci to skip asset compilation
FROM base AS ci

# full target - default if no --target option is given
FROM base AS full

RUN POSTAL_SKIP_CONFIG_CHECK=1 RAILS_GROUPS=assets bundle exec rake assets:precompile
RUN touch /opt/postal/app/public/assets/.prebuilt
