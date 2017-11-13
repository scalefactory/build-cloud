# Changelog

2017-11-13 - version 0.0.24 - Fix a bug which prevented working with IAM roles in AWS accounts with more than 100 roles. Thank you @markchalloner!

2017-03-01 - version 0.0.23 - Fix a bug where non-string values for interpolated variables caused a crash.

2016-10-18 - version 0.0.22 - Fix launch configuration error where drives are different in config to fog.

2016-07-22 - version 0.0.21 - Add support for replacing changed ASG Launch Configurations

2016-07-08 - version 0.0.20 - Add support for creating Users, Groups and lifecycle management of their policies. Add support for creating and deleting custom Managed Policies, no lifecycle support for policy versions. Improve IAM role support, lifecycle support for policies: now removes and updates role policies if they change/removed. Add policy lifecycle to S3 buckets.

2016-06-17 - version 0.0.19 - add sqs support

2016-06-16 - version 0.0.18 - fix cache parameter group creation for elasticache

2016-05-04 - version 0.0.17 - allow metrics to be enabled on an asg when it's created

2016-02-02 - version 0.0.16 - fix bug which prevented security groups containing multiple references to other security groups being updated

2015-11-10 - version 0.0.15 - allow private_ip to be optional when creating an ENI

2015-10-12 - version 0.0.14 - now allows defaults in interpolated variables, if the variable doesn't exist. Format is `%{variablename||default}` eg. `%{node_instance_type||t2.large}`

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
