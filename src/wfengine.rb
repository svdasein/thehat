############################################################################
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

# Stock modules
require 'date'
require 'parsedate'
require 'wfrenderers'
# Gem modules
require 'rubygems'
require 'inifile'
require 'fastercsv'

$Version = '0.01'
$CopyrightYears = '2007,2008'
$DumpHeaderForm="%-14s %-9s %-8s %-20s %-30s\n"
$DumpForm=      "%-14s %-9s %-8d %-20s %-30s\n"
$DumpHeader = ['OWNER','STATE','DUR(MIN)','NAME','DESCRIPTION']


class Workflow

	# Class variables

	# Class methods
	class << self
	end

	# Accessors
	attr_accessor :statesNames,:reverting,:midRevert
	attr_reader :name,:steps,:states,:baseurl,:webdir,:datadir,
			:notifsEnabled,:renderers,:basename

	# Instance methods

	def initialize(configFile='',workflow='')
		@messageText = String.new
		begin
			ini = IniFile.load(configFile)
			@datadir = ini['wfengine']['datadir']
			@webdir = ini['wfengine']['webdir']
			@baseurl = ini['wfengine']['baseurl']
			@svnroot = ini['wfengine']['svnroot']
			#@debugLevel = ini['wfengine']['debuglevel'].to_i
			@debugLevel = 1
			@renderers = Array.new
			renderers = ini['wfengine']['renderers'].split(',')
			renderers.each { |rendererClassname|
				self.addRenderer(eval(rendererClassname))
			}
		rescue
			puts "Error loading config file: #{$!}\n";
			return nil
		end
		stdout = IO.new(0,'w')

		stdout.puts("-------------------------------------------------------------------\n")
		stdout.puts("TheHat version #{$Version}, Copyright (C) #{$CopyrightYears} David Parker\n")
		stdout.puts("TheHat comes with ABSOLUTELY NO WARRANTY.  This is free software,\n")
		stdout.puts("and you are welcome to redistribute it under certain conditions.\n")
		stdout.puts("For details read the LICENSE file that came with the distribution.\n")
		stdout.puts("-------------------------------------------------------------------\n")
		self.addMessage("* Good greetings from TheHat.  OBEY! :)\n\n") # For KJA
		if not FileTest.directory?(@datadir)
			begin
				Dir.mkdir(@datadir)
				self.addMessage("Created data directory #{@datadir}\n")
			rescue
				self.addMessage("Unable to make #{@datadir} - I have no place to load or save workflows! - #{$!}\n")
			end
		end
		@idlePromptMinutes = 5
		@states = {
			'reverted'=>-2,
			'reverting'=>-1,
			'failed'=>-3,
			'pnd rvrt'=>0,
			'done'=>0,
			'in prog'=>1,
			'pending'=>2
		}
		@statesNames = {
			-2=>'reverted',
			-1=>'reverting',
			-3=>'failed',
			0=>'finished',
			1=>'in prog',
			2=>'pending'
		}
		if workflow
			self.addMessage("NOTE: Auto-loading workflow #{workflow}\n")
			self.loadFromIni(workflow)
		else
			self.reset
			self.whatsGoingOn('RESET')
		end
	end

	def clearMessages()
		@messageText = String.new
	end

	def messages()
		return @messageText
	end

	def addMessage(aString = '',noiseLevel = 1)
		if noiseLevel <= @debugLevel 
			@messageText += aString
		end
		return true
	end

	def reset
		@name = nil
		@basename = nil
		@steps = Hash.new
		@reverting = false
		@midRevert = false
		@batching = false
		@hadCheckpoint = false
		@lastActivity = Time.now.localtime
		@clockEnabled = false
		@notifsEnabled = false
		self.addMessage("All steps, states, and modes cleared.\n")
	end

	def systemStatusSummary
		self.addMessage("Workflow status dump:\n")
		self.instance_variables.each {
			|name|
				self.addMessage("#{name} = '#{self.instance_eval("#{name}")}'\n")
		}
	end

	def stepNamed(name)
		return @steps[name]
	end

	def checkout(path)
		if path
			return self.addMessage(%x(cd #{@datadir};svn checkout #{@svnroot}/#{path}))
		else
			return self.addMessage("A path is required for this command\n")
		end
	end

	def commit(params)
		if params
			path,comment = params.split(' ')
			return self.addMessage(%x(cd #{@datadir}/#{path};svn commit -m "#{comment}"))
		else
			return self.addMessage("Both a path and a comment are required for this command\n")
		end
	end

	def loadFromIni(name)
		self.reset
		if name =~ /(.*\/)(.*)/
			@basename = $2
		else
			@basename = name
		end
		@name = name
		filename = "#{@datadir}/#{name}.flow"
		begin
			ini = IniFile.load(filename)
		rescue
			return self.addMessage("Error loading #{@name} - #{$!}\n")
		end
		ini.each_section{
			|sectionName|			
			@steps[sectionName] = Step.new(self,sectionName,ini[sectionName])
		}
		self.checkpoint
		self.whatsGoingOn("Loaded workflow '#{name}', read #{@steps.size} steps")
	end

	def saveToIni
		filename = "#{@datadir}/#{@name}.flow"
		ini = IniFile.new(filename)
		newIni = Hash.new
		@steps.each {
			|stepName,step|
			newIni[stepName] = step.configValues
		}
		# Honestly - I probably just dont know the language
		# well enough, but the class docs suggest all over the
		# place that inis are easily modifyable - I saw zero
		# examples of that and this is all I can think of.
		ini.instance_variable_set('@ini',newIni)
		begin
			ini.write(filename)
			return self.addMessage("Saved workflow '#{@name}' to #{filename}\n")
		rescue
			return self.addMessage("Error writing workflow '#{@name}' to #{filename} - #{$!}\n")
		end
	end

	def reload
		return self.loadFromIni(@name)
	end

	def saveState
		baseStateDir = "#{@datadir}/state"
		pathParts = @name.split('/')
		pathParts.pop
		pathParts.unshift(baseStateDir)
		aggregatePath = ''
		pathParts.each { |part|
			aggregatePath += "#{part}/"
			if not FileTest.directory?(aggregatePath)
				begin
					Dir.mkdir(aggregatePath)
				rescue
					return self.addMessage("Unable to make #{aggregatePath} - can't save state! - #{$!}\n")
				end
			end
		}
		begin
			stateFile =  File.new("#{aggregatePath}/#{@basename}.state",  "w")
			# I had trouble doing this w/ sending the io instance in
			# and having marshal handle it. Not sure why. This here appears
			# to work though.
			dump = Marshal.dump(self)
			stateFile.puts(dump)
			stateFile.close
			return self.addMessage("Saved state of flow #{@name}\n",2)
		rescue
			return "ERROR saving state of workflow #{@name} - state *not* saved!: #{$!}\n"
		end
	end

	def restoreState(flowName=nil)
		if not flowName
			return self.addMessage("Flow name not specified - restoring nothing\n")
		end
		begin
			stateDir = "#{@datadir}/state"
			stateFile =  File.new("#{stateDir}/#{flowName}.state","r")
			spectre = Marshal.load(stateFile)
		rescue
			return self.addMessage("Error restoring state for flow '#{flowName}' - #{$!}\n#{spectre.inspect}\n")
		end
		@states = spectre.instance_eval('@states')
		@statesNames = spectre.instance_eval('@statesNames')
		@name = spectre.instance_eval('@name')
		@basename = spectre.instance_eval('@basename')
		@steps = spectre.instance_eval('@steps')
		@reverting = spectre.instance_eval('@reverting')
		@midRevert = spectre.instance_eval('@midRevert')
		@batching = spectre.instance_eval('@batching')
		@lastActivity = spectre.instance_eval('@lastActivity')
		@notifsEnabled = false
		@clocksEnabled = false
		self.checkpoint
		return self.addMessage("Restored flow '#{@name}'.\n")
	end

	def newFlow(name)
		self.reset
		@name = name
		self.checkpoint
		self.whatsGoingOn("Created workflow '#{name}'")
	end

	def seemsQuiet
		if @idlePromptMinutes > 0
			return (Time.now.localtime - @lastActivity) >= (@idlePromptMinutes * 60)
		else
			return false # zero = shut up
		end
	end

	def whatsGoingOn(message)
		@lastActivity = Time.now.localtime;
		if (@name)
			ungated = Array.new;
			@steps.each {
				|name,instance|
				if (not instance.isGated)  and instance.needsProgress
					ungated.push(instance)
				end
			}
			self.addMessage("TheHat #{Time.now.localtime}: #{message}\n")
			self.addMessage("Flow overviews + help at #{@baseurl}\n")
			if ungated.size > 0
				self.addMessage(sprintf($DumpHeaderForm,*$DumpHeader))
				ungated.each {
					|instance|
					if instance.isClock
						owner = "CLOCK(#{instance.clockType})"
					else
						owner = instance.owner
					end
					self.addMessage(sprintf($DumpForm,(owner or 'UNASSIGNED'),@statesNames[instance.state],instance.duration,instance.name,instance.description))
				}
			else
				self.addMessage("All steps completed!\n")
			end
		else
				self.addMessage("No flow loaded or defined\n")
		end
		@hadCheckpoint = false
	end


	def clearGate(gatename)
		ungated = Array.new
		@steps.each {
			|name,instance|
			instance.clearGate(gatename)
			ungated.push(instance) if ( (not instance.isGated) and instance.needsProgress )
		}
		if (ungated.size == 0) and (not @midRevert)
			self.addMessage("** Flow ended **")
		end
	end



	def reverseGatesExistFor(gatename)
		@steps.each {
			|name,instance|
			if instance.reverseGatesOn(gatename)
				return true
			end
		}
		return false
	end


	def notificationProcessing(state=nil)
		if state
			state.downcase!
			@notifsEnabled = case state
				when 'on' then true
				when 'true' then true
				when 'off' then false
				when 'false' then false
			end
			if @notifsEnabled
				return self.addMessage("Notification processing enabled\n")
			else
				return self.addMessage("Notification processing disabled\n")
			end
		else
			self.addMessage("Notification processing is currently #{@notifsEnabled.to_s}\n")
			self.addMessage("To change, mode must be one of true,on,false, or off'\n")
		end
	end
	
	def clockProcessing(state=nil)
		if state
			state.downcase!
			@clockEnabled = case state
				when 'on' then true
				when 'true' then true
				when 'off' then false
				when 'false' then false
			end
			if @clockEnabled
				return self.addMessage("Clock processing enabled\n")
			else
				return self.addMessage("Clock processing disabled\n")
			end
		else
			self.addMessage("Clock processing is currently #{@clockEnabled.to_s}\n")
			self.addMessage("To change, mode must be one of true,on,false, or off'\n")
		end
	end
	
	def giveGroupTo(groupString,newOwner)
		groups = groupString.split(/,|\s/)
		self.addMessage("Giving step group(s) #{groupString} to #{newOwner}...\n")
		groups.each {
			|group|
			@steps.each {
				|name,step|
				if step.group.size > 0
					if group =~ /#{step.group}/
						step.setOwner(newOwner)
					end
				end
			}
		}
		self.checkpoint
	end	


	def addNewSteps(listOfNames='')
		listOfNames.split(/,|\s/).each {
			|groupName|
			groupName.strip!
			@steps[groupName] = Step.new(self,groupName)
			self.addMessage("Added new step '#{groupName}' to workflow.\n")
		}
		self.checkpoint
	end
	
	def deleteSteps(listOfNames='')
		listOfNames.split(/,|\s/).each {
			|groupName|
			groupName.strip!
			if @steps[groupName]
				@steps.delete(groupName)
				self.addMessage("Deleted step '#{groupName}'\n")
			else
				self.addMessage("Step '#{groupName}' not found - nothing deleted\n")
			end
		}
		self.checkpoint
	end
	
	def setStepProperty(nameList,propertyName,value='')
		names = nameList.split(',')
		names.each {
			|name|
			if @steps[name]
				step = @steps[name]
				if step.instance_variables.include?("@#{propertyName}") or (propertyName =~ /addgate|delgate|addgroup|delgroup|gate|groups/)
					case propertyName
					when 'gates','gate'
						# set to exactly the given list
						step.instance_variable_set('@gates',Array.new)
						self.addMessage("Cleared existing gates from step '#{step.name}'\n")
						value.split(',').each {
							|gate|
							step.addGate(gate.strip)
						}
					when 'addgate'
						# add to the existing list
						value.split(',').each {
							|gate|
							step.addGate(gate.strip)
						}
					when 'delgate'
						# remove from the existing list
						value.split(',').each {
							|gate|
							step.delGate(gate.strip)
						}
					when 'group','groups'
						# set to exactly the given list
						step.instance_variable_set('@group',Array.new)
						self.addMessage("Cleared existing group membership from step '#{step.name}'\n")
						value.split(',').each {
							|group|
								step.addGroup(group.strip)
						}
					when 'addgroup'
						# add to the existing list
						value.split(',').each {
							|group|
								step.addGroup(group.strip)
						}
					when 'delgroup'
						# remove from the existing list
						value.split(',').each {
							|group|
								step.delGroup(group.strip)
						}
					else
						if value == ''
							value = nil
						end
						step.instance_variable_set("@#{propertyName}",value)
						self.addMessage("'#{propertyName}' set to '#{value}' for step '#{name}'\n")
					end
					self.checkpoint
				else
					self.addMessage("'#{propertyName}' is not a valid property for step '#{name}' - doing nothing\n")
				end
			else
				return self.addMessage("Nothing changed for unknown step '#{name}'\n")
			end
		}
	end


	def dryRun(params)
		failname = params
		@batching = true
		self.addMessage("DRY RUN RESULTS\n")
		if failname
			self.addMessage("(NOTE: Planned failure at step #{failname})\n")
		end
		self.whatsGoingOn("Dry run initial state");
		done = false
		iterations = 0
		while not done
			ungated = Array.new
			iterations = iterations + 1
			@steps.each {
				|name,instance|
				if ( not instance.isGated )  and  instance.needsProgress
					ungated.push(instance)
				end
			}
			if ungated.size > 0
				ungated.each {
					|instance|
					instance.owner = 'dryrun'
					if instance.name == failname
						instance.fail('dryrun')
					else
						if @reverting
							instance.reverted('dryrun')
						else
							instance.finish('dryrun')
						end
					end
				}
				self.whatsGoingOn("Dry run iteration #{iterations}")
			else
				done = true
			end
		end
		@batching = false
		self.checkpoint
	end


	def checkpoint
		#DAP print caller(0)
		if not @batching
			self.updateRenderings
			if @name
				self.saveState
			end
		end
		@hadCheckpoint = true
	end

	def addRenderer(aRendererClass,options={})
		@renderers.push(aRendererClass.new(self,options))
	end

	def updateRenderings
		@renderers.each {
			|renderer|
			renderer.render
		}
		depictions = "<center><h3>Depictions of workflow '#{@name}'</h3></center>"
		depictions += '<tr BGCOLOR="#E0E0E0"></tr><td>Renderer</td><td>Item</td></tr>'
		@renderers.each {
			|renderer|
			if not renderer.webFiles.empty?
				renderer.webFiles.each {
					|description,filename|
					depictions += "<tr><td>#{renderer.class.to_s}</td><td><a HREF=\"#{filename}\">#{description}</a></td>"
					#depictions += "<td><a href=\"#{@baseurl}/flow.cgi?url=#{filename}\">(auto-refresh)</a></td>"
					depictions += "</tr>"
				}
			end
		}
		depictions = "<center><table BORDER=1>#{depictions}</table></center>"
		depictions += '<center>Visit <a href="TheHat.html">this page</a> for TheHat documentation.</center>'

		file = File.new("#{@webdir}/index.html",  "w")
		file.puts("<html><head><title>Workflow: '#{@name}'</title></head><body>#{depictions}</body></html>")
		file.close

		return 
	end


	def ticToc(forced=false)
		thingsChanged = false
		done = true
		done = false if @clockEnabled or forced
		if forced
			self.addMessage("(---tictoc---)\n")
		end
		ungated = Array.new
		@batching = true # If we don't do this, we re-render a *lot* during the checkpoints - see end of loop
		while not done
			done = true
			@steps.each {
				|name,step|
				if (not step.isGated)  and step.needsProgress
					ungated.push(step)
				end
			}
			if ungated.size > 0
				ungated.each {
					|step|
					if step.isClock
						if Time.now.localtime >= step.clockTime
							# Just FYI: clock steps don't participate in revert logic. If
							# for some insane reason you wanna actually use the revert logic,
							# a human will need to claim clock steps and do 'em.
							if step.state == @states['pending']
								step.start(step.owner)
								thingsChanged = true
							end
							if step.state == @states['in prog']
								if step.clockType == 'wait'
									# If any of those whom I gate are clock steps, only
									# finish when the earliest of those clocks expires
									otherClocks = Array.new
									@steps.each {
										|name,otherStep|
										if otherStep.gatesOn(step.name)
											if otherStep.isClock and otherStep.clockType != 'stopwatch'
												if Time.now.localtime >= otherStep.clockTime
													step.finish(step.owner)
													thingsChanged = true
													done = false
												end
											end
										end
									}
								elsif step.clockType == 'event'
									if Time.now.localtime >= (step.clockTime + step.eventClockMinutes)
										step.finish(step.owner)
										thingsChanged = true
									end
								elsif step.clockType == 'stopwatch'
									# Stop watch time is treated differently - the 
									# time specified is translated to mean "number of 
									# seconds (derived from the @h:m:s part) from step
									# start 'til the event finishes.
									if step.owner =~ /^clock-(.*):(.*)@(.*):(.*):(.*)/
										secondsToRun = ($3 * 3600) + ($4 * 60) + $5
										if (Time.now.localtime - step.startTime) >= secondsToRun
											step.finish(step.owner)
											thingsChanged = true
											done = false
										end
									end
								elsif step.clockType == 'handoff'
									step.owner = nil
									self.addMessage("Handoff step '#{step.name}' owner cleared\n")
									thingsChanged = true
								else
									# alarm
									step.finish(step.owner)
									thingsChanged = true
								end
								
							end
						end
					end
					# Note that it's possible to intermix clock: owned steps 
					# and regularly owned steps, and further, that's it's possible
					# via gimme and giveto to both take tasks *from* the clock and
					# to give tasks *to* the clock. :)
				}
				if thingsChanged
					self.checkpoint
					self.whatsGoingOn('CLOCK ADVANCE')
				end
			end
		end
		@batching = false
		if thingsChanged
			self.checkpoint # with batching off, rerenders will happen
			# Point being with rendering off while a ton of clock processing happens, 
			# the clock processing can happen fairly quickly -  few secs at most - 
			# then the renders get done once.  So - for a few secs the renderings
			# are out of date, but overall execution of tictoc goes *way* down.
		elsif self.seemsQuiet
			self.whatsGoingOn("IDLE")
		end
	end

	def processCommand(user,aString='')
		command, params = aString.split(' ',2)
		case command
			# Data dir management
			when 'checkout' then checkout(params)
			when 'commit' then commit(params)
			when 'ls' then self.addMessage(%x(cd #{@datadir};find -type f -not -path '*/state*' -and -not -path '*.svn*' -printf '%-55p %6s %15a\n').gsub("./",'').gsub(".flow",'').sort.to_s)
			# Workflow memory
			when 'new'
				if params
					self.newFlow(params)
					self.addMessage('IMPORTANT: *save* your workflow before running it, else your work will be lost!')
				else
					self.addMessage('new <flowname>')
				end
			when 'load'
				if params
					self.loadFromIni(params)
				else
					self.addMessage('load <flowname>')
				end
			when 'unload' then self.reset
			when 'save' then self.saveToIni
			when 'reload' then self.reload
			when 'restore' then
				if params
					self.restoreState(params)
				else
					self.addMessage('restore <flowname>')
				end
			when 'status' then self.whatsGoingOn('status request')
			# Workflow editing
			when 'addstep'
				if params
					self.addNewSteps(params)
				else 
					self.addMessage('addstep <name1>[,<name2>...]')
				end
			when 'addsequence'
				if params
					theSequence,attachPoints = params.split(' ',2)
					lastName = nil
					theSequence = theSequence.split(',')
					theSequence.each {
						|stepName|
						stepName.strip!
						self.addNewSteps(stepName)
						if lastName
							@steps[stepName].addGate(lastName)
							self.addMessage("Set #{stepName} to gate on #{lastName}\n")
						end
						lastName = stepName
					}
					if attachPoints
						attachPoints.split(',').each {
							|parent|
							@steps[theSequence[0]].addGate(parent)
							self.addMessage("Attached sequence head to gate #{parent}\n")
						}
					end
					if lastName
						self.checkpoint
					end
				else
					self.addMessage('addsequence <name1>[,<name2>...] [<attachPoints>]')
				end
			when 'delstep'
				if params
					self.deleteSteps(params)
				else
					self.addMessage('delstep <name1>[,<name2>...]')
				end
			when 'set'
				steps,propertyName,value = params.split(' ',3) if params
				if steps and propertyName
					self.setStepProperty(steps,propertyName,value)
				else
					self.addMessage('set <stepName1>[,<stepName2>...] <propertyName> [<value>]')
				end
			# Step ownership
			when 'gimme' # <stepname1>[,<stepname2>...]
				if params
					params.split(/,|\s/).each {
						|stepName|
						if step = self.stepNamed(stepName)
							step.setOwner(user)
						else
							self.addMessage("No step named #{stepName} found, not given\n")
						end
					}
					self.checkpoint
				else
					self.addMessage('gimme <stepname1>[,<stepname2>...]')
				end
			when 'giveto'
				if params
					targetUser,steps = params.split(' ',2)
					if targetUser and steps
						steps.split(/,|\s/).each {
							|stepName|
							self.stepNamed(stepName).setOwner(targetUser)
						}
						self.checkpoint
					else
						self.addMessage('giveto <username> <stepname1>[,<stepname2>...]')
					end
				else
					self.addMessage('giveto <username> <stepname1>[,<stepname2>...]')
				end
			when 'givegroupto' # <stepname1>[,<stepname2>...] <targetUser>
				if params
					groupList,targetUser = params.split(' ',2)
					if groupList and targetUser
						self.giveGroupTo(groupList,targetUser)
					else
						self.addMessage('givegroupto <group1>[,<group2>...] targetUser')
					end
				else
					self.addMessage('givegroupto <group1>[,<group2>...] targetUser')
				end
			when 'gimmegroup'
				if params
					self.giveGroupTo(params,user)
				else
					self.addMessage('gimmegroup <stepname1>[,<stepname2>...]')
				end
			when 'gimmeall'
				@steps.each {
					|name,step|
					step.setOwner(user)
				}
				self.checkpoint
			# Step state
			when 'start'  # <stepname1>[,<stepname2>...]
				if params
					params.split.each {
						|stepName|
						if step = self.stepNamed(stepName)
							step.start(user)
							self.checkpoint
						else
							self.addMessage("No step by the name of '#{stepName}' found - state unchanged\n")
						end
					}
				else
					self.addMessage("start <stepname>[,<stepname]...\n")
				end
			when 'finish' # <stepname1>[,<stepname2>...]
				if params
					params.split.each {
						|stepName|
						if step = self.stepNamed(stepName)
							step.finish(user)
							self.checkpoint
						else
							self.addMessage("No step by the name of '#{stepName}' found - state unchanged\n")
						end
					}
				else
					self.addMessage("finish <stepname>[,<stepname>]...\n")
				end
			when 'fail' # <stepname>
				if step = self.stepNamed(params)
					step.fail(user)
					self.checkpoint
				else
					self.addMessage("No step by the name of '#{params}' found - state unchanged\n")
				end
			when 'reverting'  # <stepname1>[,<stepname2>...]
				if params
					params.split.each {
						|stepName|
						if step = self.stepNamed(stepName)
							step.reverting(user)
							self.checkpoint
						else
							self.addMessage("No step by the name of '#{stepName}' found - state unchanged\n")
						end
					}
				end
			when 'reverted' # <stepname1>[,<stepname2>...]
				if params
					params.split.each {
						|stepName|
						if step = self.stepNamed(stepName)
							step.reverted(user)
							self.checkpoint
						else
							self.addMessage("No step by the name of '#{stepName}' found - state unchanged\n")
						end
					}
				end
			# Workflow operation
			when 'run'
				self.notificationProcessing('on') and self.clockProcessing('on')
			when 'stop'
				self.notificationProcessing('off') and self.clockProcessing('off')
			when 'sysstat' then self.systemStatusSummary
			when 'notificationProcessing' then self.notificationProcessing(params) #<true|false>
			when 'clockProcessing' then self.clockProcessing(params) #<true|false>
			# Utility
			when 'tictoc' then self.ticToc(true)
			when 'list'
				lines = Array.new
				@steps.each {
					|name,step|
					lines.push("#{name}\t#{step.group}\t#{step.owner}\t#{step.description}")
				}
				self.addMessage(lines.sort.join("\n"))
			when 'idleprompt'
				if params
					@idlePromptMinutes = params.to_i
				end
				if @idlePromptMinutes > 0
					self.addMessage("Idle prompting is set to #{@idlePromptMinutes} minute(s).\n")
					self.addMessage("To change it say idleprompt <minutes>. To turn off idle prompting, set minutes to 0\n")
				else
					self.addMessage("Idle prompting is *disabled* - I will only speak when a state change occurs.\n")
					if params
						self.addMessage("** Please note: without idle prompting, you (and your team) *might* only be notified *once* when a step changes state.\nTo change idle prompting, say idleprompt <minutes>\n")
					end
				end

			when 'date','time' then self.addMessage("Workflow engine time is: "+Time.now.localtime.to_s.chomp)
			when 'exec' then self.addMessage('Construction zone') #<command>
			when 'dryrun' then self.dryRun(params) #[<batching>] [<failstep>]
			when 'dump' then self.addMessage(WorkflowRenderer.new(self).render)
			when 'debug' then self.addMessage('Construction zone')
			when 'help'
				self.addMessage(File.new("help.txt",'r').read)
				self.addMessage("Complete documentation is available at #{@baseurl}/TheHat.html")
			when 'hello','hi','howdee','ping' then self.addMessage("Hello #{user}!  I am a workflow engine. Please ask me for help if you have any questions.\nI accept commands of the form <command> [<param1>[...<paramN>]]")
			else
				if command
						self.addMessage("! Unknown command #{command}\n")
					else
						self.whatsGoingOn('status')

				end
		end
		if self.seemsQuiet or @hadCheckpoint
			whatsGoingOn("(status)")
		end
	end
end




class Step

	class << self
	end


	# Instance methods


	# Accessors
	attr_accessor :owner
	attr_reader :name,:state,:description,:gates,:reverseGates,
		:startTime,:startCommand,:notifyAtStart,
		:finishTime,:finishCommand,:notifyAtFinish,
		:group,:url,:note

	def initialize(workflow,newName,values = {})
		@workflow = workflow
		@name = newName
		values.each {
			|key,value|
			if value.size > 0
				self.instance_variable_set("@#{key}",value)
			end
		}

		%w(@name @owner @description
		@startTime @startCommand
		@finishTime @finishCommand
		@url @note).each {
			|variable|
			if not self.instance_variables.include?(variable)
				self.instance_variable_set(variable,nil)
			end
		}
		@notifyAtStart = @notifyAtStart.split(',') if @notifyAtStart
		@notifyAtFinish = @notifyAtFinish.split(',') if @notifyAtFinish
		@group = @group.split(',') if @group
		@gates = @gates.split(',') if @gates
		%w(@notifyAtStart @notifyAtFinish @group @gates).each {
			|variable|
			if not self.instance_variables.include?(variable)
				self.instance_variable_set(variable,Array.new)
			end
		}
		@reverseGates = Array.new
		@state = @workflow.states['pending']
	end

	def configValues
		result = Hash.new
		result['description'] = @description
		result['owner'] = @owner
		result['startCommand'] = @startCommand
		result['notifyAtStart'] = @notifyAtStart.join(',')
		result['finishCommand'] = @finishCommand
		result['notifyAtFinish'] = @notifyAtFinish.join(',')
		result['url'] = @url
		result['note'] = @note
		result['group'] = @group.join(',')
		result['gates'] = @gates.join(',')
		return result
	end

	def <=>(otherStep)
		return (@name <=> otherStep.name)
	end

	def inspect
		result = "Name: #{@name}\n"
		result += "Description: #{@description}\n" if @description
		if @owner 
			if self.isClock
				result += "Owner: Clock\n"
				result += "\tType: #{self.clockType}\n"
				result += "\tActivation: #{self.clockTime}\n"
			else
				result += "Owner: #{@owner}\n" if @owner
			end
		end
		result += "Start cmd: #{@startCommand}\n" if @startCommand
		result += "Finish cmd: #{@finishCommand}\n" if @finishCommand
		result += "Notif(start): #{(@notifyAtStart or []).join(', ')}\n" if @notifyAtStart.size > 0
		result += "Notif(fin): #{(@notifyAtFinish or []).join(', ')}\n" if @notifyAtFinish.size > 0
		result += "Started at: #{@startTime}\n" if @startTime
		result += "Finished at: #{@finishTime}\n" if @finishTime
		result += "Group(s): #{(@group or []).join(', ')}\n" if @group.size > 0
		result += "Url: #{@url}\n" if @url
		result += "Tooltip: #{@note}\n" if @note
		result += "Gates: #{(@gates or []).join(', ')}\n" if @gates.size > 0
		result += "State: #{@workflow.statesNames[@state]}\n"
		@workflow.addMessage(result)
	end

	def duration
		if @startTime
			if not @finishTime
				return (Time.now - @startTime)/60
			else
				return (@finishTime - @startTime)/60
			end
		else
			return 0
		end
	end

	def setOwner(owner)
		@owner = owner
		@workflow.addMessage("Owner of step #{@name} is now #{owner}\n")
	end

	def addGroup(group)
		@group.push(group)
		@workflow.addMessage("Added group '#{group}' to step #{@name}\n")
	end
	
	def delGroup(group)
		if @group.include?(group)
			@group.delete(group)
			@workflow.addMessage("Removed group '#{group}' from step #{@name}\n")
		else
			@workflow.addMessage("Couldn't delete group '#{group}' from step #{@name} - not found\n")
		end
	end

	def setState(state,signature)
		# k - need to change the whole message paradigm. It needs to be something in the workflow
		# that other stuff (like this) sets and whatsGoingOn consumes (and clears).  That will
		# permit the use of proper method return values which would otherwise be kinda kludgy 
		# if it's just "return an array where required"
		stateVal = @workflow.states[state]
		if self.isAssigned and (@owner == signature)
			if not self.isGated
				if @state > stateVal
					@state = stateVal
					if state == 'in prog'
						@startTime = Time.now
					elsif state == 'done'
						@finishTime = Time.now
						if not @startTime
							@startTime = @finishTime
						end
					end
					@workflow.addMessage(">>> #{signature} changed state of step #{@name} to #{state}\n")
					if not self.needsProgress
						@workflow.clearGate(@name)
					end
					@workflow.checkpoint
					return true
				else
					@workflow.addMessage("Sorry, you can't change state from #{@workflow.statesNames[@state]} to #{state}\n")
					return false
				end
			else
				@workflow.addMessage("Step #{@name} is gated!  If you've finished this step you've done a bad) thing!!\n")
				return false
			end
		else
			if not self.isAssigned
				@workflow.addMessage("Sorry, but #{signature} can't change state of unassigned step - gimme it first!\n")
				return false
			else
				@workflow.addMessage("Sorry, but #{signature} can't change state of step owned by #{@owner}\n")
				return false
			end
		end
	end

	def start(signature)
		if not @workflow.reverting
			if self.setState('in prog',signature)
				if @startCommand
					@workflow.addMessage("Executed startCommand for this step\n")
					@workkflow.addMessage(@workflow.executeShellCommand(@startCommand))
				end
				if @notifyAtStart
					to_list = @notifyAtStart.join(',')
					if @workflow.notifsEnabled and to_list.size > 0
						# note that the message being constructed is intended to be interpreted 
						# by bash's extended mode echo (echo -e) - newlines etc should *not* 
						# be allowed to expand in perl.
						@workflow.addMessage("Sending step #{@name} start notification to #{to_list}\n")
						topic = "[#{@workflow.name}]: #{@name} (#{@description}) has started"
						message = "The workflow step entitled '#{@description}' has begun."
						if @url
							message += "\n\nDocumentation for this step is available at #{@url}"
						end
						if @note
							message += "\n\nThis note is attached to the step: #{@note}"
						end
						if self.isClock
							message += "\n\n"
							message += case self.clockType
								when 'handoff' then "NOTE: This is a 'handoff' step as of this moment it is UNASSIGNED.  Someone *must* claim the step and mark it finished in the workflow engine it before the workflow can continue"
								when 'alarm' then  "NOTE: This is an 'alarm' step presumably it means you should do something now. The flow will continue as if you have, so you had better do it!"
								when 'stopwatch' then "NOTE: This is a 'stopwatch' step - it will execute until a specific amount of time has passed and then workflow will continue"
								when 'wait' then "NOTE: This step is scheduled to span a specified amount of time - it will expire at the moment it's earliest successor is scheduled to begin."
								when 'event' then "NOTE: This step is an event that is scheduled to last #{self.clockTypeParameters} minutes."
							end
						end
						message += "\n\nFor workflow status see #{@workflow.baseurl}"
						@workflow.executeShellCommand("echo -e '#{message}' | mail -s '#{topic}' #{to_list}")
					else
						if to_list.size > 0
							@workflow.addMessage("Notifications disabled - not sending to #{to_list}\n")
						end
					end
				end
				return
			end
		else
			@workflow.addMessage("Don't bother - #{@workflow.reverting} failed, so you need to check the flow and start reverting stuff")
			return false
		end
	end
	
	def finish(signature)
		if @workflow.reverting
			@workflow.addMessage("Damn! #{@workflow.reverting} failed, so you need to revert this step and follow the reversion flow\n")
		else
			if self.setState('done',signature)
				if @finishCommand
					@workflow.addMessage("Executed finishCommand for this step\n")
					@workflow.addMessage(@workflow.executeShellCommand(@finishCommand))
				end
				if @notifyAtFinish
					# note that the message being constructed is intended to be interpreted 
					# by bash's extended mode echo (echo -e) - newlines etc should *not* 
					# be allowed to expand in perl.
					to_list = @notifyAtFinish.join(',')
					if @workflow.notifsEnabled and (to_list.size > 0)
						@workflow.addMessage("Sending step #{@name} finish notification to #{to_list}\n")
						topic = "[#{@workflow.name}]: #{@name} (#{@description}) has finished"
						message = "The workflow step entitled '#{@description}' was finished by #{@owner}."
						message += '\n\nNOTE: This message was sent as the step *finished* it is just a notification and it is likely you need do nothing.'
						message += "\n\nFor workflow status see #{@workflow.baseurl}"
						@workflow.executeShellCommand("echo -e '#{message}' | mail -s '#{topic}' #{to_list}")
					else
						if to_list.size > 0
							@workflow.addMessage("Notifications disabled - not sending to #{to_list}\n")
						end
					end
				end
			end
		end
	end
	
	def reverting(signature)
		if @workflow.reverting
			return self.setState('reverting',signature)
		else
			@workflow.addMessage("Umm, why? We aren't reverting this flow. (gratiously refusing)")
		end
	end
	
	def reverted(signature)	
		if @workflow.reverting
			return self.setState('reverted',signature)
		else
			@workflow.addMessage("WAIT! WHAT?? We aren't reverting! What are you doing? (ungratiously refusing)")
		end
	end
	
	def isAssigned
		return @owner.size > 0 if @owner
	end



	
	def addGate(gate)
		@gates.push(gate)
		@workflow.addMessage("Added gate '#{gate}' to step #{@name}\n",5)
	end
	
	def delGate(gate)
		if @gates.include?(gate)
			@gates.delete(gate)
			@workflow.addMessage("Removed gate '#{gate}' from step #{@name}\n",5)
		else
			@workflow.addMessage("Couldn't delete gate '#{gate}' from step #{@name} - not found\n")
		end
	end

	def addReverseGate(gate)
		@reverseGates.push(gate)
		@workflow.addMessage("Added reverse gate '#{gate}' to step #{@name}\n",5)
	end


	def gatesOn(gateName)
		return @gates.include?(gateName)
	end

	def reverseGatesOn(gateName)
		return @reverseGates.include?(gateName)
	end

	def isGatedForward
		return @gates.size > 0
	end

	def isClock
		return @owner =~ /^clock-.*/ if @owner
	end

	def clockType
		if @owner =~ /^clock-(.*):(.*)@(.*)/
			type = $1
			if type =~ /(.*)-(.*)/
				type = $1
			end
			return type
		else
			return nil
		end
	end

	def clockTypeParameters
		if @owner =~ /^clock-(.*)-(.*):(.*)@(.*)/
			return $2
		else
			return nil
		end
	end

	def eventClockMinutes
		# getting perilously close to a clock class hierarchy
		return self.clockTypeParameters.to_i * 60
	end

	def nearestDate(aSense)
		times = Array.new
		case aSense
			when :before
				[@gates,@reverseGates].each {
					|gateList|
					gateList.each {
						|stepName|
						if step = @workflow.stepNamed(stepName)
							if step.isClock and (step.clockType != 'stopwatch')
								if time = step.clockTime  # RECURSIVE
									times.push(time)
								end
							end
						end
					}
				}
				timeObject = times.sort.pop
			when :after
				@workflow.steps.each {
					|name,step|
					if step.gatesOn(@name) and step.isClock and (step.clockType != 'stopwatch')
						if time = step.clockTime  # RECURSIVE
							times.push(time)
						end
					end
				}
				timeObject = times.sort.shift
			end
		if not timeObject # Make something up
			timeObject = case aSense
				when :before then Time.at(0).localtime # Long ago
				when :after then Time.now.localtime # Right now
			end
		end
		return timeObject
	end


	def clockTime
		if @owner =~ /^clock-(.*):(.*)@(.*)/
			mode,dateTime = $1,"#{$2} #{$3}"
			if mode == 'stopwatch'
				return Time.now.localtime; # Stopwatches always start "now".
			else
				begin
					timeObject = Time.local(*ParseDate.parsedate(dateTime)[0..4])
				rescue ArgumentError
					# Assume "immediately" was meant
					# Which is to say - assume the user
					# specified the start time as all zeros
					# and assume it means "as soon as
					# it's no longer gated". So:
					# to give this something like a
					# real date/time, one must crawl
					# back through the digraph 'til one
					# finds the first step or steps that
					# have an actual date/time and take
					# the latest of those to be the date
					# meant. This ignores e.g. handoff steps
					# etc that would delay the flow for an
					# indeterminate amount of time. Tricky.
					# But if icals are to render properly,
					# it must be done.
					timeObject = self.nearestDate(:before) # RECURSIVE TO THIS METHOD
				end
				return timeObject
				
			end
		else
			return nil
		end
	end

	###### NOTE: Running in a particular direction is entirely a function of the
	###### methods below.  DO NOT put the sense of direction elsewhere - it is
	###### a very confusing thing!!
	######
	###### Put another way - from the perspective of all the code (above),
	###### everything is marching towards not being gated and not needing 
	###### progress.  These routines determine what those two things mean
	###### based on whether or not we're reverting.
	
	def fail(signature)
		if @owner != signature
			return @workflow.addMessage("You don't own this step - #{@owner} does, and must be the one to do this\n")
		end
	
		@workflow.addMessage("!!!!! FLOW FAILURE !!!!!\n\n")
		@workflow.addMessage("!!! STEP #{@name} FAILED - BEGINNING REVERSION PROCESS !!!\n\n")
	
		# First, reverse the gears (alters the meaning of clearGate, needsProgress, and isGated)
		@workflow.reverting = @name;
		@workflow.statesNames[0] = 'pending reversion'; # Gets reset on a LoadFromDatabase
	
		# Then:
		#
		# Clear gates for anyone who gates on me NOW, as they
		# don't have to wait for me - I failed.
		#
		# Clear gates for anyone whos was IN THE PROCESS OF
		# BEING UNGATED BY FORWARD PROGRESS.
		# 
		# Clear gates for anyone who WAS pending start at the
		# time of failure.
		#
		# Also, notify anyone who's got a task in progress
		# that they're wasting their time and need to start
		# undoing stuff.
		#
		# This is hopelessly confusing, but it is correct ;)
	
		@workflow.midRevert = true
		@workflow.steps.each {
			|name,instance|
			if instance.gatesOn(@name)
				@workflow.clearGate(instance.name)
			end
			if instance.isGatedForward and @workflow.reverseGatesExistFor(instance.name)
				@workflow.clearGate(instance.name)
			end
			if ((not instance.isGatedForward) and (instance.state == 2 ))
				@workflow.clearGate(instance.name)
			end
			if instance.state ==  1
				@workflow.addMessage("#{instance.owner}: stop what you're doing with step #{instance.name} - we're reverting!!\n")
			end
		}
	
		# This will NOT affect any gates, as by definition (below)
		# we don't need progress on this step (it having failed and all)
		self.setState('failed',signature)
		@workflow.midRevert = false
	
		return
	end	
	
	def needsProgress
		if not @workflow.reverting
			return @state > 0;
		else
			return ( (@state > -2 ) and ( @state < 2));
		end
	end
	
	def needsKickoff
		if not @workflow.reverting
			return ( (@state == 2) and (not self.isGated) )
		else
			return ( ((@state == 0) or (@state == 1)) and (not self.isGated) )
		end
	end
	
	def isGated
		if not @workflow.reverting
			return self.isGatedForward
		else
			return @reverseGates.size > 0
		end
	end
	
	def clearGate(gatename)
		once=false
		if not @workflow.reverting
			if @gates.include?(gatename)
				if not once 
					@workflow.addMessage('Cleared gate: ',2)
					once=true
				end
				@workflow.addMessage(gatename,2)
				@workflow.addMessage("\n",2)
				@workflow.steps[gatename].addReverseGate(@name)
				@gates.delete(gatename)
			end
		else
			if @reverseGates.include?(gatename)
				if not once 
					@workflow.addMessage('Cleared reverse gate: ',2)
					once=true
				end
				@workflow.addMessage(gatename,2)
				@workflow.addMessage("\n",2)
				@workflow.steps[gatename].addGate(@name)
				@reverseGates.delete(gatename)
			end
		end
	end
end
