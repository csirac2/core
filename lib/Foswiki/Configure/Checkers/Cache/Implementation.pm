# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::Cache::Implementation;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

use Foswiki::Configure::Dependency;

sub check {
    my $this = shift;
    my $e    = q{};

    my $implementation = $Foswiki::cfg{Cache}{Implementation} || q{};
    my ($module) = $implementation =~ m/Foswiki::PageCache::(.*)/;

    return if ( !$module || ( $module eq 'DBI::Generic' ) );

    $module =~ s/^DBI::/DBD::/;

    $e =
      $this->checkPerlModule( $module, "Required to use $implementation.", 0 );

    if ( $Foswiki::cfg{Cache}{Enabled} ) {
        return (
            ( $e =~ m/Not installed./ ) ? $this->ERROR($e) : $this->NOTE($e) );
    }
    else {
        return (
            ( $e =~ m/Not installed./ ) ? $this->WARN($e) : $this->NOTE($e) );
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2013 Foswiki Contributors. Foswiki Contributors
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
