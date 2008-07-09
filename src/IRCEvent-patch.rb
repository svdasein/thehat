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

# This is a "hot patch" for a bug in the Ruby-IRC gem.  I submitted a bug to 
# that project.  'Til they fix it this will have to do.

class IRCEvent
  def initialize (line)
    line.sub!(/^:/, '')
    mess_parts = line.split(':', 2);
    # mess_parts[0] is server info
    # mess_parts[1] is the message that was sent
    @message = mess_parts[1]
    @stats = mess_parts[0].scan(/[-`\^\{\}\/\[\]\w.=\#\@\+]+/)
    
    if @stats[0].match(/^PING/)
      @event_type = 'ping'
    elsif @stats[1] && @stats[1].match(/^\d+/)
      @event_type = EventLookup::find_by_number(@stats[1]);
      @channel = @stats[3]
    else
      @event_type = @stats[2].downcase if @stats[2]
    end
    
    if @event_type != 'ping'
      @from    = @stats[0] 
      @user    = IRCUser.create_user(@from)
    end
    # FIXME: this list would probably be more accurate to exclude commands than to include them
    @hostmask = @stats[1] if %W(topic privmsg join).include? @event_type
    @channel = @stats[3] if @stats[3] && !@channel
    @target  = @stats[5] if @stats[5]
    @mode    = @stats[4] if @stats[4]

    
    
    # Unfortunatly, not all messages are created equal. This is our
    # special exceptions section
    if @event_type == 'join'
      @channel = @message
    end
    
  end
end
