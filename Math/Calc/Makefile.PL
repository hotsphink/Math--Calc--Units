use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'	=> 'Math::Calc::Units',
    'VERSION_FROM' => 'Units.pm', # finds $VERSION
    'EXE_FILES' => [ 'script/ucalc' ],
    'XS' => {},
);
