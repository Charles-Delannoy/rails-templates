run "if uname | grep -q 'Darwin'; then pgrep spring | xargs kill -9; fi"

# GEMFILE
########################################
inject_into_file 'Gemfile', before: 'group :development, :test do' do
  <<~RUBY
    gem 'autoprefixer-rails'
    gem 'font-awesome-sass'
    gem 'simple_form'

  RUBY
end

inject_into_file 'Gemfile', after: 'group :development, :test do' do
  <<-RUBY

  gem 'pry-byebug'
  gem 'pry-rails'
  gem 'dotenv-rails'
  # Test with Rspec
  gem 'rspec-rails', '~> 4.0'
  # add method to rspec
  gem 'rails-controller-testing'
  # Guard automatically launch test on modifications
  gem 'guard-rspec', require: false
  # Replacement of fixtures for Rspec
  gem 'factory_bot_rails'
  RUBY
end

# IRB conf file
########################################
irbrc = '
if defined?(Rails)
  banner = ''

  if Rails.env.production?
    banner = "\e[41;97;1m prod \e[0m "
  elsif Rails.env.staging?
    banner = "\e[43;97;1m staging \e[0m "
  end


  IRB.conf[:PROMPT][:CUSTOM] = IRB.conf[:PROMPT][:DEFAULT].merge(
    PROMPT_I: "#{banner}#{IRB.conf[:PROMPT][:DEFAULT][:PROMPT_I]}"
  )

  IRB.conf[:PROMPT_MODE] = :CUSTOM
end
'
file '.irbrc', irbrc.strip

# Clevercloud conf file
########################################
file 'clevercloud/ruby.json', <<~EOF
  {
    "deploy": {
      "rakegoals": ["assets:precompile", "db:migrate"]
    }
  }
EOF

# Database conf file
########################################
db_production_conf = <<~EOF
  production:
    <<: *default
    url: <%= ENV['POSTGRESQL_ADDON_URI'] %>
EOF

gsub_file('config/database.yml', /^production:.*\z/m, db_production_conf)

# Assets
########################################
run 'rm -rf app/assets/stylesheets'
run 'rm -rf vendor'
run 'curl -L https://github.com/Charles-Delannoy/rails-stylesheets/archive/master.zip > stylesheets.zip'
run 'unzip stylesheets.zip -d app/assets && rm stylesheets.zip && mv app/assets/rails-stylesheets-master app/assets/stylesheets'

# Dev environment
########################################
gsub_file('config/environments/development.rb', /config\.assets\.debug.*/, 'config.assets.debug = false')

# Layout
########################################
if Rails.version < "6"
  scripts = <<~HTML
    <%= javascript_include_tag 'application', 'data-turbolinks-track': 'reload', defer: true %>
        <%= javascript_pack_tag 'application', 'data-turbolinks-track': 'reload' %>
  HTML
  gsub_file('app/views/layouts/application.html.erb', "<%= javascript_include_tag 'application', 'data-turbolinks-track': 'reload' %>", scripts)
end

gsub_file('app/views/layouts/application.html.erb', "<%= javascript_pack_tag 'application', 'data-turbolinks-track': 'reload' %>", "<%= javascript_pack_tag 'application', 'data-turbolinks-track': 'reload', defer: true %>")

style = <<~HTML
  <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
      <%= stylesheet_link_tag 'application', media: 'all', 'data-turbolinks-track': 'reload' %>
HTML
gsub_file('app/views/layouts/application.html.erb', "<%= stylesheet_link_tag 'application', media: 'all', 'data-turbolinks-track': 'reload' %>", style)


# Generators
########################################
generators = <<~RUBY
  config.generators do |generate|
    generate.assets false
    generate.helper false
    generate.test_framework :rspec, fixture: false
  end

RUBY

environment generators

########################################
# AFTER BUNDLE
########################################
after_bundle do
  # Generators: db + simple form + pages controller
  ########################################
  rails_command 'db:drop db:create db:migrate'
  generate('simple_form:install')
  generate(:controller, 'pages', 'home', '--skip-routes', '--no-test-framework')

  # Routes
  ########################################
  route "root to: 'pages#home'"

  # Git ignore
  ########################################
  append_file '.gitignore', <<~TXT

    # Ignore .env file containing credentials.
    .env*

    # Ignore Mac and Linux file system files
    *.swp
    .DS_Store
  TXT

  # Webpacker / Yarn
  ########################################
  # run 'yarn add popper.js jquery bootstrap'
  append_file 'app/javascript/packs/application.js', <<~JS


    // ----------------------------------------------------
    // ABOVE IS RAILS DEFAULT CONFIGURATION
    // WRITE YOUR OWN JS STARTING FROM HERE 👇
    // ----------------------------------------------------

    // External imports
    // import "bootstrap";

    // Internal imports, e.g:
    // import { initSelect2 } from '../components/init_select2';

    document.addEventListener('turbolinks:load', () => {
      // Call your functions here, e.g:
      // initSelect2();
    });
  JS

  inject_into_file 'config/webpack/environment.js', before: 'module.exports' do
    <<~JS
      const webpack = require('webpack');

      // Preventing Babel from transpiling NodeModules packages
      environment.loaders.delete('nodeModules');

      // Bootstrap 4 has a dependency over jQuery & Popper.js:
      // environment.plugins.prepend('Provide',
      //  new webpack.ProvidePlugin({
      //    $: 'jquery',
      //    jQuery: 'jquery',
      //    Popper: ['popper.js', 'default']
      //  })
      //);

    JS
  end

  # Dotenv
  ########################################
  run 'touch .env'

  # Rubocop
  ########################################
  run 'curl -L https://raw.githubusercontent.com/Charles-Delannoy/rails-templates/master/.rubocop.yml > .rubocop.yml'

  # Rspec configuration
  ########################################
  run 'curl -L https://github.com/Charles-Delannoy/rspec-config-template/archive/master.zip > configuration.zip'
  run 'unzip configuration.zip -d spec && rm configuration.zip && cp -r spec/rspec-config-template-master/minimal/. spec/'

  # Git
  ########################################
  git add: '.'
  git commit: "-m 'Initial commit with minimal template from https://github.com/Charles-Delannoy/rails-templates'"
end
