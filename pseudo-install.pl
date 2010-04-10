#!/usr/bin/perl
use strict;

use File::Path;
use File::Copy;
use File::Spec;
use Cwd;
use Config;
use FindBin;

my $internal_gzip = 1;
eval "require Compress::Zlib";
$internal_gzip = 0 if $@;

our $install;
our $basedir;
our @extensions_path;
our $CAN_LINK;
our $force;
our $parentdir;

my $autoenable = 0;
my $installing = 1;
my $autoconf   = 0;

BEGIN {
    $basedir   = $FindBin::Bin;    # core dir
    $parentdir = "$basedir/..";
    my $path = $ENV{FOSWIKI_EXTENSIONS} || '';
    $path .=
        $Config::Config{path_sep}
      . "$basedir/twikiplugins"
      . $Config::Config{path_sep} . '.'
      . $Config::Config{path_sep}
      . $parentdir;
    @extensions_path =
      grep( -d $_, split( /$Config::Config{path_sep}/, $path ) );

    my $n = 0;
    $n++ while ( -e "testtgt$n" || -e "testlink$n" );
    open( F, '>', "testtgt$n" ) || die "$basedir is not writeable: $!";
    print F "";
    close(F);
    eval {
        symlink( "testtgt$n", "testlink$n" );
        $CAN_LINK = 1;
    };
    unlink( "testtgt$n", "testlink$n" );
}

sub error {
    warn "ERROR: ",@_;
}

sub trace {
    #warn "...",@_,"\n";
}

sub usage {
    my $def           = '(default behaviour on this platform)';
    my $linkByDefault = $CAN_LINK ? $def : "";
    my $copyByDefault = $CAN_LINK ? "" : $def;
    print <<EOM;
 Must be run from the root of a SVN checkout tree

 pseudo-install extensions in a SVN checkout tree

 This is done by a link or copy of the files listed in the MANIFEST
 for the extension. The installer script is *not* called.
 It should be almost equivalent to a tar zx of the packaged extension
 over the dev tree, except that the use of links enable a much
 more useable development environment.

 It picks up the extensions to be installed from a path defined in the
 environment variable FOSWIKI_EXTENSIONS, or if it is not defined,
 from the parent directory of the current checkout.

 Usage: pseudo-install.pl -[feA][l|c|u] [all|default|developer|<module>...]
    -f[orce] - force an action to complete even if there are warnings
    -e[nable] - automatically enable installed plugins in LocalSite.cfg
                (default)
    -m[anual] - no not automatically enable installed plugins in LocalSite.cfg
    -l[ink] - create links $linkByDefault
    -c[opy] - copy instead of linking $copyByDefault
    -u[ninstall] - self explanatory (doesn't remove dirs)
    core - install core (create and link derived objects)
    all - install core + all extensions (big job)
    default - install core + extensions listed in lib/MANIFEST
    developer - core + default + key developer environment
    <module>... one or more extensions to install
    -[A]utoconf - make a simplistic LocalSite.cfg, using just the defaults in lib/Foswiki.spec

 Example:
    softlink and enable FirstPlugin and SomeContrib
        perl pseudo-install.pl -force -enable -link FirstPlugin SomeContrib
    
    
    check out a new trunk, create a default LocalSite.cfg, install and enable
    all the plugins for the default distribution (and then run the unit tests)
        svn co http://svn.foswiki.org/trunk
        cd trunk/core
        ./pseudo-install.pl -A developer
        cd test/unit
        ../bin/TestRunner.pl -clean FoswikiSuite.pm

EOM

}

sub findRelativeTo {
    my ( $startdir, $name ) = @_;

    my @path = split( /[\\\/]+/, $startdir );

    while ( scalar(@path) > 0 ) {
        my $found = join( '/', @path ) . '/' . $name;
        return $found if -e $found;
        pop(@path);
    }
    return;
}

sub installModule {
    my $module = shift;
    $module =~ s#/+$##;    #remove trailing slashes
    print "Processing $module\n";
    my $subdir = 'Plugins';
    $subdir = 'Contrib' if $module =~ /(Contrib|Skin|AddOn|^core)$/;

    my $moduleDir;
    # If $ignoreBlock is true, will ignore blocking files (not complain
    # if a file it is trying to copy in / link already exists)
    my $ignoreBlock = 0;

    if ($module eq 'core') {
        # Special install procedure for core, processes manifest
        # and checks for missing files, and generates derived objects
        # along the way (such as compressed JS and CSS)
        $moduleDir = '.';
        $ignoreBlock = 1;
    } else {
        foreach my $dir (@extensions_path) {
            if ( -d "$dir/$module/" ) {
                $moduleDir = "$dir/$module";
                last;
            }
        }
    }

    unless ( -d $moduleDir ) {
        warn "--> Could not find $module\n";
        return;
    }

    my $manifest = findRelativeTo(
        "$moduleDir/lib/Foswiki/$subdir/$module/", 'MANIFEST' );
    my $libDir = "Foswiki";

    if ( !-e $manifest ) {
        $manifest = findRelativeTo(
            "$moduleDir/lib/TWiki/$subdir/$module/", 'MANIFEST' );
        $libDir = "TWiki";
    }
    if ( -e $manifest ) {
        installFromMANIFEST($module, $moduleDir, $manifest, $ignoreBlock);
    }
    else {
        $libDir = undef;
        warn "---> No MANIFEST in $module (at $manifest)\n";
    }

    return $libDir;
}

sub installFromMANIFEST {
    my ($module, $moduleDir, $manifest, $ignoreBlock) = @_;

    trace "Using manifest from $manifest";

    my $df;
    open( $df, '<', $manifest ) || die $!;
    foreach my $file (<$df>) {
        chomp($file);
        next unless $file =~ /^\w+/;
        $file =~ s/\s.*$//;
        next if -d "$moduleDir/$file";
        my $dir = $file;
        $dir =~ s/\/[^\/]*$//;
        &$install( $moduleDir, $dir, $file, $ignoreBlock );
    }
    close($df);

    if ( -d "$moduleDir/test/unit/$module" ) {
        opendir( $df, "$moduleDir/test/unit/$module" );
        foreach my $f ( grep( /\.pm$/, readdir($df) ) ) {
            &$install( $moduleDir, "test/unit/$module",
                       "test/unit/$module/$f", $ignoreBlock );
        }
        closedir($df);
    }

    # process dependencies, if we are installing
    if ($installing) {
        my $deps = $manifest;
        $deps =~ s/MANIFEST/DEPENDENCIES/;
        if (open( $df, '<', $deps )) {
            trace "read deps from $deps";
            foreach my $dep (<$df>) {
                chomp($dep);
                next unless $dep =~ /^\w+/;
                satisfyDependency(split(/\s*,\s*/, $dep));
            }
            close($df);
        } else {
            warn "*** Could not open $deps\n";
        }
    }
}

sub satisfyDependency {
    my ($mod, $cond, $type, $mess) = @_;

    # First see if we can find it in the install or @INC path
    my $f = $mod;
    $f =~ s#::#/#g;
    foreach my $dir ('./lib', @INC, './lib/CPAN/lib') {
        if (-e "$dir/$f.pm") {
            # Found it
            # TODO: check the version
            trace "$mod is already installed";
            return;
        }
    }
    trace "$mod is not installed";
    # Not found, is it required?
    if ($mess !~ /^required/i) {
        warn "$mod is an optional dependency, but is not installed\n";
        return;
    }
    if ($type eq 'perl' && $mod =~ /^Foswiki/) {
        warn "**** $mod is a required Foswiki dependency, but it is not installed\n";
    } else {
        warn "**** $mod is a required dependency, but it is not installed\n";
    }
}

# See also: just_link
sub copy_in {
    my ( $moduleDir, $dir, $file, $ignoreBlock ) = @_;
    return if ( -e "$file" && $ignoreBlock);  # For core manifest, ignore copy if target exists.
    File::Path::mkpath($dir);
    if ( -e "$moduleDir/$file" ) {
        File::Copy::copy( "$moduleDir/$file", $file )
          || die "Couldn't install $file: $!";
    }
    print "Copied $file\n";
}

sub _cleanPath {
    my ( $path, $base ) = @_;

    # Convert relative paths to absolute
    if ( $path !~ /^\// ) {
        $path = "$base/$path" if $base;
        $path = File::Spec->rel2abs( $path, $basedir );
    }
    $path = File::Spec->canonpath($path);
    while ( $path =~ s#/[^/]+/\.\.## ) { }
    return $path;
}

# Check that $path$c links to $moduleDir/$path$c
sub _checkLink {
    my ( $moduleDir, $path, $c ) = @_;

    my $dest = _cleanPath( readlink( $path . $c ), $path );
    $dest =~ m#/([^/]*)$#;    # Remove slashes
    unless ( $1 eq $c ) {
        warn <<HERE;
WARNING Confused by
     $path -> '$dest' doesn't point to the expected place
     (should be $moduleDir$path$c)
HERE
    }

    my $expected = _cleanPath("$moduleDir/$path$c");
    if ( $dest ne $expected ) {
        warn <<HERE;
WARNING Confused by
     $path$c -> '$dest' doesn't point to the expected place
     (should be $expected)
HERE
        return 0;
    }
    return 1;
}

# See also: copy_in
# Will try to link as high in the dir structure as it can
sub just_link {
    my ( $moduleDir, $dir, $file, $ignoreBlock ) = @_;

    my $base       = "$moduleDir/";
    my @components = split( /\/+/, $file );
    my $path       = '';
    foreach my $c (@components) {
        if ( -l $path . $c ) {
            _checkLink( $moduleDir, $path, $c ) unless $ignoreBlock;

            #warn "$path$c already linked\n";
            last;
        }
        elsif ( -d "$path$c" ) {
            $path .= "$c/";
        }
        elsif ( -e "$path$c" ) {
            warn "ERROR $path$c is in the way\n" unless $ignoreBlock;
            last;
        }
        elsif (( $c eq 'TWiki' )
            or ( $c eq 'Plugins' && $path =~ m#/(Fosw|TW)iki/$# ) )
        {    # Special case
            $path .= "$c/";
            warn "mkdir $path\n";
            if ( !mkdir( _cleanPath($path) ) ) {
                warn "Could not mkdir $path: $!\n";
                last;
            }
        }
        else {
            my $tgt = _cleanPath("$base$path$c");
            if ( -e $tgt ) {
                die "Failed to link $path$c to $tgt: $!"
                  unless symlink( $tgt, _cleanPath( $path . $c ) );
            }
            else {
                warn "WARNING: no such file $tgt\n";
            }
            print "Linked $path$c\n";
            last;
        }
    }

    # Special case s for derived objects created by compression and/or
    # zipping.
    my $found = -f "$moduleDir/$file";

    # Unlink zip generated by compression. This is inefficient, but
    # the alternative is comparing file dates, which is hard work.
    if ($found && ! -l "$moduleDir/$file" && $file =~ /\.gz$/) {
        unlink "$moduleDir/$file";
        $found = 0;
    }

    unless ($found) {
        trace "$moduleDir/$file not found";
        my $compress = 0;
        if (!$found && $file =~ /(.*)\.gz$/) {
            $file = $1;
            $found = (-f "$moduleDir/$1");
            $compress = 1;
        }
        if ( !$found && $file =~ /^(.+)(\.(?:un)?compressed|_src)(\..+)$/
            && -f "$moduleDir/$1$3" )
        {
            trace "...link $moduleDir/$file to $moduleDir/$1$3";
            symlink( _cleanPath("$moduleDir/$file"),
                _cleanPath("$moduleDir/$1$3") )
              or die "Failed to link $moduleDir/$1$3 to moduleDir/$file: $!";
            print "Linked $file as $1$3\n";
            $found++;
        }
        elsif ( !$found && $file =~ /^(.+)(\.[^\.]+)$/) {
            my ( $src, $ext ) =  ($1, $2);
            for my $kind (qw( .uncompressed .compressed _src )) {
                if ( -f "$moduleDir/$src$kind$ext" ) {
                    trace "...link $moduleDir/$src$kind$ext to $moduleDir/$1$3";
                    symlink(
                        _cleanPath("$moduleDir/$src$kind$ext"),
                        _cleanPath("$moduleDir/$file")
                      )
                      or die
"Failed to link $moduleDir/$file to $moduleDir/$src$kind$ext: $!";
                    print "Linked $file as $src$kind$ext\n";
                    $found++;
                    last;
                }
            }
        }
        if ($found && $compress) {
            trace "...compressed $moduleDir/$file to create $file.gz";
            if ($internal_gzip) {
                open( IF, '<', _cleanPath("$moduleDir/$file") ) || die "Failed to open $file to read: $!";
                local $/ = undef;
                my $text = <IF>;
                close(IF);

                $text = Compress::Zlib::memGzip( $text );

                open( OF, '>', _cleanPath("$moduleDir/$file") . ".gz" ) || die "Failed to open $file.gz to write: $!";
                binmode OF;
                print OF $text;
                close(OF);
            }
            else {
              # Try gzip as a backup, if Compress::Zlib is not available
              my $command = "gzip -c " . _cleanPath("$moduleDir/$file") . " > " . _cleanPath("$moduleDir/$file") . ".gz";
              trace `$command`;
            }
        }
    }
    unless ($found) {
        warn "WARNING: Cannot find source file for $moduleDir/#/$file\n";
        return;
    }
}

sub uninstall {
    my ( $moduleDir, $dir, $file ) = @_;

    # link handling that detects valid linking path components higher in the
    # tree so it unlinks the directories, and not the leaf files.
    # Special case when install created symlink to (un)?compressed version
    if ( -l "$moduleDir/$file" ) {
        unlink "$moduleDir/$file";
        print "Unlinked $moduleDir/$file\n";
    }
    my @components = split( /\/+/, $file );
    my $base       = $moduleDir;
    my $path       = '';
    foreach my $c (@components) {
        if ( -l "$path$c" ) {
            return unless _checkLink( $moduleDir, $path, $c ) || $force;
            unlink "$path$c";
            print "Unlinked $path$c\n";
            return;
        }
        else {
            $path .= "$c/";
        }
    }
    if ( -e $file ) {
        unlink $file;
        print "Removed $file\n";
    }
}

sub Autoconf {
    my ( $moduleDir, $dir, $file ) = @_;

    my $foswikidir   = $basedir;
    my $localSiteCfg = $foswikidir . '/lib/LocalSite.cfg';
    if ( $force || ( !-e $localSiteCfg ) ) {
        my $f;
        open($f, '<', "$foswikidir/lib/Foswiki.spec") ||
          die "Cannot autoconf: $!";
        local $/ = undef;
        my $localsite = <$f>;
        close($f);
	#assume that the commented out settings (DataDir etc) are only on one line.
        $localsite =~ s/^# (\$Foswiki::cfg[^\n]*)/$1/mg;
        $localsite =~ s/^#[^\n]*\n+//mg;
        $localsite =~ s/\n\s+/\n/sg;
        $localsite =~ s/__END__//g;
        if ( $^O eq 'MSWin32' ) {

            #oh wow, windows find is retarded
            $localsite =~ s|^(-------.*)$||m;

            #prefer non-grep SEARCH
            $localsite =~
s|^(.*)SearchAlgorithms::Forking(.*)$|$1SearchAlgorithms::PurePerl$2|m;

            #RscLite
            $localsite =~ s|^(.*)RcsWrap(.*)$|$1RcsLite$2|m;
        }

        $localsite =~ s|/home/httpd/foswiki|$foswikidir|g;

        if ( open( LS, '>', $localSiteCfg ) ) {
            print LS $localsite;
            close(LS);
            warn "wrote simple config to $localSiteCfg\n\n";
        }
        else {
            warn "ERROR: failed to write to $localSiteCfg\n\n";
        }
    }
    else {
        warn "ERROR: won't overwrite $localSiteCfg without -force\n\n";
    }
}

sub enablePlugin {
    my ( $module, $installing, $libDir ) = @_;
    my $cfg = '';
    print "Updating LocalSite.cfg\n";
    if ( open( F, '<', "lib/LocalSite.cfg" ) ) {
        local $/;
        $cfg = <F>;
        $cfg =~ s/\r//g;
    }
    my $changed = 0;
    if ( $cfg =~
        s/\$Foswiki::cfg{Plugins}{$module}{Enabled}\s*=\s*(\d+)[\s;]+//sg )
    {
        $cfg =~ s/\$Foswiki::cfg{Plugins}{$module}{Module}\s*=.*?;\s*//sg;

        # Removed old setting
        $changed = 1;
    }
    if ($installing) {
        $cfg =
            "\$Foswiki::cfg{Plugins}{$module}{Enabled} = 1;\n"
          . "\$Foswiki::cfg{Plugins}{$module}{Module} = '${libDir}::Plugins::$module';\n"
          . $cfg;
        $changed = 1;
    }

    if ($changed) {
        if ( open( F, '>', "lib/LocalSite.cfg" ) ) {
            print F $cfg;
            close(F);
            print(
                ( $installing ? 'En' : 'Dis' ),
                "abled $module in LocalSite.cfg\n"
            );
        }
        else {
            warn "WARNING: failed to write lib/LocalSite.cfg\n";
        }
    }
}

$install = $CAN_LINK ? \&just_link : \&copy_in;

while ( scalar(@ARGV) && $ARGV[0] =~ /^-/ ) {
    my $arg = shift(@ARGV);
    if ( $arg eq '-force' ) {
        $force = 1;
    }
    elsif ( $arg =~ /^-l/ ) {
        $install = \&just_link;
    }
    elsif ( $arg =~ /^-c/ ) {
        $install = \&copy_in;
    }
    elsif ( $arg =~ /^-u/ ) {
        $install    = \&uninstall;
        $installing = 0;
    }
    elsif ( $arg =~ /^-e/ ) {
        $autoenable = 1;
    }
    elsif ( $arg =~ /^-m/ ) {
        $autoenable = 0;
    }
    elsif ( $arg =~ /^-A/ ) {
        $autoconf = 1;
    }
}

if ($autoconf) {
    Autoconf();
    exit 0 unless ( scalar(@ARGV) );
}

unless ( scalar(@ARGV) ) {
    usage();
    exit 1;
}

my @modules;
for my $arg (@ARGV) {
    if ( $arg eq "all" ) {
        push(@modules, 'core');
        foreach my $dir (@extensions_path) {
            my $d;
            opendir $d, $dir or next;
            push @modules,
              grep { /(?:Tag|Plugin|Contrib|Skin|AddOn)$/ && -d "$dir/$_" }
              readdir $d;
            closedir $d;
        }
    }
    elsif ( $arg eq 'default' || $arg eq 'developer' ) {
        my $f;
        open $f, "<", "lib/MANIFEST" or die "Could not open MANIFEST: $!";
        local $/ = "\n";
        @modules =
          map { /(\w+)$/; $1 }
          grep { /^!include/ } <$f>;
        close $f;
        push @modules, 'BuildContrib', 'TestFixturePlugin', 'UnitTestContrib'
          if $arg eq 'developer';
    }
    else {
        push @modules, $arg;
    }
    # *Never* uninstall 'core'
    @modules = grep { !/^core$/ } @modules unless $installing;
}

print(
    ( $installing ? 'I' : 'Uni' ),
    "nstalling extensions: ",
    join( ", ", @modules ), "\n"
);

my @installedModules;
foreach my $module (@modules) {
    my $libDir = installModule($module);
    if ($libDir) {
        push( @installedModules, $module );
        if ( ( !$installing || $autoenable ) && $module =~ /Plugin$/ ) {
            enablePlugin( $module, $installing, $libDir );
        }
    }
}

print ' '
  . ( scalar(@installedModules) ? join( ", ", @installedModules )
        : 'No modules' )
  . ' '
  . ( $installing ? 'i' : 'uni' )
  . "nstalled\n";
