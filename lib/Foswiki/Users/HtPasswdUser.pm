# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Users::HtPasswdUser

Support for htpasswd and htdigest format password files.

Subclass of =[[%SCRIPTURL{view}%/%SYSTEMWEB%/PerlDoc?module=Foswiki::Users::Password][Foswiki::Users::Password]]=.
See documentation of that class for descriptions of the methods of this class.

=cut

package Foswiki::Users::HtPasswdUser;
use strict;
use warnings;

use Foswiki::Users::Password ();
our @ISA = ('Foswiki::Users::Password');

use Assert;
use Error qw( :try );
use Fcntl qw( :DEFAULT :flock );

# 'Use locale' for internationalisation of Perl sorting in getTopicNames
# and other routines - main locale settings are done in Foswiki::setupLocale
BEGIN {

    # Do a dynamic 'use locale' for this module
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }

#moved srand call to Foswiki::Users::BEGIN, as there is a call to rand there that would not be covered if some other Foswiki::Users::Password impl was used.
}

sub new {
    my ( $class, $session ) = @_;
    my $this = bless( $class->SUPER::new($session), $class );
    $this->{error} = undef;
    if ( $Foswiki::cfg{Htpasswd}{Encoding} eq 'md5' ) {
        require Digest::MD5;
        if ($Foswiki::cfg{AuthRealm} =~ /\:/) {
            print STDERR "ERROR: the AuthRealm cannot contain a ':' (colon) as it corrumpts the password file\n";
            throw Error::Simple("ERROR: the AuthRealm cannot contain a ':' (colon) as it corrumpts the password file");
        }
    }
    elsif ( $Foswiki::cfg{Htpasswd}{Encoding} eq 'crypt' ) {
    }
    elsif ( $Foswiki::cfg{Htpasswd}{Encoding} eq 'plain' ) {
    }
    elsif ( $Foswiki::cfg{Htpasswd}{Encoding} eq 'sha1' ) {
        require Digest::SHA;
    }
    elsif ( $Foswiki::cfg{Htpasswd}{Encoding} eq 'crypt-md5' )
    {
        if ( $Foswiki::cfg{DetailedOS} eq 'darwin' ) {
            print STDERR "ERROR: crypt-md5 FAILS on OSX (no fix in 2008)\n";
            throw Error::Simple("ERROR: crypt-md5 FAILS on OSX (no fix in 2008)");
        }
        use Config;
        if ( $Config{myuname} =~ /strawberry/i ) {
            print STDERR "ERROR: crypt-md5 FAILS on Windows with Strawberry perl (no fix in 2010)\n";
            throw Error::Simple("ERROR: crypt-md5 FAILS on Windows with Strawberry perl (no fix in 2010)");
        }
    } else {
            print STDERR "ERROR: unknown {Htpasswd}{Encoding} setting : ".$Foswiki::cfg{Htpasswd}{Encoding}."\n";
            throw Error::Simple("ERROR: unknown {Htpasswd}{Encoding} setting : ".$Foswiki::cfg{Htpasswd}{Encoding}."\n");
    }

    return $this;
}

=begin TML

---++ ObjectMethod finish()
Break circular references.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    $this->SUPER::finish();
    undef $this->{passworddata};
}

=begin TML

---++ ObjectMethod readOnly(  ) -> boolean

returns true if the password file is not currently modifyable

=cut

sub readOnly {
    my $this = shift;
    my $path = $Foswiki::cfg{Htpasswd}{FileName};

    #TODO: what if the data dir is also read only?
    if ( ( !-e $path ) || ( -e $path && -r $path && !-d $path && -w $path ) ) {
        $this->{session}->enterContext('passwords_modifyable');
        return 0;
    }
    return 1;
}

sub canFetchUsers {
    return 1;
}

sub fetchUsers {
    my $this  = shift;
    # Read passwords with shared lock
    my $db    = $this->_readPasswd( 1 );
    my @users = sort keys %$db;
    require Foswiki::ListIterator;
    return new Foswiki::ListIterator( \@users );
}

# Lock the htpasswd semaphore file (create if it does not exist)
# Returns a file handle that you can later simply close with _unlockPasswdFile
sub _lockPasswdFile {
    my $operator = @_;
    my $lockFileName = $Foswiki::cfg{WorkingDir} . '/htpasswd.lock';

    sysopen(my $fh, $lockFileName, O_RDWR|O_CREAT, 0666)
      || throw Error::Simple(
        $lockFileName . 
        ' open or create password lock file failed -' . 
        'check access rights: ' . $! );
    flock $fh, $operator;
    
    return $fh;
}

# Unlock the semaphore file. You must pass the filehandle for the lock file
# which was returned by _lockPasswdFile
sub _unlockPasswdFile {
    my $fh = shift;
    close($fh);
}

# Read the password file. The content of the file is cached in
# the password object.
# We put a shared lock while reading if requested to prevent
# other processes from writing while we read but still allows
# parallel reading. The caller must never request a shared lock
# if there is already an exclusive lock.
sub _readPasswd {
    my ( $this, $lockShared ) = @_;

    return $this->{passworddata} if ( defined( $this->{passworddata} ) );

    my $data = {};
    if ( !-e $Foswiki::cfg{Htpasswd}{FileName} ) {
        return $data;
    }

    $lockShared |= 0;
    my $lockHandle = _lockPasswdFile( LOCK_SH ) if $lockShared;
    my $IN_FILE;
    open( $IN_FILE, '<', "$Foswiki::cfg{Htpasswd}{FileName}" )
      || throw Error::Simple(
        $Foswiki::cfg{Htpasswd}{FileName} . ' open failed: ' . $! );
    my $line = '';
    while ( defined( $line = <$IN_FILE> ) ) {
        if ( $Foswiki::cfg{Htpasswd}{Encoding} eq 'md5' ) {    # htdigest format
            if ( $line =~ /^(.*?):(.*?):(.*?)(?::(.*))?$/ ) {

                # implicit untaint OK; data from htpasswd
                $data->{$1}->{pass} = $3;
                $data->{$1}->{emails} = $4 || '';
            }
        }
        else {                                                 # htpasswd format
            if ( $line =~ /^(.*?):(.*?)(?::(.*))?$/ ) {

                # implicit untaint OK; data from htpasswd
                $data->{$1}->{pass} = $2;
                $data->{$1}->{emails} = $3 || '';
            }
        }
    }
    close($IN_FILE);
    _unlockPasswdFile( $lockHandle ) if $lockShared;
    
    $this->{passworddata} = $data;
    return $data;
}

# Dumps the memory password database to a newline separated string
sub _dumpPasswd {
    my $db = shift;
    my @entries;
    foreach my $login ( sort( keys(%$db) ) ) {
        my $entry = "$login:";
        if ( $Foswiki::cfg{Htpasswd}{Encoding} eq 'md5' ) {

            # htdigest format
            $entry .= "$Foswiki::cfg{AuthRealm}:";
        }
        $entry .= $db->{$login}->{pass} . ':' . $db->{$login}->{emails};
        push( @entries, $entry );
    }
    return join( "\n", @entries ) . "\n";
}

sub _savePasswd {
    my $db = shift;

    my $content = _dumpPasswd($db);
    
    umask(077);
    my $fh;

    open( $fh, '>', $Foswiki::cfg{Htpasswd}{FileName} )
      || throw Error::Simple(
          "$Foswiki::cfg{Htpasswd}{FileName} open failed: $!" );
    print $fh $content;
    
    close($fh);
}

sub encrypt {
    my ( $this, $login, $passwd, $fresh ) = @_;

    $passwd ||= '';

    if ( $Foswiki::cfg{Htpasswd}{Encoding} eq 'sha1' ) {
        my $encodedPassword = '{SHA}' . Digest::SHA::sha1_base64($passwd) . '=';

        # don't use chomp, it relies on $/
        $encodedPassword =~ s/\s+$//;
        return $encodedPassword;

    }
    elsif ( $Foswiki::cfg{Htpasswd}{Encoding} eq 'crypt' ) {

        # by David Levy, Internet Channel, 1997
        # found at http://world.inch.com/Scripts/htpasswd.pl.html

        my $salt;
        $salt = $this->fetchPass($login) unless $fresh;
        if ( $fresh || !$salt ) {
            my @saltchars = ( 'a' .. 'z', 'A' .. 'Z', '0' .. '9', '.', '/' );
            $salt =
                $saltchars[ int( rand( $#saltchars + 1 ) ) ]
              . $saltchars[ int( rand( $#saltchars + 1 ) ) ];
        }
        return crypt( $passwd, substr( $salt, 0, 2 ) );

    }
    elsif ( $Foswiki::cfg{Htpasswd}{Encoding} eq 'md5' ) {

        # SMELL: what does this do if we are using a htpasswd file?
        my $toEncode = "$login:$Foswiki::cfg{AuthRealm}:$passwd";
        return Digest::MD5::md5_hex($toEncode);

    }
    elsif ( $Foswiki::cfg{Htpasswd}{Encoding} eq 'crypt-md5' ) {
        my $salt;
        $salt = $this->fetchPass($login) unless $fresh;
        if ( $fresh || !$salt ) {
            $salt = '$1$';
            my @saltchars = ( '.', '/', 0 .. 9, 'A' .. 'Z', 'a' .. 'z' );
            foreach my $i ( 0 .. 7 ) {

                # generate a salt not only from rand() but also mixing
                # in the users login name: unecessary
                # SMELL - see PasswordTests.pm for failure on OSX
                $salt .= $saltchars[
                  (
                      int( rand( $#saltchars + 1 ) ) +
                        $i +
                        ord( substr( $login, $i % length($login), 1 ) ) )
                  % ( $#saltchars + 1 )
                ];
            }
        }
        my $ret = crypt( $passwd, substr( $salt, 0, 11 ) );

        return $ret;

    }
    elsif ( $Foswiki::cfg{Htpasswd}{Encoding} eq 'plain' ) {
        return $passwd;

    }
    die 'Unsupported password encoding ' . $Foswiki::cfg{Htpasswd}{Encoding};
}

sub fetchPass {
    my ( $this, $login ) = @_;
    my $ret = 0;

    if ($login) {
        try {
            # Read passwords with shared lock
            my $db = $this->_readPasswd( 1 );
            if ( exists $db->{$login} ) {
                $ret = $db->{$login}->{pass};
            }
            else {
                $this->{error} = 'Login invalid';
                $ret = undef;
            }
        }
        catch Error::Simple with {
            $this->{error} = $!;
        };
    }
    else {
        $this->{error} = 'No user';
    }
    return $ret;
}

sub setPassword {
    my ( $this, $login, $newUserPassword, $oldUserPassword ) = @_;
    ASSERT($login) if DEBUG;
    if ( defined($oldUserPassword) ) {
        unless ( $oldUserPassword eq '1' ) {
            return 0 unless $this->checkPassword( $login, $oldUserPassword );
        }
    }
    elsif ( $this->fetchPass($login) ) {
        $this->{error} = $login . ' already exists';
        return 0;
    }

    my $lockHandle;
    try {
        $lockHandle = _lockPasswdFile( LOCK_EX );
        # Read password without shared lock as we have already exclusive lock
        my $db = $this->_readPasswd( 0 );
        $db->{$login}->{pass} = $this->encrypt( $login, $newUserPassword, 1 );
        $db->{$login}->{emails} ||= '';
        _savePasswd( $db );
    }
    catch Error::Simple with {
        my $e = shift;
        $this->{error} = $!;
        print STDERR "ERROR: failed to resetPassword - $! ($e)";
        $this->{error} = 'unknown error in resetPassword'
          unless ( $this->{error} && length( $this->{error} ) );
        return undef;
    }
    finally {
        _unlockPasswdFile($lockHandle) if $lockHandle;
    };

    $this->{error} = undef;
    return 1;
}

sub removeUser {
    my ( $this, $login ) = @_;
    my $result = undef;
    $this->{error} = undef;

    my $lockHandle;
    try {
        $lockHandle = _lockPasswdFile( LOCK_EX );
        # Read password without shared lock as we have already exclusive lock
        my $db = $this->_readPasswd( 0 );
        unless ( $db->{$login} ) {
            $this->{error} = 'No such user ' . $login;
        }
        else {
            delete $db->{$login};
            _savePasswd( $db );
            $result = 1;
        }
    }
    catch Error::Simple with {
        $this->{error} = shift->{-text};
    }
    finally {
        _unlockPasswdFile($lockHandle) if $lockHandle;
    };
    
    return $result;
}

sub checkPassword {
    my ( $this, $login, $password ) = @_;
    my $encryptedPassword = $this->encrypt( $login, $password );

    $this->{error} = undef;

    my $pw = $this->fetchPass($login);
    return 0 unless defined $pw;

    # $pw will be 0 if there is no pw

    return 1 if ( $pw && ( $encryptedPassword eq $pw ) );

    # pw may validly be '', and must match an unencrypted ''. This is
    # to allow for sysadmins removing the password field in .htpasswd in
    # order to reset the password.
    return 1 if ( defined $password && $pw eq '' && $password eq '' );

    $this->{error} = 'Invalid user/password';
    return 0;
}

sub isManagingEmails {
    return 1;
}

sub getEmails {
    my ( $this, $login ) = @_;

    # first try the mapping cache
    # read passwords with shared lock
    my $db = $this->_readPasswd( 1 );
    if ( $db->{$login}->{emails} ) {
        return split( /;/, $db->{$login}->{emails} );
    }

    return;
}

sub setEmails {
    my $this   = shift;
    my $login  = shift;
    my $emails = join( ';', @_ );
    ASSERT($login) if DEBUG;
    my $lockHandle;

    try {
        $lockHandle = _lockPasswdFile( LOCK_EX );
        # Read password without shared lock as we have already exclusive lock
        my $db = $this->_readPasswd( 0 );
        unless ( $db->{$login} ) {

            # Make sure the user is in the auth system, by adding them with
            # a null password if not.
            $db->{$login}->{pass} = '';
        }

        $db->{$login}->{emails} = $emails;

        _savePasswd( $db );
    }
    finally {
        _unlockPasswdFile($lockHandle) if $lockHandle;
    };
    return 1;
}

# Searches the password DB for users who have set this email.
sub findUserByEmail {
    my ( $this, $email ) = @_;
    my $logins = [];
    # read passwords with shared lock
    my $db     = $this->_readPasswd( 1 );
    while ( my ( $k, $v ) = each %$db ) {
        my %ems = map { $_ => 1 } split( ';', $v->{emails} );
        if ( $ems{$email} ) {
            push( @$logins, $k );
        }
    }
    return $logins;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
