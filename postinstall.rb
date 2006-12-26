#!/usr/bin/env ruby

require 'fileutils'
if ARGV.include?('--dry-run')
  include FileUtils::DryRun
else
  include FileUtils::Verbose
end

RAILSBENCH_BASE = File.expand_path(File.dirname(__FILE__)) unless defined?(RAILSBENCH_BASE)

chmod 0755, Dir["#{RAILSBENCH_BASE}/script/*"]
