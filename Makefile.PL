#
# Quickie Makefile.PL for Penguin Greetings modules
# E. Lagache, 7/2003
#

# Definitions
$DISTNAME = 'Pgreet';
$VERSION  = "0.9.0";

# Prerequisites
BEGIN { require 5.8.0 }
use ExtUtils::MakeMaker;

#--- Write the Makefile
WriteMakefile( # Prerequisites same as for Install.PL
			  PREREQ_PM => {
							'MIME::Lite' => '2.117',
							'Apache::Htpasswd' => '1.5.5',
							'Date::Pcalc' => '1.2',
							'Config::General' => '2.19',
							'String::Checker' => '0.03',
							'Digest::MD5' => '2.17',
							'Embperl' => '2.0'
						   },
			  VERSION   => $VERSION,
			  NAME      => $DISTNAME,	
			  ($] >= 5.005) ? (
							   'AUTHOR'     =>
							   'Edouard Lagache (elagache@canebas.org)',
							   'ABSTRACT'   =>
							   'Support modules for Penguin Greetings'
							  ) : (),
			 );


