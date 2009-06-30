# See bottom of file for license and copyright information

package Foswiki::Configure::UIs::Value;

use strict;

use Foswiki::Configure::UI ();
our @ISA = ('Foswiki::Configure::UI');

# Generates the appropriate HTML for getting a value to configure the
# entry. The actual input field is decided by the type.
sub open_html {
    my ( $this, $value, $root ) = @_;

    my $type = $value->getType();
    return '' if $value->{hidden};

    my $isExpert = $value->isExpertsOnly();
    my $info = '';

    $info .= $value->{desc};
    my $keys = $value->getKeys();

    my $checker  = Foswiki::Configure::UI::loadChecker( $keys, $value );
    my $isUnused = 0;
    my $isBroken = 0;
    my $check = '';
    if ($checker) {
        $check = $checker->check($value) || '';
        if ($check) {

            # something wrong
            $isBroken = 1;
        }
        if ( $check eq 'NOT USED IN THIS CONFIGURATION' ) {
            $isUnused = 1;
        }
    }

    # Hide rows if this is an EXPERT setting in non-experts mode, or
    # this is a hidden or unused value
    my $class = $isExpert ? 'expert' : 'newbie';
    if ( $isUnused || !$isBroken && $value->{hidden} ) {
        $class = 'foswikiHidden';
    }

    # Hidden type information used when passing to 'save'
    my $hiddenTypeOf = $this->hidden( 'TYPEOF:' . $keys, $value->{typename} );

    my $index = $keys;
    $index = "<span class='foswikiMandatory'>$index</span>" if $value->{mandatory};

    my $details = '';
    if ( $value->needsSaving($root->{valuer}) ) {
        my $defaultValue = $root->{valuer}->defaultValue($value) || '';

        # special case are Perl data structures
        # in order to edit this in the browser, it must get translated
        # to a string
        if ( $value->{typename} eq 'PERL' || $value->{typename} eq 'HASH' ) {
            use Data::Dumper;
            $Data::Dumper::Terse = 1;
            $defaultValue        = Dumper($defaultValue);

            # create stubs for special characters, put them back with javascript
            $defaultValue =~ s/'/#26;/g;
            $defaultValue =~ s/"/#22;/g;
            $defaultValue =~ s/\n/#13;/g;
        }

        my $safeKeys = $keys;
        $safeKeys =~ s/'/#26;/g;
        $details .= <<HERE;
<a onmouseover='Tip(getTip("Delta")+"$defaultValue ($value->{typename})")' onmouseout='UnTip()' title='$defaultValue' class='$value->{typename} defaultValueLink foswikiSmall' onclick="return resetToDefaultValue(this,'$value->{typename}','$safeKeys','$defaultValue')">&delta;</a>
HERE
    }

    my $control;
    if ( $isUnused && !$isBroken ) {
        # Unused and not broken - just pass the value through a hidden
        $control = CGI::hidden( $keys, $root->{valuer}->currentValue($value) );
    } else {

        # Generate a prompter for the value.
        my $promptclass = $value->{typename};
        $promptclass .= ' foswikiMandatory' if ( $value->{mandatory} );
        $control = CGI::span(
            { class => $promptclass },
            $type->prompt(
                $keys, $value->{opts}, $root->{valuer}->currentValue($value)
            )
        );
    }

    my ($tipo, $tipc) = ('', '');
    if ($info) {
        my $tip = $root->{controls}->addTooltip($info);
        $tipo = "<a onmouseover='Tip(getTip($tip))' onmouseout='UnTip()'>";
        $tipc = "</a>";
    }
    
    return CGI::Tr( { class => $class }, CGI::th( { class => "$keys $class" }, "$hiddenTypeOf$tipo$index$tipc" ) . CGI::td( "$tipo$control$tipc&nbsp;$details$check" ) );
}

sub close_html {
    my ( $this, $value, $root ) = @_;
    return '';
}

1;
__DATA__
#
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
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
#
# UI generating package for simple values
#
