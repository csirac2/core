# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::UI::Save

UI delegate for save function

=cut

package Foswiki::UI::Save;

use strict;
use warnings;
use Error qw( :try );
use Assert;

use Foswiki                ();
use Foswiki::UI            ();
use Foswiki::Meta          ();
use Foswiki::OopsException ();

# Used by save and preview
sub buildNewTopic {
    my ( $session, $topicObject, $script ) = @_;

    my $query = $session->{request};
    my $revision = $query->param('rev') || undef;

    unless ( scalar( $query->param() ) ) {

        # insufficient parameters to save
        throw Foswiki::OopsException(
            'attention',
            def    => 'bad_script_parameters',
            web    => $topicObject->web,
            topic  => $topicObject->topic,
            params => [$script]
        );
    }

    Foswiki::UI::checkWebExists( $session, $topicObject->web, 'save' );

    my $topicExists =
      $session->topicExists( $topicObject->web, $topicObject->topic );

    # Prevent saving existing topic?
    my $onlyNewTopic = Foswiki::isTrue( $query->param('onlynewtopic') );
    if ( $onlyNewTopic && $topicExists ) {

        # Topic exists and user requested oops if it exists
        throw Foswiki::OopsException(
            'attention',
            def   => 'topic_exists',
            web   => $topicObject->web,
            topic => $topicObject->topic
        );
    }

    # prevent non-Wiki names?
    my $onlyWikiName = Foswiki::isTrue( $query->param('onlywikiname') );
    if (   ($onlyWikiName)
        && ( !$topicExists )
        && ( !Foswiki::isValidTopicName( $topicObject->topic ) ) )
    {

        # do not allow non-wikinames
        throw Foswiki::OopsException(
            'attention',
            def    => 'not_wikiword',
            web    => $topicObject->web,
            topic  => $topicObject->topic,
            params => [ $topicObject->topic ]
        );
    }

    my $saveOpts = {};
    $saveOpts->{minor}            = 1 if $query->param('dontnotify');
    $saveOpts->{forcenewrevision} = 1 if $query->param('forcenewrevision');
    my ( $ancestorRev, $ancestorDate );

    my $templatetopic = $query->param('templatetopic');
    my $templateweb   = $topicObject->web;
    my $ttom;    # template topic

    my $text = $topicObject->text();

    if ($topicExists) {

        # Initialise from existing topic

        Foswiki::UI::checkAccess( $session, 'VIEW',   $topicObject );
        Foswiki::UI::checkAccess( $session, 'CHANGE', $topicObject );
        $text        = $topicObject->text();            # text of last rev
        $ancestorRev = $query->param('originalrev');    # rev edit started on

    }
    elsif ($templatetopic) {

        # Initialise new topic from template topic

        ( $templateweb, $templatetopic ) =
          $session->normalizeWebTopicName( $templateweb, $templatetopic );

        if ( $session->topicExists( $templateweb, $templatetopic ) ) {

            # Validated
            $templateweb   = Foswiki::Sandbox::untaintUnchecked($templateweb);
            $templatetopic = Foswiki::Sandbox::untaintUnchecked($templatetopic);
        }
        else {
            throw Foswiki::OopsException(
                'attention',
                def   => 'no_such_topic_template',
                web   => $templateweb,
                topic => $templatetopic
            );
        }
        $ttom = Foswiki::Meta->load( $session, $templateweb, $templatetopic );
        Foswiki::UI::checkAccess( $session, 'VIEW', $ttom );

        $text = $ttom->text();
        $text = '' if $query->param('newtopic');       # created by edit
        $text = $topicObject->expandNewTopic($text);

        foreach my $k ( keys %$ttom ) {

            # Skip internal fields and TOPICINFO, TOPICMOVED
            unless ( $k =~ /^(_|TOPIC)/ ) {
                $topicObject->copyFrom( $ttom, $k );
            }
        }

        # topic creation, there is no original rev
        $ancestorRev = 0;
    }

    if ( defined( $query->param('text') ) ) {

        # text is defined in the query, save that text, overriding anything
        # from the template or the previous rev of the topic
        $text = $query->param('text');
        $text =~ s/\r//g;
        $text .= "\n" unless $text =~ /\n$/s;
    }

    $text = '' unless defined $text;

    # Change the parent, if appropriate
    my $newParent = $query->param('topicparent');
    if ($newParent) {
        if ( $newParent eq 'none' ) {
            $topicObject->remove('TOPICPARENT');
        }
        else {
            $topicObject->put( 'TOPICPARENT', { 'name' => $newParent } );
        }
    }

    my $formName = $query->param('formtemplate');
    my $formDef;

    if ($formName) {

        # new form, default field values will be null
        if ( $formName eq 'none' ) {

            # No form, remove the old data
            $topicObject->remove('FORM');
            $topicObject->remove('FIELD');
            $formName = undef;
        }
    }
    else {

        # Recover the existing form name
        my $fm = $topicObject->get('FORM');
        $formName = $fm->{name} if $fm;
    }

    if ($formName) {
        require Foswiki::Form;
        $formDef = new Foswiki::Form( $session, $topicObject->web, $formName );
        unless ($formDef) {
            throw Foswiki::OopsException(
                'attention',
                def    => 'no_form_def',
                web    => $session->{webName},
                topic  => $session->{topicName},
                params => [ $topicObject->web, $formName ]
            );
        }
        $topicObject->put( 'FORM', { name => $formName } );

        # Remove fields that don't exist on the new form def.
        my $filter = join( '|',
            map    { $_->{name} }
              grep { $_->{name} } @{ $formDef->getFields() } );
        foreach my $f ( $topicObject->find('FIELD') ) {
            if ( $f->{name} !~ /^($filter)$/ ) {
                $topicObject->remove( 'FIELD', $f->{name} );
            }
        }

        # override existing fields with values from the query
        my ( $seen, $missing ) =
          $formDef->getFieldValuesFromQuery( $query, $topicObject );
        if ( $seen && @$missing ) {

            # chuck up if there is at least one field value defined in the
            # query and a mandatory field was not defined in the
            # query or by an existing value.
            throw Foswiki::OopsException(
                'attention',
                def    => 'mandatory_field',
                web    => $topicObject->web,
                topic  => $topicObject->topic,
                params => [ join( ' ', @$missing ) ]
            );
        }
    }

    if ($ancestorRev) {
        if ( $ancestorRev =~ /^(\d+)_(\d+)$/ ) {
            ( $ancestorRev, $ancestorDate ) = ( $1, $2 );
        }
        elsif ( $ancestorRev !~ /^\d+$/ ) {

            # Badly formatted ancestor
            throw Foswiki::OopsException(
                'attention',
                def    => 'bad_script_parameters',
                web    => $topicObject->web,
                topic  => $topicObject->topic,
                params => [$script]
            );
        }
    }

    my $merged;
    if ($ancestorRev) {

        # Get information for the most recently saved rev
        my $info = $topicObject->getRevisionInfo();

        # If the last save was done since we started the edit, and it
        # wasn't saved by the current user, we need to merge. We also
        # check the ancestor date, in case a repRev happened.
        if (
            (
                   $ancestorRev ne $info->{version}
                || $ancestorDate
                && $info->{date}
                && $ancestorDate ne $info->{date}
            )
            && $info->{author} ne $session->{user}
          )
        {

            # Load the prev rev again, so we can do a 3 way merge
            my $prevTopicObject =
              Foswiki::Meta->load( $session, $topicObject->web,
                $topicObject->topic );

            require Foswiki::Merge;

            $topicObject->getRevisionInfo();
            my $pti = $topicObject->get('TOPICINFO');
            if (   $pti->{reprev}
                && $pti->{version}
                && $pti->{reprev} == $pti->{version} )
            {

                # If the ancestor revision was generated by a reprev,
                # then the original is lost and we can't 3-way merge
                $session->{plugins}->dispatch(
                    'beforeMergeHandler', $text,
                    $pti->{version},      $prevTopicObject->text,
                    undef,                undef,
                    $topicObject->web,    $topicObject->topic
                );

                $text =
                  Foswiki::Merge::merge2( $pti->{version},
                    $prevTopicObject->text, $info->{version}, $text, '.*?\n',
                    $session );
            }
            else {

                # common ancestor; we can 3-way merge
                my $ancestorMeta =
                  Foswiki::Meta->load( $session, $topicObject->web,
                    $topicObject->topic, $ancestorRev );
                $session->{plugins}->dispatch(
                    'beforeMergeHandler', $text,
                    $info->{version},     $prevTopicObject->text,
                    $ancestorRev,         $ancestorMeta->text(),
                    $topicObject->web,    $topicObject->topic
                );

                $text =
                  Foswiki::Merge::merge3( $ancestorRev, $ancestorMeta->text(),
                    $info->{version}, $prevTopicObject->text, 'new', $text,
                    '.*?\n', $session );
            }
            if ($formDef) {
                $topicObject->merge( $prevTopicObject, $formDef );
            }
            $merged = [ $ancestorRev, $info->{author}, $info->{version} || 1 ];
        }
    }
    $topicObject->text($text);

    return ( $saveOpts, $merged );
}

=begin TML

---++ StaticMethod expandAUTOINC($session, $web, $topic) -> $topic
Expand AUTOINC\d+ in the topic name to the next topic name available

=cut

sub expandAUTOINC {
    my ( $session, $web, $topic ) = @_;

    # Do not remove, keep as undocumented feature for compatibility with
    # TWiki 4.0.x: Allow for dynamic topic creation by replacing strings
    # of at least 10 x's XXXXXX with a next-in-sequence number.
    if ( $topic =~ /X{10}/ ) {
        my $n           = 0;
        my $baseTopic   = $topic;
        my $topicObject = Foswiki::Meta->new( $session, $web, $baseTopic );
        $topicObject->clearLease();
        do {
            $topic = $baseTopic;
            $topic =~ s/X{10}X*/$n/e;
            $n++;
        } while ( $session->topicExists( $web, $topic ) );
    }

    # Allow for more flexible topic creation with sortable names.
    # See Codev.AutoIncTopicNameOnSave
    if ( $topic =~ /^(.*)AUTOINC(\d+)(.*)$/ ) {
        my $pre         = $1;
        my $start       = $2;
        my $pad         = length($start);
        my $post        = $3;
        my $topicObject = Foswiki::Meta->new( $session, $web, $topic );
        $topicObject->clearLease();
        my $webObject = Foswiki::Meta->new( $session, $web );
        my $it = $webObject->eachTopic();

        while ( $it->hasNext() ) {
            my $tn = $it->next();
            next unless $tn =~ /^${pre}(\d+)${post}$/;
            $start = $1 + 1 if ( $1 >= $start );
        }
        my $next = sprintf( "%0${pad}d", $start );
        $topic =~ s/AUTOINC[0-9]+/$next/;
    }
    return $topic;
}

=begin TML

---++ StaticMethod save($session)

Command handler for =save= command.
This method is designed to be
invoked via the =UI::run= method.

See System.CommandAndCGIScripts for details of parameters.

Note: =cmd= has been deprecated in favour of =action=. It will be deleted at
some point.

=cut

sub save {
    my $session = shift;

    my $query = $session->{request};

    my $saveaction = '';
    foreach my $action qw( save checkpoint quietsave cancel preview
      addform replaceform delRev repRev ) {
        if ( $query->param( 'action_' . $action ) )
        {
            $saveaction = $action;
            last;
        }
      }

      # the 'action' parameter has been deprecated, though is still available
      # for compatibility with old templates.
      if ( !$saveaction && $query->param('action') ) {
        $saveaction = lc( $query->param('action') );
        $session->logger->log( 'warning', <<WARN);
Use of deprecated "action" parameter to "save". Correct your templates!
WARN

        # handle old values for form-related actions:
        $saveaction = 'addform'     if ( $saveaction eq 'add form' );
        $saveaction = 'replaceform' if ( $saveaction eq 'replace form...' );
    }

    if ( $saveaction eq 'preview' ) {
        require Foswiki::UI::Preview;
        Foswiki::UI::Preview::preview($session);
        return;
    }

    my ( $web, $topic ) =
      $session->normalizeWebTopicName( $session->{webName},
        $session->{topicName} );

    $topic = expandAUTOINC( $session, $web, $topic );

    my $topicObject = Foswiki::Meta->new( $session, $web, $topic );

    if ( $saveaction eq 'cancel' ) {
        my $lease = $topicObject->getLease();
        if ( $lease && $lease->{user} eq $session->{user} ) {
            $topicObject->clearLease();
        }

        # redirect to a sensible place (a topic that exists)
        my ( $w, $t ) = ( '', '' );
        foreach my $test ( $topic, $query->param('topicparent'),
            $Foswiki::cfg{HomeTopicName} )
        {
            ( $w, $t ) = $session->normalizeWebTopicName( $web, $test );
            last if ( $session->topicExists( $w, $t ) );
        }
        my $viewURL = $session->getScriptUrl( 1, 'view', $w, $t );
        $session->redirect( $session->redirectto($viewURL), undef, 1 );

        return;
    }

    # Do this *before* we do any query parameter rewriting
    Foswiki::UI::checkValidationKey( $session );

    my $editaction = lc( $query->param('editaction') ) || '';
    my $edit       = $query->param('edit')             || 'edit';

    ## SMELL: The form affecting actions do not preserve edit and editparams
    if (   $saveaction eq 'addform'
        || $saveaction eq 'replaceform'
        || $saveaction eq 'preview' && $query->param('submitChangeForm') )
    {
        require Foswiki::UI::ChangeForm;
        $session->writeCompletePage(
            Foswiki::UI::ChangeForm::generate(
                $session, $topicObject, $editaction
            )
        );
        return;
    }

    my $redirecturl;

    if ( $saveaction eq 'checkpoint' ) {
        $query->param( -name => 'dontnotify', -value => 'checked' );
        my $edittemplate = $query->param('template');
        my %p = ( t => time() );
        # map editaction -> action and edittemplat -> template
        $p{action} = $editaction if $editaction;
        $p{template} = $edittemplate if $edittemplate;
        # Pass through selected parameters
        foreach my $pthru qw(redirectto skin cover nowysiwyg) {
            $p{$pthru} = $query->param($pthru);
        }

        $redirecturl = $session->getScriptUrl( 1, $edit, $web, $topic, %p );

        $redirecturl .= $query->param('editparams')
          if $query->param('editparams');    # May contain anchor

        my $lease = $topicObject->getLease();

        if ( $lease && $lease->{user} eq $session->{user} ) {
            $topicObject->setLease( $Foswiki::cfg{LeaseLength} );
        }

        # drop through
    }
    else {

      # redirect to topic view or any other redirectto specified as an url param
        $redirecturl =
          $session->redirectto(
            $session->getScriptUrl( 1, 'view', $web, $topic ) );
    }

    if ( $saveaction eq 'quietsave' ) {
        $query->param( -name => 'dontnotify', -value => 'checked' );
        $saveaction = 'save';

        # drop through
    }

    if ( $saveaction =~ /^(del|rep)Rev$/ ) {

        # hidden, largely undocumented functions, used by administrators for
        # reverting spammed topics. These functions support rewriting
        # history, in a Joe Stalin kind of way. They should be replaced with
        # mechanisms for hiding revisions.
        $query->param( -name => 'cmd', -value => $saveaction );

        # drop through
    }

    my $adminCmd = $query->param('cmd') || 0;
    if ( $adminCmd && !$session->{users}->isAdmin( $session->{user} ) ) {
        throw Foswiki::OopsException(
            'accessdenied',
            status => 403,
            def    => 'only_group',
            web    => $web,
            topic  => $topic,
            params => [ $Foswiki::cfg{SuperAdminGroup} ]
        );
    }

    if ( $adminCmd eq 'delRev' ) {

        # delete top revision
        try {
            $topicObject->deleteMostRecentRevision();
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

        $session->redirect($redirecturl);
        return;
    }

    if ( $adminCmd eq 'repRev' ) {

        # replace top revision with the text from the query, trying to
        # make it look as much like the original as possible. The query
        # text is expected to contain %META as well as text.
        $topicObject->text( $query->param('text') );

        try {
            $topicObject->replaceMostRecentRevision( forcedate => 1 );
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

        $session->redirect($redirecturl);
        return;
    }

    my ( $saveOpts, $merged ) = buildNewTopic( $session, $topicObject, 'save' );

    if ( $saveaction =~ /^(save|checkpoint)$/ ) {
        my $text = $topicObject->text();
        $text = '' unless defined $text;
        $session->{plugins}
          ->dispatch( 'afterEditHandler', $text, $topicObject->topic,
            $topicObject->web, $topicObject );
        $topicObject->text($text);
    }

    try {
        $topicObject->save(%$saveOpts);
    }
    catch Error::Simple with {
        throw Foswiki::OopsException(
            'attention',
            def    => 'save_error',
            web    => $topicObject->web,
            topic  => $topicObject->topic,
            params => [ shift->{-text} ]
        );
    };

    my $lease = $topicObject->getLease();

    # clear the lease, if (and only if) we own it
    if ( $lease && $lease->{user} eq $session->{user} ) {
        $topicObject->clearLease();
    }

    if ($merged) {
        throw Foswiki::OopsException(
            'attention',
            status => 200,
            def    => 'merge_notice',
            web    => $topicObject->web,
            topic  => $topicObject->topic,
            params => $merged
        );
    }

    $session->redirect($redirecturl);
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
and TWiki Contributors. All Rights Reserved.
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
