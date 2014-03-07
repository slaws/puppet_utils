# -*- coding: utf-8 -*-
require 'puppet/face'
require 'puppet/util/terminal'
require 'puppet/util/colors'
require 'json'
require 'yaml'
require 'facter'
require 'rubygems'



def makeDesc(manifest,mod_path)
  manifest.slice!("#{mod_path}")
  match = /(\w+)\/manifests\/(.*)/.match(manifest)
  if mod_path != "unknown"
    {"module" =>  match[1], "fichier" => match[2].gsub(/\//,"::") }
  else
    {"module" =>  "Recursively", "fichier" => "Managed" }
  end
end

def changed?(changes,resource,type)
  changes.find do|elem| 
    if elem =~ /^#{type}:/
      match = /^#{type}:(.*)/.match(elem)
      true if /#{match[1]}/ =~ resource
    end
  end
end

def printRequiredInfos(onlychanged, match, managedhash,changedArray, prefix, type)
  list = []
  prefix = "" if ! prefix
  sep = prefix != "" ? ":" : ""
  managedhash.sort.each do |file,manifest|
    if changed?(changedArray,file,type)
      if ! match or file =~ /#{Regexp.escape(match)}/
        #printf("%-80s %30s\n","#{prefix}#{sep}#{file} (changed)","#{manifest["module"]}::#{manifest["fichier"]}") 
        list << [ "#{prefix}#{sep}#{file} (changed)", "#{manifest["module"]}::#{manifest["fichier"]}" ]
      end
    else
      if ! match or file =~ /#{Regexp.escape(match)}/
        #printf("%-80s %30s\n","#{prefix}#{sep}#{file}","#{manifest["module"]}::#{manifest["fichier"]}") unless onlychanged
        list << [ "#{prefix}#{sep}#{file}", "#{manifest["module"]}::#{manifest["fichier"]}" ]  unless onlychanged
      end
    end
  end
  list
end

def render_output(infohash)
  format = []
  infohash.each do |resource|
    format << "#{resource[0].ljust(90)} #{resource[1].rjust(30)}"
  end
  format.join("\n")
end

FQDN=Facter.fqdn
puppetvar = Puppet.settings.value('vardir')
puppetenv = Puppet.settings.value('environment')
puppetlog = Puppet.settings.value('logdir')
puppetrun = Puppet.settings.value('rundir')

last_run = YAML.load_file("#{puppetvar}/state/last_run_report.yaml")

changed_files = []

last_run.resource_statuses.each do |id,report|
  if report.changed == true and ['File','Service', 'Package'].include?(report.resource_type)
    match = /(File|Service|Package)\[(.*)\]/.match(id)
    changed_files << "#{report.resource_type}:#{match[2]}"
  end
end

catalog_file = "#{puppetvar}/client_data/catalog/#{FQDN}.json"
module_path = "/etc/puppet/environments/#{puppetenv}/modules/"
managed_files = {}
managed_services = {}
managed_packages = {}


# On construit la liste des fichiers gérés par puppet depuis le catalogue
catalog=JSON.parse(File.read("#{catalog_file}"))
catalog["data"]["resources"].each do |resource|
  if resource["title"] =~ /^\// 
    managed_files[resource["title"]] = makeDesc(resource["file"],module_path)
  end

  if resource['type'] == "Service"
    managed_services[resource["title"]] = makeDesc(resource["file"],module_path)
  end

  if resource['type'] == "Package"
    managed_packages[resource["title"]] = makeDesc(resource["file"],module_path)
  end

  if resource.has_key?('parameters') and resource['parameters'].has_key?('path') and resource.has_key?('file')
    next if resource['parameters']['path'] == false
    managed_files[resource['parameters']['path']] = makeDesc(resource["file"],module_path)
  end
end

# On ajoute aussi ce qu'il y a dans le pupppet state (recursive tout ça ... )

state = YAML.load_file(puppetvar + "/state/state.yaml")
state.each do |key,info|
  next if key =~ /^File\[(#{puppetvar}|#{puppetlog}|#{puppetrun})/
  if key =~ /File\[\//
    match = /File\[(.*)\]/.match(key)
    if ! managed_files[match[1]]
      managed_files[match[1]] = makeDesc("unknown","unknown")
    end
  end
end



Puppet::Face.define(:list, '0.0.1') do
  extend Puppet::Util::Colors

  summary "View resources managed by puppet."
  description <<-'EOT'
This subcommand provides a command line interface to list resources
(File, Services, Package) managed by puppet and its associated manifest.
It also list changed resources during the last run.
EOT

  action :all do
    summary 'List all type of resources'
    arguments "[<file>]"
    description <<-EOT
Do not limit output for a specific type of resource
EOT

    option "--changed" do
      summary "Only show changed resources"
      default_to { false }
    end
    option "--[no-]prefix" do
      summary "Do not show resource type at the begining of the line"
      default_to { true }
    end
    output = []
    when_invoked do |*args|
      options = args.pop
      options[:path] = args[0]
      output.concat(printRequiredInfos(options[:changed], options[:path], managed_files,changed_files, !options[:prefix] ? nil : "File",'File'))
      output.concat(printRequiredInfos(options[:changed], options[:path], managed_services,changed_files,!options[:prefix] ? nil : "Service", 'Service'))
      output.concat(printRequiredInfos(options[:changed], options[:path], managed_packages,changed_files,!options[:prefix] ? nil : "Package", 'Package'))
    end

    when_rendering :console do |output|
      render_output(output)
    end
  end


  action :file do
    summary 'List all resources of type File'
    arguments "[<file>]"
    description <<-EOT
Do not limit output for a specific type of resource
EOT

    option "--changed" do
      summary "Only show changed resources"
      default_to { false }
    end
    option "--[no-]prefix" do
      summary "Do not show resource type at the begining of the line"
      default_to { true }
    end
    output = []
    when_invoked do |*args|
      options = args.pop
      options[:path] = args[0]
      output.concat(printRequiredInfos(options[:changed], options[:path], managed_files,changed_files, !options[:prefix] ? nil : "File",'File'))
    end

    when_rendering :console do |output|
      render_output(output)
    end
  end

  action :service do
    summary 'List all resources of type Service'
    arguments "[<pattern>]"
    description <<-EOT
Do not limit output for a specific type of resource
EOT

    option "--changed" do
      summary "Only show changed resources"
      default_to { false }
    end
    option "--[no-]prefix" do
      summary "Do not show resource type at the begining of the line"
      default_to { true }
    end
    output = []
    when_invoked do |*args|
      options = args.pop
      options[:path] = args[0]
      output.concat(printRequiredInfos(options[:changed], options[:path], managed_services,changed_files, !options[:prefix] ? nil : "Service",'Service'))
    end

    when_rendering :console do |output|
      render_output(output)
    end
  end

  action :package do
    summary 'List all resources of type package'
    arguments "[<pattern>]"
    description <<-EOT
Do not limit output for a specific type of resource
EOT

    option "--changed" do
      summary "Only show changed resources"
      default_to { false }
    end
    option "--[no-]prefix" do
      summary "Do not show resource type at the begining of the line"
      default_to { true }
    end
    output = []
    when_invoked do |*args|
      options = args.pop
      options[:path] = args[0]
      output.concat(printRequiredInfos(options[:changed], options[:path], managed_packages,changed_files, !options[:prefix] ? nil : "Package",'Package'))
    end

    when_rendering :console do |output|
      render_output(output)
    end
  end

  
end
# require 'json'
# require 'yaml'
# require 'facter'
# require 'rubygems'
# require 'ap'
# require 'optparse'
# require 'puppet'

# options = {}

# parser = OptionParser.new do|opts|
#   opts.banner = "Usage: #{$0} [options] [file]"
#   opts.on('-a', '--all', 'List all resources managed by puppet') do 
#     options[:list_all] = true;
#   end
#   opts.on( '--changed','List files changed on the last puppet run') do |type|
#     options[:changed] = true;
#   end
#   opts.on( '--no-prefix','Remove resource type at the begining of the line') do |type|
#     options[:disable_prefix] = true;
#   end
#   opts.on('-f', '--files', 'List files managed by puppet') do 
#     options[:files] = true;
#   end
#   opts.on('-s', '--services', 'List services managed by puppet') do 
#     options[:services] = true;
#   end
#   opts.on('-p', '--packages', 'List packages managed by puppet') do 
#     options[:packages] = true;
#   end
#   opts.on('-h', '--help', 'Displays Help') do
#     puts opts
#     exit
#   end
# end

# parser.parse!

# if ARGV.empty? and options.empty?
#   puts parser
#   exit(-1)
# else
#   options[:path] = ARGV[0]
# end


# PUPPET_CONF='/etc/puppet/puppet.conf'
# puppetvar = ""
# puppetenv = ""

# # Lecture de la conf puppet 
# Puppet.initialize_settings


# if options[:list_all]
#   printRequiredInfos(options[:changed], options[:path], managed_files,changed_files, options[:disable_prefix] ? nil : "File",'File')
#   printRequiredInfos(options[:changed], options[:path], managed_services,changed_files,options[:disable_prefix] ? nil : "Service", 'Service')
#   printRequiredInfos(options[:changed], options[:path], managed_packages,changed_files,options[:disable_prefix] ? nil : "Package", 'Package')
# end


# if options[:files]
#   printRequiredInfos(options[:changed], options[:path], managed_files,changed_files,options[:disable_prefix] ? nil : "File",'File')
# end
# if options[:services]
#   printRequiredInfos(options[:changed], options[:path], managed_services,changed_files,options[:disable_prefix] ? nil : "Service",'Service')
# end
# if options[:packages]
#   printRequiredInfos(options[:changed], options[:path], managed_packages,changed_files,options[:disable_prefix] ? nil : "Package",'Package')
# end

