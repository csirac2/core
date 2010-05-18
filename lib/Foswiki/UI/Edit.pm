# See bottom of file for license and copyright information
package Foswiki::UI::Edit;

=begin TML

---+ package Foswiki::UI::Edit

Edit command handler

=cut

use strict;
use Assert;
use Error qw( :try );

use Foswiki                ();
use Foswiki::UI            ();
use Foswiki::OopsException ();

=begin TML

---++ StaticMethod edit( $session )

Edit command handler.
This method is designed to be
invoked via the =UI::run= method.
Most parameters are in the CGI query:

| =cmd= | Undocumented save command, passed on to save script |
| =onlywikiname= | if defined, requires a wiki name for the topic name if this is a new topic |
| =onlynewtopic= | if defined, and the topic exists, then moans |
| =formtemplate= | name of the form for the topic; will replace existing form |
| =templatetopic= | name of the topic to copy if creating a new topic |
| =skin= | skin(s) to use |
| =topicparent= | what to put in the topic prent meta data |
| =text= | text that will replace the old topic text if a formtemplate is defined (what the heck is this for?) |
| =contenttype= | optional parameter that defines the application type to write into the CGI header. Defaults to text/html. |
| =action= | Optional. If supplied, use the edit${action} template instead of the standard edit template. An empty value means edit both form and text, "form" means edit form only, "text" means edit text only |

=cut

sub edit {
    my $session = shift;
    my ( $topicObject, $tmpl ) = init_edit( $session, 'edit' );
    finalize_edit( $session, $topicObject, $tmpl );
}

sub init_edit {
    my ( $session, $templateName ) = @_;
    my $query = $session->{request};
    my $web   = $session->{webName};
    my $topic = $session->{topicName};
    my $user  = $session->{user};
    my $users = $session->{users};

    # empty means edit both form and text, "form" means edit form only,
    # "text" means edit text only
    my $editaction = lc( $query->param('action') ) || "";

    my $adminCmd   = $query->param('cmd')        || '';
    my $redirectTo = $query->param('redirectto') || '';
    my $onlyWikiName  = Foswiki::isTrue( $query->param('onlywikiname') );
    my $onlyNewTopic  = Foswiki::isTrue( $query->param('onlynewtopic') );
    my $formTemplate  = $query->param('formtemplate') || '';
    my $templateTopic = $query->param('templatetopic') || '';

    # apptype is undocumented legacy
    my $cgiAppType =
         $query->param('contenttype')
      || $query->param('apptype')
      || 'text/html';
    my $parentTopic = $query->param('topicparent') || '';
    my $ptext       = $query->param('text');
    my $revision    = Foswiki::Store::cleanUpRevID($query->param('rev'));

    Foswiki::UI::checkWebExists( $session, $web, 'edit' );

    my $topicObject = Foswiki::Meta->load( $session, $web, $topic );
    my $extraLog    = '';
    my $topicExists = $session->topicExists( $web, $topic );

    # If you want to edit, you have to be able to view and change.
    Foswiki::UI::checkAccess( $session, 'VIEW',   $topicObject );
    Foswiki::UI::checkAccess( $session, 'CHANGE', $topicObject );

    # Check lease, unless we have been instructed to ignore it
    # or if we are using the 10X's or AUTOINC topic name for
    # dynamic topic names.
    my $breakLock = $query->param('breaklock') || '';
    unless ( $breakLock || $topic =~ /X{10}/ || $topic =~ /AUTOINC\d+/ ) {
        my $lease = $topicObject->getLease();
        if ($lease) {
            my $who = $users->webDotWikiName( $lease->{user} );

            if ( $who ne $users->webDotWikiName($user) ) {

                # redirect; we are trying to break someone else's lease
                my ( $future, $past );
                my $why = $lease->{message};
                my $def;
                my $t = time();
                require Foswiki::Time;

                if ( $t > $lease->{expires} ) {

                    # The lease has expired, but see if we are still
                    # expected to issue a "less forceful' warning
                    if (   $Foswiki::cfg{LeaseLengthLessForceful} < 0
                        || $t < $lease->{expires} +
                        $Foswiki::cfg{LeaseLengthLessForceful} )
                    {
                        $def = 'lease_old';
                        $past =
                          Foswiki::Time::formatDelta( $t - $lease->{expires},
                            $session->i18n );
                        $future = '';
                    }
                }
                else {

                    # The lease is active
                    $def  = 'lease_active';
                    $past = Foswiki::Time::formatDelta( $t - $lease->{taken},
                        $session->i18n );
                    $future =
                      Foswiki::Time::formatDelta( $lease->{expires} - $t,
                        $session->i18n );
                }
                if ($def) {

                    # use a 'keep' redirect to ensure we pass parameter
                    # values in the query on to the oops script
                    throw Foswiki::OopsException(
                        'leaseconflict',
                        def    => $def,
                        web    => $web,
                        topic  => $topic,
                        keep   => 1,
                        params => [ $who, $past, $future, 'edit' ]
                    );
                }
            }
        }
    }

    # Prevent editing existing topic?
    if ( $onlyNewTopic && $topicExists ) {

        # Topic exists and user requested oops if it exists
        throw Foswiki::OopsException(
            'attention',
            def   => 'topic_exists',
            web   => $web,
            topic => $topic
        );
    }

    # prevent non-Wiki names?
    if (   ($onlyWikiName)
        && ( !$topicExists )
        && ( !Foswiki::isValidTopicName($topic) ) )
    {

        # do not allow non-wikinames
        throw Foswiki::OopsException(
            'attention',
            def    => 'not_wikiword',
            web    => $web,
            topic  => $topic,
            params => [$topic]
        );
    }

    # Get edit template
    my $template =
         $query->param('template')
      || $session->{prefs}->getPreference('EDIT_TEMPLATE')
      || $templateName;

    my $tmpl = $session->templates->readTemplate( $template . $editaction );

    if ( !$tmpl ) {
        $tmpl = $session->templates->readTemplate($template);
    }

    # Item2151: We cannot throw exceptions for invalid edit templates
    # because the user cannot correct it. Instead we fall back to default
    # and write a warning log entry to aid fault finding for the admin
    if ( !$tmpl ) {
        $session->logger->log('warning',
          "Edit template $template does not exist. " .
          "Falling back to $templateName! ($web.$topic)" );

        $tmpl = $session->templates->readTemplate( $templateName );
    }

    if ( !$tmpl ) {
        throw Foswiki::OopsException(
            'attention',
            def    => 'no_such_template',
            web    => $web,
            topic  => $topic,
            params => [ $template . $editaction, 'EDIT_TEMPLATE' ]
        );
    }

    if ($revision) {

        # we are restoring from a previous revision
        # be default check on the revision checkbox
        if ( $tmpl =~ m/%FORCENEWREVISIONCHECKBOX%/ ) {
            $tmpl =~ s/%FORCENEWREVISIONCHECKBOX%/checked="checked"/go;
        }
        else {

            # no checkbox in template, so force revision
            $session->{request}
              ->param( -name => 'forcenewrevision', -value => '1' );
        }

        # Reload $topicObject with the right revision
        $topicObject->reload($revision);
    }

    my $templateWeb = $web;
    if ($topicExists) {
        $tmpl =~ s/%NEWTOPIC%//;
    }
    else {
        if ($templateTopic) {

            # User specified template
            ( $templateWeb, $templateTopic ) =
              $session->normalizeWebTopicName( $templateWeb, $templateTopic );
        }
        else {

            # Web-specific default template
            $templateTopic = 'WebTopicEditTemplate';
            if ( !$session->topicExists( $templateWeb, $templateTopic ) ) {

                # System default template
                $templateWeb = $Foswiki::cfg{SystemWebName};
            }
        }
        if ( $session->topicExists( $templateWeb, $templateTopic ) ) {

            # Validated
            $templateWeb   = Foswiki::Sandbox::untaintUnchecked($templateWeb);
            $templateTopic = Foswiki::Sandbox::untaintUnchecked($templateTopic);
        }
        else {
            throw Foswiki::OopsException(
                'accessdenied',
                status => 403,
                def    => 'no_such_topic_template',
                web    => $templateWeb,
                topic  => $templateTopic
            );
        }

        $tmpl =~ s/%NEWTOPIC%/1/;

        my $ttom =
          Foswiki::Meta->load( $session, $templateWeb, $templateTopic );
        Foswiki::UI::checkAccess( $session, 'VIEW', $ttom );
        $templateTopic = $templateWeb . '.' . $templateTopic;

        $extraLog = "(not exist)";

        # If present, instantiate form
        if ( !$formTemplate ) {
            my $form = $ttom->get('FORM');
            $formTemplate = $form->{name} if $form;
        }

        # Copy field values from the template
        $topicObject->copyFrom( $ttom, 'FIELD' );

        $topicObject->text( $topicObject->expandNewTopic( $ttom->text() ) );
#SMELL: need to at least explain why we need to do this a second time.
        $topicObject->text( $topicObject->expandNewTopic( $ttom->text() ) );
    }

    $tmpl =~ s/%TEMPLATETOPIC%/$templateTopic/;
    $tmpl =~ s/%REDIRECTTO%/$redirectTo/;

    # override with parameter if set
    $topicObject->text($ptext) if defined $ptext;

    # Insert the rev number/date we are editing. This will be boolean false if
    # this is a new topic.
    if ( $topicExists && !defined $revision ) {
        my $info = $topicObject->getRevisionInfo();
        $tmpl =~ s/%ORIGINALREV%/$info->{version}_$info->{date}/g;
    }
    else {
        $tmpl =~ s/%ORIGINALREV%/0/g;
    }

    # parent setting
    if ( $parentTopic eq 'none' ) {
        $topicObject->remove('TOPICPARENT');
    }
    elsif ($parentTopic) {
        my $parentWeb;
        ( $parentWeb, $parentTopic ) =
          $session->normalizeWebTopicName( $web, $parentTopic );
        if ( $parentWeb ne $web ) {
            $parentTopic = $parentWeb . '.' . $parentTopic;
        }
        $topicObject->put( 'TOPICPARENT', { name => $parentTopic } );
    }
    else {
        $parentTopic = $topicObject->getParent();
    }
    $tmpl =~ s/%TOPICPARENT%/$parentTopic/;

    if ($formTemplate) {
        $topicObject->remove('FORM');
        if ( $formTemplate ne 'none' ) {
            $topicObject->put( 'FORM', { name => $formTemplate } );

            # Because the form has been expanded from a Template, we
            # want to expand $percnt-style content right now
            $topicObject->forEachSelectedValue( qr/FIELD/, qr/value/,
                sub { Foswiki::expandStandardEscapes(@_) },
            );
        }
        else {
            $topicObject->remove('FORM');
        }
        $tmpl =~ s/%FORMTEMPLATE%/$formTemplate/go;
    }

    if ($adminCmd) {

        # An admin cmd is a command such as 'repRev' or 'delRev'.
        # These commands can used by admins to silently remove
        # revisions from topics histories from some stores. repRev
        # works by allowing an edit of the embedded store form of
        # the topic, which is then saved over the previous
        # top revision.
        my $basemeta = Foswiki::Meta->load( $session, $web, $topic );

        # No need to check permissions; we are admin if we got here.
        $topicObject->text( $basemeta->getEmbeddedStoreForm() );
        $tmpl =~ s/\(edit\)/\(edit cmd=$adminCmd\)/go if $adminCmd;
    }
    else {
        my $text = $topicObject->text();
        $session->{plugins}
          ->dispatch( 'beforeEditHandler', $text, $topic, $web, $topicObject );
        $topicObject->text($text);
    }

    $session->logEvent( 'edit', $web . '.' . $topic, $extraLog );

    $tmpl =~ s/\(edit\)/\(edit cmd=$adminCmd\)/go if $adminCmd;

    $tmpl =~ s/%CMD%/$adminCmd/go;

    $tmpl = $topicObject->expandMacros($tmpl);
    $tmpl = $topicObject->renderTML($tmpl);

    # Don't want to render form fields, so this after getRenderedVersion
    my $formMeta = $topicObject->get('FORM');
    my $form     = '';
    my $formText = '';
    $form = $formMeta->{name} if ($formMeta);
    if ($adminCmd) {
    }
    elsif ($form) {
        require Foswiki::Form;
        my $formDef = new Foswiki::Form( $session, $templateWeb, $form );
        if ( !$formDef ) {

            # Reverse-engineer a form definition from the topic.
            $formDef =
              new Foswiki::Form( $session, $templateWeb, $form, $topicObject );
        }

        # Update with field values from the query
        $formDef->getFieldValuesFromQuery( $session->{request}, $topicObject );

        # And render them for editing
        # SMELL: these are both side-effecting functions, that will set
        # default values for fields if they are not set in the meta.
        # This behaviour really ought to be pulled out to a common place.
        if ( $editaction eq 'text' ) {
            $formText = $formDef->renderHidden($topicObject);
        }
        else {
            $formText = $formDef->renderForEdit($topicObject);
        }
    }
    else {
        my $webObject = Foswiki::Meta->new( $session, $web );
        if ( $session->{prefs}->getPreference('WEBFORMS') ) {
            $formText = $session->templates->readTemplate('addform');
            $formText = $topicObject->expandMacros($formText);
        }
    }
    $tmpl =~ s/%FORMFIELDS%/$formText/g;

    $tmpl =~ s/%FORMTEMPLATE%//go;    # Clear if not being used

    return ( $topicObject, $tmpl );
}

sub finalize_edit {

    my ( $session, $topicObject, $tmpl ) = @_;

    my $query = $session->{request};

    # apptype is undocumented legacy
    my $cgiAppType =
         $query->param('contenttype')
      || $query->param('apptype')
      || 'text/html';

    my $text = $topicObject->text() || '';
    $tmpl =~ s/%UNENCODED_TEXT%/$text/g;

    $text = Foswiki::entityEncode($text);
    $tmpl =~ s/%TEXT%/$text/g;

    $topicObject->setLease( $Foswiki::cfg{LeaseLength} );

    $session->writeCompletePage( $tmpl, 'edit', $cgiAppType );
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
Based on parts of Ward Cunninghams original Wiki and JosWiki.
Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
