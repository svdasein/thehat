#################################################################################
# TheHat - an interactive workflow system
# Copyright (C) 2007-2014 by David Parker. All rights reserved
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#################################################################################
require 'thehat/wfengine'



class HatApp

	attr_accessor :drainPauseSeconds,:mutex,:workflow

	def initialize
		configFilename = ARGV[0]
		workflow = ARGV[1]
		if not configFilename
			puts "You must specify a configuration file - ending run\n"
			exit(1)
		end
		@stdout = IO.new(0,'w')
		@drainPauseSeconds = 0.5 # pause between sending lines from the engine - you may need to tweak it if you get kicked for flooding.
		@workflow = Workflow.new(configFilename,workflow)
		@msgtypes = { :app => '**',:com=>'XX', :clock=>'@@', :cmd=>'==',:user=>'++',:error=>'!!' }
		@config = {}
		@mutex = Mutex.new # Not all need this, but it's cheap, and many do
	end

	def getConfig(sectionName='',valueNames=[])
		# This method used to do much more before the yaml conversion - it's mostly just for diagnostic output now
		@config = @workflow.config[sectionName]
		valueNames.each { |valueName|
			begin
				logmessage(:app,"#{sectionName}->#{valueName.to_s} = #{@config[valueName.to_s]}")
			rescue
				logmessage(:error,"Failed to get [#{sectionName}]->#{valueName.to_s} from config file: #{$!}")
			end
		}
	end

	def configValue(valueName='')
		begin
			return @config[valueName.to_s]
		rescue
			return nil
		end
	end

	def drainMessages(context=:cmd,&aBlock)
		@workflow.messages.split(/\n/).each { |line|
			aBlock.call(line)
			logmessage(context,line)
			sleep(@drainPauseSeconds)
		}
		@workflow.clearMessages
	end

	def logmessage(type=:app,message='')
		@stdout.puts "#{@msgtypes[type]} #{Time.now.localtime.to_s} #{message}\n"
	end

	def run
		logmessage(:app,"If I were an actual application, I'm sure really cool things would be happening now. Sadly, I'm just an abstract base class - I'm quite dull in the 'cool things' department. If you're seeing this and you think something cool should be happening, you need to consider overriding the 'run' method you inherited from me.")
	end
end
