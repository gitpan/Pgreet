package Pgreet::Error;
#
# File: Error.pm
######################################################################
#
#                ** PENGUIN GREETINGS (pgreet) **
#
# A Perl CGI-based web card application for LINUX and probably any
# other UNIX system supporting standard Perl extensions.
#
#     Edouard Lagache, elagache@canebas.org, Copyright (C)  2003
#
# Penguin Greetings (pgreet) consists of a Perl CGI script that
# handles interactions with users wishing to create and/or
# retrieve cards and a system daemon that works behind the scenes
# to store the data and email the cards.
#
# ** This program has been released under GNU GENERAL PUBLIC
# ** LICENSE.  For information, see the COPYING file included
# ** with this code.
#
# For more information and for the latest updates go to the
# Penguin Greetings official web site at:
#
#     http://pgreet.sourceforge.net/
#
# and the SourceForge project page at:
#
#     http://sourceforge.net/projects/pgreet/
#
# ----------
#
#           Perl Module: Pgreet::Error
#
# This is the Penguin Greetings (pgreet) shared library for error
# handling.  It defines common conditions that are then handled
# differently by the CGI application and the system daemon.
######################################################################
# $Id: Error.pm,v 1.9 2003/07/29 21:33:47 elagache Exp $

$VERSION = "0.8.9"; # update after release

# Module exporter declarations
@ISA       = qw(Exporter);
@EXPORT    = qw();
@EXPORT_OK = qw();

# Perl modules.
use CGI qw(:standard escape);
use CGI::Carp;
use Log::Dispatch;                     # Syslog entries
use Log::Dispatch::Syslog;
use Log::Dispatch::File;               # pgreet own log.
use POSIX qw(strftime);

# Perl Pragmas
use strict;

########################### METHODS ###########################

sub new {
#
# Traditional empty contructor.  Any
# real work will be done by '_init'
#
  my $class = shift;
  my $Pg_config = shift;
  my $AppType = shift;
  my $syslog_obj = shift;
  my $pgreet_log_obj = shift;

  my $self = {};
  bless $self, $class;

  # Assign configuration object
  $self->{'Pg_config'} = $Pg_config;

  # Set up object to deal with various calling application types.
  if ($AppType =~ m/daemon/i) { # Daemon
	$self->{'AppType'} = 'daemon';
	$self->{'syslog_obj'} = $syslog_obj;
	$self->{'pgreet_log_obj'} = $pgreet_log_obj;
  }
  # CGI application.
  elsif ($AppType =~ m/CGIApp/i) {
	$self->{'AppType'} = 'CGIApp';
  }
  # Standard command line application (utility).
  elsif ($AppType =~ m/App/i) {
	$self->{'AppType'} = 'App';
  } else {
	die "Unknown application type trying to create Pgreet Error object";
  }

  return($self);
}



sub report {
#
# Main error reporting method.  If running as CGI report,
# output via warn and die.  Else report the errors via
# the Log::Dispatch object.  To simplify matters, only
# error or higher are reported to syslog.  All else are
# sent to pgreet.log only.
#
  my $self = shift;
  my $level = shift;
  my @messages = @_;

  if ($self->{'AppType'} eq 'CGIApp') {
	$self->report_cgi($level, @messages);
  }
  elsif ($self->{'AppType'} eq 'daemon') {
	$self->report_daemon($level, @messages);
  } else {
	$self->report_stderr($level, @messages);
  }
}

sub report_cgi {
#
# Main error reporting method for CGI application.  If
# this is a "serious" error, report via 'die', else
# report via 'warn.'  Of course actually croak/carp
# If first item is just a number, it is taken as an
# error number and sent out as a error_template
# request.
#
  my $self = shift;
  my $level = shift;
  my @messages = @_;
  my $error_no;

  if ($messages[0] =~ /^\d+$/) {
	$error_no = shift @messages;
	$self->error_template($error_no);
  }
  if (_is_error($level)) {
	croak join('', @messages);
  } else {
	carp join('', @messages);
  }
}


sub report_daemon {
#
# Main error reporting for the system daemon which
# reports the errors via the Log::Dispatch object.
# To simplify matters, only error or higher are
# reported to syslog.  All else are
# sent to pgreet.log only.
#
  my $self = shift;
  my $level = shift;
  my @messages = @_;

  my $syslog_obj = $self->{'syslog_obj'};
  my $pgreet_log_obj = $self->{'pgreet_log_obj'};

  # Just in case an error number is supplied when object is called from daemon
  if ($messages[0] =~ /^\d+$/) {
	shift @messages;
  }

  my $time = strftime("%b %d %T", localtime());
  $pgreet_log_obj->log(level => $level,
					   message => join('', $time, ' ', @messages, "\n")
					  );

  if (_is_error($level)) {
    $syslog_obj->log(level => $level,
					 message => join('', @messages)
					);
  }

}


sub report_stderr {
#
# Main error reporting method for utilities that use
# the same error handling system as the rest of Penguin
# Greetings.  These messages are just joined and displayed
# via either croak or carp.
#
  my $self = shift;
  my $level = shift;
  my @messages = @_;

  if (_is_error($level)) {
	croak join('', @messages);
  } else {
	carp join('', @messages);
  }
}



sub _is_error {
#
# Convenience internal subroutine to see if an
# alert level is worthy of the 'die' category.
#
  my $level = shift;

  return (($level eq 'error') or
		  ($level eq 'critical') or
		  ($level eq 'alert') or
		  ($level eq 'emergency')
		 );
}

sub error_template {
#
# Method to send an error message to the CGI server via
# Embperl.
#
  my $self = shift;
  my $error_no = shift;
  my $Pg_config = $self->{'Pg_config'};

  my $file = $Pg_config->access('default_error');
  my $templatedir = $Pg_config->access('templatedir');
  my $imageurl = $Pg_config->access('imageurl');
  my $tpl = $Pg_config->access('template_suffix');

  # Get Transfer hash
#  my $Transfer = ChangeVars();
  # XXXX once more temporary until CGIUtils can be finished.
  my $Transfer = { hostname => 'www.canebas.org',
				   templatedir => $templatedir,
				   error_no => $error_no,
				   imageurl => $imageurl,
				 };

  print "Content-type: text/html\n\n";
  Embperl::Execute ({inputfile  => "$templatedir/$file.$tpl",
					 param  => [$Transfer],
					}
				   );
} # End sub error_template



=head1 NAME

Pgreet::Error - Error handling object for Penguin Greetings.

=head1 SYNOPSIS

  # Constructor:
  $Pg_error = new Pgreet::Error($Pg_default_config, 'CGIApp');

  # Error reporting:
  $Pg_error->report('level',
                    "any number of diagnostic message",
                    "lines"
                   );

=head1 DESCRIPTION

The module C<Pgreet::Error> is the Penguin Greetings
content-independent error handling module.  This module uses the same
syntax whether being called from a "faceless" daemon, a CGI
application, or a command line utility.  More importantly, library
routines calling the error object passed as a parameter can correctly
output to the appropriate venue.  This module was necessary so that
Penguin Greetings could use common code between: F<pgreetd> the ecard
managing daemon, F<pgreet.pl.cgi> the CGI application, and utilities
like F<PgTemplateTest>.

The whole purpose of the module is to simplify the matter of handling
errors.  Once the object is constructed, calls to the error module are
styled after syslog entries.  Depending on the type, different
methods will actually be used to output the error message.  In the
case of a daemon error, the errors will be logged to the Penguin
Greeting log file and if the problem is serious enough the syslog
facility (usually F<messages> log file.)  If the error occurs while
running as a CGI application, the error will be handled using the Perl
modules L<CGI:Carp> and if severe enough, an error template will be
displayed, Otherwise, the error message is simply displayed to
Standard Output in a reasonable format.

=head1 CONSTRUCTING AN ERROR OBJECT

The C<Pgreet::Error> constructor expects two parameters.  The first is
a Penguin Greeting configuration object.  The second is descriptor of
the type of application is creating the object.  There are three
recognized types: C<daemon> (for a application daemon like
F<pgreetd>,) C<CGIApp> (for a CGI application, Speedy CGI application,
etc. like F<pgreet.pl.cgi>,) and C<App> (for a command line
application like F<PgTemplateTest>.)  For example, creating an error
object for a CGI application would be as follows:

  	$Pg_error = new Pgreet::Error($Pg_default_config, 'CGIApp');

From that point on, this error object can be used to report errors in
the application that created it and passed on to other modules so that
errors occurring in those modules will be handled consistently.

=head1 ERROR REPORTING SYNTAX

There is only one method that developers should ever use from this
module - it is the C<report> method.  The report method takes a error
level (from syslog) and any number of Perl expressions and outputs a
string in the appropriate venue.  If the error is severe enough,
C<report> will cause the program to halt in a manner appropriate to
the way the program is called.  If called from a CGI application,
report can output an HTML template with an error message based on a
supplied error number.  A sample call to C<report> is below:

  # Error reporting:
  $Pg_error->report('level',
                    "any number of diagnostic message",
                    "lines"
                   );

Unfortunately, the rich variation in possible error levels for syslog
are nor mirrored elsewhere.  C<Pgreet::Error> maps the error levels:
'error', 'critical', 'alert', and 'emergency' to a "die" scenario and
will cause the application to halt in an appropriate way.  All other
levels are considered a 'warn' scenario, reported, but the program is
allowed to continue.

There is an additional variation for CGI applications.  CGI
applications interact with the users who may not speak geek or even
English.  Therefore the text of error messages is configurable via the
template system that is used for all other user interactions.  To
indicate which template message to display, an error number is defined
that content developers can then create their own template error
messages around.  So indicate that an error template should be
displayed, the report function looks to see if the first error
"message" is in fact a number.  If so, and the error level is a die
scenario, then error template is displayed corresponding to that error
number and the CGI application halts.  For example, should a user
enter an incorrect access password the following call is made to
C<report>:


  $Pg_error->report('error', 110,
                    "Attempt to login with invalid login/password pair"
                   );

Note that if the error object is called in a die scenario, the Penguin
Greetings error object dies within the object itself.  This is
admittedly harder to debug, but is impossible to avoid in order to
handle error condition correctly in code that does not "know" what
sort application called it (shared libraries that are used by the
daemon, CGI Application, etc.)

=head1 OTHER METHODS

There is no obvious reason why any method besides C<report> would
never need to be used within C<Pgreet::Error>.  However, the following
methods are noted for completeness:

=over

=item report_cgi()

Method that does the work when C<report> is called from a CGI application.

=item report_daemon()

Method that does the work when C<report> is called from a "faceless" daemon.

=item report_stderr()

Method that does the work when C<report> is called from standard
command-line application.

=item _is_error()

Convenience predicate that returns true if argument is one of the
following error levels: 'error', 'critical', 'alert', or 'emergency'

=item error_template()

method to send an error message out via the content developers
L<Embperl> template.

=back

=head1 COPYRIGHT

Copyright (c) 2003 Edouard Lagache

This software is released under the GNU General Public License, Version 2.
For more information, see the COPYING file included with this software or
visit: http://www.gnu.org/copyleft/gpl.html

=head1 BUGS

No known bugs at this time.

=head1 AUTHOR

Edouard Lagache <pgreetdev@canebas.org>

=head1 VERSION

0.8.9

=head1 SEE ALSO

syslog, L<Pgreet>, L<Pgreet::Config>, L<Log::Dispatch>,
L<Log::Dispatch::File>, L<Log::Dispatch::Syslog>, L<CGI::Carp>

=cut

1;
