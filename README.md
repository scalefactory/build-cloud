# Build::Cloud

Tools for building resources in AWS

## Installation

Add this line to your application's Gemfile:

    gem 'build-cloud'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install build-cloud

## Usage

See the command line help for `build-cloud`.

## Changelog

2015-09-02 - version 0.0.13 - use the same environment variables as AWS SDKs for credentials

2015-08-24 - version 0.0.12 - adds support for tagging network interfaces, permits multiple config files to be passed on the commandline, fixes a bug with S3 buckets named to contain dots.

2015-05-18 - version 0.0.11 - fixed problems with IAM roles

2015-04-14 - version 0.0.10 - adds "lifecycle" functionality for security groups. Existing security groups will now have rules removed from them or added to them to make AWS reflect the YAML passed to build-cloud. Previously, once a security group had been created by build-cloud, it was never subsequently updated.

2014-12-12 - version 0.0.9 - bugfixes to file path resolution. It is worth noting that when multiple files are passed to `--config` they're treated as relative to the CWD - this is what you'd expect from referencing a file in a command line option. When file(s) are specified in an `:include` key in the given YAML file, relative paths given there are considered to be relative to the location of the YAML file given to `--config` - this is to ensure consistent behaviour regardless of what $CWD is when calling build-cloud.

2014-12-01 - version 0.0.8 - when multiple files are passed to `--config`, any top-level elements in the second and subsequent files which are arrays are merged into the arrays from previously read in files. This means, for examples, that you can have lists of instances or security groups in multiple files, and they will all be read in. Previously, subsequent files overwrote what was in previous files. Note that this only applies for top level elements of YAML files which are arrays - the previous overwriting behaviour applies still to strings.

2014-10-03 - version 0.0.7 - instance creation previously had a 30 second wait to transition from pending to running state. This was insufficient, and has been increased to 60 seconds.

2014-09-23 - version 0.0.6 - correctly name tags VPCs, and now allows you to refer to the public IP of a network interface (via `:network_interface_public_ip` in a Route 53 record set.

2014-09-16 - version 0.0.5 - now supports creation of DHCP Options Sets, and specifying them using the `:dhcp_options_set_name` key to a VPC.

2014-09-15 - version 0.0.4 - files can now be passed to `--config` with a path. It is no longer assumed that all files will be in the same directory.

2014-09-15 - version 0.0.3 - now accepts multiple files to `--config`. The second and subsequent files are merged into the first YAML file in order, ahead of any files specified in a `:include` list in the first YAML file.

2014-06-23 - version 0.0.2 - now accepts an array of files in the `:include` key in the given YAML config file. The files are merged in to the config file in the order that they are given.

2014-05-27 - version 0.0.1 - initial version.

## Contributing

1. Fork it ( http://github.com/<my-github-username>/build-cloud/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
