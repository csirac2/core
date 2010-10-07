# See bottom of file for license and copyright information
=begin TML

---+ package Foswiki::Store::Listener;
Abstract base class (interface) for store listeners

=cut

=begin TML

---++ ObjectMethod insert($metaObject)
Event triggered when a new Meta object is inserted into the store

=cut

=begin TML

---++ ObjectMethod update($oldMetaObject[, $newMetaObject])

We are updating the object. This is triggered when a meta-object
is saved. It should be logically equivalent to:
<verbatim>
remove($oldMetaObject)
insert($newMetaObject || $oldMetaObject)
</verbatim>
but listeners may optimise on this. The two parameter form is called when
a topic is moved.

=cut

=begin TML

---++ ObjectMethod remove($metaObject)
We are removing the given object.

=cut

1;
__DATA__

Author: Crawford Currie http://c-dot.co.uk

Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/, http://Foswiki.org/

Copyright (C) 2010 Foswiki Contributors. All Rights Reserved.
Foswiki Contributors are listed in the AUTHORS file in the root
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

