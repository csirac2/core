# See bottom of file for license and copyright information

# This is both the factory for UIs and the base class of UI constructors.
# A UI is the V part of the MVC model used in configure.
#
# Each structural entity in a configure screen has a UI type, either
# stored directly in the entity or indirectly in the type associated
# with a value. The UI type is used to guide a visitor which is run
# over the structure to generate the UI.
#
package Foswiki::Configure::UI;

use strict;
use warnings;
use File::Spec ();
use FindBin    ();

our $totwarnings;
our $toterrors;
our $firsttime;

our $MESSAGE_TYPE = {
    NONE                      => ( 1 << 0 ),    # 1
    OK                        => ( 1 << 1 ),    # 2
    PASSWORD_CHANGED          => ( 1 << 2 ),    # 4
    PASSWORD_NOT_SET          => ( 1 << 3 ),    # 8
    PASSWORD_INCORRECT        => ( 1 << 4 ),    # 16
    PASSWORD_CONFIRM_NO_MATCH => ( 1 << 5 ),    # 32
    PASSWORD_EMPTY            => ( 1 << 6 ),    # 64
};
my $DEFAULT_TEMPLATE_PARSER = 'SimpleFreeMarker';
my $templateParser;

sub reset {
    my ($isFirstTime) = @_;

    $firsttime   = $isFirstTime;
    $toterrors   = 0;
    $totwarnings = 0;
}

sub new {
    my ( $class, $item ) = @_;

    Carp::confess unless $item;

    my $this = bless( { item => $item }, $class );

    $FindBin::Bin =~ /(.*)/;
    $this->{bin} = $1;
    my @root = File::Spec->splitdir( $this->{bin} );
    pop(@root);

    # SMELL: Force a trailing separator - Linux and Windows are inconsistent
    $this->{root} = File::Spec->catfile( @root, 'x' );
    chop $this->{root};

    $this->{filecount} =
      0;    # Used by recursive checkTreePerms to count files and limit

    return $this;
}

sub findRepositories {
    my $this = shift;
    unless ( defined( $this->{repositories} ) ) {
        my $replist = '';
        $replist .= $Foswiki::cfg{ExtensionsRepositories}
          if defined $Foswiki::cfg{ExtensionsRepositories};
        $replist = ";$replist;";
        while (
            $replist =~ s/[;\s]+(.*?)=\((.*?),(.*?)(?:,(.*?),(.*?))?\)\s*;/;/ )
        {
            push(
                @{ $this->{repositories} },
                { name => $1, data => $2, pub => $3, user => $4, pass => $5 }
            );
        }
    }
}

sub getRepository {
    my ( $this, $reponame ) = @_;
    foreach my $place ( @{ $this->{repositories} } ) {
        return $place if $place->{name} eq $reponame;
    }
    return;
}

# Static UI factory
# UIs *must* exist
sub loadUI {
    my ( $id, $item ) = @_;
    $id = 'Foswiki::Configure::UIs::' . $id;
    my $ui;

    eval "use $id (); \$ui = new $id(\$item);";

    return if ( !$ui && $@ );

    return $ui;
}

# Static checker factory
# Checkers *need not* exist
sub loadChecker {
    my ( $id, $item ) = @_;
    $id =~ s/}{/::/g;
    $id =~ s/[}{]//g;
    $id =~ s/'//g;
    $id =~ s/-/_/g;
    my $checkClass = 'Foswiki::Configure::Checkers::' . $id;
    my $checker;

    eval "use $checkClass (); \$checker = new $checkClass(\$item);";

    # Can't locate errors are OK
    die $@ if ( $@ && $@ !~ /Can't locate / );

    return $checker;
}

# Returns a response object as described in Foswiki::Net
sub getUrl {
    my ( $this, $url ) = @_;

    require Foswiki::Net;
    my $tn       = new Foswiki::Net();
    my $response = $tn->getExternalResource($url);
    $tn->finish();
    return $response;
}

# STATIC Used by a whole bunch of things that just need to show a key-value row
# in a table (called as a method, i.e. with class as first parameter)
sub setting {
    my $this = shift;
    my $key  = shift;

    my $data = join( ' ', @_ ) || ' ';

    return CGI::Tr( {}, CGI::th( {}, $key ) . CGI::td( {}, $data ) );
}

# encode a string to make a simplified unique ID useable
# as an HTML id or anchor
sub makeID {
    my ( $this, $str ) = @_;

    $str =~ s/\s(\w)/uc($1)/ge;
    $str =~ s/\W//g;
    return $str;
}

sub NOTE {
    my $this = shift;
    return CGI::div( { class => 'configureInfo' },
        CGI::span( {}, join( "\n", @_ ) ) );
}

sub NOTE_OK {
    my $this = shift;
    return CGI::div( { class => 'configureOk' },
        CGI::span( {}, join( "\n", @_ ) ) );
}

# a warning
sub WARN {
    my $this = shift;
    $this->{item}->inc('warnings');
    $totwarnings++;
    return CGI::div( { class => 'foswikiAlert configureWarn' },
        CGI::span( {}, CGI::strong( {}, 'Warning: ' ) . join( "\n", @_ ) ) );
}

# an error
sub ERROR {
    my $this = shift;
    $this->{item}->inc('errors');
    $toterrors++;
    return CGI::div( { class => 'foswikiAlert configureError' },
        CGI::span( {}, CGI::strong( {}, 'Error: ' ) . join( "\n", @_ ) ) );
}

# Used in place of CGI::hidden, which is broken in some versions.
# HTML encodes the value
sub hidden {
    my ( $name, $value ) = @_;
    $name ||= '';
    $name =~ s/([[\x01-\x09\x0b\x0c\x0e-\x1f"%&'*<=>@[_\|])/
      '&#'.ord($1).';'/ge;
    $value ||= '';
    $value =~ s/([[\x01-\x09\x0b\x0c\x0e-\x1f"%&'*<=>@[_\|])/
      '&#'.ord($1).';'/ge;
    return "<input type='hidden' name='$name' value='$value' />";
}

# URL encode a value.
sub urlEncode {
    my ( $this, $value ) = @_;
    $value =~ s/([^0-9a-zA-Z-_.:~!*'\/])/'%'.sprintf('%02x',ord($1))/ge;
    return $value;
}

=pod

StaticMethod authorised () -> ($isAuthorized, $messageType)

Invoked to confirm authorisation, and handle password changes. The password
is changed in $Foswiki::cfg, a change which is then detected and written when
the configuration file is actually saved.

=cut

sub authorised {

    my $pass    = $Foswiki::query->param('cfgAccess');
    my $newPass = $Foswiki::query->param('newCfgP');

    # Change the password if so requested
    if ( $Foswiki::query->param('changePassword') ) {
        my $confPass = $Foswiki::query->param('confCfgP') || '';
        if ( !$newPass ) {
            return ( 0, $MESSAGE_TYPE->{PASSWORD_EMPTY} );
        }
        if ( $newPass ne $confPass ) {
            return ( 0, $MESSAGE_TYPE->{PASSWORD_CONFIRM_NO_MATCH} );
        }
        $Foswiki::cfg{Password} = _encode($newPass);
        return ( 1, $MESSAGE_TYPE->{PASSWORD_CHANGED} );
    }

    if ( !defined($pass) && $Foswiki::query->param('checkCfpP') ) {

        # first time, but using reload a password has been passed at least once

        my $confPass = $Foswiki::query->param('confCfgP');
        if ( $newPass ne $confPass ) {
            return ( 0, $MESSAGE_TYPE->{PASSWORD_CONFIRM_NO_MATCH} );
        }
        if ( !$newPass || !$confPass ) {
            return ( 0, $MESSAGE_TYPE->{PASSWORD_NOT_SET} );
        }
        $Foswiki::cfg{Password} = _encode($newPass);
        return ( 1, $MESSAGE_TYPE->{PASSWORD_CHANGED} );
    }

    # The first time we get here is after the "next" button is hit. A password
    # won't have been defined yet; so the authorisation must fail to force
    # a prompt.
    if ( !defined($pass) ) {
        return ( 0, $MESSAGE_TYPE->{NONE} );
    }

    # If we get this far, a password has been given. Check it.
    if ( !$Foswiki::cfg{Password} && !$Foswiki::query->param('confCfgP') ) {

        return ( 0, $MESSAGE_TYPE->{PASSWORD_NOT_SET} );
    }

    # If a password has been defined, check that it has been used
    if (
        !$pass
        || ( $Foswiki::cfg{Password}
            && crypt( $pass, $Foswiki::cfg{Password} ) ne
            $Foswiki::cfg{Password} )
      )
    {
        return ( 0, $MESSAGE_TYPE->{PASSWORD_INCORRECT} );
    }

    # Password is correct, or no password defined

    return ( 1, $MESSAGE_TYPE->{OK} );
}

sub collectMessages {
    my $this = shift;
    my ($item) = @_;

    my $errors   = $item->{errors}   || 0;
    my $warnings = $item->{warnings} || 0;

    return ( $errors, $warnings );
}

sub _encode {
    my $pass = shift;
    my @saltchars = ( 'a' .. 'z', 'A' .. 'Z', '0' .. '9', '.', '/' );
    my $salt =
        $saltchars[ int( rand( $#saltchars + 1 ) ) ]
      . $saltchars[ int( rand( $#saltchars + 1 ) ) ];
    return crypt( $pass, $salt );
}

# Return a string of settingBlocks giving the status of various
# required modules.
# Either takes an array of hashes, or parameters in a hash.
# Each module hash needs:
# name - e.g. Car::Wreck
# usage - description of what it's for
# dispostion - 'required', 'recommended'
# minimumVersion - lowest acceptable $Module::VERSION
#
sub checkPerlModules {
    my ( $this, $useTR, $mods ) = @_;

    my $e = '';
    foreach my $mod (@$mods) {
        $mod->{minimumVersion} ||= 0;
        $mod->{disposition}    ||= '';
        my $n = '';
        my $mod_version;

        # require instead of use = see Bugs:Item4585
        eval 'require ' . $mod->{name};
        if ($@) {
            $n = 'Not installed. ' . $mod->{usage};
        }
        else {
            no strict 'refs';
            eval '$mod_version = $' . $mod->{name} . '::VERSION';
            $mod_version ||= 0;
            $mod_version =~ s/(\d+(\.\d*)?).*/$1/;    # keep 99.99 style only
            use strict 'refs';
            if ( $mod_version < $mod->{minimumVersion} ) {
                $n = $mod_version || 'Unknown version';
                $n .=
                    ' installed. Version '
                  . $mod->{minimumVersion} . ' '
                  . $mod->{disposition};
                $n .= ' ' . $mod->{usage} if $mod->{usage};
            }
        }
        if ($n) {
            if ( $mod->{disposition} eq 'required' ) {
                $n = $this->ERROR($n);
            }
            elsif ( $mod->{disposition} eq 'recommended' ) {
                $n = $this->WARN($n);
            }
            else {
                $n = $this->NOTE($n);
            }
        }
        else {
            $mod_version ||= 'Unknown version';
            $n = $this->NOTE( $mod_version . ' installed' );
            $n .= ' ' . $mod->{usage} if $mod->{usage};
        }
        if ($useTR) {
            $e .= $this->setting( $mod->{name}, $n );
        }
        else {
            $e .=
"<div class='configureSetting'><code>$mod->{name}:</code> $n</div>";
        }
    }
    return $e;
}

sub checkPerlModule {
    my ( $this, $module, $usage, $version ) = @_;
    my $error = $this->checkPerlModules(
        0,
        [
            {
                name           => $module,
                minimumVersion => $version,
                usage          => $usage
            }
        ]
    );
    return $error;
}

sub getTemplateParser {
    if ( !$templateParser ) {

        # get the template parser
        eval 'use Foswiki::Configure::TemplateParser ()';
        if ($@) {
            die "TemplateParser could not be loaded:" . join( " ", $@ );
        }

        $templateParser = Foswiki::Configure::TemplateParser::getParser(
            $DEFAULT_TEMPLATE_PARSER);

        # skin can be set using url parameter 'skin'
        my $skin = $Foswiki::query->param('skin') if $Foswiki::query;
        $templateParser->setSkin($skin) if $skin;
    }
    return $templateParser;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
