#!/usr/bin/perl
################################################################################
# This file is part of TheHat - an interactive workflow system
# Copyrigt (C) 2007,2014  by Dave Parker. All rights reserved
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

# Show the flow diagram during releases with automatic refresh
# and dates.

use strict;
use Time::Local;
use Time::Zone;
use LWP::UserAgent;
use CGI;

my @MONTH = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
my @DAY   = qw(Sun Mon Tue Wed Thu Fri Sat);
my $MYURL = "http://$ENV{SERVER_NAME}$ENV{SCRIPT_NAME}?$ENV{QUERY_STRING}";

my $q       = CGI->new();
my $url     = $q->param('url');
my $cmap    = $q->param('cmap');
my $refresh = $q->param('refresh');  $refresh = 60 unless(defined($refresh));
my $now     = &timestamp(time);
my $lastmod = 'unknown';
my $fnsize  = '-1';

# Set the title from the URL for Parker's MtV Conf Room monitor
my $title;
$title = $url;
$title =~ s,^.*/,,g;
$title =~ s/\.(?:gif|jpg|png)//i;


# Find the last modification time of the image
my $ua = LWP::UserAgent->new();
my $req = HTTP::Request->new(HEAD => $url);

my $res = $ua->request($req);


if ($res->is_success()) {
  $lastmod = &timestamp(&gmt2unix($res->header('last-modified')));
}

my $refreshtag;
if ($refresh) {
  $refreshtag = "<META http-equiv=refresh content=$refresh>";
}


# Load the image with refresh
print "Content-type: text/html\n\n";

print qq{
<HTML>

  <HEAD>
    <TITLE>$title</TITLE>
    $refreshtag
  </HEAD>

  <BODY>
    <FORM NAME="MyForm" METHOD="GET" ACTION="$MYURL">
    <TABLE BGCOLOR="#F2F2F2" WIDTH=80%>
      <TR>
        <TD><FONT SIZE="$fnsize"><B>Fetched:</B></FONT></TD>
        <TD><FONT SIZE="$fnsize">$now</FONT></TD>

        <TD WIDTH=10%>&nbsp;</TD>

        <TD><FONT SIZE="$fnsize"><B>URL:</B></FONT></TD>
        <TD COLSPAN=2>
          <FONT SIZE="$fnsize">
            <INPUT NAME="url" TYPE="text" VALUE="$url" SIZE=50>
          </FONT>
        </TD>


      </TR>
      <TR>

        <TD><FONT SIZE="$fnsize"><B>Last update:</B></FONT></TD>
        <TD><FONT SIZE="$fnsize">$lastmod</FONT></TD>

        <TD>&nbsp;</TD>

        <TD><FONT SIZE="$fnsize"><B>Refresh:</B></FONT></TD>
        <TD>
            <FONT SIZE="$fnsize">
              <INPUT NAME="refresh" TYPE="text" VALUE="$refresh" SIZE=5>
        </TD>
        <TD>
              <INPUT TYPE="reset"> 
              &nbsp; &nbsp;
              <INPUT TYPE="submit" VALUE="Submit">
              &nbsp; &nbsp;
              <INPUT TYPE="button" VALUE="Clear" onClick="
                window.document.MyForm.url.value='';
                window.document.MyForm.refresh.value='';
              ">
              &nbsp; &nbsp;
              <INPUT TYPE="button" VALUE="Reload" onClick="
                window.location='$MYURL'
              ">
            </FONT>
        </TD>
      </TR>
      <TR>
      </TR>
    </TABLE>
    </FORM>
};

if ($cmap) {
	open(FILE,$cmap);
	print qq{<map name="$cmap">};
	print <FILE>;
	print qq{</map>};
	close(FILE);
    	print qq{<IMG SRC="$url" BORDER="0" ISMAP USEMAP="#$cmap">}
} else {
    print qq{<IMG SRC="$url" BORDER="0">}
}

print qq{
  </BODY>

</HTML>

};

##############################################################################
###############################  Subroutines  ################################
##############################################################################



###############
sub timestamp {
###############
  my $time = shift;
  #my($sec,$min,$hour,$mday,$mon,$year,$wday) = localtime($time);

  return join(" ", scalar(localtime($time)),  uc(tz_name()));
}


##############
sub gmt2unix {
##############
  my $gmt = shift;

  # Format:  Fri, 28 Feb 2003 00:16:54 GMT
  my($wday, $mday, $mon, $year, $hour, $min, $sec, $zone) = 
                                                      split(/[\s,:]+/, $gmt);

  $year -= 1900;
  $mon = (grep($MONTH[$_] eq $mon, 0..scalar(@MONTH)))[0];

  return timegm($sec, $min, $hour, $mday, $mon, $year);
}

