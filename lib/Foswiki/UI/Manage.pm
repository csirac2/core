# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::UI::Manage

UI functions for web, topic and user management. The =manage= script is
a dispatcher for a number of admin functions that are gathered
in one place.

=cut

package Foswiki::UI::Manage;

use strict;
use warnings;
use Assert;
use Error qw( :try );

use Foswiki                ();
use Foswiki::UI            ();
use Foswiki::OopsException ();
use Foswiki::Sandbox       ();

=begin TML

---++ StaticMethod manage( $session )

=manage= command handler.
This method is designed to be invoked via the =UI::run= method.

=cut

sub manage {
    my $session = shift;

    my $action = $session->{request}->param('action');

    # Dispatch to action function
    if ( defined $action ) {
        my $method = 'Foswiki::UI::Manage::_action_' . $action;

        if ( defined &$method ) {
            no strict 'refs';
            &$method($session);
        }
        else {
            throw Foswiki::OopsException(
                'attention',
                def    => 'unrecognized_action',
                params => [$action]
            );
        }
    }
    else {
        throw Foswiki::OopsException( 'attention', def => 'missing_action' );
    }
}

sub _action_changePassword {
    my $session = shift;
    require Foswiki::UI::Passwords;
    Foswiki::UI::Passwords::changePasswordAndOrEmail($session);
}

sub _action_resetPassword {
    my $session = shift;
    require Foswiki::UI::Passwords;
    Foswiki::UI::Passwords::resetPassword($session);
}

sub _action_bulkRegister {
    my $session = shift;
    require Foswiki::UI::Register;
    Foswiki::UI::Register::bulkRegister($session);
}

sub _action_deleteUserAccount {
    my $session = shift;

    require Foswiki::UI::Register;
    Foswiki::UI::Register::deleteUser($session);
}

sub _action_addUserToGroup {
    my $session = shift;

    require Foswiki::UI::Register;
    Foswiki::UI::Register::addUserToGroup($session);
}

sub _action_removeUserFromGroup {
    my $session = shift;

    require Foswiki::UI::Register;
    Foswiki::UI::Register::removeUserFromGroup($session);
}

sub _isValidHTMLColor {
    my $c = shift;
    return $c =~
m/^(#[0-9a-f]{6}|black|silver|gray|white|maroon|red|purple|fuchsia|green|lime|olive|yellow|navy|blue|teal|aqua)/i;

}

sub _action_createweb {
    my $session = shift;

    my $topicName = $session->{topicName};
    my $webName   = $session->{webName};
    my $query     = $session->{request};
    my $cUID      = $session->{user};

    my $newWeb = $query->param('newweb');

    # Validate and untaint
    $newWeb = Foswiki::Sandbox::untaint(
        $newWeb,
        sub {
            my $newWeb = shift;
            unless ($newWeb) {
                throw Foswiki::OopsException( 'attention',
                    def => 'web_missing' );
            }
            unless ( Foswiki::isValidWebName( $newWeb, 1 ) ) {
                throw Foswiki::OopsException(
                    'attention',
                    def    => 'invalid_web_name',
                    params => [$newWeb]
                );
            }
            return $newWeb;
        }
    );

    # For hierarchical webs, check that parent web exists
    my $parent = undef;    # default is root if no parent web
    if ( $newWeb =~ m|^(.*)[./](.*?)$| ) {
        $parent = $1;
    }
    if ($parent) {
        unless ( $session->webExists($parent) ) {
            throw Foswiki::OopsException(
                'attention',
                def    => 'web_creation_error',
                params => [
                    $newWeb,
                    $session->i18n->maketext(
                        'The [_1] web does not exist', $parent
                    )
                ]
            );
        }
    }

    # check permission, user authorized to create web here?
    my $webObject = Foswiki::Meta->new( $session, $parent );
    unless ( $webObject->haveAccess('CHANGE') ) {
        throw Foswiki::OopsException(
            'accessdenied',
            def    => 'topic_access',
            web    => $parent,
            params => [ 'CHANGE', $Foswiki::Meta::reason ]
        );
    }

    my $baseWeb = $query->param('baseweb') || '';
    $baseWeb =~ s#\.#/#g;    # normalizeWebTopicName does this

    # Validate the base web name
    $baseWeb = Foswiki::Sandbox::untaint(
        $baseWeb,
        sub {
            my $baseWeb = shift;
            unless ( Foswiki::isValidWebName( $baseWeb, 1 ) ) {
                throw Foswiki::OopsException(
                    'attention',
                    def    => 'invalid_web_name',
                    params => [$baseWeb]
                );
            }
            return $baseWeb;
        }
    );

    unless ( $session->webExists($baseWeb) ) {
        throw Foswiki::OopsException(
            'attention',
            def    => 'base_web_missing',
            params => [$baseWeb]
        );
    }

    if ( $session->webExists($newWeb) ) {
        throw Foswiki::OopsException(
            'attention',
            def    => 'web_exists',
            params => [$newWeb]
        );
    }

    Foswiki::UI::checkValidationKey($session);

    # Get options from the form (only those options that are already
    # set in the template WebPreferences topic are changed, so we can
    # just copy everything)
    my $me   = $session->{users}->getWikiName($cUID);
    my $opts = {

        # Set permissions such that only the creating user can modify the
        # web preferences
        ALLOWTOPICCHANGE => '%USERSWEB%.'.$me,
        ALLOWTOPICRENAME => '%USERSWEB%.'.$me,
        ALLOWWEBCHANGE   => '%USERSWEB%.'.$me,
        ALLOWWEBRENAME   => '%USERSWEB%.'.$me,
    };
    foreach my $p ( $query->param() ) {
        $opts->{ uc($p) } = $query->param($p);
    }

    my $webBGColor = $opts->{'WEBBGCOLOR'} || '';
    unless ( _isValidHTMLColor($webBGColor) ) {
        throw Foswiki::OopsException(
            'attention',
            def    => 'invalid_web_color',
            params => [$webBGColor]
        );
    }

    $webObject = Foswiki::Meta->new( $session, $newWeb );
    try {
        $webObject->populateNewWeb( $baseWeb, $opts );
    }
    catch Error::Simple with {
        throw Foswiki::OopsException(
            'attention',
            def    => 'web_creation_error',
            params => [ $newWeb, shift->{-text} ]
        );
    };

    my $newTopic = $query->param('newtopic');

    if ($newTopic) {

        # Validate
        $newTopic = Foswiki::Sandbox::untaint(
            $newTopic,
            sub {
                my ( $topic, $nonww ) = @_;
                if ( !Foswiki::isValidTopicName( $topic, $nonww ) ) {
                    throw Foswiki::OopsException(
                        'attention',
                        web    => $newWeb,
                        topic  => $newTopic,
                        def    => 'not_wikiword',
                        params => [$topic]
                    );
                }
                return $topic;
            },
            Foswiki::isTrue( $query->param('nonwikiword') )
        );
    }

    # everything OK, redirect to last message
    throw Foswiki::OopsException(
        'attention',
        status => 200,
        web    => $newWeb,
        topic  => $newTopic,
        def    => 'created_web'
    );
}

=begin TML

---++ StaticMethod _action_create()

Creates a topic to new topic with name passed in query param 'topic'.
Creates an exception when the topic name is not valid; the topic name does not have to be a WikiWord if parameter 'nonwikiword' is set to 'on'.
Redirects to the edit screen.

Copy an existing topic using:
	<form action="%SCRIPTURL{manage}%/%WEB%/">
	<input type="text" name="topic" class="foswikiInputField" value="%TOPIC%Copy" size="30">
	<input type="hidden" name="action" value="create" />
	<input type="hidden" name="templatetopic" value="%TOPIC%" />
	<input type="hidden" name="action_save" value="1" />
	...
	</form>

=cut

sub _action_create {
    my ($session) = @_;

    my $query = $session->{request};

    # distill web and topic from Web.Topic input
    my ( $newWeb, $newTopic ) =
      Foswiki::Func::normalizeWebTopicName( $session->{webName},
        $query->param('topic') );

    # Validate topic name
    $newTopic = Foswiki::Sandbox::untaint(
        $newTopic,
        sub {
            my ($topic) = @_;
            unless ($topic) {
                throw Foswiki::OopsException(
                    'attention',
                    web    => $newWeb,
                    topic  => $newTopic,
                    def    => 'empty_topic_name',
                    params => undef
                );
            }
            unless (
                Foswiki::isValidTopicName(
                    $topic, Foswiki::isTrue( $query->param('nonwikiword') )
                )
              )
            {
                throw Foswiki::OopsException(
                    'attention',
                    web    => $newWeb,
                    topic  => $newTopic,
                    def    => 'not_wikiword',
                    params => [$newTopic]
                );
            }
            return $topic;
        }
    );

    # Validate web name
    $newWeb = Foswiki::Sandbox::untaint(
        $newWeb,
        sub {
            my ($web) = @_;
            unless ( $session->webExists($web) ) {
                throw Foswiki::OopsException(
                    'accessdenied',
                    status => 403,
                    def    => 'no_such_web',
                    web    => $web,
                    params => ['create']
                );
            }
            return $web;
        }
    );

    # user must have change access
    my $topicObject = Foswiki::Meta->new( $session, $newWeb, $newTopic );
    Foswiki::UI::checkAccess( $session, 'CHANGE', $topicObject );

    my $oldWeb   = $session->{webName};
    my $oldTopic = $session->{topicName};

    $session->{topicName} = $newTopic;
    $session->{webName}   = $newWeb;

    require Foswiki::UI::Edit;
    Foswiki::UI::Edit::edit($session);
}

sub _action_editSettings {
    my $session = shift;
    my $topic   = $session->{topicName};
    my $web     = $session->{webName};

    my $topicObject = Foswiki::Meta->load( $session, $web, $topic );
    Foswiki::UI::checkAccess( $session, 'VIEW', $topicObject );

    my $settings = "";

    my @fields = $topicObject->find('PREFERENCE');
    foreach my $field (@fields) {
        my $name  = $field->{name};
        my $value = $field->{value};
        $settings .= '   * '
          . ( ( $field->{type} eq 'Local' ) ? 'Local' : 'Set' ) . ' '
          . $name . ' = '
          . $value . "\n";
    }

    my $tmpl = $session->templates->readTemplate('settings');
    $tmpl = $topicObject->expandMacros($tmpl);
    $tmpl = $topicObject->renderTML($tmpl);

    $tmpl =~ s/%TEXT%/$settings/o;

    my $info = $topicObject->getRevisionInfo();
    $tmpl =~ s/%ORIGINALREV%/$info->{version}/g;

    $session->writeCompletePage($tmpl);
}

sub _action_saveSettings {
    my $session = shift;
    my $topic   = $session->{topicName};
    my $web     = $session->{webName};
    my $cUID    = $session->{user};

    # set up editing session
    require Foswiki::Meta;
    my $newTopicObject = Foswiki::Meta->load( $session, $web, $topic );

    my $query       = $session->{request};
    my $settings    = $query->param('text');
    my $originalrev = $query->param('originalrev');

    $newTopicObject->remove('PREFERENCE');    # delete previous settings
        # Note: $Foswiki::regex{setVarRegex} cannot be used as it requires
        # use in code that parses multiline settings line by line.
    $settings =~
s(^(?:\t|   )+\*\s+(Set|Local)\s+($Foswiki::regex{tagNameRegex})\s*=\s*?(.*)$)
        (_parsePreferenceValue($newTopicObject, $1, $2, $3))mgeo;

    my $saveOpts = {};
    $saveOpts->{minor}            = 1;    # don't notify
    $saveOpts->{forcenewrevision} = 1;    # always new revision

    # Merge changes in meta data
    if ($originalrev) {
        my $info = $newTopicObject->getRevisionInfo();

        # If the last save was by me, don't merge
        if (   $info->{version} ne $originalrev
            && $info->{author} ne $session->{user} )
        {
            my $currTopicObject = Foswiki::Meta->load( $session, $web, $topic );
            $newTopicObject->merge($currTopicObject);
        }
    }

    Foswiki::UI::checkAccess( $session, 'CHANGE', $newTopicObject );

    try {
        $newTopicObject->save( minor => 1, forcenewrevision => 1 );
    }
    catch Error::Simple with {
        throw Foswiki::OopsException(
            'attention',
            def    => 'save_error',
            web    => $web,
            topic  => $topic,
            params => [ shift->{-text} ]
        );
    };

    my $viewURL = $session->getScriptUrl( 0, 'view', $web, $topic );
    $session->redirect( $session->redirectto($viewURL) );
}

sub _parsePreferenceValue {
    my ( $topicObject, $type, $name, $value ) = @_;

    $value =~ s/^\s*(.*?)\s*$/$1/ge;

    my $args = {
        name  => $name,
        title => $name,
        value => $value,
        type  => $type
    };
    $topicObject->putKeyed( 'PREFERENCE', $args );
    return '';
}

sub _action_restoreRevision {
    my ($session) = @_;
    my ( $web, $topic ) =
      $session->normalizeWebTopicName( $session->{webName},
        $session->{topicName} );

    # read the current topic
    my $meta = Foswiki::Meta->load( $session, $web, $topic );

    if ( !$meta->haveAccess('CHANGE') ) {

        # user has no permission to change the topic
        throw Foswiki::OopsException(
            'accessdenied',
            def    => 'topic_access',
            web    => $web,
            topic  => $topic,
            params => [ 'change', 'denied' ]
        );
    }
    $session->{cgiQuery}->delete('action');
    require Foswiki::UI::Edit;
    Foswiki::UI::Edit::edit($session);
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
