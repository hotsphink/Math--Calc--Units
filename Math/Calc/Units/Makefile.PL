use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'	=> 'Units::Calc',
    'VERSION_FROM' => 'Calc.pm', # finds $VERSION
    'EXE_FILES' => [ 'ucalc' ],
);
