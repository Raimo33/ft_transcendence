#!/usr/bin/env ruby

if $PROGRAM_NAME == __FILE__
  DaemonControl.new(ARGV).run
end