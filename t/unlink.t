use PDL;
use PDL::IO::HDF5;
use PDL::Types;


# Test case for HDF5 unlink function
#   This is a new feature as-of version 0.64
#
print "1..2\n";  

my $testNo = 1;


my $filename = "unlink.hd5";
# get rid of filename if it already exists
unlink $filename if( -e $filename);

my $hdf5 = new PDL::IO::HDF5($filename);

my $group=$hdf5->group('group1');

# Store a dataset
my $dataset=$group->dataset('data1');
my $data = pdl [ 2.0, 3.0, 4.0 ];
$dataset->set($data);

$expected = 'data1';
my @datasets1=$group->datasets();
#print "datasets '".join(", ",@datasets1)."'\n";
ok($testNo++, join(', ',@datasets1) eq $expected);

# Remove the dataset.
$group->unlink('data1');

$expected = '';
my @datasets2=$group->datasets();
#print "datasets '".join(", ",@datasets2)."'\n";
ok($testNo++, join(', ',@datasets2) eq $expected);


#  Testing utility functions:
sub ok {
        my $no = shift ;
        my $result = shift ;
        print "not " unless $result ;
        print "ok $no\n" ;
}
