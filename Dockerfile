FROM ruby:2.6

RUN apt-get update
RUN apt-get install software-properties-common -y

# Setup additional repositories
RUN apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
RUN add-apt-repository 'deb [arch=amd64,i386,ppc64el] http://mirrors.coreix.net/mariadb/repo/10.1/ubuntu xenial main'
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN apt-get update

# Install main dependencies
RUN apt-get install -y \
  build-essential  \
  curl \
  libmariadbclient-dev \
  nano \
  nodejs

# Setup an application
RUN useradd -r -d /opt/postal -m -s /bin/bash -u 999 postal
USER postal
RUN mkdir -p /opt/postal/app /opt/postal/config
WORKDIR /opt/postal/app

# Install bundler
RUN gem install bundler --no-doc
RUN bundle config frozen 1
RUN bundle config build.sassc --disable-march-tune-native

# Install the latest and active gem dependencies and re-run
# the appropriate commands to handle installs.
COPY Gemfile Gemfile.lock ./
RUN bundle install -j 4

# Copy the application (and set permissions)
COPY --chown=postal . .

# Copy temporary configuration file which can be used for
# running the asset precompilation.
COPY --chown=postal config/postal.defaults.yml /opt/postal/config/postal.yml

# Precompile assets
RUN POSTAL_SKIP_CONFIG_CHECK=1 RAILS_GROUPS=assets bundle exec rake assets:precompile
RUN touch /opt/postal/app/public/assets/.prebuilt

# Set the CMD
CMD ["bundle", "exec"]
