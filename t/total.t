use PDL;
use PDL::Char;
use PDL::HDF5;
use PDL::Types;

# Script to test the PDL::HDF5 objects together in the
#   way they would normally be used
#
#  i.e. not the way they would normally be used as described
#  in the PDL::HDF5 synopsis

print "1..29\n";  

my $testNo = 1;

# New File Check:
my $filename = "newFile.hd5";
# get rid of filename if it already exists
unlink $filename if( -e $filename);

my $hdfobj;
ok($testNo++,$hdfobj = new PDL::HDF5("newFile.hd5"));


# Set attribute for file (root group)
ok($testNo++, $hdfobj->attrSet( 'attr1' => 'dudeman', 'attr2' => 'What??'));

# Try Setting attr for an existing attr
ok($testNo++,$hdfobj->attrSet( 'attr1' => 'dudeman23'));


# Add a attribute and then delete it
ok($testNo++, $hdfobj->attrSet( 'dummyAttr' => 'dummyman', 
				'dummyAttr2' => 'dummyman'));
				
ok($testNo++, $hdfobj->attrDel( 'dummyAttr', 'dummyAttr2' ));


# Get list of attributes
my @attrs = $hdfobj->attrs;
ok($testNo++, join(",",sort @attrs) eq 'attr1,attr2' );

# Get a list of attribute values
my @attrValues = $hdfobj->attrGet(sort @attrs);

ok($testNo++, join(",",@attrValues) eq 'dudeman23,What??' );
# print "Attr Values = '".join("', '",@attrValues)."'\n";

##############################################

# Create a dataset in the root group
my $dataset = $hdfobj->dataset('rootdataset');

my $pdl = sequence(5,4);


ok($testNo++, $dataset->set($pdl) );
# print "pdl written = \n".$pdl."\n";

# Create String dataset using PDL::Char
my $dataset2 = $hdfobj->dataset('charData');

my $pdlChar = new PDL::Char( [ ["abccc", "def", "ghi"],["jkl", "mno", 'pqr'] ] );
 
ok($testNo++,$dataset2->set($pdlChar));


my $pdl2 = $dataset->get;
# print "pdl read = \n".$pdl2."\n";

ok($testNo++, (($pdl - $pdl2)->sum) < .001 );


my @dims = $dataset->dims;

ok( $testNo++, join(", ",@dims) eq '5, 4' );

# Get a list of datasets (should be two)
my @datasets = $hdfobj->datasets;

ok($testNo++, scalar(@datasets) == 2 );


#############################################

my $group = $hdfobj->group("mygroup");

my $subgroup = $group->group("subgroup");

# Create a dataset in the subgroup
$dataset = $subgroup->dataset('my dataset');

$pdl = sequence(5,4)->float; # Try a non-default data type


ok($testNo++, $dataset->set($pdl) );
# print "pdl written = \n".$pdl."\n";


$pdl2 = $dataset->get;
# print "pdl read = \n".$pdl2."\n";

ok($testNo++, (($pdl - $pdl2)->sum) < .001 );

# Check for the PDL returned being a float
ok($testNo++, ($pdl->get_datatype - $PDL_F) < .001 );

################ Set Attributes at the Dataset Leve ###############			
					
# Set attribute for group
ok($testNo++, $dataset->attrSet( 'attr1' => 'DSdudeman', 'attr2' => 'DSWhat??'));

# Try Setting attr for an existing attr
ok($testNo++,$dataset->attrSet( 'attr1' => 'DSdudeman23'));


# Add a attribute and then delete it
ok($testNo++, $dataset->attrSet( 'dummyAttr' => 'dummyman', 
				'dummyAttr2' => 'dummyman'));
				
ok($testNo++, $dataset->attrDel( 'dummyAttr', 'dummyAttr2' ));


# Get list of attributes
@attrs = $dataset->attrs;
ok($testNo++, join(",",sort @attrs) eq 'attr1,attr2' );

# Get a list of attribute values
@attrValues = $dataset->attrGet(sort @attrs);

ok($testNo++, join(",",@attrValues) eq 'DSdudeman23,DSWhat??' );

################ Set Attributes at the Group Leve ###############			
					
# Set attribute for group
ok($testNo++, $group->attrSet( 'attr1' => 'dudeman', 'attr2' => 'What??'));

# Try Setting attr for an existing attr
ok($testNo++,$group->attrSet( 'attr1' => 'dudeman23'));


# Add a attribute and then delete it
ok($testNo++, $group->attrSet( 'dummyAttr' => 'dummyman', 
				'dummyAttr2' => 'dummyman'));
				
ok($testNo++, $group->attrDel( 'dummyAttr', 'dummyAttr2' ));


# Get list of attributes
@attrs = $group->attrs;
ok($testNo++, join(",",sort @attrs) eq 'attr1,attr2' );

# Get a list of datasets (should be none)
@datasets = $group->datasets;

ok($testNo++, scalar(@datasets) == 0 );

# Create another group
my $group2 = $hdfobj->group("dude2");


# Get a list of groups in the root group
my @groups = $hdfobj->groups;

# print "Root group has these groups '".join(",",sort @groups)."'\n";
ok($testNo++, join(",",sort @groups) eq 'dude2,mygroup' );


# Get a list of groups in group2 (should be none)
@groups = $group2->groups;

ok($testNo++, scalar(@groups) == 0 );


# unlink("newfile.hd5");

print "completed\n";


#  Testing utility functions:
sub ok {
        my $no = shift ;
        my $result = shift ;
        print "not " unless $result ;
        print "ok $no\n" ;
}
