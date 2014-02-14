###########################################################################
# This file is part of TheHat - an interactive workflow system
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
###########################################################################

# I tried using ruby-graphviz, but ended up extremely frustrated. There were 
# three problems:
# 1) the dot file that it generated contained a huge amount of specification that's
#    just plain not required by graphviz itself. Graphviz does a real nice job
#    of arranging stuff usually, so all those options dealing with exact placement
#    of objects in the image are just that - *options* - you don't need them, and:
# 2) I suspect it slows down execution
# 3) ruby-graphviz's function is such that it's impossible to do an image+cmap in
#    a single call to the executable, thus further hindering overall performance
# 
#
class SimpleGraphViz

	attr_reader :dotfilePath

	def initialize(name='',dotfilePath='')
		@name = name
		@dotfilePath = dotfilePath
		@nodes = {}
		@connections = []
	end

	def add_node(name='',props={})
		@nodes[name]=props
	end

	def add_edge(a='',b='')
		@connections.push([a,b])
	end

	def output(targets='')
		dotFile = File.new(@dotfilePath,'w')
		dotFile.puts("digraph #{@name} {\n")
		@nodes.each { |name,props|
			props.each { |key,value|
				dotFile.puts("\t#{name} [#{key}=\"#{value}\"];\n")
			}
		}
		@connections.each {|connection|
			dotFile.puts("\t#{connection[0]} -> #{connection[1]};\n")
		}
		dotFile.puts("}\n")
		dotFile.close
		cmd = "dot -Nshape=box #{targets}  #{@dotfilePath} 2>&1"
		#puts "****************** CMD: #{cmd}]n"
		f = IO.popen(cmd)
		puts f.readlines
		f.close
	end
end
