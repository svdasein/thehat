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


class VersionControlSystem
	# Class methods
	
	def VersionControlSystem.interface(workflow,config)
		begin
			vcsclass = config['wfengine']['vcs']['class']
			if vcsclass
				workflow.addMessage("Using the '#{vcsclass}' version control interface\n")
				vcsInstance = Kernel.const_get(vcsclass).new(workflow,config)
				#print "=================\n"
				#pp vcsInstance
				#print "=================\n"
				return vcsInstance
			else
				workflow.addMessage("No vcs class specified in configuration - no version control system available\n")
				return nil
			end
		rescue
			workflow.addMessage("Error instantiating version control system interface: #{$!}\n")
			return nil
		end
	end

	# Instance methods
	def initialize(workflow,config = {})
		@workflow = workflow
		@config = config
	end

	def configValue(valueName='')
		begin
			return @config['vcs'][valueName]
		rescue
			@workflow.addMessage("No value '#{valueName}' for vcs #{@config['vcs']['class']}")
			return nil
		end
	end


	def checkout(path='',branch='')
		reuturn false
	end
	def commit(path='',comment='')
		return false
	end
	def addFile(path='')
		return false
	end
end

class Cvs < VersionControlSystem
end

class Subversion < VersionControlSystem
	def initialize(workflow,config)
		super
		@workflow.addMessage("Subversion interface configured with svn root = #{config['wfengine']['vcs']['root']}\n")
	end

	def checkout(path=nil,branch=nil)
		# SVN doesn't use the branch part
		if path
			@workflow.addMessage(%x(cd #{@workflow.datadir} && svn checkout #{configValue('root')}/#{path}))
		else
			@workflow.addMessage("You must specify a path for me to check out\n")
		end
	end

	def commit(path=nil,comment=nil)
		if path
			if not comment
				comment = "Update from TheHat"
			end
			@workflow.addMessage(%x{echo "Committing #{path}";cd #{@workflow.datadir}/#{path} && svn add * && svn commit -m "#{comment}"})
		else
			@workflow.addMessage("You must specify a path for me to commit\n")
		end
	end
end

class Git < VersionControlSystem
end

class Mercurial < VersionControlSystem
end
