package Pgreet::CGIUtils;
#
# File: CGIUtils.pm
######################################################################
#
#                ** PENGUIN GREETINGS (pgreet) **
#
# A Perl CGI-based web card application for LINUX and probably any
# other UNIX system supporting standard Perl extensions.
#
#   Edouard Lagache, elagache@canebas.org, Copyright (C)  2003, 2004
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
#           Perl Module: Pgreet::CGIUtils
#
# This is the Penguin Greetings (pgreet) module for sharing CGI
# specific routines between the CGI program and associated modules.
# In particular it houses the routines that create the transfer
# hash reference for Embperl.
######################################################################
# $Id: CGIUtils.pm,v 1.9 2004/01/12 20:18:37 elagache Exp $

$VERSION = "0.9.5"; # update after release

# Perl modules.
use CGI qw(:standard escape);
use CGI::Carp;

# Perl Pragmas
use strict;
sub new {
#
# Create new object and squirrel away CGI query object
# so that it is available for methods.
#
  my $class = shift;
  my $Pg_config = shift;
  my $cgi_script = shift;
  my $query = shift;
  my $SpeedyCGI = shift;
  my $Invocations = shift;
  my $StartTime = shift;

  my $self = {};
  bless $self, $class;

  $self->{'Pg_config'} = $Pg_config;
  $self->{'cgi_script'} = $cgi_script;
  $self->{'query'} = $query;
  $self->{'SpeedyCGI'} = $SpeedyCGI;
  $self->{'Invocations'} = $Invocations;
  $self->{'StartTime'} = $StartTime;

  return($self);
}

sub set_site_conf {
#
# Subroutine to set pgreet_conf and card_conf objects when
# pgreet.pl.cgi has bootstrapped itself and knows which site
# it is acting upon.
#
  my $self = shift;
  my $Pg_config = shift;
  my $card_conf = shift;
  my $BackVarStr = shift;
  my $BackHiddenFields = shift;

  $self->{'Pg_config'} = $Pg_config;
  $self->{'card_conf'} = $card_conf;
  $self->{'BackVarStr'} = $BackVarStr;
  $self->{'BackHiddenFields'} = $BackHiddenFields;
}

sub set_value {
#
# Convenience method to set a value in object
#
  my $self = shift;
  my $key = shift;
  my $value = shift;

  $self->{$key} = $value;
}

sub ChangeVars {
#
# Create hash with variables needed for Embperl to process templates.
#
  my $self = shift;
  my $Transfer = {};
  my $URL_script;
  my $separator;

  # Retrieve values from object
  my $Pg_config = $self->{'Pg_config'};
  my $card_conf = $self->{'card_conf'};
  my $BackVarStr = $self->{'BackVarStr'};
  my $BackHiddenFields = $self->{'BackHiddenFields'};
  my $query = $self->{'query'};
  my $SpeedyCGI = $self->{'SpeedyCGI'};
  my $Invocations = $self->{'Invocations'};
  my $StartTime = $self->{'StartTime'};
  my $cgi_script = $self->{'cgi_script'};

  # List of configuration file items to pass to Embperl
  my @config_values = ('cgiurl', 'imageurl', 'mailprog',
					   'tmpdir', 'templatedir', 'hostname',
					   'login_only'
					  );

  # Transfer the variables needed from the configuration hash.
  foreach my $config (@config_values) {
	$Transfer->{$config} = $Pg_config->access($config);
  }

  # If Card configuration object is defined, add it to transfer hash.
  if (ref($card_conf) eq 'Pgreet::Config') {
	$Transfer->{'card_hash'} = $card_conf->get_hash();
  }

  # Transfer the variables needed from the CGI state
  foreach my $CGI ($query->param()) {
	$Transfer->{$CGI} = $query->param($CGI);
  }

  # Special values
  $Transfer->{'script'} = $cgi_script;
  $Transfer->{'cgi_script'} = $cgi_script;
  $Transfer->{'number'} = $self->{'CardLogin'};
  $Transfer->{'error_hash'} = $self->{'error_hash'};
  $Transfer->{'error_no'} = $self->{'error_no'};
  # SpeedyCGI values
  $Transfer->{'SpeedyCGI'} = $SpeedyCGI;
  $Transfer->{'StartTime'} = $StartTime;
  $Transfer->{'Invocations'} = $Invocations;
  # Values for back buttons
  $Transfer->{'BackVarStr'} = $BackVarStr;
  $Transfer->{'BackHiddenFields'} = $BackHiddenFields;

  # Create URL to access card (for secondary ecard sites.)
  if ($query->param('site')) {
	$URL_script = join('',
					   $Pg_config->access('cgiurl'),
					   "/$cgi_script",
					   "?site=",$query->param('site')
					  );
	$separator = "&";
  } else {
	$URL_script = join('',
					   $Pg_config->access('cgiurl'),
					   "/$cgi_script",
					  );
	$separator = "?";
  }

  # Create URL short-cut to save typing for user.
  if ($Pg_config->access('allow_quick_views') and
	  exists($self->{'CardLogin'}) and
	  defined($query->param('password'))
	 ) {
	$Transfer->{'URL_short_cut'} = join('',
										$URL_script, $separator,
										"action=view&",
										"next_template=view&",
										"code=", $self->{'CardLogin'},
										"&password=",
										escape($query->param('password'))
									   );
  } else {
	$Transfer->{'URL_short_cut'} = $URL_script;
  }

  # Return hash reference
  return($Transfer);
}

=head1 NAME

Pgreet::CGIUtils - Penguin Greetings shared routines for CGI functions.

=head1 SYNOPSIS

  # Constructor:
  $Pg_cgi = new Pgreet::CGIUtils($Pg_default_config, $cgi_script,
                                 $query, $SpeedyCGI, $Invocations,
                                 $StartTime
                                );

  # Set card site specific configuration
  $Pg_cgi->set_site_conf($Pg_config, $card_conf, $BackVarStr,
                         $BackHiddenFields
                        );

  # Assign a value to be passed on to Embperl
  $Pg_cgi->set_value('error_hash', $error_hash);

  # Create Transfer hash for Embperl
  my $Transfer = $Pg_cgi->ChangeVars();


=head1 DESCRIPTION

The module C<Pgreet::CGIUtils> is the Penguin Greetings module for any
routines that must be shared between the CGI application and other
modules.  The first task thus shared is the creation of a hash of
values to be transferred from Penguin Greetings to Embperl for
processing of templates.

Like the other modules associated with Penguin Greetings, there is a
certain bit of bootstrapping involved.  The constructor is used as
soon as the other main objects associated with Penguin Greetings are
created.  However, that information may not be up-to-date once
secondary ecard sites have been selected.  So the state of the
CGIUtils object is updated once an ecard site is definitely selected.

For the matter of setting up the Transfer hash to Embperl the method
C<ChangeVars> is used in two settings.  It is used within the main CGI
Application itself and used with C<Pgreet::Error> to allow for error
templates to have access to all of the state variables that content
developers would have access to in a normal (non-error) situation.

=head1 CONSTRUCTING A CGIUTILS OBJECT

The C<Pgreet::CGIUtils> constructor should be called after a query
object has been obtained from the CGI module and a Penguin Greetings
Configuration object has been created.  In addition,
C<Pgreet::CGIUtils> requires one additional argument and has three
other arguments related to the SpeedyCGI version of Penguin Greetings.
The required argument is the name of the script creating the object
(usually the basename of C<$0>.)  The three optional arguments are a
boolean which if true indicates that this script is running as a
SpeedyCGI process, the number of SpeedyCGI innovcations, and the UNIX
time when this SpeedyCGI process was started.  The calling syntax is
illustrated below:

  $Pg_cgi = new Pgreet::CGIUtils($Pg_default_config, $cgi_script,
                                 $query, $SpeedyCGI, $Invocations,
                                 $StartTime
                                 );

Because the Penguin Greetings error object needs a reference to the
C<Pgreet::CGIUtils> object, you should use the C<add_cgi_obj> method
of C<Pgreet::Error> to attach that reference as soon as you have
created the new CGIUtils object:

  # Attach new CGIUtils object to Error obj.
  $Pg_error->add_cgi_obj($Pg_cgi);

  $Pg_error = new Pgreet::Error($Pg_default_config, 'CGIApp');

From that point on, this error object can be used to report errors in
the application with all state variables available for error template.

=head1 METHODS TO UPDATE STATE

Once the C<Pgreet::CGIUtils> object has been created, you may need to
update some of the settings with which it was created.  There is a
very particular point when this must be done, when the choice of ecard
sites has been made and the object needs to now reflect those
configuration settings.  There is a specific method for the post ecard
site adjustment and a general method for all other cases.

Once an ecard site is selected, use the C<set_site_conf> method to
update the essential parameters.  It expects 4 parameters: the Penguin
Greetings configuration object (for that site,) the card configuration
object, and the URL get parameter and URL post hidden fields needed to
"back up" via a new CGI request.  The call look like:

  # Set card site specific configuration
  $Pg_cgi->set_site_conf($Pg_config, $card_conf, $BackVarStr,
                         $BackHiddenFields
                        );

As the CGI Application is run, it may create other values that must be
passed to Embperl.  To set these values generally, use the
C<set_value> method.  It takes two parameters: the name of the value
to set and the value to assign to it.  These values are simply added
to the hash associated with the C<Pgreet::CGIUtils> object.  So it is
possible to reset anything.  Thus documented, it becomes a feature and
programmers are thus warned.  An example call is provided below:

  $Pg_cgi->set_value('error_hash', $error_hash);

=head1 CGI UTILITY METHODS

The utility functions that can be used from C<Pgreet::CGIUtils> are
listed below.

=over

=item ChangeVars()

This is the method that creates a transfer hash to pass on to Embperl.
It takes no parameters and instead provides a "snapshot" of the
current state of the CGI application at the time of its invocation.  A
sample call is provided below:

  # Create Transfer hash for Embperl
  my $Transfer = $Pg_cgi->ChangeVars();

=back

=head1 COPYRIGHT

Copyright (c) 2003, 2004 Edouard Lagache

This software is released under the GNU General Public License, Version 2.
For more information, see the COPYING file included with this software or
visit: http://www.gnu.org/copyleft/gpl.html

=head1 BUGS

No known bugs at this time.

=head1 AUTHOR

Edouard Lagache <pgreetdev@canebas.org>

=head1 VERSION

0.9.5

=head1 SEE ALSO

syslog, L<Pgreet>, L<Pgreet::Config>, L<Pgreet::Error>, L<Log::Dispatch>,
L<Log::Dispatch::File>, L<Log::Dispatch::Syslog>, L<CGI::Carp>

=cut

1;
