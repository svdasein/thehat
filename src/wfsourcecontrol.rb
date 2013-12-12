#################################################################################
# TheHat - an interactive workflow system
# Copyright (C) 2007,2008,2009,2010,2011,2012,2013  David Parker
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
	
	# Ini needs a section called [VersionControlSystem] with a type=SubclassName entry
	# Then for whatever subclass is specified, there needs to be [SubclassName] and appropriate entries after that.
	def VersionControlSystem.interface(workflow,inifile)
		begin
			vcsclass = inifile['VCS']['type']
			if vcsclass
				workflow.addMessage("Using a #{vcsclass} version control interface\n")
				return Kernel.const_get(vcsclass).new(workflow,inifile)
			else
				workflow.addMessage("No [VCS]type specified in config file - no version control system available\n")
				return nil
			end
		rescue
			workflow.addMessage("Error instantiating version control system interface: #{$!}\n")
			return nil
		end
	end

	# Instance methods
	def initialize(workflow,inifile)
		@workflow=workflow
		@ini = inifile
		@config = {}
	end

	def getConfig(valueNames=[])
		sectionName = self.class.to_s
		valueNames.each { |valueName|
			begin
				@config[valueName] = @ini[sectionName][valueName.to_s]
			rescue
				puts("Failed to get [#{sectionName}]->#{valueName} from config file: #{$!}")
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
	def initialize(workflow,iniFilename='')
		super
		getConfig([:root])
		@workflow.addMessage("Subversion interface configured with svn root = #{configValue(:root)}\n")
	end

	def checkout(path=nil,branch=nil)
		# SVN doesn't use the branch part
		if path
			@workflow.addMessage(%x(cd #{@workflow.datadir} && svn checkout #{configValue(:root)}/#{path}))
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
