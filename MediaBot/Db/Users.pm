package MediaBot::Db::Users;

use strict;
use warnings;

use Carp;

use Crypt::Passwd::XS;

use lib qw(../../);
use MediaBot::Class qw(AUTOLOAD DESTROY _get_root);
use MediaBot::Db::Users::Object qw();
use MediaBot::Log;

our $AUTOLOAD;

our %fields = (
    handle  => undef,
    _parent => undef,
);
# Constructor
#############
sub new {
    my ( $proto, $parent ) = @_;
    DEBUG( "Creating new " . __PACKAGE__, 5);
    croak "No parent specified" unless ref $parent;
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->_parent($parent);
    return $s;
}

# User exists?
##############
sub exists {
    my ( $s, $id ) = @_;
    $s->_parent->die_if_not_open();
    my $h     = $s->_parent->handle;
    my $query = <<SQL;
		SELECT * FROM users WHERE id= ?
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute($id)
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    my $row = $sth->fetch;
    return $row if $row;
    return 0;
}

# User exists?
##############
sub existsby_name {
    my ( $s, $name ) = @_;
    $s->_parent->die_if_not_open();
    my $h     = $s->_parent->handle;
    my $query = <<SQL;
		SELECT id FROM users WHERE name= ?
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute($name)
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    my $row = $sth->fetch;
    return $row if $row;
    return 0;
}

# Create user
#############
sub create {
    my ( $s, $name, $password, $lvl ) = @_;
    $s->_parent->die_if_not_open();
    if ( $s->existsby_name($name) ) {
        $s->LOG("DB::Error User '$name' already exists");
        return 1;
    }
    $lvl = 1000 unless defined $lvl;
    my $h = $s->_parent->handle;

    #	my $root = $s->_get_root;
    #	print "Root: $root/ ref: ". ref($root) . "\n";
    my $salt = $s->_get_root->Config->bot->{password_salt};
    croak "No password salt defined in configuration" unless $salt;
    my $query = <<SQL;
		INSERT INTO users (name, password, lvl, pending)
		VALUES (?, ?, ?, 1)
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute( $name, Crypt::Passwd::XS::crypt( $password, $salt ), $lvl )
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    return 0;
}

sub login_successfull {
    my ($s, $id, $ident, $host) = @_;   
    $s->_parent->die_if_not_open();
    my $h     = $s->_parent->handle;
    my $time = time;
    my $query = <<SQL;
		UPDATE users SET ident = ?, host = ?, logged_on = ?, last_access = ?
		WHERE id = ?
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute($ident, $host, $time, $time, $id)
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
}

sub logout {
    my ($s, $id) = @_;   
    $s->_parent->die_if_not_open();
    my $h     = $s->_parent->handle;
    my $query = <<SQL;
		UPDATE users SET ident = ?, host = ?, logged_on = ?
		WHERE id = ?
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute(undef, undef, undef, $id)
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
}

sub last_access {
    my ($s, $id) = @_;   
    $s->_parent->die_if_not_open();
    my $h     = $s->_parent->handle;
    my $query = <<SQL;
		UPDATE users SET last_access = ?
		WHERE id = ?
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute(time, $id)
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
}

sub delete_idle {
    my ($s) = @_;   
    $s->_parent->die_if_not_open();
    my $h     = $s->_parent->handle;
    my $time = time - 600;
    my $query = <<SQL;
		UPDATE users SET ident = ?, host = ?, logged_on = ?
		WHERE last_access < ?
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute(undef, undef, undef, $time)
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
}



# Get user id
##################
sub get_id {
    my ( $s, $name ) = @_;
    $s->_parent->die_if_not_open();
    my $h     = $s->_parent->handle;
    my $query = <<SQL;
		SELECT * FROM users WHERE name= ?;
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute($name)
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    my $ru = $sth->fetchrow_hashref;
    return undef unless $ru;
    return $ru->{id};
}

# Get user by id
##################
sub get {
    my ( $s, $id ) = @_;
    $s->_parent->die_if_not_open();
    unless ( $s->exists($id) ) {
        $s->LOG("DB::Error User '$id' doesn't exist");
        return undef;
    }
    my $h     = $s->_parent->handle;
    my $query = <<SQL;
		SELECT * FROM users WHERE id= ?;
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute($id)
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    my $ru = $sth->fetchrow_hashref;
    return undef unless $ru;
    my $U = new MediaBot::Db::Users::Object();

    for my $k ( keys %{$U} ) {
        next if $k =~ /^_.*/;
        $U->$k( $ru->{$k} );
    }
    return $U;
}

sub get_byname {
    my ( $s, $name ) = @_;
    $s->_parent->die_if_not_open();
    my $h     = $s->_parent->handle;
    my $query = <<SQL;
		SELECT * FROM users WHERE name= ?;
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute($name)
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    my $ru = $sth->fetchrow_hashref;
    return undef unless $ru;
    my $U = new MediaBot::Db::Users::Object();
    for my $k ( keys %{$U} ) {
        next if $k =~ /^_.*/;
        $U->$k( $ru->{$k} );
    }
    return $U;
}

sub get_byidenthost {
    my ( $s, $ident, $host ) = @_;
    $s->_parent->die_if_not_open();
    my $h     = $s->_parent->handle;
    my $query = <<SQL;
		SELECT * FROM users 
		WHERE ident= ? AND host = ?;
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute($ident, $host)
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    my $ru = $sth->fetchrow_hashref;
    return undef unless $ru;
    my $U = new MediaBot::Db::Users::Object();
    for my $k ( keys %{$U} ) {
        next if $k =~ /^_.*/;
        $U->$k( $ru->{$k} );
    }
    return $U;
}
# Delete user
#############
sub delete {
    my ( $s, $id ) = @_;
    $s->_parent->die_if_not_open();
    unless ( $s->exists($id) ) {
        $s->LOG("DB::Error Cannot remove non existing user '$id'");
        return 1;
    }
    my $h     = $s->_parent->handle;
    my $query = <<SQL;
		DELETE FROM users WHERE id= ? 
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute($id)
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    return 0;
}

# Check Db::User object against password
#########################################
sub check_password {
    my ( $s, $User, $password ) = @_;
    $s->_parent->die_if_not_open();
    croak "Need User object as first parameter"
      if ( not defined $User or not ref($User) );
    my $salt = $s->_get_root->Config->bot->{password_salt};
    my $encrypted = Crypt::Passwd::XS::crypt( $password, $salt );
    if ( $User->password eq $encrypted ) {
        return 1;
    }
    return 0;
}

1;
