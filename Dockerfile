FROM starefossen/ruby-node:2-8-stretch
RUN apt-get update -qq && \
  apt-get install -y nano build-essential libpq-dev && \
  gem install bundler
RUN mkdir /project
COPY . /project
WORKDIR /project
RUN bundle update json rails rails-api && bundle install
