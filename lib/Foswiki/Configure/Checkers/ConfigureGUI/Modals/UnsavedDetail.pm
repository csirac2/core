# See bottom of file for license and copyright information

use strict;
use warnings;

package Foswiki::Configure::Checkers::ConfigureGUI::Modals::UnsavedDetail;

# Modal action checker for unsaved item detail.

use Foswiki::Configure(qw/:auth :util/);

require Foswiki::Configure::ModalTemplates;

require Foswiki::Configure::Checkers::ConfigureGUI::MODAL;
our @ISA = ('Foswiki::Configure::Checkers::ConfigureGUI::MODAL');

# Called to display unsaved item detail
#

sub generateForm {
    my $this = shift;
    my ( $keys, $query, $session, $template ) = @_;

    my $e = '';

    unless ( loggedIn($session) || $badLSC ) {
        ( my $ok, $e ) =
          $template->passwordRequiredForm( $query, 'unsaveditemdetail' );
        return $e unless ($ok);
    }

    refreshLoggedIn($session);

    my $templateArgs = $template->getArgs;

    my $updated  = $this->{item}{_fbChanged};
    my $modified = keys %$updated;

    my $cart = Foswiki::Configure::Feedback::Cart->get($session);
    my $passChanged = $cart->param('{Password}') ? 1 : 0;

    my $pendingItems = [];
    foreach my $key ( sortHashkeyList( keys %$updated ) ) {
        next if ( $key =~ /^\{ConfigureGUI\}/ );
        my $valueString;
        my $type = $query->param("TYPEOF:$key") || 'UNKNOWN';
        if ( $key =~ /password/i ) {
            $valueString = '&bull;' x 9;
        }
        elsif ( $type eq 'BOOLEAN' ) {
            $valueString = $query->param($key) ? 1 : 0;
        }
        else {
            $valueString = join( ',', $query->param($key) );
        }
        push( @$pendingItems, { item => $key, value => $valueString } );
    }

    $template->addArgs(
        pendingCount    => scalar @$pendingItems,
        pendingItems    => $pendingItems,
        passwordChanged => $passChanged,
        timesaved       => scalar localtime( $cart->timeSaved ),
    );

    $template->renderFeedbackWindow('unsavedDetailFormFeedback');

    # Template is parsed twice intentionally.  See MODAL.pm for why.

    my $html = $template->extractArgs('unsaveditemdetail');
    $html = Foswiki::Configure::UI::getTemplateParser()
      ->parse( $html, $templateArgs );
    $html = Foswiki::Configure::UI::getTemplateParser()
      ->parse( $html, $templateArgs );
    Foswiki::Configure::UI::getTemplateParser()->cleanupTemplateResidues($html);

    $html = $this->FB_MODAL( 'r,o', $html );
    return $html . $e;
}

sub processForm {
    my $this = shift;
    my ( $keys, $query, $session, $template ) = @_;

    my $e = '';

    return $e . $this->ERROR("There is no action button on this form.");
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
