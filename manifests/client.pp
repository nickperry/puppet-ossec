# Setup for ossec client
class ossec::client(
  $ossec_active_response   = true,
  $ossec_server_ip,
  $ossec_emailnotification = "yes",
  $selinux = false,
) {
  include ossec::common

  case $::osfamily {
    'Debian' : {
      package { $ossec::common::hidsagentpackage:
        ensure  => installed,
        require => Apt::Source['alienvault'],
      }
    }
    'RedHat' : {
      package { 'ossec-hids':
        ensure  => installed,
      }
      package { $ossec::common::hidsagentpackage:
        ensure  => installed,
        require => Package['ossec-hids'],
      }
    }
    default: { fail('OS family not supported') }
  }

  service { $ossec::common::hidsagentservice:
    ensure    => running,
    enable    => true,
    hasstatus => $ossec::common::servicehasstatus,
    pattern   => $ossec::common::hidsagentservice,
    require   => Package[$ossec::common::hidsagentpackage],
  }

  concat { '/opt/ossec/etc/ossec.conf':
    owner   => 'root',
    group   => 'ossec',
    mode    => '0440',
    require => Package[$ossec::common::hidsagentpackage],
    notify  => Service[$ossec::common::hidsagentservice]
  }
  concat::fragment { 'ossec.conf_10' :
    target  => '/opt/ossec/etc/ossec.conf',
    content => template('ossec/10_ossec_agent.conf.erb'),
    order   => 10,
    notify  => Service[$ossec::common::hidsagentservice]
  }
  concat::fragment { 'ossec.conf_99' :
    target  => '/opt/ossec/etc/ossec.conf',
    content => template('ossec/99_ossec_agent.conf.erb'),
    order   => 99,
    notify  => Service[$ossec::common::hidsagentservice]
  }

  concat { '/opt/ossec/etc/client.keys':
    owner   => 'root',
    group   => 'ossec',
    mode    => '0640',
    notify  => Service[$ossec::common::hidsagentservice],
    require => Package[$ossec::common::hidsagentpackage]
  }
  ossec::agentkey{ "ossec_agent_${::fqdn}_client":
    agent_id         => $::uniqueid,
    agent_name       => $::fqdn,
    agent_ip_address => $::ipaddress,
  }
  @@ossec::agentkey{ "ossec_agent_${::fqdn}_server":
    agent_id         => $::uniqueid,
    agent_name       => $::fqdn,
    agent_ip_address => $::ipaddress
  }

  # Set log permissions properly to fix
  # https://github.com/djjudas21/puppet-ossec/issues/20
  file { '/var/log/ossec':
    ensure  => directory,
    require => Package[$ossec::common::hidsagentpackage],
    owner   => 'ossec',
    group   => 'ossec',
    mode    => '0755',
  }

  # SELinux
  if ($::osfamily == 'RedHat' and $selinux == true) {
    selinux::module { 'ossec-logrotate':
      ensure => 'present',
      source => 'puppet:///modules/ossec/ossec-logrotate.te',
    }
  }
}
