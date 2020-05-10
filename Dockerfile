# See https://github.com/ledermann/docker-rails/blob/develop/Dockerfile
FROM ruby:2.6.5-alpine

RUN apk add --update --no-cache \
    build-base \
    postgresql-dev \
    imagemagick \
    nodejs \
    yarn \
    tzdata \
    libnotify \
    git \
    python2 \
    vim

COPY Gemfile* /usr/src/app/
WORKDIR /usr/src/app

ENV BUNDLE_PATH /gems

RUN bundle install && cp Gemfile.lock /tmp

COPY . /usr/src/app/

CMD ["/bin/sh"]
