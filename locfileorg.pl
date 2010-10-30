#
# locfileorg.pl for bash and zsh
# by pts@fazekas.hu at Sat Jan 20 22:29:43 CET 2007
#

#** Adds or removes or sets tags.
#** @example _mmfs_tag 'tag1 -tag2 ...' file1 file2 ...    # keep tag3
function _mmfs_tag() {
	# Midnight Commander menu for movemetafs
	# Dat: works for weird filenames (containing e.g. " " or "\n"), too
	# Imp: better mc menus
	# Imp: make this a default option
        # SUXX: prompt questions may not contain macros
        # SUXX: no way to signal an error
	perl -w -- - "$@" <<'END'
use Cwd;
$ENV{LC_MESSAGES}=$ENV{LANGUAGE}="C"; # Make $! English
use integer; use strict;  $|=1;
require "syscall.ph"; my $SYS_setxattr=&SYS_setxattr;
my $SYS_getxattr=&SYS_getxattr;
my($tags)=shift(@ARGV);
$tags="" if !defined $tags;
my $key0 = "user.lfo.tags";
# Simple superset of UTF-8 words.
my $tagchar_re = qr/(?:\w| [\xC2-\xDF] [\x80-\xBF] |
                           [\xE0-\xEF] [\x80-\xBF]{2} |
                           [\xF0-\xF4] [\x80-\xBF]{3}) /x;
my $pmtag_re = qr/([-+]?)((?:$tagchar_re)+)/;
# Same as WORDDATA_SPLIT_WORD_RE in locfileorg/base.py.
my $split_word_re = qr/[^\s?!.,;\[\](){}<>"\']+/;
# Read the tag list file (of lines <tag> or <tag>:<description> or
# <space><comment> or #<comment>).
my $F;
my $tags_fn = "$ENV{HOME}/.locfileorg_tags";
die "$0: error opening $tags_fn: $!\n" if !open $F, "<", $tags_fn;
my $lineno = 0;
my %known_tags;
for my $line (<$F>) {
  ++$lineno;
  next if $line !~ /^([^\s#][^:\s]*)([\n:]*)/;
  my $tag = $1;
  if (!length($2)) {
    print "\007syntax error in $tags_fn:$.: missing colon or newline\n"; exit 4;
  }
  if ($tag !~ /\A(?:$tagchar_re)+\Z(?!\n)/) {
    # TODO(pts): Support -* here.
    print "\007syntax error in $tags_fn:$lineno: bad tag syntax: $tag\n";
    exit 5;
  }
  if (exists $known_tags{$tag}) {
    print "\007syntax error in $tags_fn:$lineno: duplicate tag: $tag\n";
    exit 6;
  }
  $known_tags{$tag} = 1;
}
die unless close $F;

# Parse the +tag and -tag specification in the command line
my @ptags;
my @mtags;
my @unknown_tags;
for my $pmitem (split/\s+/,$tags) {
  if ($pmitem !~ /\A$pmtag_re\Z(?!\n)/) {
    # TODO(pts): Report this later.
    print "\007bad tag syntax ($pmitem), skipping files\n"; exit 3;
  }
  my $tag = $2;
  if (!exists $known_tags{$tag}) { push @unknown_tags, $tag }
  elsif ($1 eq "-") { push @mtags, $tag }
  else { push @ptags, $tag }
}
if (@unknown_tags) {
  @unknown_tags = sort @unknown_tags;
  print "\007unknown tags (@unknown_tags), skipping files\n"; exit 7;
}
{ my %ptags_hash = map { $_ => 1 } @ptags;
  my @intersection_tags;
  for my $tag (@mtags) {
    push @intersection_tags, $tag if exists $ptags_hash{$tag};
  }
  if (@intersection_tags) {
    @intersection_tags = sort @intersection_tags;
    print "\007plus and minus tags (@intersection_tags), skipping files\n";
    exit 8;
  }
}
# vvv Dat: menu item is not run on a very empty string
if (!@ptags and !@mtags) {
  print STDERR "no tags specified ($tags)\n"; exit 2
}

# Read file xattrs, apply updates, write file xattrs.
print "to these files:\n";
#my $mmdir="$ENV{HOME}/mmfs/root/";
my $mmdir="/";
my $C=0;
my $KC=0;
my $EC=0;
for my $fn0 (@ARGV) {
  my $fn=Cwd::abs_path($fn0);
  substr($fn,0,0)=$mmdir if substr($fn,0,length$mmdir)ne$mmdir;
  print "  $fn\n";
  # vvv Imp: move, not setfattr
  my $key = $key0; # Dat: must be in $var

  my $oldtags="\0"x65535;
  my $got=syscall($SYS_getxattr, $fn, $key, $oldtags,
    length($oldtags), 0);
  if ((!defined $got or $got<0) and !$!{ENODATA}) {
    print "    error: $!\n"; $EC++; next
  }
  $oldtags=~s@\0.*@@s;
  my $tmp = $oldtags;
  my %old_tags_hash;
  my @old_tags;
  $tmp =~ s/($split_word_re)/ $old_tags_hash{$1} = @old_tags;
                              push @old_tags, $1 /ge;
  my @new_tags = @old_tags;
  my %new_tags_hash = %old_tags_hash;
  # Keep the original word order while updating.
  for my $tag (@ptags) {
    if (!exists $new_tags_hash{$tag}) {
      $new_tags_hash{$tag} = @new_tags;
      push @new_tags, $tag;
    }
  }
  for my $tag (@mtags) {
    if (exists $new_tags_hash{$tag}) {
      $new_tags[$new_tags_hash{$tag}] = undef;
    }
  }
  @new_tags = grep { defined $_ } @new_tags;
  #print "@new_tags;;@old_tags\n"; next;
  if (join("\0", @old_tags) eq join("\0", @new_tags)) {
    $KC++; next
  }
  my $set_tags = join(" ", @new_tags);
  $key=$key0;
  # Setting $set_tags to the empty string removes $key on reiserfs3. Good.
  $got=syscall($SYS_setxattr, $fn, $key, $set_tags,
    length($set_tags), 0);
  if (!defined $got or $got<0) {
    if ("$!" eq "Cannot assign requested address") {
      print "\007bad tags ($tags), skipping other files\n"; exit
    } else { print "    error: $!\n"; $EC++ }
  } else { $C++ }
}
print "\007error with $EC file@{[$EC==1?q():q(s)]}\n" if $EC;
print "kept tags of $KC file@{[$C==1?q():q(s)]}: $tags\n" if $KC;
print "modified tags of $C file@{[$C==1?q():q(s)]}: $tags\n"
END
}

#** Makes both files have the union of the tags.
#** Imp: also unify the descriptions.
#** SUXX: needed 2 runs: modified 32, then 4, then 0 files (maybe because of
#**   equivalence classes)
#** @example _mmfs_unify_tags file1 file2
#** @example echo "... 'file1' ... 'file2' ..." ... | _mmfs_unify_tags --stdin
function _mmfs_unify_tags() {
	perl -we '
use Cwd;
$ENV{LC_MESSAGES}=$ENV{LANGUAGE}="C"; # Make $! English
use integer; use strict;  $|=1;
require "syscall.ph";
my $SYS_setxattr=&SYS_setxattr;
my $SYS_getxattr=&SYS_getxattr;
#my $mmdir="$ENV{HOME}/mmfs/root/";
my $mmdir="/";
my $C=0;  my $EC=0;
$0="_mmfs_unify_tags";
die "Usage: $0 <file1> <file2>
     or echo \"... \x27file1\x27 ... \x27file2\x27 ...\" ... | $0 --stdin\n" if
     @ARGV!=2 and @ARGV!=1;
print "unifying tags\n";

#** @return :String, may be empty
sub get_tags($) {
  my $fn=Cwd::abs_path($_[0]);
  substr($fn,0,1)=$mmdir if substr($fn,0,length$mmdir)ne$mmdir;
  #print "  $fn\n";
  # vvv Imp: move, not setfattr
  my $key="user.lfo.tags"; # Dat: must be in $var
  my $tags="\0"x65535;
  my $got=syscall($SYS_getxattr, $fn, $key, $tags,
    length($tags), 0);
  if ((!defined $got or $got<0) and !$!{ENODATA}) {
    print "    error: $fn: $!\n"; $EC++;
    return "";
  } else {
    $tags=~s@\0.*@@s;
    return $tags;
  }
}

sub add_tags($$) {
  my($fn0,$tags)=@_;
  my $fn=Cwd::abs_path($fn0);
  substr($fn,0,0)=$mmdir if substr($fn,0,length$mmdir)ne$mmdir;
  #print "  $fn\n";
  my $key="user.lfo.tags.modify"; # Dat: must be in $var
  my $got=syscall($SYS_setxattr, $fn, $key, $tags,
    length($tags), 0);
  if (!defined $got or $got<0) {
    if ("$!" eq "Cannot assign requested address") {
      print "\007bad tags ($tags)\n"; $EC++;
    } else { print "add-error: $fn: $!\n"; $EC++ }
  } else { $C++ }
}


sub unify_tags($$) {
  my($fn0,$fn1)=@_;
  my $tags0=get_tags($fn0);
  my $tags1=get_tags($fn1);
  if ($tags0 eq $tags1) {
    if ($tags0 eq "") {
      print "neither: ($fn0) ($fn1)\n";
      return -1
    }
    print "both ($tags0): ($fn0) ($fn1)\n";
    return -2
  }
  #print "$tags0; $tags1\n";
  add_tags($fn0, $tags1) if $tags1 ne "";
  add_tags($fn1, $tags0) if $tags0 ne "";
  
  my $tags0b=get_tags($fn0);
  my $tags1b=get_tags($fn1);
  if ($tags0b eq $tags1b) {
    print "unified ($tags0b): ($fn0) ($fn1)\n";
  } else {
    print "\007failed to unify: ($fn0):($tags0b), ($fn1):($tags1b)\n";
    $EC++;
    return -3;
  }
  return 0;
}

if (@ARGV==2) {
  unify_tags($ARGV[0], $ARGV[1]);
} else {
  die "error: supply filename pairs in STDIN (not a TTY)\n" if -t STDIN;
  while (<STDIN>) {
    next if !/\S/ or /^\s*#/;
    my @L;
    while (/\x27((?:[^\x27]+|\x27\\\x27\x27)*)\x27/g) {
      push @L, $1;
      $L[-1]=~s@\x27\\\x27\x27@\x27@g;
    }
    if (@L!=2) { chomp; print "not two: $_\n"; $EC++; next }
    #print "($L[0]) ($L[1])\n";
    unify_tags($L[0], $L[1]);
  }
}

print "\007error with $EC file@{[$EC==1?q():q(s)]}\n" if $EC;
print "modified tags of $C file@{[$C==1?q():q(s)]}\n";
exit 1 if $EC;
' -- "$@"
}

#** @example _mmfs_show file1 file2 ...
function _mmfs_show() {
	# Midnight Commander menu for movemetafs
	# Dat: works for weird filenames (containing e.g. " " or "\n"), too
	# Imp: better mc menus
	# Imp: make this a default option
        # SUXX: prompt questions may not contain macros
        # SUXX: no way to signal an error
	perl -w -- - "$@" <<'END'
use Cwd;
$ENV{LC_MESSAGES}=$ENV{LANGUAGE}="C"; # Make $! English
use integer; use strict;  $|=1;
require "syscall.ph"; my $SYS_getxattr=&SYS_getxattr;
print "to these files:\n";
#my $mmdir="$ENV{HOME}/mmfs/root/";
my $mmdir="/";
my $C=0;  my $EC=0;  my $HC=0;
for my $fn0 (@ARGV) {
  my $fn=Cwd::abs_path($fn0);
  substr($fn,0,1)=$mmdir if substr($fn,0,length$mmdir)ne$mmdir;
  print "  $fn\n";
  # vvv Imp: move, not setfattr
  my $key="user.lfo.tags"; # Dat: must be in $var
  my $tags="\0"x65535;
  my $got=syscall($SYS_getxattr, $fn, $key, $tags,
    length($tags), 0);
  if ((!defined $got or $got<0) and !$!{ENODATA}) {
    print "    error: $!\n"; $EC++
  } else {
    $tags=~s@\0.*@@s;
    if ($tags ne"") { $HC++ } else { $tags=":none" }
    print "    $tags\n";  $C++;
  }
}
print "\007error with $EC file@{[$EC==1?q():q(s)]}\n" if $EC;
print "shown tags of $HC of $C file@{[$C==1?q():q(s)]}\n"
END
}

#** Like _mmfs_show, but only one file, and without extras. Suitable for
#** scripting.
#** @example _mmfs_get_tags file1
function _mmfs_get_tags() {
	# Midnight Commander menu for movemetafs
	# Dat: works for weird filenames (containing e.g. " " or "\n"), too
	# Imp: better mc menus
	# Imp: make this a default option
        # SUXX: prompt questions may not contain macros
        # SUXX: no way to signal an error
	perl -w -- - "$@" <<'END'
use Cwd;
$ENV{LC_MESSAGES}=$ENV{LANGUAGE}="C"; # Make $! English
use integer; use strict;  $|=1;
require "syscall.ph"; my $SYS_getxattr=&SYS_getxattr;
#my $mmdir="$ENV{HOME}/mmfs/root/";
my $mmdir="/";
die "error: not a single filename specified\n" if @ARGV != 1;
for my $fn0 (@ARGV) {
  my $fn=Cwd::abs_path($fn0);
  substr($fn,0,1)=$mmdir if substr($fn,0,length$mmdir)ne$mmdir;
  my $key="user.lfo.tags"; # Dat: must be in $var
  my $tags="\0"x65535;
  my $got=syscall($SYS_getxattr, $fn, $key, $tags,
    length($tags), 0);
  if ((!defined $got or $got<0) and !$!{ENODATA}) {
    print STDERR "error: $fn0: $!\n";
    exit(2);
  } else {
    $tags=~s@\0.*@@s;
    exit(1) if 0 == length($tags);
    print "$tags\n";
    exit;
  }
}
END
}

#** @example ls | _mmfs_grep '+foo -bar baz'  # anything with foo and baz, but without bar
#** @example ls | _mmfs_grep '* -2004'        # anything with at least one tag, but without 2004
#** @example ls | _mmfs_grep '*-foo *-bar'    # anything with at least one tag, which is not foo or bar
#** @example ls | _mmfs_grep '-*'             # anything without tags
function _mmfs_grep() {
	perl -w -e '
use Cwd;
$ENV{LC_MESSAGES}=$ENV{LANGUAGE}="C"; # Make $! English
use integer; use strict;  $|=1;
require "syscall.ph"; my $SYS_getxattr=&SYS_getxattr;
die "_mmfs_grep: grep spec expected\n" if 1!=@ARGV;
my %needplus;
my %needminus;
my %ignore;
my $spec=$ARGV[0];
while ($spec=~/(\S+)/g) {
  my $word = $1;
  if ($word =~ s@^-@@) {
    $needminus{$word} = 1;
  } elsif ($word =~ s@^[*]-@@) {
    $ignore{$word} = 1;
    $needplus{"*"} = 1;
  } else {
    $needplus{$word} = 1;
  }
}
die "_mmfs_grep: empty spec\n" if !%needplus and !%needminus;
#my $mmdir="$ENV{HOME}/mmfs/root/";
my $mmdir="/";
my $C=0;  my $EC=0;  my $HC=0;
my $fn0;
while (defined($fn0=<STDIN>)) {
  chomp $fn0;
  my $fn=Cwd::abs_path($fn0);
  substr($fn,0,1)=$mmdir if substr($fn,0,length$mmdir)ne$mmdir;
  #print "  $fn\n";
  # vvv Imp: move, not setfattr
  my $key="user.lfo.tags"; # Dat: must be in $var
  my $tags="\0"x65535;
  my $got=syscall($SYS_getxattr, $fn, $key, $tags,
    length($tags), 0);
  if ((!defined $got or $got<0) and !$!{ENODATA}) {
    print STDERR "tag error: $fn: $!\n"; $EC++
  } else {
    $tags=~s@\0.*@@s;
    my $ok_p=1;
    my %N=%needplus;
    #print "($tags)\n";
    my $tagc=0;
    while ($tags=~/(\S+)/g) {
      my $tag=$1;
      $tagc++ if !$ignore{$tag};
      delete $N{$tag};
      if ($needminus{$tag} or $needminus{"*"}) { $ok_p=0; last }
    }
    delete $N{"*"} if $tagc>0;
    $ok_p=0 if %N;
    print "$fn0\n" if $ok_p;
  }
}
print STDERR "warning: had error with $EC file@{[$EC==1?q():q(s)]}\n" if $EC;
' -- "$@"
}

#** @example _mmfs_dump [--printfn=...] file1 file2 ...
#** @example _copyattr() { _mmfs_dump --printfn="$2" -- "$1"; }; duprm.pl . | perl -ne 'print if s@^rm -f @_copyattr @ and s@ #, keep @ @' >_d.sh; source _d.sh | sh
function _mmfs_dump() {
	# Midnight Commander menu for movemetafs
	# Dat: works for weird filenames (containing e.g. " " or "\n"), too
	# Imp: better mc menus
	# Imp: make this a default option
        # SUXX: prompt questions may not contain macros
        # SUXX: no way to signal an error
	perl -w -- - "$@" <<'END'
use Cwd;
$ENV{LC_MESSAGES}=$ENV{LANGUAGE}="C"; # Make $! English
use integer; use strict;  $|=1;
sub fnq($) {
  #return $_[0] if substr($_[0],0,1)ne'-'
  return $_[0] if $_[0]!~m@[^-_/.0-9a-zA-Z]@;
  my $S=$_[0];
  $S=~s@'@'\\''@g;
  "'$S'"
}
my $printfn;
if (@ARGV and $ARGV[0]=~/\A--printfn=(.*)/s) { $printfn=$1; shift @ARGV }
if (@ARGV and $ARGV[0] eq '--') { shift @ARGV }
require "syscall.ph"; my $SYS_getxattr=&SYS_getxattr;
#print "to these files:\n";
#my $mmdir="$ENV{HOME}/mmfs/root/";
my $mmdir="/";
my $C=0;  my $EC=0;  my $HC=0;
if (defined $printfn) {
  $printfn=Cwd::abs_path($printfn);
  substr($printfn,0,1)=$mmdir if substr($printfn,0,length$mmdir)ne$mmdir;
}
for my $fn0 (@ARGV) {
  my $fn=Cwd::abs_path($fn0);
  substr($fn,0,1)=$mmdir if substr($fn,0,length$mmdir)ne$mmdir;
  #print "  $fn\n";
  # vvv Imp: move, not setfattr
  my $key="user.lfo.tags"; # Dat: must be in $var
  my $tags="\0"x65535;
  my $got=syscall($SYS_getxattr, $fn, $key, $tags,
    length($tags), 0);
  if ((!defined $got or $got<0) and !$!{ENODATA}) {
    print "    error: $!\n"; $EC++
  } else {
    $tags=~s@\0.*@@s;
    if ($tags ne"") {
      $HC++;
      print "setfattr -n user.lfo.tags.modify -v ".fnq($tags)." ".
        fnq(defined$printfn ? $printfn : $fn)."\n";
    } else { $tags=":none" }
    #print "    $tags\n";
    $C++;
  }
}
print "# \007error with $EC file@{[$EC==1?q():q(s)]}\n" if $EC;
print "# shown tags of $HC of $C file@{[$C==1?q():q(s)]}\n"
END
}

#** @example _mmfs_fixprincipal file1 file2 ...
function _mmfs_fixprincipal() {
  echo "$0: error: _mmfs_fixprincipal not supported with locfileorg" >&2
  return 1
}

#** Displays all known tags whose prefix is $1, displaying at most $2 tags.
#** @example _mmfs_expand_tag ta
function _mmfs_expand_tag() {
	perl -w -- - "$@" <<'END'
$ENV{LC_MESSAGES}=$ENV{LANGUAGE}="C"; # Make $! English
use integer; use strict;  $|=1;
# Simple superset of UTF-8 words.
my $tagchar_re = qr/(?:\w| [\xC2-\xDF] [\x80-\xBF] |
                           [\xE0-\xEF] [\x80-\xBF]{2} |
                           [\xF0-\xF4] [\x80-\xBF]{3}) /x;
# Read the tag list file (of lines <tag> or <tag>:<description> or
# <space><comment> or #<comment>).
my $F;
my $tags_fn = "$ENV{HOME}/.locfileorg_tags";
die "$0: error opening $tags_fn: $!\n" if !open $F, "<", $tags_fn;
my $lineno = 0;
my %known_tags;
for my $line (<$F>) {
  ++$lineno;
  next if $line !~ /^([^\s#][^:\s]*)([\n:]*)/;
  my $tag = $1;
  if (!length($2)) {
    print "\007syntax error in $tags_fn:$.: missing colon or newline\n"; exit 4;
  }
  if ($tag !~ /\A(?:$tagchar_re)+\Z(?!\n)/) {
    # TODO(pts): Support -* here.
    print "\007syntax error in $tags_fn:$lineno: bad tag syntax: $tag\n";
    exit 5;
  }
  if (exists $known_tags{$tag}) {
    print "\007syntax error in $tags_fn:$lineno: duplicate tag: $tag\n";
    exit 6;
  }
  $known_tags{$tag} = 1;
}
die unless close $F;

my @tags = sort keys %known_tags;
my $sign = '';
my $prefix = @ARGV ? $ARGV[0] : "";
$sign = $1 if $prefix =~ s@^([-+]+)@@;
my $limit = @ARGV > 1 ? 0 + $ARGV[1] : 10;
my @found_tags = grep { substr($_, 0, length($prefix)) eq $prefix } @tags;
if ($limit > 0 and @found_tags > $limit) {
  splice @found_tags, $limit - 1, @found_tags, '...';
}
print map { "$sign$_\n" } @found_tags;
exit(@found_tags > 1 ? 2 : @found_tags ? 1 : 0);
END
}
