use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'App::IRC::Bot::Shoze',
    AUTHOR              => q{Joachim Basmaison <joachim.basmaison@gmail.com>},
    VERSION_FROM        => 'lib/App/IRC/Bot/Shoze.pm',
    ABSTRACT_FROM       => 'lib/App/IRC/Bot/Shoze.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'POE' => 0,
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'App-IRC-Bot-Shoze-*' },
);
