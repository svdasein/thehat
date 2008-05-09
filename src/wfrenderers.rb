###########################################################################
# This file is part of TheHat - an interactive workflow system
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
###########################################################################


###################################################################
###################################################################
# "Drivers" for various representations of the workflow...
###################################################################
###################################################################
require 'simple-graphviz'
require 'rubygems'
require 'icalendar'

class WorkflowRenderer
	attr_reader :webFiles

	def initialize(workflow,options={})
		@workflow = workflow
		@options = options
		@webFiles = {}
	end
	def render
		results = "Steps in #{@workflow.name}:\n\n"
		@workflow.steps.each {
			|name,step|
			results += "#{step.inspect}\n"
		}
		return results
	end

	def description
		return "#{self.class.to_s} of #{@workflow.name}"
	end
end

class WorkflowDumpFile < WorkflowRenderer
	def render
		dumpText = WorkflowRenderer.new(@workflow).render
		file = File.new("#{@workflow.webdir}/#{@workflow.name}-dump.txt",  "w")
		file.puts(dumpText)
		file.close
		@webFiles['Dump of workflow definition and status'] = "#{@workflow.name}-dump.txt"
	end
end


class WorkflowDigraph < WorkflowRenderer
	# Options:
	# :type = type to tell dot to generate (default=gif)

	def initialize(workflow,options={})
		options[:type] = self.type
		super(workflow,options)
	end

	def type
		return 'png'
	end

	def render
		@attentionColor = 'IndianRed'
		@allgoodColor = 'PaleGreen2'
		@actionColor = 'gold'
		@dormantColor = 'LightGrey'
		@statesColors = {
			-2=>@allgoodColor,
			-1=>@actionColor,
			-3=>@attentionColor,
			0=>@allgoodColor,
			1=>@actionColor,
			2=>@dormantColor
		}

		@graph = SimpleGraphViz.new(@workflow.basename.gsub(/\W/,'_'),"#{@workflow.webdir}/#{@workflow.basename}-digraph.dot")

		@workflow.steps.each {
			|name,step|
				nodeProperties = {
					:fontsize=>'9',
					:label=>self.labelForStep(step),
					:style=>'filled'
				}

				if step.url
					nodeProperties[:URL] = step.url
				end
				if step.note
					nodeProperties[:tooltip] = step.note
					if not step.url
						nodeProperties[:URL] = "about:blank"
					end
				elsif step.url
					nodeProperties[:tooltip] = "Click for details"
				end
				
				if step.owner
					nodeProperties[:color] = @allgoodColor
				else
					nodeProperties[:color] = @attentionColor
				end
				if step.needsKickoff
					nodeProperties[:fillcolor] = @attentionColor
				elsif @statesColors[step.state]
					nodeProperties[:fillcolor] = @statesColors[step.state]
				end
				@graph.add_node(name,nodeProperties)
		}
		@workflow.steps.each {
			|name,step|
				step.gates.each {
					|gatename|
					@graph.add_edge(gatename,name)
				}
				step.reverseGates.each {
					|gatename|
					@graph.add_edge(name,gatename)
				}
		}
		@webFiles["Directed graph rendered as a dot file"] = "#{@workflow.basename}-digraph.dot"
		if @options[:type] =~ /gif|png|jpg/
			reloaderUrl = "#{@workflow.baseurl}/flow.cgi"
			imageBasename = "#{@workflow.basename}-digraph.#{@options[:type]}"
			cmapBasename = "#{@workflow.basename}-digraph.cmap"
			@graph.output("-T#{@options[:type]} -o #{@workflow.webdir}/#{imageBasename} -Tcmap -o #{@workflow.webdir}/#{cmapBasename}")
			@webFiles["Directed graph rendered as a #{@options[:type]} file (auto-refresh)"] = "#{reloaderUrl}?url=#{imageBasename}&cmap=#{cmapBasename}"
			@webFiles["Directed graph rendered as a #{@options[:type]} file"] = "#{imageBasename}"
		else
			@webFiles["Directed graph rendered as a #{@options[:type]} file"] = "#{@workflow.basename}-digraph.#{@options[:type]}"
		end
	end


	def labelForStep(step)
		result = "Name: #{step.name}\n"
		result += "Description: #{step.description}\n" if step.description
		if step.owner 
			if step.isClock
				result += "Owner: Clock\n"
				result += "\tType: #{step.clockType}\n"
				if step.clockType == 'event'
					result += "\tDuration: #{step.eventClockMinutes}"
				end
				result += "\tActivation: #{step.clockTime}\n"
			else
				result += "Owner: #{step.owner}\n" if step.owner
			end
		end
		result += "Start cmd: #{step.startCommand}\n" if step.startCommand
		result += "Finish cmd: #{step.finishCommand}\n" if step.finishCommand
		result += "Notif(start): #{(step.notifyAtStart or []).join(', ')}\n" if step.notifyAtStart.size > 0
		result += "Notif(fin): #{(step.notifyAtFinish or []).join(', ')}\n" if step.notifyAtFinish.size > 0
		result += "Started at: #{step.startTime}\n" if step.startTime
		result += "Finished at: #{step.finishTime}\n" if step.finishTime
		result += "Group(s): #{(step.group or []).join(', ')}\n" if step.group.size > 0
		return result.gsub(/\n/,'\n')
	end

end

class WorkflowDigraphPostscript < WorkflowDigraph
	def type
		return 'ps'
	end
end


class Time
	# Extend the Time class with a to_datetime method so we can
	# make icals
	def to_datetime
	# Convert seconds + microseconds into a fractional number of seconds
	#seconds = sec + Rational(usec, 10**6)
	seconds = 0
	# Convert a UTC offset measured in minutes to one measured in a
	# fraction of a day.
	offset = Rational(utc_offset, 60 * 60 * 24)
	begin
		DateTime.new(year, month, day, hour, min, seconds, offset)
	rescue ArgumentError
			print "Argument error. Inputs were: #{year},#{month},#{day},#{hour},#{min},#{seconds},#{offset}\n"
			exit(1);
	end
	end
end


class WorkflowIcal < WorkflowRenderer
	include Icalendar
	def render
		cal = Calendar.new
		@workflow.steps.each {
			|name,step|
			if step.isClock
				event = cal.event do
					dtstart       step.clockTime.to_datetime
					summary       step.description
				end
				event.description = self.descriptionForStep(step)
				case step.clockType
				when 'wait'
					event.dtend = step.nearestDate(:after).to_datetime
				when 'event'
					event.dtend = (step.clockTime + (step.clockTypeParameters.to_i * 60)).to_datetime
				when 'alarm','handoff'
					event.dtend = (step.clockTime + 1800).to_datetime # Show a nominal 1/2 hr - has no basis in reality
					event.alarm
				end
			end
		}
		file = File.new("#{@workflow.webdir}/#{@workflow.basename}.ics",  "w")
		file.puts(cal.to_ical)
		file.close
		@webFiles['ical file - many apps can read this']="#{@workflow.basename}.ics"
	end

	def descriptionForStep(step)
		result = "Name: #{step.name} Description: #{step.description}\n"
		if step.owner 
			if step.isClock
				result += "Owner: Clock\n"
				result += "\tType: #{step.clockType}\n"
				if step.clockType == 'event'
					result += "\tDuration: #{step.clockTypeParameters.to_i * 60}"
				end
				result += "\tActivation: #{step.clockTime}\n"
			else
				result += "Owner: #{step.owner}\n" if step.owner
			end
		end
		result += "Start cmd: #{step.startCommand}\n" if step.startCommand
		result += "Finish cmd: #{step.finishCommand}\n" if step.finishCommand
		result += "Notif(start): #{(step.notifyAtStart or []).join(', ')}\n" if step.notifyAtStart.size > 0
		result += "Notif(fin): #{(step.notifyAtFinish or []).join(', ')}\n" if step.notifyAtFinish.size > 0
		result += "Started at: #{step.startTime}\n" if step.startTime
		result += "Finished at: #{step.finishTime}\n" if step.finishTime
		result += "Group(s): #{(step.group or []).join(', ')}\n" if step.group.size > 0
		return result
	end
end