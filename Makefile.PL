#
# Quickie Makefile.PL for Penguin Greetings modules
# E. Lagache, 7/2003
#

$DISTNAME = 'Pgreet';
$VERSION  = "0.8.9";

#--- Write the Makefile

BEGIN { require 5.8.0 }

use ExtUtils::MakeMaker;

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
);


