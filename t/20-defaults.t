use Test::More tests => 123;
use strict;
use warnings;
use POSIX ();
use Config;
eval { require Time::HiRes };

# running the default emulator of S::X should produce the
# same behavior as not using S::X

# it takes a few seconds to test each signal
# so this is the most time consuming test.

###########################################################
#
# If this test has failures ...
#   1) Examine the __DATA__ section of Signals/XSIG/Default.pm
#   2) If the name of your OS does not appear (e.g., [linux], [MSWin32], ...)
#   3)     Run  spike/analyze_default_signal_behavior.pl
#   4)     Send the output to  mob@cpan.org
#   5)     Append the output to  Signals/XSIG/Default.pm
#
###########################################################

$ENV{"PERL5LIB"} = join ':', @INC;
if ($^O eq 'MSWin32') {
  $ENV{"PERL5LIB"} = join ';', @INC;
}

if (${^TAINT}) {
  $ENV{PATH} = "";
  ($^X) = $^X =~ /(.*)/;
  ($ENV{PERL5LIB}) = $ENV{PERL5LIB} =~ /(.*)/s;
}


our $PAUSE_TIME = $ENV{PAUSE_TIME} || 3;
sub pause {
  # 2.5-3 seconds is *usually* long enough to spawn a process
  # and give it time to send itself a signal that will suspend it.
  # If you test on a heavily loaded or old system, it might
  # need even more time.
  sleep $PAUSE_TIME || 1;
}

my @sig_names = split ' ', $Config{sig_name};
my @sig_num = split ' ', $Config{sig_num};
my ($SIGCONT) = grep { $sig_names[$_] eq 'CONT' } @sig_num;
my %sig_exists = map { $_ => 1 } @sig_names;
my $failed = 0;


 
my @signals 
  = qw(HUP INT QUIT ILL TRAP ABRT EMT FPE KILL BUS
       SEGV SYS PIPE ALRM TERM URG STOP TSTP CONT CHLD
       TTIN TTOU IO XCPU XFSZ VTALRM PROF WINCH LOST
       USR1 USR2 CLD
       STKFLT RTMIN RTMAX RTMIN+1 RTMAX-1 IOT CLD
       BREAK 
       FOO);
if (@ARGV > 0) {
  my $n = @signals;
  @signals = @ARGV;
  unshift @signals, '#' while @signals < $n;
}

my $program_without_SHS = <<'__PROGRAM_WITHOUT_SHS__';
$SIG{'__SIGNAL__'} = 'DEFAULT';
kill '__SIGNAL__', $$;
print "Hello world\nFoo!";
exit 0;
__PROGRAM_WITHOUT_SHS__
;

my $program_with_SHS = <<'__PROGRAM_WITH_SHS__';
use Signals::XSIG;
$XSIG{'__SIGNAL__'} = [ sub { }, 'DEFAULT' ];
kill '__SIGNAL__', $$;
print "Hello world\nFoo!";
exit 0;
__PROGRAM_WITH_SHS__
;


foreach my $signal (@signals) {

 SKIP: {

    if (!exists $SIG{$signal} && !exists $sig_exists{$signal}) {
      skip "Signal $signal doesn't exist in $^O $]", 3;
    }

    # signal might suspend a program, in which we case we need to
    # arrange for SIGCONT to be delivered to it later.

    my $program1 = $program_without_SHS;
    $program1 =~ s/__SIGNAL__/$signal/g;

    my $program2 = $program_with_SHS;
    $program2 =~ s/__SIGNAL__/$signal/g;

    my $PID = $$;
    open(PROG1, '>', "control_group.$PID.tt");
    print PROG1 $program1;
    close PROG1;

    open(PROG2, '>', "experimental_group.$PID.tt");
    print PROG2 $program2;
    close PROG2;

    unlink "out1.$PID","out2.$PID";

    open(OUT1, '>', "out1.$PID");
    my $pid1 = fork();
    if ($pid1 == 0) {
      open(STDOUT, '>&' . fileno(*OUT1));
      exec($^X,"control_group.$PID.tt");
      die;
    }

    open(OUT2, '>', "out2.$PID");
    my $pid2 = fork();
    if ($pid2 == 0) {
      open(STDOUT, '>&' . fileno(*OUT2));
      exec($^X,"experimental_group.$PID.tt");
      die;
    }
    pause();;
    my $xpid1 = my $ypid1 = waitpid $pid1, &POSIX::WNOHANG;
    my $status1 = $?;

    my $xpid2 = my $ypid2 = waitpid $pid2, &POSIX::WNOHANG;
    my $status2 = $?;

    kill 'CONT', $pid1, $pid2;
    $ypid1 || $ypid2 || pause();
    kill 'KILL', $pid1, $pid2;
    close OUT1;
    close OUT2;
    if ($ypid1 == 0) {
      $ypid1 = waitpid $pid1, 0;
      $status1 = $?;
    }
    if ($ypid2 == 0) {
      $ypid2 = waitpid $pid2, 0;
      $status2 = $?;
    }

    ok(!!$xpid1 == !!$xpid2, 
       "suspend behavior was the same for SIG$signal "
       . "($xpid1 $ypid1 / $xpid2 $ypid2)")
      or $failed++;

    open(IN1, '<', "out1.$PID");
    my $in1 = join'', <IN1>;
    close IN1;
    open(IN2, '<', "out2.$PID");
    my $in2 = join'', <IN2>;
    close IN2;

    ok($in1 eq $in2, 
       "program output with SIG$signal was the same "
       . length($in1) . " === " . length($in2))
      or $failed++;

    if (@ARGV == 0) {
      unlink "control_group.$PID.tt", "experimental_group.$PID.tt";
      unlink "out1.$PID", "out2.$PID";
    }

    ok($status1 == $status2, 
       "SIG$signal exit status was the same $status1 == $status2") 
    or $failed++;
  }
}

END {
  if ($failed) {

  diag <<"ON_FAILURE";

If this test has failures ...
   1) Examine the __DATA__ section of Signals/XSIG/Default.pm
   If the name of your OS does not appear (e.g., [linux], [MSWin32], ...)
   2)   Run  spike/analyze_default_signal_behavior.pl
   3)   Append the output to  Signals/XSIG/Default.pm
   4)   Send the output to  mob\@cpan.org  for inclusion in a future release

ON_FAILURE

  }
}
