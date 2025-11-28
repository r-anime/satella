# Satella (AnimeMod 2.0)

This is a project to allow for more flexible AutoMod like rule modules to run for r/anime.

This project is meant to be run in conjunction with [modbot](https://github.com/r-anime/modbot), which will populate the RabbitMQ messages that this app will consume and process.

# Local Dev Setup

1. Install ruby. Newest should be fine, but the version is in .tool-versions. As u/baseballlover723 is currently writing this, it's ruby 3.4.7 and he installed it via [asdf](https://asdf-vm.com/)
2. Install bundler. Bundler is the dependency management tool, it probably comes stock, and the version doesn't matter, as any modern version will install the project specific version automatically.
3. Install dependencies. Run `bundle install` in the root directory. There shouldn't be anything too crazy in there that should require extra deps to be installed (except maybe postgres, but you need postgres, duh)
4. Start external dependencies (Postgres & RabbitMQ)
5. Run the project. `bundle exec ruby app.rb`. Bundle exec is needed here to ensure that it loads the right reddit library gem.
6. App should be running. You should see `Successfully connected to postgres`, `Successfully authed to reddit`, and `✅ Listening on ...` if everything is sucessful.

## Docker Compose Dev Setup
1. `docker compose build --pull`
2. `docker compose up --build`
3. App should be running. You should see `Successfully connected to postgres`, `Successfully authed to reddit`, and `✅ Listening on ...` if everything is sucessful.

## Config
Config is done via environment variables. I'm too lazy to list all of the env variables, but they're easily searchable by searching for `ENV["var_name"]`. Their meaning should be fairly evident. I recommend lifting a copy of the .env from staging.

Note: You may need some slightly different env variables running ruby locally, and docker compose, depending on the specifics of the other services setup.

## External Services Needed

At the very minimum, you need to have Postgres and RabbitMQ running, accessible, and properly configured. I recommend just using the docker compose file on stage / prod and starting up other services via docker compose.

Relevant docker compose services are `stage_db`, `stage_rabbitmq`, and also `stage_all_feeds` (to ingest data).

The first time you set it up, and ingest data, you may want to go to the rabbitmq instance and purge the queues of messages, so it doesn't back process data.

---

u/baseballlover723 recommends running external dependencies via docker compose, and AnimeMod 2.0 via direct ruby for ease of development.

When running ruby directly, you'll probably need to use `127.0.0.1` as your hosts and the local machine ports to connect to them.

When running via docker compose, you may need to use `host.docker.internal` as the hosts (still using local machine ports).

On stage and prod, they are hooked up directly to the relevant containers, using internal ports. This requires that everything be in the same docker network though, which is a pain to setup / across multiple docker compose files.

---

# Creating New Rule Modules

This might change some in the future. But the general gist of it is that any new rule module (new rule modules should be preferred if there is logical separation from existing rule modules, smaller / more narrowly scoped rule modules should be preferred) should be inheriting from src/base_rule.rb and placed in src/rules/.

BaseRule has all of it's hooks documented. You may need to make changes to src/services/reddit_service.rb if there are new reddit API uses that need to be programmed. Or other services if needed, but I imagine that most things won't need to touch that kind of stuff.

And then you need to implement the relevant hooks and put some config in AutoMod (using id: `AnimeMod 2.0: {your rule name here}`). And that's it. It'll automagically get picked up and loaded. It'll automagically read the AutoMod config (and keep it up to date via the `on_upsert` hook) and call the hooks as they are needed. Nothing more needs to be done on the code side.

# Known Limitations And Traps To Watch Out For At The Current Moment

AnimeMod 2.0 is currently in MVP (minimum viable product), so some features are currently missing / unimplemented at the moment. These are all things that should eventually be implemented or otherwise handled, and should not be considered out of scope.

1. Multiple instances of a rule module are not yet supported. Workaround: Merge them into 1 rule module, or duplicate the rule module and give them unique ids.
2. Matching AutoMod default behavior beyond initial coding requires code changes. Ie, if you change something to use a regex instead of includes, that'll likely break a rule module.
3. Standard Rule Actions aren't implemented yet. Workaround: Everything should use a `CustomAction` for now.
4. Standard AutoMod configurations. Ideally, by default, AnimeMod 2.0 should be able to reasonably emulate AutoMod and support those options are a standard implementation. u/baseballlover723 thinks that eventually, there'll be a `StandardRule` that'll be defined, where it'll by default handle AutoMod basic functionality (like supporting all the different options, like `author` or `body` or `includes` vs `regex`) with some kind of notation to actively prevent usage for custom parameters (probably on the rule module code side).
5. Placeholders. There is a placeholder service, but it's very bare bones. Eventually, standard AutoMod placeholders should be implemented and even custom placeholders (as defined by the rule module).
6. Multiple Rule Modules matching. Currently, AnimeMod 2.0 doesn't batch up actions (requires Standard Rule Actions to be implemented first), so any rule modules that match will be executed. This should lead to multiple separate removals / reports or whatever actions it does in the case of a multi rule match. This should be mildly inconvenient, but not a huge blocker for most cases. In u/baseballover723's opinion, reports are the most affected, as they hard limited to a single one.
7. Significant code / config changes might cause splicing / desync errors as one gets deployed before the other. Workaround: be vigilant of such matters and reduce the time delay between commiting the config change and the deployment of the new code. If needed, code for both configs to work (ie, the old config runs the old code, and the new config runs the new code), and deploy the code first.
8. Only runs on new posts / comments / mod actions (this is more of a modbot limitation). In the future, we may want to ingest data via Devvit since u/baseballlover723 thinks that Devvit may have better hooks for ingesting data.
9. Order of processing is only roughly guaranteed (this is more of a modbot limitation). Modbot guarantees that all actions of a type (post / comment / mod action) will be processed in order, but due to the polling nature of it, they may get interweaved or be delayed on the order of ~20 seconds or so. One should not rely on single digit second level precision.
10. Some messages may get dropped (this is more of a modbot limitation). Currently, modbot isn't super robust in its message passing. It currently holds failed messages in memory to be resent to RabbitMQ. Restarting the modbot container (like for an update) will currently drop any failed messages. u/baseballlover723 will fix this to persist failed messages to disk and thus be persistent across restart at some point.
11. Parallel processing of slow hooks is not yet implemented (as noted in the hook documentation). They are currently run sequentially. Eventually they will be run in parallel to aid performance as the number of rule modules grows.
12. Report messages can only be 100 characters long (reddit API limitation). This may or may not be worked around in the future.
13. No dev alerting in case of failure. This will almost certainly not be done, it's too much effort for what it's worth.
14. Proper CI / tests. This will almost certainly not be done, it's too much effort for what it's worth. I might set up a linter though.

## Implemented features

1. Reddit API level rate limiting. Implemented by Redd, the ruby reddit API library. Should sleep to ensure that rate limits don't get exceeded.
2. Module retries. If there is an exception in the execution of a rule module, it will fail the message, and send it off to the retry queue where it will be pushed back to the main queue 10 seconds later (this delay value is configured via RabbitMQ policy, as the `message-ttl` (ms) in `/src/{env}/rabbitmq4/startup.sh` in `Retryable Queue` policy). It will retry `ENV["RABBITMQ_MAX_ATTEMPTS"]` times, before giving up and properly deadlettering it for manual resolution.
3. Auto config updating. Updating the AutoMod config will be processed by AnimeMod 2.0 and refetch the latest AutoMod config and call all the `on_upsert` hooks.
4. Disabling rule modules. This can be done by simply commenting out the AutoMod config (except for non AutoMod dependent rule modules, which are always on and usually internal modules). It will be discluded from the active rule modules list if it doesn't find a matching AutoMod id.
5. Logging (and log rotation). Logs are generated at `./logs/satella.log` (.# is log rotation) and `./logs/satella_db.log`
6. CD. PRs will automatically be deployed to staging, and merges to master will automatically be deployed to prod. No manual action is needed in most cases for that (should only be necessary if specific orchestration is required).
7. Standard removal headers and footers. These are configured in AutoMod and are automatically added to removals with comments.

Overall, you should only need to care about the rule module you're implementing in isolation. And AnimeMod 2.0 should automagically take care of the rest.

# More Help

Contact u/baseballlover723 on discord (r/anime internal use) or by reddit chat for any further questions or assistance.

![Satella](profile_pic.png)

aishiteru aishiteru aishiteru aishiteru aishiteru aishiteru aishiteru aishiteru aishiteru aishiteru aishiteru aishiteru aishiteru aishiteru aishiteru 
