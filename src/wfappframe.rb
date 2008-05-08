#################################################################################
# TheHat - an interactive workflow system
# Copyright (C) 2007,2008  David Parker
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
require 'wfengine'



class HatApp
	def initialize
		iniFilename = ARGV[0]
		workflow = ARGV[1]
		if not iniFilename
			puts "You must specify a configuration file - ending run\n"
			exit(1)
		end
		@stdout = IO.new(0,'w')
		# This is duplicated effort - maybe better to pass the object into the workflow
		# constructor...?  Though another perspective is "keep wf config separate from fe config"
		# dunno - it's a small thing.
		@ini = IniFile.load(iniFilename)
		@workflow = Workflow.new(iniFilename,workflow)
		@msgtypes = { :app => '**',:com=>'XX', :clock=>'@@', :cmd=>'==',:user=>'++',:error=>'!!' }
		@config = {}
		@mutex = Mutex.new # Not all need this, but it's cheap, and many do
	end

	def getConfig(sectionName='',valueNames=[])
		valueNames.each { |valueName|
			begin
				logmessage(:app,"value name as string is #{valueName.to_s}")
				@config[valueName] = @ini[sectionName][valueName.to_s]
			rescue
				logmessage(:error,"Failed to get [#{sectionName}]->#{valueName} from config file: #{$!}")
			end
		}
	end

	def configValue(valueName='')
		begin
			return @config[valueName]
		rescue
			return nil
		end
	end

	def drainMessages(context=:cmd,&aBlock)
		@workflow.messages.split(/\n/).each { |line|
			aBlock.call(line)
			logmessage(context,line)
			sleep(0.5)
		}
		@workflow.clearMessages
	end

	def logmessage(type=:app,message='')
		@stdout.puts "#{@msgtypes[type]} #{Time.now.localtime.to_s} #{message}\n"
	end

	def run
	end
end