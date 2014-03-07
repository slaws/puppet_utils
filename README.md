# Puppet_utils #

# Description #

This package add a subcommand to puppet to list managed files, services and packages.

# Usage #

>USAGE: puppet list <action> <option>
>ACTIONS:
>all        List all type of resources
>file       List all resources of type File
>package    List all resources of type package
>service    List all resources of type Service
>
>OPTIONS:
>--render-as FORMAT             - The rendering format to use.
>--verbose                      - Whether to log verbosely.
>--debug                        - Whether to log debug information.
>--changed                      - Only show changed resources
>--[no-]prefix                  - Do not show resource type at the begining of the line
											 

