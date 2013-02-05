# See bottom of file for license and copyright information
package Foswiki::Logger::Compatibility;

use strict;
use warnings;
use utf8;
use Assert;

use Foswiki::Logger ();
our @ISA = ('Foswiki::Logger');
use Foswiki::Logger::EventIterator          ();
use Foswiki::Logger::AggregateEventIterator ();
use Foswiki::Logger::MergeEventIterator     ();

=begin TML

---+ package Foswiki::Logger::Compatibility

Compatibility with old LocalSite.cfg settings, if user has not run
configure yet. This logger is automatically used if Foswiki senses
that the LocalSite.cfg hasn't been modified for 1.1 (configure has
not been run yet). It may also be explicitly selected in
=configure=.

Plain file implementation of the Foswiki Logger interface. Mostly
compatible with TWiki (and Foswiki 1.0.0) log files, except that dates
are recorded using ISO format, and include the time, and it dies when
a log can't be written (rather than printing a warning).

This logger implementation maps groups of levels to a single logfile, viz.
   * =debug= messages are output to $Foswiki::cfg{DebugFileName}
   * =info= messages are output to $Foswiki::cfg{LogFileName}
   * =warning=, =error=, =critical=, =alert=, =emergency= messages are
     output to $Foswiki::cfg{WarningFileName}.
   * =error=, =critical=, =alert=, and =emergency= messages are also
     written to standard error (the webserver log file, usually)

This is a copy of the Foswiki 1.0 code.

=cut

use Foswiki::Time            ();
use Foswiki::Configure::Load ();
use Fcntl qw(:flock);

use constant TRACE => 0;

# Local symbol used so we can override it during unit testing
sub _time { return time() }

sub new {
    my $class = shift;
    return bless( { acceptsHash => 1, }, $class );
}

=begin TML

---++ ObjectMethod log($level, @fields)

See Foswiki::Logger for the interface.

=cut

sub log {
    my $this = shift;
    my $level;
    my @fields;

    # Native interface:  Convert the hash back to list format
    if ( ref( $_[0] ) eq 'HASH' ) {
        ( $level, @fields ) = Foswiki::Logger::getOldCall(@_);
        return unless defined $level;
    }
    else {
        ( $level, @fields ) = @_;
    }

    my @logs = _getLogsForLevel( [$level] );
    my $log = shift @logs;

    my $now = _time();
    $log = _expandDATE( $log, $now );
    my $time = Foswiki::Time::formatTime( $now, 'iso', 'gmtime' );

    # Unfortunate compatibility requirement; need the level, but the old
    # logfile format doesn't allow us to add fields. Since we are changing
    # the date format anyway, the least pain is to concatenate the level
    # to the date; Foswiki::Time::ParseTime can handle it, and it looks
    # OK too.
    unshift( @fields, "$time $level" );
    my $message =
      '| ' . join( ' | ', map { s/\|/&vbar;/g; $_ } @fields ) . ' |';

    my $file;
    my $mode = '>>';

    # Item10764, SMELL UNICODE: actually, perhaps we should open the stream this
    # way for any encoding, not just utf8. Babar says: check what Catalyst does.
    if (   $Foswiki::cfg{Site}{CharSet}
        && $Foswiki::cfg{Site}{CharSet} =~ /^utf-?8$/ )
    {
        $mode .= ":encoding($Foswiki::cfg{Site}{CharSet})";
    }
    elsif ( utf8::is_utf8($message) ) {
        require Encode;
        $message = Encode::encode( $Foswiki::cfg{Site}{CharSet}, $message, 0 );
    }

    if ( open( $file, $mode, $log ) ) {
        print $file "$message\n";
        close($file);
    }
    else {
        die 'ERROR: Could not write ' . $message . ' to ' . "$log: $!\n";
    }
    if ( $level =~ /^(error|critical|alert|emergency)$/ ) {
        print STDERR "$message\n";
    }
}

=begin TML

---++ StaticMethod eachEventSince($time, $level) -> $iterator

See Foswiki::Logger for the interface.

This logger implementation maps groups of levels to a single logfile, viz.
   * =info= messages are output together.
   * =warning=, =error=, =critical=, =alert=, =emergency= messages are
     output together.
This method cannot 

=cut

sub eachEventSince {
    my ( $this, $time, $level, $version ) = @_;

    $level = ref $level ? $level : [$level];    # Convert level to array.
    my $numLevels = scalar @$level;

    #SMELL: Only returns a single logfile for now
    my @log4level = _getLogsForLevel($level);

    # Find the year-month for the current time
    my $now          = _time();
    my $lastLogYear  = Foswiki::Time::formatTime( $now, '$year', 'servertime' );
    my $lastLogMonth = Foswiki::Time::formatTime( $now, '$mo', 'servertime' );

    # Convert requested level to a regex
    my $reqLevel = join( '|', @$level );
    $reqLevel = qr/(?:$reqLevel)/;

    my @mergeIterators;

    foreach my $log (@log4level) {

        # Find the year-month for the first time in the range
        my $logYear  = $lastLogYear;
        my $logMonth = $lastLogMonth;
        if ( $log =~ /%DATE%/ ) {
            $logYear =
              Foswiki::Time::formatTime( $time, '$year', 'servertime' );
            $logMonth = Foswiki::Time::formatTime( $time, '$mo', 'servertime' );
        }

        # Enumerate over all the logfiles in the time range, creating an
        # iterator for each.
        my @iterators;
        while (1) {
            my $logfile = $log;
            my $logTime = $logYear . sprintf( "%02d", $logMonth );
            $logfile =~ s/%DATE%/$logTime/g;
            my $fh;
            if ( -f $logfile && open( $fh, '<', $logfile ) ) {
                my $logIt =
                  new Foswiki::Logger::EventIterator( $fh, $time,
                    $reqLevel, $numLevels, $version, $logfile );
                $logIt->{logLocked} =
                  eval { flock( $fh, LOCK_SH ) }; # No error in case on non-flockable FS; eval in case flock not supported.
                push( @iterators, $logIt );
            }
            else {

                # Would be nice to report this, but it's chicken and egg and
                # besides, empty logfiles can happen.
                #print STDERR "Failed to open $logfile: $!";
            }
            last if $logMonth == $lastLogMonth && $logYear == $lastLogYear;
            $logMonth++;
            if ( $logMonth == 13 ) {
                $logMonth = 1;
                $logYear++;
            }
        }
        push @mergeIterators,
          new Foswiki::Logger::AggregateEventIterator( \@iterators );
    }

    if (TRACE) {
        require Data::Dumper;
        print STDERR "Merge built for \@mergeIterators "
          . Data::Dumper::Dumper( \@mergeIterators );
    }

    return new Foswiki::Logger::MergeEventIterator( \@mergeIterators );
}

# Expand %DATE% in a logfile name
sub _expandDATE {
    my ( $log, $time ) = @_;
    my $stamp = Foswiki::Time::formatTime( $time, '$year$mo', 'servertime' );
    $log =~ s/%DATE%/$stamp/go;
    return $log;
}

# Get the name of the log for a given reporting level
sub _getLogsForLevel {
    my $level = shift;
    my %logs;
    my $defaultLogDir = '';
    $defaultLogDir = "$Foswiki::cfg{DataDir}/" if $Foswiki::cfg{DataDir};
    my $log;

    foreach my $lvl (@$level) {
        if ( $lvl eq 'debug' ) {
            $log = $Foswiki::cfg{DebugFileName}
              || $defaultLogDir . 'debug%DATE%.txt';
        }
        elsif ( $lvl eq 'info' ) {
            $log = $Foswiki::cfg{LogFileName}
              || $defaultLogDir . 'log%DATE%.txt';
        }
        else {
            ASSERT( $lvl =~ /^(warning|error|critical|alert|emergency)$/ )
              if DEBUG;
            $log = $Foswiki::cfg{WarningFileName}
              || $defaultLogDir . 'warn%DATE%.txt';
        }

      # SMELL: Expand should not be needed, except if bin/configure tries
      # to log to locations relative to $Foswiki::cfg{WorkingDir}, DataDir, etc.
      # Windows seemed to be the most difficult to fix - this was the only thing
      # that I could find that worked all the time.
        Foswiki::Configure::Load::expandValue($log);    # Expand in place
        $logs{$log} = 1;
    }

    return ( keys %logs );
}

1;
__END__
Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
