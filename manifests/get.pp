# Definition: rsync::get
#
# get files via rsync
#
# Parameters:
#   $source  - source to copy from
#   $path    - path to copy to, defaults to $name
#   $user    - username on remote system
#   $purge   - if set, rsync will use '--delete'
#   $exlude  - string to be excluded
#   $keyfile - path to ssh key used to connect to remote host, defaults to /home/${user}/.ssh/id_rsa
#   $timeout - timeout in seconds, defaults to 900
#   $debug   - if exec should send notice, boolean
#   $excludes - array of multiple exclude pattern, will create a file for it
#   $cron_run_interval - cron type param minute
#
# Actions:
#   get files via rsync
#
# Requires:
#   $source must be set
#
# Sample Usage:
#
#  rsync::get { '/foo':
#    source  => "rsync://${rsyncServer}/repo/foo/",
#    require => File['/foo'],
#  } # rsync
#
define rsync::get (
  $source,
  $path = undef,
  $user = undef,
  $purge = undef,
  $exclude = undef,
  $keyfile = undef,
  $timeout = '900',
  $debug = false,
  $excludes = undef,
  $cron_run_interval = undef
) {

  if $keyfile {
    $Mykeyfile = $keyfile
  } else {
    $Mykeyfile = "/home/${user}/.ssh/id_rsa"
  }

  if $user {
    $MyUser = "-e 'ssh -i ${Mykeyfile} -l ${user}' ${user}@"
  }

  if $purge {
    $MyPurge = '--delete'
  }

  if $exclude {
    $MyExclude = "--exclude=${exclude}"
  }

  if $path {
    $MyPath = $path
  } else {
    $MyPath = $name
  }

  if $excludes {
    $exclude_sanitized_file_name = regsubst($name,'[^\w\d]','_','G')
    $exclude_file_path = "/tmp/${exclude_sanitized_file_name}_excludes"
    $MyExcludes = "--exclude-from=${exclude_file_path}"
    file { $exclude_file_path:
      ensure => file,
      content => inline_template("# This file is being maintained by Puppet.\n# DO NOT EDIT\n<%= @excludes.join('\n') %>")
    }
    if $cron_run_interval == undef {
      File[$exclude_file_path] -> Exec["rsync ${name}"]
    }
  }

  $rsync_options = "-a ${MyPurge} ${MyExclude} ${MyExcludes} ${MyUser}${source} ${MyPath}"
  $exec_command = "rsync -q ${rsync_options}"
  $exec_onlyif = "test `rsync --dry-run --itemize-changes ${rsync_options} 2>&1 | wc -l` -gt 0"

  if $cron_run_interval {
    cron { "rsync ${name}":
      command => "/usr/bin/env ${exec_command}",
      minute  => $cron_run_interval
    }
  } else {
    exec { "rsync ${name}":
      command => $exec_command,
      path    => [ '/bin', '/usr/bin' ],
      # perform a dry-run to determine if anything needs to be updated
      # this ensures that we only actually create a Puppet event if something needs to
      # be updated
      # TODO - it may make senes to do an actual run here (instead of a dry run)
      #        and relace the command with an echo statement or something to ensure
      #        that we only actually run rsync once
      # NOTE - Pipe stderr to stdout so that exec will actually trigger on errors
      #        so that we can catch it
      onlyif  => $exec_onlyif,
      timeout => $timeout,
    }
  }

  if $debug {
    notice("Rsync command: ${exec_command}")
    notice("Rsync onlyif: ${exec_onlyif}")
  }
}
