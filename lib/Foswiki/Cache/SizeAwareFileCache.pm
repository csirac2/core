# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2008 Michael Daum http://michaeldaumconsulting.com
#
# All Rights Reserved. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
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

=pod

---+ package Foswiki::Cache::SizeAwareFileCache

Implementation of a Foswiki::Cache using Cache::SizeAwareFileCache

=cut

package Foswiki::Cache::SizeAwareFileCache;

use strict;
use Cache::SizeAwareFileCache;
use Foswiki::Cache;

@Foswiki::Cache::SizeAwareFileCache::ISA = ( 'Foswiki::Cache' );

=pod 

---++ ClassMethod new( $session ) -> $object

Construct a new cache object. 

=cut

sub new {
  my ($class, $session) = @_;

  return bless($class->SUPER::new($session), $class);
}

=pod 

---++ ObjectMethod init($session)

this is called after creating a cache object and when reusing it
on a second call

=cut

sub init {
  my ($this, $session) = @_;

  $this->SUPER::init($session);
  unless($this->{handler}) {
    $this->{handler} = new Cache::SizeAwareFileCache({
        'namespace' => $this->{namespace}, # also encoded into object keys, see Foswiki::Cache::genKey()
        'auto_purge_on_set' => 1,
        'cache_root' => $Foswiki::cfg{Cache}{RootDir} || '/tmp/foswiki_cache',
        'cache_depth' => $Foswiki::cfg{Cache}{SubDirs} || 3,
        'directory_umask' => $Foswiki::cfg{Cache}{Umask} || 077,
        'max_size' => $Foswiki::cfg{Cache}{MaxSize} || 10000,
    });
  }
}


1;
