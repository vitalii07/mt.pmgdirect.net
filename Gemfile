source "https://rubygems.org"

# RubyGem 1.8.15. Bundler 1.0.21

gem "rails", "2.3.14"
gem 'rake', "0.9.2.2"
gem 'rmagick'
gem "carrierwave", "0.4.10"
gem "chronic"
gem 'whenever', "0.5.0"
gem 'fastercsv'
gem 'will_paginate', "2.3.15"
gem 'thinking-sphinx', "~>1.3.20"
gem 'riddle', "1.2.1"
gem 'ts-datetime-delta'
gem 'decoder', ">=0.6.5" # There's an unpacked version that contains fixes that were later incorporated by the maintainer. Can be removed now. 
gem 'acts_as_archive'
gem 'mysql2', '0.2.18'
gem 'redis'
gem 'system_timer'
gem 'yajl-ruby'
gem 'resque', :require => "resque/server"
gem "resque-pool", "~> 0.2.0"
gem "net-scp", "~> 1.0.4"
gem 'geokit' #, :git => 'https://github.com/geokit/geokit.git', :branch => 'master'
gem 'resque-job-stats'
gem 'resque-scheduler', '2.0.0'
gem 'resque-retry'

gem "httparty", "0.11.0"  # Last version which supports Ruby 1.8.6. Needed by Bugsnag
gem "bugsnag"

group :development do
  # bundler requires these gems in development
  gem 'thin'
  gem 'ruby-debug'
  gem 'capistrano', '~> 2.15.5'
  gem 'net-ssh', '~> 2.7.0'
  gem 'net-ssh-gateway', '~> 1.2.0'
end

group :test do
  # bundler requires these gems in test
  gem 'shoulda'
  # gem 'wrong'
  gem 'miniskirt'
  gem 'faker'
  gem 'test-unit'
end
