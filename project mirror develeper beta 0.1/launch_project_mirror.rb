#!/usr/bin/env ruby
# Main Project Mirror Dev Beta 1 launcher.

require_relative "launcher/project_mirror_launcher"

ProjectMirror::Launcher.new(ARGV).run
