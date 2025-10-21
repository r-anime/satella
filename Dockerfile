FROM ruby:3.4.7-alpine

ENV APP_HOME=/app

RUN apk add --no-cache \
      build-base \
      postgresql-client \
      postgresql-dev \
      tzdata \
      git \
      bash

WORKDIR $APP_HOME

RUN gem update --system

COPY Gemfile Gemfile.lock ./

RUN bundle install

COPY . .

ARG GIT_COMMIT_HASH
ENV GIT_COMMIT_HASH=$GIT_COMMIT_HASH
ARG GIT_REPO_URL
ENV GIT_REPO_URL=$GIT_REPO_URL

CMD ["ruby", "app.rb"]
