use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'	=> 'Units::Calc',
    'VERSION_FROM' => 'Units/Calc.pm', # finds $VERSION
    'PMLIBDIRS' => [ 'Units/Calc' ],
    'EXE_FILES' => [ 'ucalc' ],
    'XS' => {},
);
