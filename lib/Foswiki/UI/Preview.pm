# See bottom of file for license and copyright information

package Foswiki::UI::Preview;

use strict;
use Error qw( :try );

use Foswiki                ();
use Foswiki::UI::Save      ();
use Foswiki::OopsException ();

use Assert;

sub preview {
    my $session = shift;

    my $query = $session->{request};
    my $web   = $session->{webName};
    my $topic = $session->{topicName};
    my $user  = $session->{user};

    # SMELL: it's probably not good to do this here, because a preview may
    # give enough time for a new topic with the same name to be created.
    # It would be better to do it only on an actual save.

    $topic = Foswiki::UI::Save::expandAUTOINC( $session, $web, $topic );

    my $topicObject = Foswiki::Meta->new( $session, $web, $topic );

    my ( $saveOpts, $merged ) =
      Foswiki::UI::Save::buildNewTopic( $session, $topicObject, 'preview' );

    # Note: param(formtemplate) has already been decoded by buildNewTopic
    # so the $meta entry reflects if it was used.
    # get form fields to pass on
    my $formFields = '';
    my $form = $topicObject->get('FORM') || '';
    my $formName;
    if ($form) {
        $formName = $form->{name};    # used later on as well
        require Foswiki::Form;
        my $formDef = new Foswiki::Form( $session, $web, $formName );
        unless ($formDef) {
            throw Foswiki::OopsException(
                'attention',
                def    => 'no_form_def',
                web    => $session->{webName},
                topic  => $session->{topicName},
                params => [ $web, $formName ]
            );
        }
        $formFields = $formDef->renderHidden( $topicObject, 0 );
    }

    my $text = $topicObject->text();
    $session->{plugins}->dispatch( 'afterEditHandler', $text, $topic, $web );

    my $template = $session->{prefs}->getPreference('VIEW_TEMPLATE')
      || 'preview';
    my $tmpl = $session->templates->readTemplate($template);

    # if a VIEW_TEMPLATE is set, but does not exist or is not readable,
    # revert to 'preview' template (same code as View.pm)
    if ( !$tmpl && $template ne 'preview' ) {
        $tmpl = $session->templates->readTemplate('preview');
        $template = 'preview';
    }

    my $content = '';
    if ( $template eq 'preview' ) {
        $content = $text;
    }
    else {

        # only get the contents of TMPL:DEF{"content"}
        $content = $session->templates->expandTemplate('content');

        # put the text we have inside this template's content
        $content =~ s/%TEXT%/$text/go;

        # now we are ready to put the expanded and styled topic content in the
        # 'normal' preview template
    }

    $tmpl = $session->templates->readTemplate('preview');

    if ( $saveOpts->{minor} ) {
        $tmpl =~ s/%DONTNOTIFYCHECKBOX%/checked="checked"/go;
    }
    else {
        $tmpl =~ s/%DONTNOTIFYCHECKBOX%//go;
    }
    if ( $saveOpts->{forcenewrevision} ) {
        $tmpl =~ s/%FORCENEWREVISIONCHECKBOX%/checked="checked"/go;
    }
    else {
        $tmpl =~ s/%FORCENEWREVISIONCHECKBOX%//go;
    }
    my $saveCmd = $query->param('cmd') || '';
    $tmpl =~ s/%CMD%/$saveCmd/go;

    my $redirectTo = $query->param('redirectto') || '';
    $tmpl =~ s/%REDIRECTTO%/$redirectTo/go;

    $formName ||= '';
    $tmpl =~ s/%FORMTEMPLATE%/$formName/g;

    my $parent = $topicObject->get('TOPICPARENT');
    $parent = $parent->{name} if ($parent);
    $parent ||= '';
    $tmpl =~ s/%TOPICPARENT%/$parent/g;

    my $displayText = $content;
    $displayText = $topicObject->expandMacros($displayText);
    $displayText = $topicObject->renderTML($displayText);

    # Disable links and inputs in the text
    $displayText =~
      s#<a\s[^>]*>(.*?)</a>#<span class="foswikiEmulatedLink">$1</span>#gis;
    $displayText =~ s/<(input|button|textarea) /<$1 disabled="disabled" /gis;
    $displayText =~ s(</?form(|\s.*?)>)()gis;
    $displayText =~ s/(<[^>]*\bon[A-Za-z]+=)('[^']*'|"[^"]*")/$1''/gis;

    # let templates know the context so they can act on it
    $session->enterContext( 'preview', 1 );

    # note: preventing linkage in rendered form can only happen in templates
    # see formtables.tmpl

    $tmpl = $topicObject->expandMacros($tmpl);
    $tmpl = $topicObject->renderTML($tmpl);
    $tmpl =~ s/%TEXT%/$displayText/go;

    # write the hidden form fields
    $tmpl =~ s/%FORMFIELDS%/$formFields/go;

    # SMELL: this should be done using CGI::hidden
    $text = Foswiki::entityEncode( $text, "\n" );

    $tmpl =~ s/%HIDDENTEXT%/$text/go;

    $tmpl =~ s/<\/?(nop|noautolink)\/?>//gis;

    # I don't know _where_ these should be done,
    # so I'll do them as late as possible
    my $originalrev = $query->param('originalrev');    # rev edit started on
         #ASSERT($originalrev ne '%ORIGINALREV%') if DEBUG;
    $tmpl =~ s/%ORIGINALREV%/$originalrev/go;
    my $templatetopic = $query->param('templatetopic');

    #ASSERT($templatetopic ne '%TEMPLATETOPIC%') if DEBUG;
    $tmpl =~ s/%TEMPLATETOPIC%/$templatetopic/go;

    #this one's worrying, its special, and not set much at all
    #$tmpl =~ s/%SETTINGSTOPIC%/$settingstopic/go;
    my $newtopic = $query->param('newtopic');

    #ASSERT($newtopic ne '%NEWTOPIC%') if DEBUG;
    $tmpl =~ s/%NEWTOPIC%/$newtopic/go;

    $session->writeCompletePage($tmpl);
}

1;
__DATA__
# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
