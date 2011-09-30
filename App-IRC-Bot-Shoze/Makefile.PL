use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'App::IRC::Bot::Shoze',
    AUTHOR        => q{Joachim Basmaison <joachim.basmaison@gmail.com>},
    VERSION_FROM  => 'lib/App/IRC/Bot/Shoze.pm',
    ABSTRACT_FROM => 'lib/App/IRC/Bot/Shoze.pm',
    ( $ExtUtils::MakeMaker::VERSION >= 6.3002
       ? ( 'LICENSE' => 'perl' )
       : () ),
    PL_FILES  => {
        
    },
    PREREQ_PM => {
        'POE'                                     => 0,
        'POE::Component::IRC'                     => 0,
        'POE::Component::IRC::Plugin'             => 0,
        'POE::Component::IRC::Plugin::CycleEmpty' => 0,
        'POE::Component::IRC::Plugin::Connector'  => 0,
        'POE::Component::IRC::Plugin::AutoJoin'   => 0,
        'POE::Component::Server::TCP'             => 0,
        'POE::Filter::Stream'                     => 0,
        'POE::Filter::SSL'                        => 0,
        'IRC::Utils'                              => 0,
        'HTTP::Status'                            => 0,
        'DBI'                                     => 0,
        'DBD::SQLite'                             => 0,
        'Crypt::Passwd::XS'                       => 0,
        'Digest::HMAC'                            => 0,
        'Digest::SHA256'                          => 0,
        'POE::Filter::SSL'                        => 0,
        'Class::Unload' => 0,

        'Test::More' => 0,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES    => 'App-IRC-Bot-Shoze-*' },
);
