BEGIN {				# Magic Perl CORE pragma
    if ($ENV{PERL_CORE}) {
        chdir 't' if -d 't';
        @INC = '../lib';
    }
}

use Thread::Exit; # cannot have Test use this, otherwise exit() isn't changed
use Test::More tests => 15;

use threads;
use threads::shared;

use_ok( 'Thread::Exit' ); # just for the record
can_ok( 'Thread::Exit',qw(
 automatic
 end
 import
) );

my $check = "This is the check string";

my $thread = threads->new( sub { exit( $check ) } );
is( scalar($thread->join),$check,		'check exit from thread' );

$thread = threads->new( sub { exit( [$check] ) } );
is( join('',@{$thread->join}),$check,		'check exit from thread' );

$thread = threads->new( sub { exit( $check,$check ) } );
is( join('',$thread->join),$check,		'check exit from thread' );

($thread) = threads->new( sub { exit( $check,$check ) } );
is( join('',$thread->join),$check.$check,	'check exit from thread' );

$thread = threads->new( sub { exit( $check ) } );
is( join('',$thread->join),$check,		'check exit from thread' );

my $result : shared = '';
ok( Thread::Exit->end( 'end' ),'check end() setting' );

threads->new( sub {} )->join;
is( $result,'',					'check result of END' );

ok( Thread::Exit->automatic( 1 ),		'check automatic() setting' );
threads->new( sub {} )->join;
is( $result,$check,				'check result of END' );

$result = '';
ok( !Thread::Exit->automatic( 0 ),		'check automatic() setting' );
threads->new( sub {} )->join;
is( $result,'', 				'check result of END' );

threads->new( sub { Thread::Exit->end( \&end ) } )->join;
is( $result,$check, 				'check result of END' );

eval q(sub Apache::exit { $result = shift });
exit( '' );
is( $result,'', 				'check result of exit()' );

sub end {$result = $check}
