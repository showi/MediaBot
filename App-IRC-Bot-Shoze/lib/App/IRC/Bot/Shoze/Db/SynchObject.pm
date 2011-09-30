package App::IRC::Bot::Shoze::Db::SynchObject;

=head1 NAME

App::IRC::Bot::Shoze::Db::SynchObject - Underlying methods exported for our database object

=cut

=head1 SYNOPSIS
    
This module export a lot of methods that permit to automatically create, update, delete 
SQL rows. The intent is to have faster access to new SQL table and less coding. There's also 
facilities for table fields updated_on and created_on. Database object use a special AUTOLOAD 
method that keep track of modified fields so we can just update those fields on table row update

=cut

use strict;
use warnings;

use Carp;

=head1 EXPORT_OK

=over

=item _add_permitted_field 

=item _init_fields 

=item _get _get_by 

=item _create 

=item _delete 

=item _delete_by 

=item _update 

=item _update_by 
  
=item _list 

=item _list_match

=item _list_by

=item _pretty 

=item AUTOLOAD 

=item synched 

=item is_synch

=item _serializable

=back

=cut

use Exporter;
use Encode qw(decode);

our @TAGS =
  qw(_add_permitted_field _init_fields 
  _get _get_by _create _delete _delete_by 
  _update _update_by  _serializable
  _list _list_match _list_by _pretty AUTOLOAD synched is_synch);
our @ISA         = qw(Exporter);
our @EXPORT_OK   = @TAGS;
our %EXPORT_TAGS = ( ALL => [@TAGS] );

use lib qw(../../../../../);

use App::IRC::Bot::Shoze::Class qw(DESTROY);
use App::IRC::Bot::Shoze::Log;

use Data::Dumper;

our $AUTOLOAD;

our %fields = (
    _object_name => undef,
    _object_db   => undef,
    _module_name => undef,
    id           => undef,
);

=head1 SUBROUTINES/METHODS

=over

=item new (never used ...)

=cut

sub new {
    my ( $proto, $object_name, $object_db ) = @_;
    DEBUG( "Creating new " . __PACKAGE__, 8);
    croak "No database object passed as first argument" unless ref($object_db);
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->_object_name($object_name);
    $s->_object_db($object_db);
    return $s;
}

=item _init_fields

=cut

sub _init_fields {
    my $s = shift;
    for my $k(keys %{$s->{_permitted}}) {
        next if $k =~ /^_/;
        $s->$k(undef);
    }
}

=item AUTOLOAD

=cut

sub AUTOLOAD {
    my $self = shift;
    my $name = $AUTOLOAD;
    $name =~ s/.*://;    # strip fully-qualified portion
    my $type = ref($self) 
        or croak "$self is not an object (AUTOLOAD: $name)";
    unless ( exists $self->{_permitted}->{$name} ) {
        croak "Can't access `$name' field in class $type";
    }
    if (@_) {
        my $value = shift;
        if ( $name !~ /^_/ ) {
            if ( not defined $self->{$name} and not defined $value ) {

            }
            elsif ( not defined $self->{$name} and defined $value ) {
                $self->{_changed}->{$name} = 1;
            }
            elsif ( defined $self->{$name} and not defined $value ) {
                $self->{_changed}->{$name} = 1;
            }
            elsif ( $self->{$name} ne $value ) {
                $self->{_changed}->{$name} = 1;
            }
        }
        return $self->{$name} = $value;#decode('utf8', $value);
    }
    else {
        return $self->{$name};
    }
}

=item synched

=cut

sub synched {
    my $s = shift;
    $s->{_changed} = undef;
}

=item is_synch

=cut

sub is_synch {
    my $s = shift;
    return 0 if defined $s->{_changed};
    return 1;
}

=item _add_permitted_field

=cut

sub _add_permitted_field {
    my ( $s, $name ) = @_;
    $s->{_permitted}->{$name} = 1;
}

=item _get

=cut

sub _get {
    my ( $s, $id ) = @_;
    $s->_object_db->die_if_not_open();
    my $h     = $s->_object_db->handle;
    
    my $query = "SELECT * FROM  " . $s->_object_name . " WHERE id = ?;";
    DEBUG( "[" . $s->_object_name . "] GET Query: $query", 4 );
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute($id)
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    my $rn = $sth->fetchrow_hashref;
    return undef unless $rn;

    for my $k ( keys %{$rn} ) {
        next if $k =~ /^_/;
        $s->{_permitted}->{$k} = 1
          unless defined $s->{_permitted}->{$k};
        $s->$k( $rn->{$k} );
    }
    $s->synched;
    return $s;
}

=item _delete

=cut

sub _delete {
    my ( $s ) = @_;
    $s->_object_db->die_if_not_open();
    my $h     = $s->_object_db->handle;
    
    my $query = "DELETE FROM  " . $s->_object_name . " WHERE id = ?;";
    DEBUG( "[" . $s->_object_name . "] DELETE Query: $query", 4 );
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute($s->id)
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    return $sth->rows;
}

=item _delete_by

=cut

sub _delete_by {
    my ( $s, $kv) = @_;
    $s->_object_db->die_if_not_open();
    my $h     = $s->_object_db->handle;
    
    my $query = "DELETE FROM  " . $s->_object_name . " WHERE";
    my @args;
    for my $k(keys %{$kv}) {
        $query.= " $k = ? AND";
        push @args, $kv->{$k};
    }
    $query =~ s/^(.*)AND\s*/$1/;
    DEBUG( "[" . $s->_object_name . "] DELETE Query: $query", 4 );
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute(@args)
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    return $sth->rows;
}

=item _get_by

=cut

sub _get_by {
    my ( $s, $kv ) = @_;
    croak "Not an hash ref" unless ref($kv) =~ /^HASH/;
    $s->_object_db->die_if_not_open();
    my $h     = $s->_object_db->handle;
    
    my $query = "SELECT * FROM  " . $s->_object_name . " WHERE ";
    my @args;
    for my $k ( keys %{$kv} ) {
        next if $k =~ /^_/;
        $query .= "$k = ? AND ";
        push @args, $kv->{$k};
    }
    $query =~ s/^(.*)\s+AND\s+/$1/;
    DEBUG( "[" . $s->_object_name . "] GET_BY Query: $query", 4 );
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute(@args)
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    my $rn = $sth->fetchrow_hashref;
    return undef unless $rn;
    for my $k ( keys %{$rn} ) {
        next if $k =~ /^_/;
        $s->{_permitted}->{$k} = 1
          unless defined $s->{_permitted}->{$k};
        $s->$k( $rn->{$k} );
    }
    $s->synched;
    return $s;
}

=item _list

=cut

sub _list {
    my ( $s) = @_;
    $s->_object_db->die_if_not_open();
    my $h     = $s->_object_db->handle;
    
    my $query = "SELECT * FROM  " . $s->_object_name . ";";
    DEBUG( "[" . $s->_object_name . "] LIST Query: $query", 4 );
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute()
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    my @list;
    while ( my $rn = $sth->fetchrow_hashref ) {
        my $O = $s->new( $s->_object_db, $s->_object_name, $s->_object_db );
        for my $k ( keys %{$rn} ) {
            next if $k =~ /^_/;
            $O->$k( $rn->{$k} );
        }
        $O->synched;
        push @list, $O;
    }
    return @list;
}

=item _list_by

=cut

sub _list_by {
    my ( $s, $matches ) = @_;
    $s->_object_db->die_if_not_open();
    my $h     = $s->_object_db->handle;
    
    my $query = "SELECT * FROM  " . $s->_object_name . " WHERE";
    my @args;
    for my $k (keys %{$matches}) {
        if (defined $matches->{$k}) {
            $query .= " $k = ? AND";
            push @args, $matches->{$k};
        } else {
            $query .= " $k IS NULL AND";
        }
    }
    $query =~ s/^(.*)\s+AND/$1/;
    DEBUG( "[" . $s->_object_name . "] LIST Query: $query", 4 );
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute(@args)
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    my @list;
    while ( my $rn = $sth->fetchrow_hashref ) {
        my $O = $s->new( $s->_object_db, $s->_object_name, $s->_object_db );
        for my $k ( keys %{$rn} ) {
            next if $k =~ /^_/;
            $O->$k( $rn->{$k} );
        }
        $O->synched;
        push @list, $O;
    }
    return @list;
}

=item _list_match

=cut

sub _list_match {
    my ( $s, $matches ) = @_;
    $s->_object_db->die_if_not_open();
    my $h     = $s->_object_db->handle;
    
    my $query = "SELECT * FROM  " . $s->_object_name . " WHERE";
    my @args;
    for my $k (keys %{$matches}) {
        $query .= " $k LIKE ? AND";
        push @args, $matches->{$k};
    }
    $query =~ s/^(.*)\s+AND/$1/;
    DEBUG( "[" . $s->_object_name . "] LIST Query: $query", 4 );
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute(@args)
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    my @list;
    while ( my $rn = $sth->fetchrow_hashref ) {
        my $O = $s->new( $s->_object_db, $s->_object_name, $s->_object_db );
        for my $k ( keys %{$rn} ) {
            next if $k =~ /^_/;
            $O->$k( $rn->{$k} );
        }
        $O->synched;
        push @list, $O;
    }
    return @list;
}

=item _create

=cut

sub _create {
    my ($s) = @_;
    return if $s->is_synch;
    $s->_object_db->die_if_not_open();
    my $h = $s->_object_db->handle;
    my @args;
    my $time = time;
    if (defined $s->{_permitted}->{created_on}) {
        #LOG("Create created_on $time");
        $s->created_on($time);
    }
    if (defined $s->{_permitted}->{updated_on}) {
        $s->updated_on($time);
    }
    my $query = "INSERT INTO " . $s->_object_name . " (";
    for my $k ( keys %{ $s->{_permitted} } ) {
        $k =~ /^_/ and next;
        $k eq 'id' and next;
        if (defined $s->{$k}) {
        $query .= "$k, ";
        push @args, $s->$k;
        }
    }
    $query =~ s/^(.*),\s*$/$1/;
    $query .= " ) VALUES (";
    my @newargs;
    for ( 1 .. @args ) {
            $query .= "?,";
    }
    $query =~ s/^(.*),\s*$/$1/;
    $query .= ");";
    DEBUG( "[" . $s->_object_name . "] CREATE Query: $query", 4 );
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute(@args)
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    $s->synched;
    return $sth->rows;
}

=item _update

=cut

sub _update {
    my ($s) = @_;
    return if $s->is_synch;
    $s->_object_db->die_if_not_open();
    my $h = $s->_object_db->handle;
    my @args;
    if (defined $s->{_permitted}->{updated_on}) {
        $s->updated_on(time);
    }
    my $query = "UPDATE " . $s->_object_name . " SET ";
    for my $k ( keys %{ $s->{_changed} } ) {
        $k =~ /^_/ and next;
        $k eq 'id' and next;
        $query .= "$k = ?,";
        push @args, $s->$k;
    }
    $query =~ s/^(.*),$/$1/;
    $query .= " WHERE id = ?";
    push @args, $s->id;
    DEBUG( "[" . $s->_object_name . "] GET Query: $query", 4 );
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute(@args)
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    $s->synched;
    return $sth->rows;
}

=item _update_by

=cut

sub _update_by {
    my ($s, $kv) = @_;
    return if $s->is_synch;
    $s->_object_db->die_if_not_open();
    my $h = $s->_object_db->handle;
    my @args;
    
    my $query = "UPDATE " . $s->_object_name . " SET ";
    for my $k ( keys %{ $s->{_changed} } ) {
        $k =~ /^_/ and next;
        $k eq 'id' and next;
        $query .= "$k = ?,";
        push @args, $s->$k;
    }
    $query =~ s/^(.*),$/$1/;
    $query .= " WHERE";
    for my $key(keys %{$kv}) {
        $query .= " $key = ? AND";
        push @args, $kv->{$key};
    }
    $query =~ s/^(.*)AND\s*/$1/;
    DEBUG( "[" . $s->_object_name . "] GET Query: $query", 4 );
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute(@args)
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    $s->synched;
    return $sth->rows;
}

=item _pretty

=cut

sub _pretty {
    my $s   = shift;
    my $str = '-' x 25 . "\n";
    $str.= 'SQL TABLE: ' . $s->_object_name . "\n";
    $str.= '-' x 25 . "\n";
    for my $k ( sort keys %{ $s->{_permitted} } ) {
        next if $k =~ /^_/;
        $str .= "  $k: ";
        if ( defined $s->$k ) {
            $str .= $s->$k;
        }
        else {
            $str .= '<<UNDEF>>';
        }
        $str .= "\n";
    }
    return $str;
}

=item _serializable

=cut

sub _serializable {
    my ($s) = @_;
    my %h;
    for my $k(keys %{$s->{_permitted}}) {
        next if $k =~ /^_/;
        $h{$k} = $s->$k;
    }
    return \%h;
}

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2011 Joachim Basmaison.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;
