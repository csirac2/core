# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::LoginManager::TemplateLogin

This is a login manager that you can specify in the security setup section of
[[%SCRIPTURL{"configure"}%][configure]]. It provides users with a
template-based form to enter usernames and passwords, and works with the
PasswordManager that you specify to verify those passwords.

Subclass of Foswiki::LoginManager; see that class for documentation of the
methods of this class.

=cut

package Foswiki::LoginManager::TemplateLogin;

use strict;
use Assert;

use Foswiki::LoginManager ();
our @ISA = ('Foswiki::LoginManager');

=begin TML

---++ ClassMethod new ($session, $impl)

Construct the TemplateLogin object

=cut

sub new {
    my ( $class, $session ) = @_;
    my $this = $class->SUPER::new($session);
    $session->enterContext('can_login');
    if ( $Foswiki::cfg{Sessions}{ExpireCookiesAfter} ) {
        $session->enterContext('can_remember_login');
    }
    if ( $Foswiki::cfg{TemplateLogin}{PreventBrowserRememberingPassword} ) {
        $session->enterContext('no_auto_complete_login');
    }
    return $this;
}

# Pack key request parameters into a single value
# Used for passing meta-information about the request
# through a URL (without requiring passthrough)
sub _packRequest {
    my ($uri, $method, $action) = @_;
    return '' unless $uri;
    if (ref($uri)) { # first parameter is a $session
        my $r = $uri->{request};
        $uri = $r->uri();
        $method = $r->method();
        $action = $r->action();
    }
    return "$method,$action,$uri";
}

# Unpack single value to key request parameters
sub _unpackRequest {
    my $packed = shift || '';
    my ($method, $action, $uri) = split(',', $packed, 3);
    return ($uri, $method, $action);
}

=begin TML

---++ ObjectMethod forceAuthentication () -> $boolean

method called when authentication is required - redirects to (...|view)auth
Triggered on auth fail

=cut

sub forceAuthentication {
    my $this    = shift;
    my $session = $this->{session};

    unless ( $session->inContext('authenticated') ) {
        my $query = $session->{request};

        # Redirect with passthrough so we don't lose the original query params
        my $session = $this->{session};
        my $topic   = $session->{topicName};
        my $web     = $session->{webName};
        my $url     = $session->getScriptUrl( 0, 'login', $web, $topic );
        $query->param( -name => 'foswiki_origin',
                       -value => _packRequest($session) );
        $session->redirect( $url, 1 );    # with passthrough
        return 1;
    }
    return 0;
}

=begin TML

---++ ObjectMethod loginUrl () -> $loginUrl

Overrides LoginManager. Content of a login link.

=cut

sub loginUrl {
    my $this    = shift;
    my $session = $this->{session};
    my $topic   = $session->{topicName};
    my $web     = $session->{webName};
    return $session->getScriptUrl(
        0, 'login', $web, $topic,
        foswiki_origin => _packRequest($session)
       );
}

=begin TML

---++ ObjectMethod login( $query, $session )

If a login name and password have been passed in the query, it
validates these and if authentic, redirects to the original
script. If there is no username in the query or the username/password is
invalid (validate returns non-zero) then it prompts again.

If a flag to remember the login has been passed in the query, then the
corresponding session variable will be set. This will result in the
login cookie being preserved across browser sessions.

The password handler is expected to return a perl true value if the password
is valid. This return value is stored in a session variable called
VALIDATION. This is so that password handlers can return extra information
about the user, such as a list of Wiki groups stored in a separate
database, that can then be displayed by referring to
%<nop>SESSION_VARIABLE{"VALIDATION"}%

=cut

sub login {
    my ( $this, $query, $session ) = @_;
    my $users = $session->{users};

    my $origin     = $query->param('foswiki_origin');
    my ($origurl, $origmethod, $origaction) = _unpackRequest($origin);
    my $loginName  = $query->param('username');
    my $loginPass  = $query->param('password');
    my $remember   = $query->param('remember');

    # Eat these so there's no risk of accidental passthrough
    $query->delete( 'foswiki_origin', 'username', 'password', 'validation_key' );

    # UserMappings can over-ride where the login template is defined
    my $loginTemplate = $users->loginTemplateName();    #defaults to login.tmpl
    my $tmpl =
      $session->templates->readTemplate( $loginTemplate, $session->getSkin() );

    my $banner = $session->templates->expandTemplate('LOG_IN_BANNER');
    my $note   = '';
    my $topic  = $session->{topicName};
    my $web    = $session->{webName};

    my $cgisession = $this->{_cgisession};

    $cgisession->param( 'REMEMBER', $remember ) if $cgisession;
    if (   $cgisession
        && $cgisession->param('AUTHUSER')
        && $loginName
        && $loginName ne $cgisession->param('AUTHUSER') )
    {
        $banner = $session->templates->expandTemplate('LOGGED_IN_BANNER');
        $note   = $session->templates->expandTemplate('NEW_USER_NOTE');
    }

    my $error = '';

    if ($loginName) {
        my $validation = $users->checkPassword( $loginName, $loginPass );
        $error = $users->passwordError();

        if ($validation) {

            # SUCCESS our user is authenticated. Note that we may already
            # have been logged in by the userLoggedIn call in loadSession,
            # becuase the username-password URL params are the same as
            # the params passed to this script, and they will be used
            # in loadSession if no other user info is available.
            $this->userLoggedIn($loginName);
            $session->logEvent( 'login', $web . '.' . $topic,
                                "AUTHENTICATION SUCCESS - $loginName - " );

            # remove the sudo param - its only to tell TemplateLogin
            # that we're using BaseMapper..
            $query->delete('sudo');

            $cgisession->param( 'VALIDATION', $validation ) if $cgisession;
            if ( !$origurl || $origurl eq $query->url() ) {
                $origurl = $session->getScriptUrl( 0, 'view', $web, $topic );
            }
            else {

                # Unpack params encoded in the origurl and restore them
                # to the query. If they were left in the query string they
                # would be lost if we redirect with passthrough.
                if ( $origurl =~ s/\?(.*)// ) {
                    foreach my $pair ( split( /[&;]/, $1 ) ) {
                        if ( $pair =~ /(.*?)=(.*)/ ) {
                            $query->param( $1, TAINT($2) );
                        }
                    }
                }
                # Restore the action too
                $query->action($origaction) if $origaction;
            }

            # If the method used to access origUrl was POST, we want to
            # enable passthrough on this redirect, so that all the parameters
            # get restored. That willhappen by default because the login
            # script is submitted method=POST. However some GET targets 
            # don't support passthrough, and we have to make sure we
            # suppress redirect for these targets.
            $session->redirect( $origurl, uc($origmethod) eq 'POST' );
            return;
        }
        else {
            # Tasks:Item1029  After much discussion, the 403 code is not
            # used for authentication failures. RFC states: "Authorization
            # will not help and the request SHOULD NOT be repeated" which
            # is not the situation here.  
            $session->{response}->status(200);
            $session->logEvent( 'login', $web . '.' . $topic,
                                "AUTHENTICATION FAILURE - $loginName - " );
            $banner = $session->templates->expandTemplate('UNRECOGNISED_USER');
        }
    }
    else {
        # If the loginName is unset, then the request was likely a perfectly
        # valid GET call to http://foswiki/bin/login
        # 4xx cannot be a correct status, as we want the user to retry the
        # same URL with a different login/password
        $session->{response}->status(200);
    }

    # TODO: add JavaScript password encryption in the template
    $origurl ||= '';

    # Set session preferences that will be expanded when the login
    # template is instantiated
    $session->{prefs}->setSessionPreferences(
        FOSWIKI_ORIGINAL => Foswiki::entityEncode(
            _packRequest($origurl, $origmethod, $origaction)),
        BANNER     => $banner,
        NOTE       => $note,
        ERROR      => $error
    );

    my $topicObject = Foswiki::Meta->new( $session, $web, $topic );
    $tmpl = $topicObject->expandMacros($tmpl);
    $tmpl = $topicObject->renderTML($tmpl);
    $tmpl =~ s/<nop>//g;
    $session->writeCompletePage($tmpl);
}

1;
__DATA__
Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. All Rights Reserved.
Foswiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2005-2006 TWiki Contributors. All Rights Reserved.
Copyright (C) 2005 Greg Abbas, twiki@abbas.org

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
