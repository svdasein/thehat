#################################################################################
 TheHat - an interactive workflow system
 Copyright (C) 2007-2014 by David Parker. All rights reserved

 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version 2
 of the License, or (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#################################################################################


TheHat is a library and a collection of frontends to that library that act as 
an interactive workflow engine. Its user interface is command line-ish.  In 
operation, a TheHat instance guides a "conversation" between workflow 
particpants and itself, prompting workflow activities in whatever 
communication medium(s) you happen to be using.  TheHat has a number of 
rendering modules that give various views of the progress of a given workflow.  
The output from these renderers is available from a web page that the engine 
generates automatically.

This distribution comes with three frontends:

thehat-tty: This is just you and the engine - no clocks, no network, no nuthin. 
It's useful for learning, authoring, debugging, etc.

thehat-irc: This logs onto an IRC server and joins a channel.  It includes 
automatic clock processing, etc and is an example of the way that group 
coordination can be done.

thehat-xmpp: This logs onto an xmpp (jabber server) and connects to a MUC (multi-
user chat).  It includes automatic clock processing.

Comprehensive documentation is at https://github.com/svdasein/thehat/wiki

