use ExtUtils::MakeMaker;
use 5.006;

WriteMakefile(
	NAME			=> 'Sort::ByExample',
  LICENSE   => 'perl',
	VERSION_FROM	=> 'lib/Sort/ByExample.pm',
  PREREQ_PM => {
    'Sub::Exporter' => 0,
    'Params::Util'  => 0,
  },
);

