BEGIN {				# Magic Perl CORE pragma
    if ($ENV{PERL_CORE}) {
        chdir 't' if -d 't';
        @INC = '../lib';
    }
}

use Thread::Exit; # cannot have Test use this, otherwise exit() isn't changed
use Test::More tests => 21;

use threads;
use threads::shared;

use_ok( 'Thread::Exit' ); # just for the record
can_ok( 'Thread::Exit',qw(
 end
 import
 inherit
 ismain
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

my $begin : shared = '';
my $end : shared = '';
ok( Thread::Exit->begin( 'begin' ),		'check begin() setting' );
ok( Thread::Exit->end( 'main::end' ),		'check end() setting' );

threads->new( sub { is( $begin,$check,'check result of BEGIN' ) } )->join;
is( $end,$check,				'check result of END' );

$begin = $end = '';
ok( !Thread::Exit->inherit( 0 ),		'check inherit() setting' );
threads->new( sub { is( $begin,'','check result of BEGIN' ) } )->join;
is( $end,'',					'check result of END' );

ok( Thread::Exit->inherit( 1 ),			'check inherit() setting' );
threads->new( sub { is( $begin,$check,'check result of BEGIN' ) } )->join;
is( $end,$check, 				'check result of END' );

$begin = $end = '';
ok( !Thread::Exit->end( undef ),		'check end() setting' );
threads->new( sub {
 Thread::Exit->end( \&end );
 is( $begin,$check,'check result of BEGIN' );
} )->join;
is( $end,$check, 				'check result of END' );

eval q(sub Apache::exit { $end = shift });
exit( '' );
is( $end,'', 				'check result of exit()' );

sub begin { $begin = $check}
sub end   { $end   = $check}
