web: bundle exec puma -C config/puma.rb
worker: bundle exec ruby script/worker.rb
cron: bundle exec rake postal:cron
smtp: bundle exec rake postal:smtp_server
requeuer: bundle exec rake postal:requeuer
