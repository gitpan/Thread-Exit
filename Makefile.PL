require 5.008;
use threads (); # just to force breakage if threads are not available
use ExtUtils::MakeMaker;

WriteMakefile (
 NAME		=> "Thread::Exit",
 ($[ >= 5.005) ?
 (AUTHOR	=> 'Elizabeth Mattijsen (liz@dijkmat.nl)',
  ABSTRACT	=> 'provide thread-local exit() and END {}') : (),
 VERSION_FROM	=> 'lib/Thread/Exit.pm',
 PREREQ_PM	=> {
		   Thread::Serialize => '0.02',
                   },
);
