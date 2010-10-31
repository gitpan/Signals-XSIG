# Default.pm.PL: creates the lib/Signals/XSIG/Default.pm file,
# which specifies how to emulate the 'DEFAULT' behavior of each signal.

# analyze_default_signal_behavior.pl: see what each signal does
# to a Perl program when the "DEFAULT" signal handler is set on 
# that program. The results can be appended to the
# lib/Signals/XSIG/Default.pm  file.

use IO::Handle;
use POSIX ':sys_wait_h';
use strict;
use warnings;
$| = 1;

print STDERR <<"";
This program will experimentally determine the default behavior 
of each signal on your system. The data collected will be
helpful in creating an appropriate  Signals/XSIG/Default.pm  
file.\n

;


my (@IGNORE, @SUSPEND, @TERMINATE, @UNKNOWN);
my $num_simultaneous = shift @ARGV || 10;
@IGNORE = ('__WARN__','__DIE__');

my @sigs = (sort keys %SIG, 'ZERO');
@sigs = @ARGV if @ARGV > 0;
my $abort_status;

printf STDERR "There are %d signals to analyze.\n", scalar @sigs;
print STDERR "This may take a few minutes.\n\n";

sub abort_status {
  use POSIX ();
  if (!defined $abort_status) {
    if (fork() == 0) {
      POSIX::abort();
      exit 0;
    }
    wait;
    $abort_status = $? || -9E9;
  }
  return $abort_status;
}

sub analysis_file {
    my ($signal) = @_;
    "siganal$signal.txt";
}

sub analyze_default_behavior_for_signal {
  my ($sig, $i, $analysis_file, $analysis_script) = @_;

# local $SIG{$sig} = 'DEFAULT';
  $analysis_file ||= analysis_file($sig);
  $analysis_script ||= "siganal$i.pl";
  unlink $analysis_file, $analysis_script;

  open my $cfh, '>', $analysis_script;
  print $cfh <<"CHILD_SIGNAL_TESTER";

\$SIG{'$sig'} = 'DEFAULT';
my \$n = sleep 2;
my \$msg = "CHILD \$n / 4\n";
open(F, '>>', '$analysis_file');
print F \$msg;
close F;
exit 0;

CHILD_SIGNAL_TESTER
  ;
  close $cfh;
  my $status = 'unknown';
  my ($pid, $win32ProcObj);

  if ($^O eq 'MSWin32') {
    require Win32::Process;
    require Win32;
    Win32::Process::Create( $win32ProcObj, 
			    $^X, 
			    "$^X $analysis_script",
			    0, 
			    &Win32::Process::NORMAL_PRIORITY_CLASS,
			    "." ) || die Win32::GetLastError();
    $pid = $win32ProcObj->GetProcessID();    
  } else {
    $pid = fork();
    if ($pid == 0) {
      %SIG = ();
      exec $^X, $analysis_script;
      die;
    }
  }

  sleep 2;
  my $nk = kill $sig, $pid;
  sleep 1;
  my $r = waitpid $pid, &WNOHANG;
  $status = $? if $r == $pid;
  sleep 5;
  $nk = kill 'CONT', $pid;
  sleep 1;
  $r = waitpid $pid, &WNOHANG;
  $status = $? if $r == $pid;
  $nk = kill 'KILL', $pid;
  $r = waitpid $pid, 0;
  $status = $? if $r == $pid;
  if (defined $win32ProcObj) {
    $win32ProcObj->Wait(&Win32::Process::INFINITE);
  }
  my $msg = "Status: $status\n";
  open my $fh, '>>', $analysis_file;
  print $fh $msg;
  close $fh;

  unlink $analysis_script;
  return $analysis_file;
}

$::j=0;
print "[$^O]\n";
while (@sigs) {
    my @sigz = splice @sigs, 0, $num_simultaneous;
    my $i = 0;
    foreach my $sig (@sigz) {
	if (fork() == 0) {
	    analyze_default_behavior_for_signal($sig,$i);
	    exit 0;
	}
	$i++;
    }
    wait foreach @sigz;
    foreach my $sig (@sigz) {
	parse_analysis_file($sig,analysis_file($sig));
    }
}

sub parse_analysis_file {
  use Config;

  my ($sig,$file) = @_;
  open G, '<', $file;
  my @g = <G>;
  close G;

  my $i = ++$::j;
  my @sig_name = split ' ', $Config{sig_name};
  my @sig_num = split ' ', $Config{sig_num};
  my ($sig_no) = grep { $sig_name[$_] eq $sig } 0..$#sig_num;
  $sig_no ||= 9999;
  $sig_no = $sig_num[$sig_no];
  $sig_no ||= '';

  my ($sleep_result, $sleep_benchmark) = $g[0] =~ /CHILD (\d+) \/ (\d+)/;
  if (defined $sleep_benchmark && $sleep_result > $sleep_benchmark) {
    push @SUSPEND, $sig;
    printf STDERR "%d. SIG", $i;
    printf "%-7s [%s] => %s\n", $sig, $sig_no, "SUSPEND";
  } else {
    my ($status) = $g[-1] =~ /Status: (\d+)/;
    if ($status eq "0") {
      push @IGNORE, $sig;
      printf STDERR "%d. SIG", $i;
      printf "%-7s [%s] => %s\n", $sig, $sig_no, "IGNORE";
    } elsif ($status > 0) {
      push @TERMINATE, $sig;

      printf STDERR "%d. SIG", $i;
      if ($status == $sig_no << 8) {
	printf "%-7s [%s] => %s\n", $sig, $sig_no, "EXIT $sig_no";
      } elsif (0 && $status == abort_status()) {
	printf "%-7s [%s] => %s\n", $sig, $sig_no, "ABORT";
      } else {
	printf "%-7s [%s] => %s\n", $sig, $sig_no, "TERMINATE $status";
      }
    } else {
      push @UNKNOWN, $sig;
      printf STDERR "%d. SIG", $i;
      printf "%-7s [%s] => %d %s\n", $sig, $sig_no, $status, "UNKNOWN";
    }
  }

  unlink $file;
}   ### next sig

