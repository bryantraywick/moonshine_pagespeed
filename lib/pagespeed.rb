require 'pathname'

module Pagespeed
  def self.included(manifest)
    manifest.class_eval do
      extend ClassMethods
    end
  end

  module ClassMethods
    def pagespeed_configuration
      configuration[:pagespeed][rails_env.to_sym]
    end

    def pagespeed_template_dir
      @pagespeed_template_dir ||= Pathname.new(__FILE__).dirname.dirname.join('templates')
    end
  end

  # Define options for this plugin via the <tt>configure</tt> method
  # in your application manifest:
  #
  #   configure(:pagespeed => {:foo => true})
  #
  # Then include the plugin and call the recipe(s) you need:
  #
  #  recipe :pagespeed
  def pagespeed
    configure(
      :pagespeed => {
        :enabled => true,
        :cache_path => '/var/mod_pagespeed/cache/',
        :file_prefix => '/var/mod_pagespeed/files/',
        :enabled_filters => [],
        :disabled_filters => [],
        :extra_domains => []
      }
    )
    # dependencies for install
    package 'wget',                 :ensure => :installed
    package "apache2-threaded-dev", :ensure => :installed
    
    file "/usr/local/src",          :ensure => :directory
    
    arch = Facter.architecture
    if arch == "x86_64"
      arch = "amd64"
    end
    
    exec 'download_pagespeed',
      :command => "wget https://dl-ssl.google.com/dl/linux/direct/mod-pagespeed-beta_current_#{arch}.deb",
      :cwd => "/usr/local/src",
      :unless => "test -f /usr/local/src/mod-pagespeed-beta_current_#{arch}.deb"
    
    exec 'install_pagespeed',
      :command => [
        "dpkg -i mod-pagespeed-beta_current_#{arch}.deb",
        "apt-get -f install"
      ].join(' && '),
      :cwd => "/usr/local/src",
      :require => [
        package('wget'),
        package("apache2-mpm-worker"),
        package("apache2-threaded-dev"),
        exec('download_pagespeed')
      ],
      :unless => "dpkg -s mod-pagespeed-beta"
    
    file "/etc/apache2/mods-available/pagespeed.conf",
      :ensure => :present,
      :content => template(File.join(File.dirname(__FILE__), '..', 'templates', 'pagespeed.conf.erb')),
      :require => [ exec('install_pagespeed') ],
      :notify => service('apache2'),
      :alias => "pagespeed_conf"
    
    a2enmod 'pagespeed', :require => [ exec('install_pagespeed'), file('pagespeed_conf') ]
  end
end