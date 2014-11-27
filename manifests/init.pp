class mclearn (
  # empty for now
  ) {
  }

class mclearn::apache {

  case $::osfamily {
    "redhat": {
      $apache_package = "httpd"
      $apache_service = "httpd"
    }
    "debian": {
      $apache_package = "apache2"
      $apache_service = "apache2"
    }
    default: {
      $apache_package = undef
      $apache_service = undef
    }
  }

  package { $apache_package:
    name => $apache_package,
    ensure => installed,
  }
 
  service { $apache_service:
    ensure  => running,
    enable => true,
    require => Package[$apache_package],
  }

}

class mclearn::mysql (
  $mysql_password = undef
  ) {

  # needed by exec, otherwise one needs to provide full path to sed, grep, ...
  Exec {
    path => "/bin:/sbin:/usr/bin:/usr/sbin",
  }

  case $::osfamily {
    "redhat": {
      $mysql_package = "mysql-server"
      $mysql_service = "mysqld"
    }
    "debian": {
      $mysql_package = "mysql-server"
      $mysql_service = "mysql"
    }
    default: {
      $mysql_package = undef
      $mysql_service = undef
    }
  }

  package { $mysql_package:
    name => $mysql_package,
    ensure => installed,
  }

  # expect is used to mysql_secure_installation
  package { "expect":
    name => "expect",
    ensure => installed,
    before => Exec["mysql_secure_installation"],
  }

  # this is the mysql_secure_installation expect script
  file { "mysql_secure_installation":
    ensure => file,
    replace => false,
    path => "/root/mysql_secure_installation",
    owner => "root",
    group => "root",
    mode => 640,
    source => "puppet:///modules/mclearn/mysql_secure_installation",
    before => Exec["mysql_secure_installation"],
  }

  # actual operation of performing mysql_secure_installation - run only once!
  exec { "mysql_secure_installation":
    command => "sed -i 's|MYSQL_PASSWORD|$mysql_password|' /root/mysql_secure_installation&& expect /root/mysql_secure_installation&& echo 'SELECT User, Host, Password FROM mysql.user;' | mysql -u root --password=$mysql_password",
    onlyif => "grep -E 'MYSQL_PASSWORD' /root/mysql_secure_installation",
  }

  service { $mysql_service:
    ensure  => running,
    enable => true,
    require => Package[$mysql_package],
    before => File["mysql_secure_installation"],
  }

}

class mclearn::build (
  $url = "https://svn.mccode.org/svn/McCode/trunk",
  $srcdir = "/root/trunk",
  $extra_repo = "deb http://ftp.debian.org/debian/ stable main contrib non-free"
  ) {

  # needed by exec, otherwise one needs to provide full path to executables ...
  Exec {
    path => "/bin:/sbin:/usr/bin:/usr/sbin",
  }

  case $::osfamily {
    "redhat": {
      $build_dependencies = [
                             "wget",
                             "subversion",
                             "cmake",
                             "texlive",
                             "latex2html",
                             "gcc",
                             "flex",
                             "bison",
                             "openmpi-devel",
                             "rpm-build",
                             "createrepo",
                             ]
      $build_mcstas = "build_rpms_mcstas"
      $build_mcxtrace = "build_rpms_mcxtrace"
    }
    "debian": {
      $build_dependencies = [
                             "wget",
                             "subversion",
                             "cmake",
                             "texlive-full",
                             "latex2html",
                             "latexmk",
                             "gcc",
                             "flex",
                             "bison",
                             "xbase-clients",
                             "build-essential",
                             "dpkg-dev",
                             "libopenmpi-dev",
                             ]
      $build_mcstas = "build_debs_mcstas"
      $build_mcxtrace = "build_debs_mcxtrace"
    }
    default: {

      $build_dependencies = undef
      $build_mcstas = undef
      $build_mcxtrace = undef
    }

  }

  case $::osfamily {
    "debian": {
      exec { "apt-update":
        command => "apt-get update",
        refreshonly => true;
      }
    }
  }

  package { $build_dependencies:
    ensure => installed,
  }

  exec { "checkout":
    command => "rm -rf $srcdir&& echo t | svn co --no-auth-cache $url $srcdir&& touch $srcdir/svn.co",
    onlyif => "test ! -f $srcdir/svn.co",
    timeout => 3600,
    require => Package[$build_dependencies],
  }

  case $::osfamily {
    "debian": {
      exec { "nodash":
        command => "echo 'dash dash/sh boolean false' | debconf-set-selections && DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash",
        onlyif => 'test ! -z "`debconf-show dash | grep -i true`"',
        require => Package[$build_dependencies],
      }
    }
  }

  case $::osfamily {
    "debian": {
      # e.g. libpgplot-perl comes from there
      file { "extra repo":
        content => $extra_repo,
        path    => "/etc/apt/sources.list.d/extra.list",
        owner   => root,
        group   => root,
        mode    => 0644,
        notify  => Exec["apt-update"],
      }
    }
  }

  exec { "build-mcstas":
    command => "ls $srcdir&& cd $srcdir&& sh $build_mcstas 2.1&& touch $srcdir/mcstas.built",
    onlyif => "test -f $srcdir/svn.co && test ! -f $srcdir/mcstas.built",
    timeout => 3600,
    require => Exec["checkout"],
  }

  exec { "build-mcxtrace":
    command => "ls $srcdir&& cd $srcdir&& sh $build_mcxtrace 1.1&& touch $srcdir/mcxtrace.built",
    onlyif => "test -f $srcdir/svn.co && test ! -f $srcdir/mcxtrace.built",
    timeout => 3600,
    require => Exec["checkout"],
  }

  case $::osfamily {
    "debian": {
      exec { "libtk-codetext-perl":
        command => "wget --timestamping --no-directories --no-check-certificate http://packages.mccode.org/debian/dists/stable/main/binary-amd64/libtk-codetext-perl_0.3.4-1_all.deb -O $srcdir/dist/libtk-codetext-perl_0.3.4-1_all.deb",
        onlyif => "test -d $srcdir/dist && test ! -f $srcdir/dist/libtk-codetext-perl_0.3.4-1_all.deb",
        timeout => 600,
        require => Exec["build-mcstas", "build-mcxtrace"],
      }
    }
    "redhat": {
      exec { "libtk-codetext-perl":
        command => "wget --timestamping --no-directories --no-check-certificate http://packages.mccode.org/rpm/x86_64/libtk-codetext-perl-0.3.4-2.noarch.rpm -O $srcdir/dist/libtk-codetext-perl-0.3.4-2.noarch.rpm",
        onlyif => "test -d $srcdir/dist && test ! -f $srcdir/dist/libtk-codetext-perl-0.3.4-2.noarch.rpm",
        timeout => 600,
        require => Exec["build-mcstas", "build-mcxtrace"],
      }
    }
  }

  case $::osfamily {
    "debian": {
      # http://askubuntu.com/questions/170348/how-to-make-my-own-local-repository
      exec { "local repo packages":
        command => "ls $srcdir/dist&& cd $srcdir/dist&& rm -f *linux32.deb&& dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz",
        onlyif => "test ! -f $srcdir/dist/Packages.gz && test -f $srcdir/mcxtrace.built && test -f $srcdir/mcxtrace.built && test -f $srcdir/dist/libtk-codetext-perl_0.3.4-1_all.deb",
        timeout => 600,
        require => Exec["libtk-codetext-perl"],
      }
    }
    "redhat": {
      exec { "local repo packages":
        # last chaco was in Fedora 15
        command => "ls $srcdir/dist&& cd $srcdir/dist&& rm -f *linux32.rpm&& rm -f *chaco*.rpm&& createrepo `pwd`",
        onlyif => "test ! -f $srcdir/dist/repodata/repomd.xml && test -f $srcdir/mcxtrace.built && test -f $srcdir/mcxtrace.built && test -f $srcdir/dist/libtk-codetext-perl-0.3.4-2.noarch.rpm",
        timeout => 600,
        require => Exec["libtk-codetext-perl"],
      }
    }
  }

  case $::osfamily {
    "debian": {
      exec { "local repo":
        command => "ls $srcdir/dist&& echo 'deb file:$srcdir/dist /' > /etc/apt/sources.list.d/mccode_local.list&& apt-get update",
        onlyif => "test -f $srcdir/dist/Packages.gz && test ! -f /etc/apt/sources.list.d/mccode_local.list",
        require => Exec["local repo packages"],
        notify => Exec["apt-update"],
      }
    }
    "redhat": {
      exec { "local repo":
        command => "ls $srcdir/dist&& echo -e '[mccode_local]\nname=mccode local\nbaseurl=file://$srcdir/dist\nenabled=1\ngpgcheck=0' > /etc/yum.repos.d/mccode_local.repo",
        onlyif => "test -f $srcdir/dist/repodata/repomd.xml && test ! -f /etc/yum.repos.d/mccode_local.repo",
        require => Exec["local repo packages"],
      }
    }
  }

}

class mclearn::install (
  $srcdir = "/root/trunk",
  $wwwdir = "/srv/mcstas-django"
  ) {

  # needed by exec, otherwise one needs to provide full path to executables ...
  Exec {
    path => "/bin:/sbin:/usr/bin:/usr/sbin",
  }

  case $::osfamily {
    "redhat": {
      # last chaco was in Fedora 15
      $mcpackages = [
                     "mcstas-2.1",
                     #"mcstas-manuals-2.1",
                     "mcstas-tools-perl-2.1",
                     "mcstas-tools-python-mcdisplay-2.1",
                     "mcstas-tools-python-mcdisplay-matplotlib-2.1",
                     "mcstas-tools-python-mcdisplay-r-2.1",
                     "mcstas-tools-python-mcdisplay-vtk-2.1",
                     #"mcstas-tools-python-mcplot-chaco-2.1",
                     "mcstas-tools-python-mcplot-matplotlib-2.1",
                     "mcstas-tools-python-mcrun-2.1",
                     "mcxtrace-1.1",
                     "mcxtrace-tools-perl-1.1",
                     "mcxtrace-tools-python-mxdisplay-1.1",
                     #"mcxtrace-tools-python-mxplot-chaco-1.1",
                     "mcxtrace-tools-python-mxplot-matplotlib-1.1",
                     "mcxtrace-tools-python-mxrun-1.1",
                     ]
      $install_dependencies = [
                               "openmpi",
                               "python-devel",
                               "nginx",
                               "python-django",
                               #"uwsgi",  # not available on EL7 yet
                     ]
      $execinstall = "yum install -y mcxtrace-* mcstas-*"
      $src_sentinel = "/usr/local/mcstas"
    }
    "debian": {
      $mcpackages = [
                     "mcstas-2.1",
                     "mcstas-manuals-2.1",
                     "mcstas-tools-perl-2.1",
                     "mcstas-tools-python-mcdisplay-2.1",
                     "mcstas-tools-python-mcdisplay-matplotlib-2.1",
                     "mcstas-tools-python-mcdisplay-r-2.1",
                     "mcstas-tools-python-mcdisplay-vtk-2.1",
                     "mcstas-tools-python-mcplot-chaco-2.1",
                     "mcstas-tools-python-mcplot-matplotlib-2.1",
                     "mcstas-tools-python-mcrun-2.1",
                     "mcxtrace-1.1",
                     "mcxtrace-tools-perl-1.1",
                     "mcxtrace-tools-python-mxdisplay-1.1",
                     "mcxtrace-tools-python-mxplot-chaco-1.1",
                     "mcxtrace-tools-python-mxplot-matplotlib-1.1",
                     "mcxtrace-tools-python-mxrun-1.1",
                     ]
      $install_dependencies = [
                       "openmpi-bin",
                       "python-dev",
                       "nginx-full",
                       "python-django",
                       "uwsgi",
                     ]
      $execinstall = "apt-get install -y --force-yes mcxtrace-* mcstas-*"
      $src_sentinel = "/usr/bin/mcdoc"
    }

    default: {

      $mcpackages = undef
      $install_dependencies = undef
      $src_sentinel = undef
    }

  }

  exec { $execinstall:
    command => $execinstall,
    onlyif => "test ! -r $src_sentinel",
    timeout => 3600,
    require => Exec["local repo"],
  }
  
  package { $install_dependencies:
    ensure => installed,
  }

  exec { $wwwdir:
    command => "cp -rp $srcdir/tools/Python/www/www-django/mcwww $wwwdir",
    onlyif => "test ! -d $wwwdir && test -r $src_sentinel",
    require => Exec["$execinstall"],
  }

}

class mclearn::initdb (
  $wwwdir = "/srv/mcstas-django",
  $django_user = undef,
  $django_email = undef,
  $django_password = undef
  ) {

  # needed by exec, otherwise one needs to provide full path to sed, grep, ...
  Exec {
    path => "/bin:/sbin:/usr/bin:/usr/sbin",
  }

  # expect is used to initdb
  package { "expect":
    name => "expect",
    ensure => installed,
    before => Exec["initdb"],
  }

  # this is the initdb expect script
  file { "initdb":
    ensure => file,
    replace => false,
    path => "/root/initdb",
    owner => "root",
    group => "root",
    mode => 640,
    source => "puppet:///modules/mclearn/initdb",
    before => Exec["initdb"],
  }

  # actual operation of performing initdb - run only once!
  exec { "initdb":
    command => "sed -i 's|WWWDIR|$wwwdir|' /root/initdb&& sed -i 's|DJANGO_USER|$django_user|' /root/initdb&& sed -i 's|DJANGO_EMAIL|$django_email|' /root/initdb&& sed -i 's|DJANGO_PASSWORD|$django_password|' /root/initdb&& cd $wwwdir&& LC_ALL='en_US.UTF-8' expect /root/initdb",
    onlyif => "grep -E 'DJANGO_PASSWORD' /root/initdb",
    require => Exec[$wwwdir],
  }

}


class mclearn::mclearn (
  $scm = "git",
  $url = "github.com/marcindulak/puppet-mclearn.git",
  $user = undef,
  $password = undef,
  $mysql_password = undef,
  $apache_ssl_cert_custom = undef,
  $apache_ssl_key_custom = undef
  ) {
  
  $use_password = $password ? {
    undef => "" ,
    default => ":$password",
  }
 
  # needed by exec, otherwise one needs to provide full path to git ...
  Exec {
    path => "/bin:/sbin:/usr/bin:/usr/sbin",
  }

  case $::osfamily {
    "redhat": {
      $apache_service = "httpd"
      $apache_root = "/var/www/html"
      $apache_confdir = "/etc/httpd/conf.d"
      $apache_ssl_cert = $apache_ssl_cert_custom ? {
        undef => "/etc/pki/tls/certs/localhost.crt" ,
        default => $apache_ssl_cert_custom,
      }
      $apache_ssl_key = $apache_ssl_key_custom ? {
        undef => "/etc/pki/tls/private/localhost.key" ,
        default => $apache_ssl_key_custom,
      }
      $apache_user = "apache"
      $apache_group = "apache"
      $modssl_package = "mod_ssl"
      $modphp_package = "php"
      $php_mysql_package = "php-mysql"
    }
    "debian": {
      $apache_service = "apache2"
      $apache_root = "/var/www"
      $apache_confdir = "/etc/apache2/conf.d"
      $apache_ssl_cert = $apache_ssl_cert_custom ? {
        undef => "/etc/ssl/certs/ssl-cert-snakeoil.pem" ,
        default => $apache_ssl_cert_custom,
      }
      $apache_ssl_key = $apache_ssl_key_custom ? {
        undef => "/etc/ssl/private/ssl-cert-snakeoil.key" ,
        default => $apache_ssl_key_custom,
      }
      $apache_user = "www-data"
      $apache_group = "www-data"
      $modssl_package = "apache2"
      $modphp_package = "libapache2-mod-php5"
      $php_mysql_package = "php5-mysql"
    }
    default: {
      $apache_service = undef
      $apache_root = undef
      $apache_confdir = undef
      $apache_ssl_cert = undef
      $apache_ssl_key = undef
      $apache_user = undef
      $apache_group = undef
      $modssl_package = undef
      $modphp_package = undef
      $php_mysql_package = undef
    }
  }

  # mod_ssl: on RHEL simply install, on Debian special steps
  case $::osfamily {
    "redhat": {
      if ! defined(Package[$modssl_package]) {
        package { $modssl_package:
          name => $modssl_package,
          ensure => installed,
          before => File['mclearn.conf'],
          notify => Service[$apache_service],
        }
      }
    }
    "debian": {
      exec { "a2enmod ssl":
        command => 'a2enmod ssl',
        before => File['mclearn.conf'],
        notify => Service[$apache_service],
      }
    }
  }

  if ! defined(Package[$modphp_package]) {
    package { $modphp_package:
      name => $modphp_package,
      ensure => installed,
      before => File['mclearn.conf'],
      notify => Service[$apache_service],
    }
  }

  if ! defined(Package[$php_mysql_package]) {
    package { $php_mysql_package:
      name => $php_mysql_package,
      ensure => installed,
      before => File['mclearn.conf'],
      notify => Service[$apache_service],
    }
  }

  package { "$scm":
    name => $scm ? {
      "hg" => "mercurial",
      default => $scm,
    },
    ensure => installed,
    before => Exec["clone", "checkout"],
  }

  # apache configuration
  file { "mclearn.conf":
    ensure => file,
    path => "$apache_confdir/mclearn.conf",
    owner => $apache_user,
    group => $apache_group,
    mode => 644,
    content => template("mclearn/mclearn.erb"),
    notify => Service[$apache_service],
  }

  exec { "clone":
    command => "rm -rf $apache_root/mclearn&& cd $apache_root&& $scm clone https://$user$use_password@$url&& cd mclearn&& $scm status",
    onlyif => "test ! -d $apache_root/mclearn",
    before => Exec["checkout"],
  }

  exec { "checkout":
    command => "ls $apache_root/mclearn&& cd $apache_root/mclearn&& $scm checkout&& $scm status&& chown -R $apache_user:$apache_group .; chmod -R o-rwx .",
    onlyif => "test -d $apache_root/mclearn",
    before => Exec["mysql_password"],
    notify => Service[$apache_service]
  }

  exec { "mysql_password":
    command => "ls $apache_root/mclearn/db_create_tables.php&& sed -i 's|\$ADMIN_PASSWORD =.*|\$ADMIN_PASSWORD = \"$mysql_password\"; // modified by puppet |' $apache_root/mclearn/db_create_tables.php",
    onlyif => "test -d $apache_root/mclearn",
    notify => Service[$apache_service],
  }

}
