-----------
Description
-----------

A puppet module that builds and installs
http://www.mcstas.org/ on amd64 Debian(Ubuntu) or x86_64 RHEL(Fedora).

Tested on: Debian 7/8, Ubuntu 14.04 and RHEL7, Fedora 20.

------------
Sample Usage
------------

1. Install the module and dependencies:
---------------------------------------

* on Debian/Ubuntu::

        $ sudo apt-get -y install puppet git
        $ cd /etc/puppet/modules
        $ sudo mkdir -p ../manifests
        $ sudo git clone https://github.com/marcindulak/puppet-mclearn.git
        $ sudo ln -s puppet-mclearn mclearn

* on RHEL7::

        $ su -c "yum -y install http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-2.noarch.rpm"
        $ su -c "yum -y install puppet git httpd"
        $ cd /etc/puppet/modules
        $ su -c "mkdir -p ../manifests"
        $ su -c "git clone https://github.com/marcindulak/puppet-mclearn.git"
        $ su -c "ln -s puppet-mclearn mclearn"

  **Note 1**: cmake-2.8.12 is needed, take it from Fedora 19::

        $ su -c "yum -y install http://dl.fedoraproject.org/pub/fedora/linux/updates/19/x86_64/cmake-2.8.12.2-2.fc19.x86_64.rpm"

  **Note 2**: pgplot is needed, normally available from rpmfusion repositories, take it from Fedora 19 for now::

        $ su -c "yum -y install http://download1.rpmfusion.org/nonfree/fedora/releases/19/Everything/x86_64/os/pgplot-5.2.2-35.fc19.x86_64.rpm http://download1.rpmfusion.org/nonfree/fedora/updates/19/x86_64/perl-PGPLOT-2.21-2.fc19.x86_64.rpm"

* on Fedora, enable http://rpmfusion.org/Configuration (provides pgplot), and::

        $ su -c "yum -y install puppet git httpd"
        $ cd /etc/puppet/modules
        $ su -c "mkdir -p ../manifests"
        $ su -c "git clone https://github.com/marcindulak/puppet-mclearn.git"
        $ su -c "ln -s puppet-mclearn mclearn"


2. Configure the module:
-------------------------------------------------------------------------

As root user, create the /etc/puppet/manifests/site.pp file, e.g. Debian stable::

        node default {
        class { 'mclearn::build': } ->
        class { 'mclearn::install': }
        # The 'mclearn::initdb' does not work yet due to a missing LDAP setup.
        #class { 'mclearn::install': } ->
        #class { 'mclearn::initdb': django_user => "root", django_email => "root@domain.com", django_password => "password" }
        }

On Ubuntu 14.04 use Ubuntu's repository::

        node default {
	class { 'mclearn::build': extra_repo => "deb http://archive.ubuntu.com/ubuntu/ trusty multiverse\ndeb http://archive.ubuntu.com/ubuntu/ trusty-updates multiverse" } ->
	class { 'mclearn::install': }
        # The 'mclearn::initdb' does not work yet due to a missing LDAP setup.
	#class { 'mclearn::install': } ->
	#class { 'mclearn::initdb': django_user => "root", django_email => "root@domain.com", django_password => "password" }
        }

Debian testing requires the following repository configuration::

        deb http://ftp.debian.org/debian/ testing main contrib non-free

On RHEL/Fedora use the default Apache www directory::

        node default {
        class { 'mclearn::build': } ->
        class { 'mclearn::install': wwwdir => "/var/www/html" }
        # The 'mclearn::initdb' does not work yet due to a missing LDAP setup.
        #class { 'mclearn::install': wwwdir => "/var/www/html" } ->
        #class { 'mclearn::initdb': django_user => "root", django_email => "root@domain.com", django_password => "password", wwwdir => "/var/www/html" }
        }

Change permissions so only root can read your credentials::

        # chmod go-rwx /etc/puppet/manifests/site.pp


3. Apply the module:
--------------------

* on Debian/Ubuntu:

        $ sudo puppet apply --verbose --debug /etc/puppet/manifests/site.pp

* on RHEL7/Fedora:

        $ su -c "puppet apply --verbose /etc/puppet/manifests/site.pp"


------------
Dependencies
------------

None


----
Todo
----
