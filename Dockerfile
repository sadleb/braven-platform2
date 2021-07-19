# See https://github.com/ledermann/docker-rails/blob/develop/Dockerfile
FROM ruby:2.7.2-alpine

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

# Allow local builds to change it. Defaults to development.
ARG RAILS_ENV=development
ENV RAILS_ENV ${RAILS_ENV}
ENV NODE_ENV=${RAILS_ENV}

WORKDIR /app

ENV BUNDLE_PATH=/app/vendor/bundle

COPY Gemfile Gemfile.lock /app/

RUN bundle config --local frozen 1 && \
    bundle config --local build.sassc --disable-march-tune-native && \
    bundle install -j4 --retry 3

RUN bundle install --path vendor/bundle --jobs 4 --frozen --no-deployment && cp Gemfile.lock /tmp

COPY . /app/

CMD ["/bin/sh"]
