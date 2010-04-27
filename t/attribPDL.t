use PDL;
use PDL::Char;
use PDL::IO::HDF5;
use PDL::Types;


# Test case for HDF5 attributes that are pdls 
#   This is a new feature as-of version 0.6
#
print "1..6\n";  

my $testNo = 1;


my $filename = "newFile.hd5";
# get rid of filename if it already exists
unlink $filename if( -e $filename);

my $hdf5 = new PDL::IO::HDF5($filename);


# Create pdls to store:
my $pchar = PDL::Char->new( [['abc', 'def', 'ghi'],['jkl', 'mno', 'pqr']] );
my $bt=pdl([[1.2,1.3,1.4],[1.5,1.6,1.7],[1.8,1.9,2.0]]);

my $group=$hdf5->group('Radiometric information');

# Store a dadtaset
my $dataset=$group->dataset('SP_BT');
$dataset->set($bt);

# Store a scalar and pdl attribute
$dataset->attrSet('UNITS'=>'K');
$dataset->attrSet('NUM_COL'=>pdl(long,[[1,2,3],[4,5,6]]));
$dataset->attrSet('NUM_ROW'=>$pchar);
$dataset->attrSet('SCALING'=>'pepe');
$dataset->attrSet('OFFSET'=>pdl(double,[0.0074]));

######## Now Read HDF5 file  #####
my $hdf2= new PDL::IO::HDF5($filename);
my $group2=$hdf2->group('Radiometric information');
my $dataset2=$group2->dataset('SP_BT');
my $expected;


$expected = '
[
 [1.2 1.3 1.4]
 [1.5 1.6 1.7]
 [1.8 1.9   2]
]
';
my $bt2=$dataset2->get();
#print "expoected = '$bt2'\n";
ok($testNo++, "$bt2" eq $expected);

$expected = 'K';
my ($units)=$dataset2->attrGet('UNITS');
#print "units '$units'\n";
ok($testNo++, $units eq $expected);


$expected = '
[
 [1 2 3]
 [4 5 6]
]
';
my ($numcol)=$dataset2->attrGet('NUM_COL');
#print "numcol '$numcol'\n";
ok($testNo++, "$numcol" eq $expected);

$expected = "[
 [ 'abc' 'def' 'ghi'  ] 
 [ 'jkl' 'mno' 'pqr'  ] 
] 
";
my ($numrow)=$dataset2->attrGet('NUM_ROW');
#print "numrow '$numrow'\n";
ok($testNo++, "$numrow" eq $expected);

$expected = 'pepe';
my ($scaling)=$dataset2->attrGet('SCALING');
#print "scaling '$scaling\n";
ok($testNo++, $scaling eq $expected);


$expected = '[0.0074]';
my ($offset)=$dataset2->attrGet('OFFSET');
#print "offset '$offset'\n";
ok($testNo++, "$offset" eq $expected);

#  Testing utility functions:
sub ok {
        my $no = shift ;
        my $result = shift ;
        print "not " unless $result ;
        print "ok $no\n" ;
}
