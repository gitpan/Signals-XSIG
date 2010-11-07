package PackageOne;
use Signals::XSIG qw(untied %XSIG);
use t::SignalHandlerTest;
use Test::More tests => 42;
use Config;
use strict;
use warnings;

# are signal handlers registered correctly when we
# set $XSIG{signal} or @{$XSIG{signal}} directly?

sub foo { 42 }

################### valid signal name ###############

my $sig = appropriate_signals();

ok(tied @{$XSIG{$sig}});

$XSIG{$sig} = [];
ok(!defined $XSIG{$sig}[0]);

$XSIG{$sig} = ['foo'];
ok($XSIG{$sig}[0] eq 'main::foo', 'list assignment is qualified');
ok(!defined $XSIG{$sig}[1]);

if ($Config{PERL_VERSION} != 8) {
  $XSIG{$sig} = ['foo',*bar,\&foo];
  ok($XSIG{$sig}[1] eq *PackageOne::bar);
} else {
  $XSIG{$sig} = ['foo',\&PackageOne::bar,\&foo];
  ok($XSIG{$sig}[1] eq \&PackageOne::bar);
}
ok($XSIG{$sig}[0] eq 'main::foo');
ok($XSIG{$sig}[2] eq \&foo);

ok(tied @{$XSIG{$sig}});

# also try/test $XSIG{sig} = scalar as synonym for  $XSIG{$sig} = [func] ?

################### alias signal name ###############

my $alias;
($sig,$alias) = alias_pair();

ok(tied @{$XSIG{$sig}});
ok(tied @{$XSIG{$alias}});

$XSIG{$sig} = ['bar'];
ok($XSIG{$sig}[0] eq 'main::bar');
ok($XSIG{$alias}[0] eq 'main::bar');

if ($Config{PERL_VERSION} != 8) {
  $XSIG{$alias} = ['foo', *bar, \&foo];
  ok($XSIG{$sig}[1] eq *PackageOne::bar);
  ok($XSIG{$alias}[1] eq *PackageOne::bar);
} else {
  $XSIG{$alias} = ['foo', \&bar, \&foo];
  ok($XSIG{$sig}[1] eq \&PackageOne::bar);
  ok($XSIG{$alias}[1] eq \&PackageOne::bar);
}
ok($XSIG{$sig}[0] eq 'main::foo');
ok($XSIG{$alias}[0] eq 'main::foo');
ok(ref $XSIG{$alias}[2] eq 'CODE');
ok($XSIG{$sig}[2] eq \&foo);
ok($XSIG{$sig}[2] eq $XSIG{$alias}[2]);

ok(tied @{$XSIG{$sig}});
ok(tied @{$XSIG{$alias}});

################### bogus signal name ###############

$sig = 'qwerty';
ok(!tied $XSIG{$sig});
ok(!tied @{$XSIG{$sig}});

$XSIG{$sig} = ['foo'];
ok(ref $XSIG{$sig} eq 'ARRAY');
ok($XSIG{$sig}[0] eq 'foo');

$XSIG{$sig} = 'oof';
ok(ref $XSIG{$sig} eq '');
ok($XSIG{$sig} eq 'oof');

#####################################################

$sig = appropriate_signals();

$XSIG{$sig} = [];
ok(!defined($XSIG{$sig}[0]), '$XSIG{$sig} is clear ');
push @{$XSIG{$sig}}, \&ook;
ok(!defined($XSIG{$sig}[0]), 'push does not set default handler');
ok($XSIG{$sig}[1] eq \&ook, 'push sets posthandler');

ok(!defined $XSIG{$sig}[-1], 'prehandler not set');
my $u = pop @{$XSIG{$sig}};
ok($u eq \&ook, 'pop retrieves pushed value');
ok(!defined($XSIG{$sig}[0]), 'still no default handler');
ok(!defined($XSIG{$sig}[1]), 'pop removes signal post-handler');

push @{$XSIG{$sig}}, '::posthandler';
ok(defined $XSIG{$sig}[1]);
$u = shift @{$XSIG{$sig}};
ok(!defined($u), 'shift does not access signal post-handler');
ok(defined($XSIG{$sig}[1]),'post-handler remains after shift');
$XSIG{$sig}[1] = undef;

unshift @{$XSIG{$sig}}, '::prehandler2', '::prehandler';
ok($XSIG{$sig}[-1] eq '::prehandler', 'unshift installs pre-handler');
$u = pop @{$XSIG{$sig}};
ok(!defined($u) && $XSIG{$sig}[-1] eq '::prehandler',
   'pop does not remove pre-handler');
$u = shift @{$XSIG{$sig}};
ok($u eq '::prehandler2' && !defined($XSIG{$sig}[-2]),
   'shift removes pre-handler');

$XSIG{$sig} = [];
$XSIG{$sig}[0] = '::default';
$u = pop @{$XSIG{$sig}};
ok(!defined($u), 'pop does not remove default handler');
$XSIG{$sig}[0] = '::default';
$u = shift @{$XSIG{$sig}};
ok(!defined($u), 'shift does not remove default handler');

# array operators. 4 spec:
#    splice => no result
