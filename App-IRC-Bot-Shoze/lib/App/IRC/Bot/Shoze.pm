package App::IRC::Bot::Shoze;

use 5.006;
use strict;
use warnings;

use Carp;

=head1 NAME

App::IRC::Bot::Shoze - The great new App::IRC::Bot::Shoze!

=head1 VERSION

Version 0.01

=cut

our $PROGRAMNAME  = "Shoze";
our $VERSION      = "0.0.7";
our $VERSIONNAME  = "regeneration";
our $LASTVERSION  = "1314675373";
our $PROGRAMBIRTH = "1313893570";
our $DEBUG        = 1;

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use App::IRC::Bot::Shoze;

    my $foo = App::IRC::Bot::Shoze->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 function1

=cut
use lib qw(../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Config;
use App::IRC::Bot::Shoze::POE;
use App::IRC::Bot::Shoze::Db;
use App::IRC::Bot::Shoze::HTTP;
use App::IRC::Bot::Shoze::Log;


our %fields = (
    _path  => "",
    _debug => 1,
    POE    => undef,
    Log    => undef,
    HTTP   => undef,
);

our $Singleton = undef;

sub new {
    my ( $proto, $path ) = @_;
    if ($Singleton) {
        DEBUG("SINGLETON " . __PACKAGE__, 5);
        return $Singleton;
    }
    DEBUG( "Creating new " . __PACKAGE__, 5 );
    croak "No configuration path given as first parameter"
        unless $path;
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->_path($path);
    $s->read_config($s);
    $Singleton = $s;
    new App::IRC::Bot::Shoze::Db();  
    $s->POE( new App::IRC::Bot::Shoze::POE($s) );
    $s->HTTP( new App::IRC::Bot::Shoze::HTTP($s) );
    return $Singleton;
}

sub read_config {
    my $s = shift;
    new App::IRC::Bot::Shoze::Config($s->_path);
}

=head1 AUTHOR

Joachim Basmaison, C<< <joachim.basmaison at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-app-irc-bot-shoze at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=App-IRC-Bot-Shoze>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc App::IRC::Bot::Shoze


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-IRC-Bot-Shoze>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/App-IRC-Bot-Shoze>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/App-IRC-Bot-Shoze>

=item * Search CPAN

L<http://search.cpan.org/dist/App-IRC-Bot-Shoze/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2011 Joachim Basmaison.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;
