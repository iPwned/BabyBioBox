use strict;
use warnings;
use ExtUtils::MakeMaker;

# Normalize version strings like 6.30_02 to 6.3002,
# so that we can do numerical comparisons on it.
my $eumm_version = $ExtUtils::MakeMaker::VERSION;
$eumm_version =~ s/_//;

WriteMakefile(
    NAME                => 'BabyBioBox',
    AUTHOR              => q{Christopher Betancourt <christopher.betancourt@gmail.com>},
    VERSION_FROM        => 'lib/BabyBioBox.pm',
    ABSTRACT            => 'Data logging server for infant biorythms',
    ($eumm_version >= 6.3001
      ? ('LICENSE'=> 'bsd')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'YAML'       => 0,
        'Dancer2'     => 0.161000,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'BabyBioBox-*' },
);
