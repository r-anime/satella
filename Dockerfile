FROM ruby:3.4.7-alpine AS builder

ENV APP_HOME=/app

RUN apk add --no-cache \
      build-base \
      postgresql-dev \
      tzdata \
      git \
    && rm -rf /var/cache/apk/*

WORKDIR $APP_HOME

RUN gem update --system

COPY Gemfile Gemfile.lock ./

RUN bundle install

FROM ruby:3.4.7-alpine

ENV APP_HOME=/app

RUN apk add --no-cache postgresql-libs bash && rm -rf /var/cache/apk/*

WORKDIR $APP_HOME

# copy over deps
COPY --from=builder /usr/local/bundle/ /usr/local/bundle/

COPY . .

ARG GIT_COMMIT_HASH
ENV GIT_COMMIT_HASH=$GIT_COMMIT_HASH
ARG GIT_REPO_URL
ENV GIT_REPO_URL=$GIT_REPO_URL

CMD ["bundle", "exec", "ruby", "app.rb"]
