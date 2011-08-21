#!/usr/bin/perl -wT
# See bottom of file for license and copyright information
use strict;
use warnings;

use re 'taint';
use File::Path();
use File::Copy();
use File::Spec();
use FindBin();
use English qw( -no_match_vars );

my $usagetext = <<'EOM';
pseudo-install extensions into a SVN (or git) checkout

This is done by a link or copy of the files listed in the MANIFEST for the
extension. The installer script is *not* called. It should be almost equivalent
to a tar zx of the packaged extension over the dev tree, except that the use
of links enable a much more useable development environment.

It picks up extensions to be installed from a search path compiled from (1) the
environment variable $FOSWIKI_EXTENSIONS, then (2) the extensions_path array
defined under the key 'pseudo-install' in the config file ($HOME/.buildcontrib
by default). The default path includes current working directory & its parent.

Usage: pseudo-install.pl -[G|C][feA][l|c|u] [all|default|developer|<module>
                                            |git://a.git/url, a@g.it:/url etc.]
   -C[onfig]    - path to config file (default $HOME/.buildcontrib, or envar
                                               $FOSWIKI_PSEUDOINSTALL_CONFIG)
   -G[enerate]  - generate default psuedo-install config in $HOME/.buildcontrib
   -f[orce]     - force an action to complete even if there are warnings
   -e[nable]    - automatically enable installed plugins in LocalSite.cfg
                  (default)
   -m[anual]    - do not automatically enable installed plugins in LocalSite.cfg
   -l[ink]      - create links %linkByDefault%
   -c[opy]      - copy instead of linking %copyByDefault%
   -u[ninstall] - self explanatory (doesn't remove dirs)
   core         - install core (create and link derived objects)
   all          - install core + all extensions (big job)
   default      - install core + extensions listed in lib/MANIFEST
   developer    - core + default + key developer environment
   <module>...  - one or more extensions to install (by name or git URL)
   -[A]utoconf  - make a simplistic LocalSite.cfg, using just the defaults in lib/Foswiki.spec

Examples:
   softlink and enable FirstPlugin and SomeContrib
       perl pseudo-install.pl -force -enable -link FirstPlugin SomeContrib
   
   check out a new trunk, create a default LocalSite.cfg, install and enable
   all the plugins for the default distribution (and then run the unit tests)
       svn co http://svn.foswiki.org/trunk
       cd trunk/core
       ./pseudo-install.pl -A developer
       cd test/unit
       ../bin/TestRunner.pl -clean FoswikiSuite.pm

   check out a new trunk using git, then install and enable an extension from
   an abritrary git repository
       git clone git://github.com/foswiki/core.git
       cd core
       ./pseudo-install.pl -A developer
       ./pseudo-install.pl -e git@github.com:/me/MyPlugin.git
EOM
my $install;
my $basedir;
my $CAN_LINK;
my $force;
my $parentdir;
my $fetchedExtensionsPath;
my @error_log;
my %config;
my $do_genconfig;
my @extensions_path;
my $autoenable    = 0;
my $installing    = 1;
my $autoconf      = 0;
my $config_file   = $ENV{FOSWIKI_PSEUDOINSTALL_CONFIG};
my $internal_gzip = eval { require Compress::Zlib; 1; };
my %arg_dispatch  = (
    '-f' => sub { $force   = 1 },
    '-l' => sub { $install = \&just_link },
    '-c' => sub {
        $install  = \&copy_in;
        $CAN_LINK = 0;
    },
    '-u' => sub {
        $install    = \&uninstall;
        $installing = 0;
    },
    '-e' => sub {
        $autoenable = 1;
    },
    '-m' => sub {
        $autoenable = 0;
    },
    '-A' => sub {
        $autoconf = 1;
    },
    '-C' => sub {
        $config_file = shift(@ARGV);
    },
    '-G' => sub {
        $do_genconfig = 1;
    }
);
my %default_config = (
    repos => [
        {
            type     => 'svn',
            url      => 'http://svn.foswiki.org',
            branches => {
                pharvey => {
                    WikiDrawPlugin => 'branches/scratch/pharvey/WikiDrawPlugin'
                },
                ItaloValcy => {
                    ImageGalleryPlugin =>
                      'branches/scratch/ItaloValcy/ImageGalleryPlugin_5x10'
                },
                'Release01x00' => { path => 'branches/Release01x00' },
                'Release01x01' => { path => 'branches/Release01x01' },
                'trunk'        => { path => 'trunk' }
            }
        },
        {
            type => 'git',
            url  => 'git://github.com/foswiki',
            svn  => 'http://svn.foswiki.org',
            bare => 1,
            note => <<'HERE'
This will automatically configure any cloned git repo with git-svn to track
svn.foswiki.org, because the svn value matches the url of the svn repo.
HERE
        }
    ],
    extensions_path => [ '$basedir/twikiplugins', '.', '$parentdir' ],
    clone_dir       => '$parentdir'
);

sub init {
    no re 'taint';
    $FindBin::Bin =~ /(.*)/;    # core dir
    $basedir = $1;
    use re 'taint';
    $parentdir             = "$basedir/..";
    $fetchedExtensionsPath = $parentdir;
    my $n = 0;
    $n++ while ( -e "testtgt$n" || -e "testlink$n" );
    open( my $testfile, '>', "testtgt$n" )
      or die "$basedir is not writable: $!";
    print $testfile "";
    close $testfile;
    $CAN_LINK = eval {
        symlink( "testtgt$n", "testlink$n" );
        1;
    };
    if ( $CAN_LINK and not $EVAL_ERROR ) {
        $install = \&just_link;
    }
    else {
        $install = \&copy_in;
    }
    unlink( "testtgt$n", "testlink$n" );

    return;
}

sub init_config {
    if ( not $config_file ) {
        if ( $ENV{HOME} ) {
            $config_file = File::Spec->catfile( $ENV{HOME}, '.buildcontrib' );
        }
    }
    if ( $config_file and -f $config_file ) {
        my $buildconfig;

        $config_file = untaint($config_file);
        $buildconfig = do "$config_file";
        die "Malformed config: '$config_file'"
          unless ref($buildconfig) eq 'HASH';
        if ( exists $buildconfig->{'pseudo-install'} ) {
            die "Malformed config: '$config_file'"
              unless ref( $buildconfig->{'pseudo-install'} ) eq 'HASH';
            %config = %{ $buildconfig->{'pseudo-install'} };
        }
    }
    if ($do_genconfig) {
        genconfig();
    }
    if ( not scalar( keys %config ) ) {
        %config = %default_config;
    }
    if ( $config{extensions_path} ) {
        die "Malformed config: '$config_file'"
          unless ref( $config{extensions_path} ) eq 'ARRAY';
        @{ $config{extensions_path} } =
          map { expandConfigPathTokens($_) } @{ $config{extensions_path} };
    }
    if ( $config{clone_dir} ) {
        $config{clone_dir} = expandConfigPathTokens( $config{clone_dir} );
    }

    return;
}

sub init_extensions_path {
    my %paths;

    if ( $ENV{FOSWIKI_EXTENSIONS} ) {
        my @filtered = filterpaths( \%paths, $ENV{FOSWIKI_EXTENSIONS} );

        # Only put FOSWIKI_EXTENSIONS first in the search path if that dir is
        # not already in the search path
        if ( scalar(@filtered) ) {
            unshift( @extensions_path, @filtered );
        }
    }
    push( @extensions_path,
        filterpaths( \%paths, @{ $config{extensions_path} } ) );

    return;
}

sub genconfig {
    my $buildconfig;
    my $needforce;

    # Detect if we're about to clobber some stuff in the existsing buildconfig
    if ( -f $config_file ) {
        $buildconfig = do "$config_file";
        if ( exists $buildconfig->{'pseudo-install'} ) {
            foreach my $key ( keys %default_config ) {
                if ( exists $buildconfig->{'pseudo-install'}{$key} ) {
                    $needforce = 1;
                }
            }
        }
    }
    if ( $needforce and not $force ) {
        die <<"HERE";
Not writing a default pseudo-install config into '$config_file': already
contains a pseudo-install config, and -f (force) not specified.
HERE
    }
    elsif ( not -f $config_file or -w $config_file ) {
        foreach my $key ( keys %default_config ) {
            $buildconfig->{'pseudo-install'}{$key} = $default_config{$key};
        }
        $config_file = untaint($config_file);
        if ( open( my $fh, '>', $config_file ) ) {
            require Data::Dumper;
            print $fh Data::Dumper->Dump( [$buildconfig] );
            if ( close($fh) ) {
                print <<"HERE";
Successfully wrote a default 'pseudo-install' config into
'$config_file'
HERE
            }
        }
        else {
            die <<"HERE";
Failed to write a default pseudo-install config into
'$config_file': error opening for write
HERE
        }
    }
    else {
        die <<"HERE";
Failed to write a default pseudo-install config into
'$config_file': not writeable
HERE
    }

    return;
}

# Remove duplicates and missing dirs
sub filterpaths {
    my ( $map, @paths ) = @_;
    my @result;

    foreach my $p ( grep { -d $_ } @paths ) {
        if ( not exists $map->{$p} ) {
            $map->{$p} = 1;
            push( @result, $p );
        }
    }

    return @result;
}

sub expandConfigPathTokens {
    my ($path) = @_;

    $path =~ s/\$parentdir/$parentdir/g;
    $path =~ s/\$basedir/$basedir/g;

    return $path;
}

sub untaint {
    no re 'taint';
    $_[0] =~ /^(.*)$/;
    use re 'taint';

    return $1;
}

sub error {
    my @errors = @_;

    push @error_log, @errors;
    warn 'ERROR: ', @errors;

    return;
}

sub trace {

    #warn "...",@_,"\n";

    return;
}

sub usage {
    my $def           = '(default behaviour on this platform)';
    my $linkByDefault = $CAN_LINK ? $def : "";
    my $copyByDefault = $CAN_LINK ? "" : $def;

    $usagetext =~ s/%linkByDefault%/$linkByDefault/g;
    $usagetext =~ s/%copyByDefault%/$copyByDefault/g;
    print $usagetext;

    return;
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

sub findModuleDir {
    my ($module) = @_;
    my $moduleDir;

    foreach my $dir (@extensions_path) {
        if ( -d "$dir/$module/" ) {
            $moduleDir = "$dir/$module";
            last;
        }
    }

    return $moduleDir;
}

sub urlToModuleName {
    my ($url) = @_;

    $url =~ /^.*\/([^\.\/]+)(\.git)?\/?$/;

    return $1;
}

sub installModule {
    my ($module) = @_;

    # Assume that only URLs will have '.' or '/', never module names
    if ( $module =~ /[\/\.]/ ) {
        cloneModuleByURL( $config{clone_dir}, $module );
        $module = urlToModuleName($module);
    }

    return installModuleByName($module);
}

sub installModuleByName {
    my $module = shift;
    my $subdir = 'Plugins';
    my $libDir = 'Foswiki';
    my $moduleDir;
    my $manifest;

    # If $ignoreBlock is true, will ignore blocking files (not complain
    # if a file it is trying to copy in / link already exists)
    my $ignoreBlock = 0;

    $module =~ s#/+$##;    #remove trailing slashes
    print "Processing $module\n";
    $subdir = 'Contrib' if $module =~ /(Contrib|Skin|AddOn|^core)$/;

    if ( $module eq 'core' ) {

        # Special install procedure for core, processes manifest
        # and checks for missing files
        $moduleDir   = '.';
        $ignoreBlock = 1;
    }
    else {
        $moduleDir = findModuleDir($module);
    }

    if ( not defined $moduleDir ) {
        $moduleDir = cloneModuleByName($module);
    }

    unless ( defined $moduleDir and -d $moduleDir ) {
        warn "--> Could not find $module\n";
        return;
    }
    $manifest =
      findRelativeTo( "$moduleDir/lib/Foswiki/$subdir/$module/", 'MANIFEST' );
    if ( !-e $manifest ) {
        $manifest =
          findRelativeTo( "$moduleDir/lib/TWiki/$subdir/$module/", 'MANIFEST' );
        $libDir = 'TWiki';
    }
    if ( -e $manifest ) {
        installFromMANIFEST( $module, $moduleDir, $manifest, $ignoreBlock );
    }
    else {
        $libDir = undef;
        warn "---> No MANIFEST in $module (at $manifest)\n";
    }

    return $libDir;
}

sub populateSVNRepoListings {
    my ($svninfo) = @_;
    my $ctx;

    if ( not eval { require SVN::Client; 1 } or $EVAL_ERROR ) {
        warn <<'HERE';
SVN::Client not installed, unable discover branch listings from SVN
HERE
        return;
    }

    $ctx = SVN::Client->new();
    $svninfo->{extensions} = {};
    while ( my ( $branch, $branchdata ) = each( %{ $svninfo->{branches} } ) ) {

        # If it contains a path key, then assume we need to populate the list
        # of extensions this branch contains via SVN listing
        if ( $branchdata->{path} ) {
            my @branchextensions;
            print "Listing $svninfo->{url}/$branchdata->{path}\n";
            @branchextensions =
              keys %{
                $ctx->ls( $svninfo->{url} . '/' . $branchdata->{path},
                    'HEAD', 0 )
              };
            foreach my $ext (@branchextensions) {
                if ( $ext ne 't2fos.sh' ) {
                    $branchdata->{$ext} = $branchdata->{path} . '/' . $ext;
                    push(
                        @{ $svninfo->{extensions}->{$ext} },
                        { branch => $branch, path => $branchdata->{$ext} }
                    );
                }
            }
        }

        # Else, we have a manual branch+path mapping for a given extension
        else {
            while ( my ( $ext, $path ) = each %{$branchdata} ) {
                push(
                    @{ $svninfo->{extensions}->{$ext} },
                    { branch => $branch, path => $path }
                );
            }
        }
    }

    return;
}

sub gitClone2GitSVN {
    my ( $module, $moduleDir, $svninfo ) = @_;
    my $success = 0;

    if ( $svninfo->{extensions}->{$module} ) {
        foreach my $branchdata ( @{ $svninfo->{extensions}->{$module} } ) {
            if ( $branchdata->{branch} ne 'trunk' ) {
                my $svnremoteref = "refs/remotes/$branchdata->{path}";
                my $gitremoteref = "origin/$branchdata->{branch}";
                my $svnurl =
"$svninfo->{url}/$svninfo->{branches}->{$branchdata->{branch}}->{path}/$module";
                print "Aliasing $svnremoteref as $gitremoteref\n";
                do_commands(<<"HERE");
cd $moduleDir
git update-ref $svnremoteref $gitremoteref
HERE
                print "\tclone from SVN url $svnurl :$svnremoteref\n";
                do_commands(<<"HERE");
cd $moduleDir
git config svn-remote.$branchdata->{branch}.url $svnurl
git config svn-remote.$branchdata->{branch}.fetch :$svnremoteref
HERE
            }
        }
        print
"Aliasing refs/remotes/$svninfo->{branches}->{trunk}->{path}/$module as refs/remotes/trunk &\n";
        print "Aliasing refs/remotes/trunk as origin/master\n";
        do_commands(<<"HERE");
cd $moduleDir
git update-ref refs/remotes/trunk origin/master
git svn init $svninfo->{url} -T $svninfo->{branches}->{trunk}->{path}/$module
HERE
        $success = 1;
    }
    else {
        print STDERR <<"HERE";
Couldn't find $module at $svninfo->{url} in any branch paths,
module is not configured for git-svn
HERE
    }

    return $success;
}

sub do_commands {
    my ($commands) = @_;

    #print $commands . "\n";
    local $ENV{PATH} = untaint( $ENV{PATH} );

    return `$commands`;
}

sub connectGitRepoToSVN {
    my ( $module, $moduleDir, $svninfo ) = @_;

    if ( not $svninfo->{extensions}->{$module} ) {
        populateSVNRepoListings($svninfo);
    }

    return gitClone2GitSVN( $module, $moduleDir, $svninfo );
}

sub connectGitRepoToSVNByRepoURL {
    my ( $module, $moduleDir, $svnreponame ) = @_;
    my $lookingupname = 1;
    my $repoIndex     = 0;

    while ( $lookingupname and $repoIndex < scalar( @{ $config{repos} } ) ) {
        if ( $config{repos}->[$repoIndex]->{url} eq $svnreponame ) {
            $lookingupname = 0;
            connectGitRepoToSVN( $module, $moduleDir,
                $config{repos}->[$repoIndex] );
        }
        else {
            $repoIndex = $repoIndex + 1;
        }
    }

    return;
}

sub cloneModuleByName {
    my ($module)  = @_;
    my $cloned    = 0;
    my $repoIndex = 0;
    my $moduleDir = "$config{clone_dir}/$module";

    while ( not $cloned and ( $repoIndex < scalar( @{ $config{repos} } ) ) ) {
        if ( $config{repos}->[$repoIndex]->{type} eq 'git' ) {
            my $url = $config{repos}->[$repoIndex]->{url} . "/$module";

            if ( $config{repos}->[$repoIndex]->{bare} ) {
                $url .= '.git';
            }
            cloneModuleByURL( $config{clone_dir}, $url );
            if ( -d $moduleDir ) {
                $cloned = 1;
                if ( $config{repos}->[$repoIndex]->{svn} ) {
                    connectGitRepoToSVNByRepoURL( $module, $moduleDir,
                        $config{repos}->[$repoIndex]->{svn} );
                }
                print "Cloned $module OK\n";
            }
            else {
                $repoIndex = $repoIndex + 1;
            }
        }
        else {
            $repoIndex = $repoIndex + 1;
        }
    }
    if ( not checkModuleByNameHasSVNBranch( 'core', 'Release01x01' ) ) {
        my $svnRepo = getSVNRepoByModuleBranchName( 'core', 'Release01x01' );

        print "It seems your 'core' checkout isn't connected to a svn repo... ";
        if ($svnRepo) {
            print "connecting\n";
            connectGitRepoToSVNByRepoURL( 'core', "$config{clone_dir}/core",
                $svnRepo->{url} );
        }
        else {
            print "couldn't find any svn repo containing 'core'\n";
        }
    }

    return $moduleDir;
}

sub getSVNRepoByModuleBranchName {
    my ( $module, $branch ) = @_;
    my $svnRepo;
    my $nRepos = scalar( @{ $config{repos} } );
    my $i      = 0;

    while ( not $svnRepo and $i < $nRepos ) {
        my $repo = $config{repos}->[$i];

        if ( $repo->{type} eq 'svn' ) {
            if ( $repo->{branches}->{$branch} ) {
                if ( $repo->{branches}->{$branch}->{$module} ) {
                    $svnRepo = $repo;
                }
            }
        }
        $i += 1;
    }

    return $svnRepo;
}

sub checkModuleByNameHasSVNBranch {
    my ( $module, $branch ) = @_;

    return do_commands(<<"HERE") ? 1 : 0;
cd $config{clone_dir}/$module
git config --get svn-remote.$branch.url
HERE
}

sub cloneModuleByURL {
    my ( $target, $source ) = @_;

    #TODO: Make this capable of using svn as an alternative

    return gitCloneFromURL( $target, $source );
}

sub gitCloneFromURL {
    my ( $target, $source ) = @_;
    my $command   = "cd $target && git clone $source";
    my $moduleDir = "$target/" . urlToModuleName($source);

    if ( not -d $moduleDir ) {
        print "Trying clone from $source...\n";
        local $ENV{PATH} = untaint( $ENV{PATH} );
        trace `$command`;
    }
    else {
        print STDERR "$moduleDir already exists\n";
    }

    return;
}

sub installFromMANIFEST {
    my ( $module, $moduleDir, $manifest, $ignoreBlock ) = @_;

    trace "Using manifest from $manifest";

    open( my $df, '<', $manifest ) or die $!;
    foreach my $file (<$df>) {
        chomp($file);
        next unless $file =~ /^\w+/;
        $file =~ s/\s.*$//;
        next if -d "$moduleDir/$file";
        $file = untaint($file);
        my $dir = $file;
        $dir =~ s/\/[^\/]*$//;
        $install->( $moduleDir, $dir, $file, $ignoreBlock );

        if ($installing) {

            # Unlink zip generated by compression. This is inefficient, but
            # the alternative is comparing file dates, which is hard work.
            if ( -f "$moduleDir/$file" && $file =~ /\.gz$/ ) {
                unlink _cleanPath("$moduleDir/$file");
            }

            # Special cases for derived objects created by compression and/or
            # zipping.
            my $found = -f "$moduleDir/$file";

            unless ($found) {
                $found = generateAlternateVersion( $moduleDir, $dir, $file,
                    $CAN_LINK );
            }
            unless ($found) {
                warn
                  "WARNING: Cannot find source file for $moduleDir/#/$file\n";
            }
        }
    }
    close $df;

    if ( -d "$moduleDir/test/unit/$module" ) {
        opendir( $df, "$moduleDir/test/unit/$module" );
        foreach my $f ( grep { /\.pm$/ } readdir($df) ) {
            $f = untaint($f);
            $install->(
                $moduleDir, "test/unit/$module", "test/unit/$module/$f",
                $ignoreBlock
            );
        }
        closedir $df;
    }

    # process dependencies, if we are installing
    if ($installing) {
        my $deps = $manifest;
        $deps =~ s/MANIFEST/DEPENDENCIES/;
        if ( open( $df, '<', $deps ) ) {
            trace "read deps from $deps";
            my $skipnext = 0;
            foreach my $dep (<$df>) {
                chomp($dep);
                if ($skipnext) {
                    $skipnext = 0;
                    next;
                }
                next unless $dep =~ /^\w+/;

                # We skip the next line if we each an ONLYIF assuming these
                # are dependencies only for old versions of Foswiki
                # and not something a developer needs to worry about
                # Otherwise we get a lot of false warnings about
                # ZonePlugin missing
                if ( $dep =~ /^ONLYIF/ ) {
                    $skipnext = 1;
                    next;
                }
                satisfyDependency( split( /\s*,\s*/, $dep ) );
            }
            close $df;
        }
        else {
            error "*** Could not open $deps\n";
        }
    }
    if ( $installing and $autoconf ) {

        # Read current LocalSite.cfg to see if the current module is enabled
        my $localSiteCfg = $basedir . '/lib/LocalSite.cfg';
        open my $lsc, '<', $localSiteCfg
          or die "Cannot open $localSiteCfg for reading: $!";
        my $enabled = 0;
        my $spec;
        my $localConfiguration = '';
        while (<$lsc>) {

            # Can't $_ eq '1;' because /^1;$/ is less picky about newlines
            next if /^1;$/;
            $localConfiguration .= $_;
            if (m/^\$Foswiki::cfg{Plugins}{$module}{(\S+)}\s+=\s+(\S+);/) {
                if ( $1 eq 'Enabled' ) {
                    $enabled = $2;
                }
                elsif ( $1 eq 'Module' ) {
                    my $moduleName = $2;
                    $moduleName =~ s#::#/#g;
                    $moduleName =~ s#'##g;
                    $spec = "$basedir/lib/$moduleName/Config.spec";
                }
            }
        }
        close $lsc;
        if ( $enabled && $spec && -f $spec ) {
            if ( open( my $pluginSpec, '<', $spec ) ) {
                $localConfiguration .= "# $module specific configuration\n";
                while (<$pluginSpec>) {
                    next if /^(?:1;|\s*|#.*)$/;
                    $localConfiguration .= $_;
                }
                close $pluginSpec;
                $localConfiguration .= "1;\n";
                if ( open( my $lsc, '>', $localSiteCfg ) ) {
                    print $lsc $localConfiguration;
                    close $lsc;
                    warn "Added ${module}'s Config.spec to $localSiteCfg\n";
                }
                else {
                    warn "Could not write new $localSiteCfg: $!\n";
                }
            }
            else {
                warn "Could not open spec file $spec for $module: $!\n";
            }
        }
    }

    return;
}

sub package_exists {
    my ($mod) = @_;
    local @INC = @INC;
    my @curdir = File::Spec->splitdir( File::Spec->curdir() );

    # Add ./lib to front of INC path
    unshift( @INC, File::Spec->catdir( @curdir, 'lib' ) );

    # Add ./lib/CPAN/lib to end of INC path
    push( @INC, File::Spec->catdir( @curdir, qw(lib CPAN lib) ) );
    no re 'taint';
    $mod =~ /^([\w:]+)$/;
    $mod = $1;
    use re 'taint';

    return eval "require $mod; 1;" and not $EVAL_ERROR;
}

sub satisfyDependency {
    my ( $mod, $cond, $type, $mess ) = @_;

    # First see if we can find it in the install or @INC path
    if ( package_exists($mod) ) {
        trace "$mod is already installed";
    }
    else {
        trace "$mod is not installed";

        # Not found, is it required?
        if ( $mess !~ /^required/i ) {
            warn "$mod is an optional dependency, but is not installed\n";
            return;
        }
        if ( $type eq 'perl' && $mod =~ /^Foswiki/ ) {
            error
"**** $mod is a required Foswiki dependency, but it is not installed\n";
        }
        else {
            error
              "**** $mod is a required dependency, but it is not installed\n";
        }
    }

    return;
}

sub linkOrCopy {
    my ( $moduleDir, $source, $target, $link ) = @_;

    trace '...'
      . ( $link ? 'link' : 'copy' )
      . " $moduleDir/$source to $moduleDir/$target";
    if ($link) {
        symlink(
            _cleanPath("$moduleDir/$source"),
            _cleanPath("$moduleDir/$target")
          )
          or die "Failed to link $moduleDir/$source as $moduleDir/$target: $!";
        print "Linked $source as $target\n";
    }
    else {
        if ( -e "$moduleDir/$source" ) {
            File::Copy::copy( "$moduleDir/$source", $target )
              || die "Couldn't install $target: $!";
        }
        print "Copied $source as $target\n";
    }

    return;
}

# Tries to find out alternate versions of a file
# So that file.js.gz and file.uncompressed.js get created
sub generateAlternateVersion {
    my ( $moduleDir, $dir, $file, $link ) = @_;
    my $found = 0;
    trace "$moduleDir/$file not found";
    my $compress = 0;

    if ( !$found && $file =~ /(.*)\.gz$/ ) {
        $file     = $1;
        $found    = ( -f "$moduleDir/$1" );
        $compress = 1;
    }
    if (  !$found
        && $file =~ /^(.+)(\.(?:un)?compressed|_src)(\..+)$/
        && -f "$moduleDir/$1$3" )
    {
        linkOrCopy $moduleDir, $file, "$1$3", $link;
        $found++;
    }
    elsif ( !$found && $file =~ /^(.+)(\.[^\.]+)$/ ) {
        my ( $src, $ext ) = ( $1, $2 );
        for my $kind (qw( .uncompressed .compressed _src )) {
            if ( -f "$moduleDir/$src$kind$ext" ) {
                linkOrCopy $moduleDir, "$src$kind$ext", $file, $link;
                $found++;
                last;
            }
        }
    }
    if ( $found && $compress ) {
        trace "...compressed $file to create $file.gz";
        if ($internal_gzip) {
            open( my $if, '<', _cleanPath($file) )
              or die "Failed to open $file to read: $!";
            local $/ = undef;
            my $text = <$if>;
            close($if);

            $text = Compress::Zlib::memGzip($text);

            open( my $of, '>', _cleanPath($file) . ".gz" )
              or die "Failed to open $file.gz to write: $!";
            binmode $of;
            print $of $text;
            close($of);
        }
        else {

            # Try gzip as a backup, if Compress::Zlib is not available
            my $command =
                "gzip -c "
              . _cleanPath($file) . " > "
              . _cleanPath($file) . ".gz";
            local $ENV{PATH} = untaint( $ENV{PATH} );
            trace `$command`;
        }
    }

    return $found;
}

# See also: just_link
sub copy_in {
    my ( $moduleDir, $dir, $file, $ignoreBlock ) = @_;

    # For core manifest, ignore copy if target exists.
    return if -e $file and $ignoreBlock;
    File::Path::mkpath( _cleanPath($dir) );
    if ( -e "$moduleDir/$file" ) {
        File::Copy::copy( "$moduleDir/$file", $file )
          or die "Couldn't install $file: $!";
        print "Copied $file\n";
    }

    return;
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

    return untaint($path);
}

# Check that $path$c links to $moduleDir/$path$c
sub _checkLink {
    my ( $moduleDir, $path, $c ) = @_;
    my $expected;
    my $dest = _cleanPath( readlink( $path . $c ), $path );

    $dest =~ m#/([^/]*)$#;    # Remove slashes
    unless ( $1 eq $c ) {
        warn <<"HERE";
WARNING Confused by
     $path -> '$dest' doesn't point to the expected place
     (should be $moduleDir$path$c)
HERE
    }

    $expected = _cleanPath("$moduleDir/$path$c");
    if ( $dest ne $expected ) {
        warn <<"HERE";
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
            last;
        }
        elsif ( -d "$path$c" ) {
            $path .= "$c/";
        }
        elsif ( -e "$path$c" ) {
            error "$path$c is in the way\n" unless $ignoreBlock;
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
                print "Linked $path$c\n";
            }
            last;
        }
    }

    return;
}

sub uninstall {
    my ( $moduleDir, $dir, $file ) = @_;

    # link handling that detects valid linking path components higher in the
    # tree so it unlinks the directories, and not the leaf files.
    # Special case when install created symlink to (un)?compressed version
    if ( -l "$moduleDir/$file" ) {
        unlink _cleanPath("$moduleDir/$file");
        print "Unlinked $moduleDir/$file\n";
    }
    my @components = split( /\/+/, $file );
    my $base       = $moduleDir;
    my $path       = '';

    foreach my $c (@components) {
        if ( -l "$path$c" ) {
            return unless _checkLink( $moduleDir, $path, $c ) || $force;
            unlink _cleanPath("$path$c");
            print "Unlinked $path$c\n";
            return;
        }
        else {
            $path .= "$c/";
        }
    }
    if ( -e $file ) {
        unlink _cleanPath($file);
        print "Removed $file\n";
    }

    return;
}

sub Autoconf {
    my $foswikidir   = $basedir;
    my $localSiteCfg = $foswikidir . '/lib/LocalSite.cfg';

    if ( $force || ( !-e $localSiteCfg ) ) {
        open( my $f, '<', "$foswikidir/lib/Foswiki.spec" )
          or die "Cannot autoconf: $!";
        local $/ = undef;
        my $localsite = <$f>;
        close $f;

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

        if ( open( my $ls, '>', $localSiteCfg ) ) {
            print $ls $localsite;
            close $ls;
            warn "wrote simple config to $localSiteCfg\n\n";
        }
        else {
            error "failed to write to $localSiteCfg\n\n";
        }
    }
    else {
        error "won't overwrite $localSiteCfg without -force\n\n";
    }

    return;
}

sub enablePlugin {
    my ( $module, $installingModule, $libDir ) = @_;
    my $cfg     = '';
    my $changed = 0;

    print "Updating LocalSite.cfg\n";
    if ( open( my $lsc, '<', 'lib/LocalSite.cfg' ) ) {
        local $/;
        $cfg = <$lsc>;
        $cfg =~ s/\r//g;
        close $lsc;
    }
    if ( $cfg =~
        s/\$Foswiki::cfg{Plugins}{$module}{Enabled}\s*=\s*(\d+)[\s;]+//sg )
    {
        $cfg =~ s/\$Foswiki::cfg{Plugins}{$module}{Module}\s*=.*?;\s*//sg;

        # Removed old setting
        $changed = 1;
    }
    if ($installingModule) {
        $cfg =
            "\$Foswiki::cfg{Plugins}{$module}{Enabled} = 1;\n"
          . "\$Foswiki::cfg{Plugins}{$module}{Module} = '${libDir}::Plugins::$module';\n"
          . $cfg;
        $changed = 1;
    }

    if ($changed) {
        if ( open( my $lsc, '>', 'lib/LocalSite.cfg' ) ) {
            print $lsc $cfg;
            close $lsc;
            print(
                ( $installingModule ? 'En' : 'Dis' ),
                "abled $module in LocalSite.cfg\n"
            );
        }
        else {
            warn "WARNING: failed to write lib/LocalSite.cfg\n";
        }
    }

    return;
}

sub run {
    if ($autoconf) {
        Autoconf();
        exit 0 unless ( scalar(@ARGV) );
    }

    unless ( $do_genconfig or scalar(@ARGV) ) {
        usage();
        exit 1;
    }

    my @modules;
    for my $arg (@ARGV) {
        if ( $arg eq 'all' ) {
            push( @modules, 'core' );
            foreach my $dir (@extensions_path) {
                opendir my $d, $dir or next;
                push @modules, map { untaint($_) }
                  grep { /(?:Tag|Plugin|Contrib|Skin|AddOn)$/ && -d "$dir/$_" }
                  readdir $d;
                closedir $d;
            }
        }
        elsif ( $arg eq 'default' || $arg eq 'developer' ) {
            open my $f, '<', 'lib/MANIFEST'
              or die "Could not open MANIFEST: $!";
            local $/ = "\n";
            @modules =
              map { /(\w+)$/; untaint($1) }
              grep { /^!include/ } <$f>;
            close $f;
            push @modules, 'BuildContrib', 'TestFixturePlugin',
              'UnitTestContrib'
              if $arg eq 'developer';
        }
        else {
            push @modules, untaint($arg);
        }

        # *Never* uninstall 'core'
        @modules = grep { $_ ne 'core' } @modules unless $installing;
    }

    print(
        ( $installing ? 'I' : 'Uni' ),
        'nstalling extensions: ',
        join( ', ', @modules ), "\n"
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
      . (
        scalar(@installedModules)
        ? join( ', ', @installedModules )
        : 'No modules'
      )
      . ' '
      . ( $installing ? 'i' : 'uni' )
      . "nstalled\n";

    if ( scalar(@error_log) ) {
        print "\n----\nError log:\n" . join( '', @error_log );
    }
}

sub exec_opts {
    while ( scalar(@ARGV) && $ARGV[0] =~ /^(-.)/ ) {
        shift(@ARGV);
        if ( exists $arg_dispatch{$1} ) {
            $arg_dispatch{$1}->();
        }
    }

    return;
}

init();
exec_opts();
init_config();
init_extensions_path();
run();

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2011 Foswiki Contributors. Foswiki Contributors
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
