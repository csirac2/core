# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Configure::UIs::Section;

A UI for a collection object.
The layout of a configuration page is depth-sensitive, so we have slightly
different behaviours for each of level 0 (the root), level 1 (tab
sections) and level > 1 (subsection).

=cut

package Foswiki::Configure::UIs::Section;

use strict;
use warnings;

use Foswiki::Configure (qw/:config/);

use Foswiki::Configure::UIs::Value ();
use Foswiki::Configure::UI         ();
our @ISA = ('Foswiki::Configure::UIs::Item');

=begin TML

---++ ObjectMethod renderHtml($section, $root, $contents) -> ($html, \%properties)

Overrides Foswiki::Configure::UIs::Item

Sections are of two types; "plain" and "tabbed". A plain section formats
all its subsections inline, in a table. A tabbed section formats all its
subsections as tabs.
   * $section the Foswiki::Configure::Section
   * $root the Foswiki::Configure::UIs::Root
   * =$contents= is the content (a set of table rows) to use for the
     section if there are no configuration items.

=cut

require Foswiki::Configure::ModalTemplates;

sub renderHtml {
    my ( $this, $section, $root, $contents ) = @_;

    $contents ||= '';
    my $depth = $section->getDepth();
    my $class = $section->isExpertsOnly() ? 'configureExpert' : '';
    my $id    = $this->makeID( $section->{headline} )
      || ( 'randomId' . int( rand(1000) ) );

    my $headline    = $section->{headline};
    my $navigation  = '';
    my $description = $section->{desc} || '';

    my $fullId    = $id;
    my $bodyClass = '';
    $bodyClass = 'configureRootSection' if $depth == 2;
    $bodyClass = 'configureSubSection'  if $depth > 2;

    # render values within this section
    # note that has to happen before creating tab sections
    # because field checks are done while rendering
    # these may update the WARN and ERROR messages
    my $values = $this->_renderValues( $section, $root );
    if ($values) {
        $contents = $this->renderValueBlock($values) . $contents;
    }

    my $sectionErrors   = 0;
    my $sectionWarnings = 0;

    if ( $section->{parent} ) {
        if ( $section->{parent}->{opts} =~ /TABS/ ) {

            # this is a tab within a tabbed page

            # See what errors and warnings exist in the tab
            ( $sectionErrors, $sectionWarnings ) =
              $this->collectMessages($section);

            $section->{parent}->{controls} ||=
              new Foswiki::Configure::GlobalControls(
                $this->makeID( $section->{parent}->{headline} || '' ) );

            $section->{parent}->{controls}
              ->openTab( $id, $depth, $section->{opts}, $section->{headline},
                $sectionErrors, $sectionWarnings );

            $id = $section->{parent}->{controls}->sectionId($id);

            $bodyClass .= ' configureToggleSection';
        }
    }

    if ( $section->{opts} =~ /TABS/ ) {
        $navigation = $section->{controls}->generateTabs($depth);
    }

    my $outText = '';
    if ( $depth == 1 ) {
        my $isFirstTime = (
            $Foswiki::Configure::UI::firsttime
              && ( $Foswiki::Configure::UI::totwarnings
                || $Foswiki::Configure::UI::toterrors )
          )
          || 0;

        my $template = Foswiki::Configure::ModalTemplates->new(
            $root,
            'navigation'    => $navigation,
            'contents'      => $contents,
            'firstTime'     => $isFirstTime,
            'unsavedNotice' => $Foswiki::unsavedChangesNotice,
        );
        $template->renderActivationButton(    # buttonID => ModalModule
            passwordButton => 'ChangePassword'
        );
        $template->renderActivationButton( discardButton => 'DiscardChanges' );
        $template->renderActivationButton( saveButton    => 'SaveChanges' );
        $template->renderActivationButton( errorsButton => 'DisplayErrors', 1 );
        $template->renderActivationButton(
            warningsButton => 'DisplayErrors',
            1
        );
        $template->renderFeedbackWindow( statusBarFeedback => 'SaveChanges' );

        my $templateArgs = $template->getArgs;

        # parsed twice for MODAL.pm
        $outText = $template->extractArgs('main');
        $outText = Foswiki::Configure::UI::getTemplateParser()
          ->parse( $outText, $templateArgs );
        $outText = Foswiki::Configure::UI::getTemplateParser()
          ->parse( $outText, $templateArgs );
    }
    else {
        my $alertActive =
          ( $sectionErrors || $sectionWarnings ) ? '' : ' foswikiAlertInactive';
        $outText =
          Foswiki::Configure::UI::getTemplateParser()->readTemplate('section');
        $outText = Foswiki::Configure::UI::getTemplateParser()->parse(
            $outText,
            {
                'id'          => $id,
                'bodyClass'   => $bodyClass,
                'depth'       => $depth,
                'headline'    => $headline,
                'alertActive' => $alertActive,
                'navigation'  => $navigation,
                'description' => $description,
                'contents'    => $contents,
            }
        );
    }
    return $outText;
}

# Render the leaf values in a section.
#    * $section the Foswiki::Configure::Section
#    * $root the Foswiki::Configure::UIs::Root
sub _renderValues {
    my ( $this, $section, $root ) = @_;

    my $out         = '';
    my $expertCount = 0;
    my $infoCount   = 0;
    foreach my Foswiki::Configure::Value $item ( @{ $section->{values} } ) {
        my $class = ref($item);
        $class =~ s/.*:://;
        my $ui = Foswiki::Configure::UI::loadUI( $class, $item );
        die "Fatal Error - Could not load UI for $class - $@" unless $ui;

        my ( $rowHtml, $properties ) = $ui->renderHtml( $item, $root );
        $out .= $rowHtml;
        $expertCount++ if $properties->{expert};
        $infoCount++   if $properties->{info};
    }

    if ( $expertCount > 0 || $infoCount > 0 ) {
        my @placeholders = ();
        push( @placeholders, 'CONFIGURE_EXPERT_LINK' ) if $expertCount > 0;
        push( @placeholders, 'CONFIGURE_INFO_LINK' )   if $infoCount > 0;

        my $expertTitle = '';

# title unfinished:
# - should be in template
# - should be left-aligned
# - language should cater for 1 option or multiple
#		$expertTitle = "<span class='configureTableExpertTitle'>$expertCount expert options</span>" if $expertCount > 0;

        $out .=
          _getOutsideRowHtml( 'configureTableOutside', $expertTitle,
            join( ' ', @placeholders ) );
    }

    return $out;
}

sub _getOutsideRowHtml {
    my ( $class, $title, $data ) = @_;

    return CGI::Tr( {},
        CGI::td( { class => $class, colspan => "3" }, "$title $data" ) );
}

=begin TML

---++ PROTECTED ObjectMethod renderValueBlock($string) -> $html

Render a value block. This is exported so that UIs can render value
strings other than those composed of configuration items e.g. the
environment.

Only for use by subclasses.

=cut

sub renderValueBlock {
    my ( $this, $values ) = @_;

    return "<table class='configureSectionValues'>$values</table>";
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
