use PDL;
use PDL::Char;
use PDL::HDF5;
use PDL::Types;

# Script to test the attribute index functionality of the PDL::HDF5 Class

use Data::Dumper;

print "1..6\n";  

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
          '/mygroup/subgroup' => {
                                   'attr1' => 'dudeman23',
                                   'attr2' => 'What??'
                                 },
          '/mygroup' => {
                          'attr1' => 'dudeman23',
                          'attr2' => 'What??'
                        },
          '/dude2' => {
                        'attr1' => 'dudeman23',
                        'attr2' => 'What??'
                      },
          '/' => {
                   'attr1' => 'dudeman23',
                   'attr2' => 'What??'
                 }
        };
!;

#print $result;
ok($testNo++,$baseline eq $result );

my @values = $hdfobj->allAttrValues('attr1');

$baseline = 
q!$VAR1 = [
          'dudeman23',
          'dudeman23',
          'dudeman23',
          'dudeman23'
        ];
!;

# print Dumper(\@values);
$result = Dumper(\@values);
ok($testNo++,$baseline eq $result );

@values = $hdfobj->allAttrValues('attr1','attr2');
$baseline = 
q!$VAR1 = [
          [
            'dudeman23',
            'What??'
          ],
          [
            'dudeman23',
            'What??'
          ],
          [
            'dudeman23',
            'What??'
          ],
          [
            'dudeman23',
            'What??'
          ]
        ];
!;

# print Dumper(\@values);
$result = Dumper(\@values);
ok($testNo++,$baseline eq $result );

my @names = $hdfobj->allAttrNames;

$baseline = 
q!$VAR1 = [
          'attr1',
          'attr2'
        ];
!;

# print Dumper(\@names);
$result = Dumper(\@names);
ok($testNo++,$baseline eq $result );

# Test building the groupIndex
$hdfobj->_buildGroupIndex('attr1','attr2');
$hdfobj->_buildGroupIndex('attr2');
$hdfobj->_buildGroupIndex('attr1','attr3');

$baseline = 
"\$VAR1 = {
          'attr2' => {
                       'What??' => [
                                     '/mygroup/subgroup',
                                     '/mygroup',
                                     '/dude2',
                                     '/'
                                   ]
                     },
          'attr1$;attr2' => {
                             'dudeman23$;What??' => [
                                                     '/mygroup/subgroup',
                                                     '/mygroup',
                                                     '/dude2',
                                                     '/'
                                                   ]
                           },
          'attr1$;attr3' => {}
        };
";

# print Dumper($hdfobj->{groupIndex});
$result = Dumper($hdfobj->{groupIndex});
ok($testNo++,$baseline eq $result );

print "completed\n";


#  Testing utility functions:
sub ok {
        my $no = shift ;
        my $result = shift ;
        print "not " unless $result ;
        print "ok $no\n" ;
}
