use PDL;
use PDL::Char;
use PDL::HDF5;
use PDL::Types;

# Script to test the attribute index functionality of the PDL::HDF5 Class

use Data::Dumper;

print "1..2\n";  

my $testNo = 1;

# New File Check:
my $filename = "newFile.hd5";

my $hdfobj;
ok($testNo++,$hdfobj = new PDL::HDF5("newFile.hd5"));

# It is normally a no-no to call a internal method, but we
#  are just testing here:
$hdfobj->_buildAttrIndex;

my $result = Dumper($hdfobj->{attrIndex});

my $baseline = 
q!$VAR1 = {
          '/mygroup/subgroup' => {},
          '/mygroup' => {
                          'attr1' => 'dudeman23',
                          'attr2' => 'What??'
                        },
          '/dude2' => {},
          '/' => {
                   'attr1' => 'dudeman23',
                   'attr2' => 'What??'
                 }
        };
!;

ok($testNo++,$baseline eq $result );



print "completed\n";


#  Testing utility functions:
sub ok {
        my $no = shift ;
        my $result = shift ;
        print "not " unless $result ;
        print "ok $no\n" ;
}
