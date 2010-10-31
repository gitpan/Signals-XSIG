use Signals::XSIG qw(untied %XSIG);
use t::SignalHandlerTest;
use Test::More tests => 16;
use strict;
use warnings;

my $R = '';
my %f = ();
my $sig = 'ALRM';
sub CLEAR { $R = '' };
for my $letter ('A' .. 'Z') {
  $f{$letter} = sub { $R .= $letter };
}

##################################################################

$XSIG{$sig}[0] = \&CLEAR;
$XSIG{$sig}[1] = $f{'A'};
$XSIG{$sig}[2] = $f{'B'};
$XSIG{$sig}[3] = $f{'C'};

ok($R eq '', 'no signals trapped yet');
trigger($sig);
ok($R eq 'ABC', '$XSIG{sig}[idx] assignments respected');

delete $XSIG{$sig}[2];
trigger($sig);
ok($R eq 'AC', 'signal handler deleted');

$XSIG{$sig}[7] = $f{'T'};
trigger($sig);
ok($R eq 'ACT', 'signal handler added');

@{$XSIG{$sig}} = (\&CLEAR, 'IGNORE', $f{F}, $f{O}, $f{O}, 'IGNORE');
trigger($sig);
ok($R eq 'FOO', '@{$XSIG{sig}} assignment respected');

$XSIG{$sig} = [ $f{B}, undef, $f{A}, 'IGNORE', undef, $f{R}, 'IGNORE' ];
trigger($sig);
ok($R eq 'FOOBAR', '$XSIG{sig} array ref assignment respected');

push @{$XSIG{$sig}}, sub { chop $R; $R .= 'Z' };
trigger($sig);
ok($R eq 'FOOBARBAZ');

##################################################################

# alias ?
my $alias;
($sig,$alias) = alias_pair();

SKIP: {
  skip "alias test on curmudgeony MSWin32", 9  if $^O eq 'MSWin32';

  $SIG{$sig} = \&CLEAR;
  trigger($sig);
  ok($R eq '', '$R cleared');

  $SIG{$sig} = 'IGNORE';
  unshift @{$XSIG{$sig}}, \&CLEAR, $f{X}, $f{Y}, $f{Z}, undef, $f{G};
  ok(tied @{$XSIG{$sig}});
  trigger($sig);
  ok($R eq 'XYZG', "\$R is $R, expect XYZG");

  push @{$XSIG{$alias}}, $f{H}, $f{I}, $f{J}, $f{T};
  trigger($alias);
  ok($R eq 'XYZGHIJT');

  $XSIG{$alias}[-4] = undef;
  pop @{$XSIG{$sig}};
  trigger($sig);
  ok($R eq 'XZGHIJ', "\$R is $R, expected 'XZGHIJ'");


  $XSIG{$sig} = [ sub { substr($R,1,3) = "o" } ];
  unshift @{$XSIG{$sig}}, \&CLEAR, $f{X}, $f{Y}, $f{Z}, undef, $f{G};
  push @{$XSIG{$sig}}, $f{H}, $f{I}, $f{J};
  trigger($alias);
  ok($R eq 'XoHIJ', "\$R is $R, expect XoHIJ");

  $R = '';
  $XSIG{$sig} = [];
  push @{$XSIG{$sig}}, 'IGNORE', undef, '', '', $f{Q}, $f{R}, $f{S};

  trigger($sig);
  ok($R eq 'QRS', "\$R is $R, expected QRS");

  unshift @{$XSIG{$alias}}, 'main::CLEAR', $f{X}, $f{S}, $f{I}, $f{G};
  sub fbang { $R .= "!" };
  $SIG{$sig} =  'main::fbang';

#  print @{$XSIG{$sig}};

  trigger($alias);
  ok($R eq 'XSIG!QRS', "\$R is $R, expected XSIG!QRS");

  shift @{$XSIG{$sig}};  # \&CLEAR
  pop @{$XSIG{$sig}};    # S
  trigger($alias);
  ok($R eq 'XSIG!QRSXSIG!QR');

}
