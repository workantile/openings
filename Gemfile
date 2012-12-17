source 'https://rubygems.org'
ruby '1.9.3'

gem 'rails', '3.2.9'
gem 'pg'
gem 'devise'


# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'

  # See https://github.com/sstephenson/execjs#readme for more supported runtimes
  gem 'therubyracer', :platforms => :ruby

  gem 'uglifier', '>= 1.0.3'
  gem 'less-rails'
  gem 'twitter-bootstrap-rails'
end

gem 'jquery-rails'

group :development, :test do
	gem 'rspec-rails', '>= 2.0.0'
	gem 'factory_girl_rails'
end

group :test do
	gem 'shoulda-matchers'
 	gem 'steak'
 	gem 'capybara-webkit'
	gem 'database_cleaner'
	gem 'email_spec'
	gem 'action_mailer_cache_delivery', '~> 0.3.2'
  gem 'timecop'
end
