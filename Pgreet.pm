package Pgreet;
#
# File: Pgreet.pm
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
#           Perl Module: Pgreet
#
# This is the main shared library module for the Penguin Greetings
# (pgreet) ecard system.  It contains shared code between the CGI
# application and the system daemon that does not fit into any
# submodule category.
#
######################################################################
# $Id: Pgreet.pm,v 1.7 2003/07/25 21:51:28 elagache Exp $

$VERSION = "0.9.0"; # update after release

# Module exporter declarations
@ISA       = qw(Exporter);
@EXPORT    = qw();
@EXPORT_OK = qw();

# Perl modules.
use Fcntl;
use FileHandle;
use File::Basename;
use CGI qw(:standard escape);
use CGI::Carp;
use MIME::Lite;
use DB_File;
use Config::General;
use Embperl;
use Data::Dumper; # Needed only for debugging.
use Digest::MD5  qw(md5_hex);

# XXX For testing only!! XXX
use lib "/home/users/elagache/Perl_projects/pgreet/lib";
use Pgreet::Error;
# Perl Pragmas
use strict;


########################### METHODS ###########################

sub new {
#
# Traditional empty contructor.
# Assign values needed by
# particular instances of object
#
  my $class = shift;
  my $Pg_config = shift;
  my $Pg_error = shift;
  my $Apptype = shift;
  my $self = {};

  bless $self, $class;

  # Quick initialization
  $self->{'Pg_config'} = $Pg_config;
  $self->{'Pg_error'} = $Pg_error;
  $self->{'AppType'} = $Apptype;

  return($self);
}

sub read_state {
#
# Method to read the state variables from a state file and
# put them in the hash reference $data_hash for use in for
# example restoring the state of CGI script from a previous
# call.
#

  my $self = shift;
  my $data_hash = shift;
  my $StateFilName = shift;


  # Get other objects needed for work
  my $Pg_config = $self->{'Pg_config'};
  my $Pg_error = $self->{'Pg_error'};

 
  # Misc values.
  my $StateHdl = new FileHandle;
  my $dataline;
  my @message_text;
  my ($key, $value);
	
  # Open file.
  unless ($StateHdl->open("$StateFilName")) {
	$Pg_error->report('die', 20,
					  "can't open temporary state file: $StateFilName"
					 );
  }

  # Loop through short values
  while ($dataline = $StateHdl->getline()) {
	chomp($dataline);
	if (($dataline =~ m/^\#/) or ($dataline !~ /\w/)) {
		next;
	  }
	  elsif ($dataline =~ m/^EOV/) {
		last;
	  } else {
		unless(($key, $value) = split(/\t/, $dataline)) {
		  Report_error(24);
		  $Pg_error->report('die', 24,
							"Corrupted state data file: $StateFilName"
						   );
		}
		  $data_hash->{$key} =$value;
	  }
  }

  # Get message lines if any.
  if ($dataline = $StateHdl->getline()) {
	unless ($dataline =~ m/MESSAGE:/) {
	  $Pg_error->report('die', 24,
						"Corrupted State data file: $StateFilName"
					   );
	}
	@message_text = $StateHdl->getlines();
	unless (scalar(@message_text)) {
	  $Pg_error->report('die', 24,
						"Corrupted State data file: $StateFilName"
					   );
	}
	my $message = join('', @message_text);
	$data_hash->{'message'} =$message;
  }

  # traditional close protection.
  unless ($StateHdl->close()) {
	  $Pg_error->report('warn', "Unable to close file: $StateFilName");
  }
  return($data_hash);
}


sub store_state {
#
# Subroutine to store state variables in a temporary file and then
# create a hidden fields and/or GET variables to store the name of
# the temporary file to be retrieved on the next call to the CGI
# script.
#
  my $self = shift;
  my $data_hash = shift;
  my $StateFilName = shift;

  # Get other objects needed for work
  my $Pg_config = $self->{'Pg_config'};
  my $Pg_error = $self->{'Pg_error'};


  # Create handle, assign filename (either data or state) and open file
  my $StateHdl = new FileHandle;

  unless ($StateHdl->open(">$StateFilName")) {
	$Pg_error->report('die', 20,
					  "can't create temporary state file: $StateFilName"
					 );
  }

  # Create a quick header to help the overworked sysadmin :-)
  $StateHdl->print("# pgreet intermediate state file - autogenerated.\n");
  $StateHdl->print("# Created on: ", scalar(localtime()), "\n\n");

  # Store state variables except for long message
  foreach my $var (keys(%{$data_hash})) {
	if ($var eq 'message') {
	  next;  # place long text at end of file.
	} else {
	  $StateHdl->print($var, "\t", $data_hash->{$var}, "\n");
	}
  }
  $StateHdl->print("EOV\n");

  # Add message to file if any.
  if (exists($data_hash->{'message'})) {
	$StateHdl->print("MESSAGE:\n");
	$StateHdl->print($data_hash->{'message'});
  }

  # Close file.
  unless ($StateHdl->close()) {
	$Pg_error->report('warn',
					  "unable to close temporary state file: $StateFilName"
					 );
  }

  return(1);
}

=head1 NAME

Pgreet - General purpose shared methods for Penguin Greetings.

=head1 SYNOPSIS

  $Pg_obj = new Pgreet($Pg_config, $Pg_error, 'daemon');

  $Pg_obj->store_state($data_hash_ref, $Complete_path_to_StateFilName);

  $data_hash_ref = $Pg_obj->read_state($data_hash_ref,
                                       $Complete_path_to_StateFilName
                                      );

=head1 DESCRIPTION

The Perl module: C<Pgreet> (F<Pgreet.pm>) provides shared
functionality for the C<Penguin Greetings> application that is not
provided by any specific submodule.  Presently, it provide consistent
access to the intermediate state files between the CGI Application and
daemon.

=head1 INITIALIZATION

This module depends on the C<Pgreet::Error> and C<Pgreet::Config>
modules to provide error handling and configuration information
respectively.  The normal initialization sequence would be to first
create a Penguin Greetings configuration object and then a Penguin
Greetings error object using declarations similar to what is shown
below:

  $Pg_config = new Pgreet::Config($config_file)

  $Pg_error = new Pgreet::Error($Pg_config, 'CGIApp');

Once these two objects exist, the Pgreet object may be constructed.
The required arguments are the Penguin Greetings config object (below
C<$Pg_config>,) the Penguin Greetings error object (below
C<$Pg_error>,) and the type of application that is creating the Pgreet
object.  There are three recognized types: C<daemon> (for a
application daemon like F<pgreetd>,) C<CGIApp> (for a CGI application,
Speedy CGI application, etc. like F<pgreet.pl.cgi>,) and C<App> (for a
command line application like F<PgTemplateTest>.)  These are used to
determine how input/output will be dealt with for example.


  $Pg_obj = new Pgreet($Pg_config, $Pg_error, 'CGIApp');


=head1 METHODS

There are two methods in C<Pgreet>.  They provide a consistent
interface to reading and writing the temporary state files used to
communicate between the CGI application and the system daemon.  To
store data, use the C<store_state> method.  It takes a hash reference of
items to store and complete path to a file.

  $Pg_obj->store_state($data_hash_ref, $Complete_path_to_StateFilName);

To retrieve data from a state file, use the method C<read_state>.  It
takes the same two arguments: a hash reference and the path to the
file to read.  The method returns the hash reference so that it may be
called in a more functional-programming style if desired (shown
below.)

  $data_hash_ref = $Pg_obj->read_state($data_hash_ref,
                                       $Complete_path_to_StateFilName
                                      );

Because errors are handled by the Penguin Greetings Error object,
these methods will not return error conditions but will produce error
conditions consistent with the Error object.

=head1 STATE FILE FORMAT

The state file format is very simple minded.  Items are in a key-data
format that is tab-delimited.  All tabs in the data is converted to
spaces to avoid ambiguity.  The only exception (and the reason for
these special methods) is the message text of the ecard.  It is listed
separately line by line.  The reason for this special handing is
limitations in the length of fields in other implementations of state
file transition.  An example of a state file is shown below

  # pgreet intermediate state file - autogenerated.
  # Created on: Fri Jul 25 10:27:53 2003
  
  recipient_email	user@miscserver.org
  password	testpassword	
  copy_for_you	yes
  recipient_name	Jane & John Doe
  sender_name	Jane & John Doe
  sender_email	user@miscserver.org
  card	St_Gabriel_new_day
  site	PgSaint
  state_file	pgreet-state-84760f0946f1ead86770d156e3ac4e7f.txt
  EOV
  MESSAGE:
  This is a test message.  This is a test message.  This is a test message.
  This is a test message.

The line C<EOV> indicates that all tab-separated values have been
provided.  The next line C<MESSAGE:> is the start of the message text.
The message text continues until the end of the file.

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

0.9.0

=head1 SEE ALSO

L<Pgreet::Config>, L<Pgreet::Error>

=cut

1;
