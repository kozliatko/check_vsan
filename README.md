# check_vsan
==============

This is a pure bash/curl/grep/perl plugin for _nagios_ to check health of VSAN
clusters. It uses **no vmware SDK**, just pure unix tools.

There is also [python implementation](https://github.com/markhamb/check_vsan)
which uses [the VMware python
SDK](https://www.vmware.com/support/developer/vapi/index.html), but it
didn't work for me.

This plugin can parse malformed XML response.

--------------

__Usage: check_vsan.sh [-h | --help | -s server -u user -p password | --username user --password password --server server] [-v | --verbose ] [ -n | --noclean ]__

Check VMWare VSAN status 

  **check_vsan.sh -h | --help**
    print this help

  **check_vsan.sh -v | --verbose**
     verbose output to logfile

  **check_vsan.sh -n | --noclean**
     do not delete temporary directory /tmp/vsan-*

  **check_vsan.sh -u | --username**
     vcenter username (can be omitted if VCENTERUSERNAME is set)

  **check_vsan.sh -p | --password**
     vcenter password (can be omitted if VCENTERPASSWORD is set)

  **check_vsan.sh -s | --server**
     vcenter hostname (can be omitted if VCENTERSERVER is set)

--------------

_If the plugin doesn't work, you have patches or want to suggest improvements
send email to jan.vajda@gmail.com.
Please include version information with all correspondence_
