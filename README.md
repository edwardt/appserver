Automagic application server configurator
=========================================

Monit/Nginx/Unicorn application server configurator using deployment via git
(simply git push applications to your server to deploy them).

This tool automatically generates server configs for [Monit][monit],
[Nginx][nginx] and [Unicorn][unicorn] to host your [Rack][rack]-based (Rails)
applications. Running it automatically in git update hooks provides an
automatic deployment of applications whenever the repository is updated
on the server.

Requirements
------------

A server running [Monit][monit], [Nginx][nginx] and having [Git][git] and
Ruby with RubyGems installed.

Install
-------

    gem install appserver

Or check out the [repository][repo] on github.

Setup
-----

### Initialize an appserver directory

To run applications, you need to initialize an appserver directory first. To
do so, run `appserver init`.

    $ appserver init /var/webapps

An appserver directory holds configuration files and everything needed to run
multiple applications (application code, temp files, log files, ...). You can
customize settings by editing the `appserver.conf.rb` configuration file. **All
other files are updated automatically and should not be modified manually.**

### Activate generated Nginx configuration

Modify your system's Nginx configuration (e.g. `/etc/nginx/nginx.conf` on
Ubuntu) to include the generated `nginx.conf` **inside a `http` statement**.
Reload Nginx to apply the configuration changes.

*/etc/nginx/nginx.conf:*

    ⋮
    http {
      ⋮
      include /var/webapps/nginx.conf;
    }
    ⋮

### Activate generated Monit configuration

Modify your system's Monit configuration (e.g. `/etc/monit/monitrc` on Ubuntu)
to include the generated `monitrc` at the bottom. Reload Monit to apply the
configuration changes.

*/etc/monit/monitrc:*

    ⋮
    include /var/webapps/monitrc

### Optional: Activate generated Logrotate configuration

Modify your system's Logrotate configuration (e.g. `/etc/logrotate.conf` on
Ubuntu) to include the generated `logrotate.conf` at the bottom. Logrotate
is typically executed from cron, so there's no daemon to reload to apply the
configuration changes.

*/etc/logrotate.conf:*

    ⋮
    include /var/webapps/logrotate.conf

Deploying an application
------------------------

to be done...

How it works
------------

to be done...

Security considerations
-----------------------

to be done...

Author
------

Andreas Neuhaus :: <http://zargony.com/>

[repo]: http://github.com/zargony/appserver/
[monit]: http://mmonit.com/monit/
[nginx]: http://nginx.com/
[unicorn]: http://unicorn.bogomips.org/
[git]: http://git-scm.com/
[rack]: http://rack.rubyforge.org/
