package main;
use Signals::XSIG;
use t::SignalHandlerTest;
use Test::More tests => 19;
use Config;
use strict;
use warnings;
no warnings 'signal';

# S::X behavior persists inside and after a localized block

sub foo { 42 }
sub bar { 43 }

my $s = appropriate_signals();

ok(!defined($SIG{$s}));
$SIG{$s} = 'main::foo';
ok($SIG{$s} eq 'main::foo');
ok($XSIG{$s}[0] eq 'main::foo');
my $oldreg = $XSIG{$s}[0];

my %z = %SIG;
{
  local $SIG{$s} = 'DEFAULT';
  ok($SIG{$s} eq 'DEFAULT');
  ok(tied %SIG);
  ok($XSIG{$s}[0] eq 'DEFAULT');
}

ok(tied %SIG, "tied hash restored after local \$SIG{...}");
ok($SIG{$s} eq 'main::foo', "hash val restored after local \$SIG{...}");
ok($XSIG{$s}[0] eq $oldreg, "XSIG val restored");

my $restored = 1;
for my $k (keys %z) {
  next unless defined($z{$k}) || defined($SIG{$k});
  $restored &&= $z{$k} eq $SIG{$k};
}
ok($restored, "hash val restored after local \$SIG{...}");


#
#     { local %SIG; ... }
#
# will break the tied functionality, so don't do that and avoid
# modules that do that:
#
#     PAR::Dist::_unzip
#
#     { local $SIG{signal} = ... }  is ok, though.
#
# only workaround is to save and restore the whole table
# when the local var goes out of scope.

{
  ok(tied %SIG, "\%SIG tied before localization");

  %z = %SIG;
  SKIP: {
    local %SIG;
    $SIG{$s} = 'IGNORE';
    ok($SIG{$s} eq 'IGNORE', 'set $SIG{sig}');

    # failure point with perl 5.13
    if ($Config{PERL_VERSION} == 13) {
      skip '5.13 local breaks tie', 2;
    }
    ok(tied %SIG, "\%SIG tied during localization");
    ok($XSIG{$s}[0] eq 'IGNORE', 'set $XSIG{sig}');
  }

  # perl 5.6,5.8 - lots of uninitialized warnings here
  no warnings 'uninitialized';
  %SIG = %z;
  ok(tied %SIG, "\%SIG tied after localization");
}

ok(tied %SIG, "tied hash restored after local \%SIG");
ok($SIG{$s} eq 'main::foo', "hash val restored after local \%SIG");
ok($XSIG{$s}[0] eq $oldreg, "XSIG val restored");
$restored = 1;
for my $k (keys %z) {
  no warnings 'uninitialized';
  next unless defined($z{$k}) || defined($SIG{$k});
  $restored &&= $z{$k} eq $SIG{$k};
}
ok($restored, "hash val restored after local \%SIG");


__END__

# do extended signal handlers run when %SIG is local?
#  

$s = 'ALRM';
%z = %SIG;
ok(tied %SIG);
my ($x,$y,$z) = (0,0,0);
$XSIG{$s} = [ sub { $x=1 }, sub { $y=$z=1 } ];
trigger($s);
ok($x==1 && $y==1 && $z==1);
$x=$y=$z=0;
{
  local %SIG;
  $SIG{$s} = sub { $x=2 };
  trigger($s);
  ok($x==2);

  # this works on 5.8, fails on >= 5.10
  ok($y==1 && $z==1, '%XSIG handlers run after local %SIG');
}


