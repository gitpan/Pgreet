#!/usr/bin/perl
# File: Pgreet.t
######################################################################
#
#                ** PENGUIN GREETINGS (pgreet) **
#
# Testing script for modules: Pgreet, Pgreet::Config, and
#                             Pgreet::Error
#
#  Edouard Lagache, elagache@canebas.org, Copyright (C)  2003, 2004
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
######################################################################
# $Id: Pgreet.t,v 1.4 2004/01/13 21:09:32 elagache Exp $
#
use Test::More tests => 16;
use File::Temp qw(tempdir);
use File::Basename;



# Global declarations
our ($TmpDir, $ErrorMessage, $config_file, $state_file);
our ($Pg_config, $Pg_error, $Pg_obj);

our $Test_state_hash = { varstring => "PgTemplateTest=true",
						 hiddenfields =>  "<!-- Templatetest hiddenfields -->",
						 sender_name => "Test Sender Name",
						 sender_email => "test\@PgTemplateTest.org"
					   };

$state_file = "Test_state_file.txt";

# ....... Test setup Subroutines .......

sub make_tmp_dir {
#
# Subroutine to create a temporarily directory
# in which to drop a temporary configuration file
# and create state files.
#
  # Try to create a directory to create test values in.
  unless (($TmpDir = tempdir("PgreetTestingDirXXXX", CLEANUP => 1)) and
		  (-d $TmpDir)
		  ){
	$ErrorMessage = "Cannot create test directory ... Try setting TmpDir";
	return(0);
  }
  return(1);

}

sub create_config_file {
#
# A Perl "here" document containing the bare-bones
# Penguin Greeting configuration file for testing
# the modules.
#
  $config_file = "$TmpDir/pgreet.conf";
  unless (open(CONFIG, ">$config_file")) {
	$ErrorMessage = "Unable to create temporary configuration file";
	return(0);
  }

  print CONFIG << "EOF";
  TestVar = TestValue
  PgreetVar = 3
EOF

	close(CONFIG);
}

# Need modules to run this puppy
BEGIN { use_ok( 'Pgreet' ); }
BEGIN { use_ok( 'Pgreet::Config' ); }
BEGIN { use_ok( 'Pgreet::Error' ); }
BEGIN { use_ok( 'Pgreet::CGIUtils'); }

# Create a temporary environment to run tests in
ok(make_tmp_dir() and create_config_file(),
   "Create temporary Penguin Greetings environment") or
  diag($ErrorMessage);

########## MAIN SCRIPT ###########

{
  my $cgi_script = basename($0);
  my $query = 0;

  # Create objects for tests
  ok($Pg_config = new Pgreet::Config($config_file),
	 "Create Pgreet::Config object");
  ok($Pg_error = new Pgreet::Error($Pg_config, 'App'),
	 "Create Pgreet::Error object");
  ok($Pg_config->add_error_obj($Pg_error),
	 "Attach Error object to configuration object");
  ok($Pg_obj = new Pgreet($Pg_config, $Pg_error, 'App'),
	 "Create Pgreet object");
  ok($Pg_cgi = new Pgreet::CGIUtils($Pg_config, $cgi_script, $query),
	 "Create Pgreet::CGIUtils object");
  ok($Pg_error->add_cgi_obj($Pg_cgi),
	 "Adding Pgreet::CGIUtils object reference to Pgreet::Error object");

  # Test configuration file access
  is($Pg_config->access('TestVar'), 'TestValue',
	 "Retrieve config variable \'TestVar\'");
  cmp_ok(($Pg_config->access('PgreetVar', 5) and
		  $Pg_config->access('PgreetVar')),
		 '==', 5,
		 "Set \'PgreetVar\' to 5");

  # Test creation and access of state file
  my $test_file_path = join('/', $TmpDir, $state_file);
  my $data_hash;
  ok($Pg_obj->store_state($Test_state_hash, $test_file_path),
	 "Create state file");
  ok($data_hash = $Pg_obj->read_state($data_hash, $test_file_path),
	 "Read state file");
  is_deeply($Test_state_hash, $data_hash,
			"Compare state file data to original");

}
