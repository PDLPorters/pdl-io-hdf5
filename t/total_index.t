use PDL;
use PDL::Char;
use PDL::HDF5;
use PDL::Types;

# Script to test the attribute index functionality of the PDL::HDF5 Class

use Data::Dumper;

print "1..7\n";  

my $testNo = 1;

# New File Check:
my $filename = "newFile.hd5";

my $hdfobj;
ok($testNo++,$hdfobj = new PDL::HDF5("newFile.hd5"));

# It is normally a no-no to call a internal method, but we
#  are just testing here:
$hdfobj->_buildAttrIndex;

my $result = recursiveDump($hdfobj->{attrIndex});

my $baseline = 
q!{
    / =>     {
        attr1 => dudeman23,
        attr2 => What??,
    }
    /dude2 =>     {
        attr1 => dudeman23,
        attr2 => What??,
    }
    /mygroup =>     {
        attr1 => dudeman23,
        attr2 => What??,
    }
    /mygroup/subgroup =>     {
        attr1 => dudeman23,
        attr2 => What??,
    }
}
!;

# print $result;
ok($testNo++,$baseline eq $result );

# die;

my @values = $hdfobj->allAttrValues('attr1');

$baseline = 
q![
    dudeman23,
    dudeman23,
    dudeman23,
    dudeman23,
]
!;

#print recursiveDump(\@values);
$result = recursiveDump(\@values);
ok($testNo++,$baseline eq $result );

@values = $hdfobj->allAttrValues('attr1','attr2');
$baseline = 
q![
    [
        dudeman23,
        What??,
    ]
    [
        dudeman23,
        What??,
    ]
    [
        dudeman23,
        What??,
    ]
    [
        dudeman23,
        What??,
    ]
]
!;

#print recursiveDump(\@values);
$result = recursiveDump(\@values);
ok($testNo++,$baseline eq $result );

my @names = $hdfobj->allAttrNames;

$baseline = 
q![
    attr1,
    attr2,
]
!;

#print recursiveDump(\@names);
$result = recursiveDump(\@names);
ok($testNo++,$baseline eq $result );

# Test building the groupIndex
$hdfobj->_buildGroupIndex('attr1','attr2');
$hdfobj->_buildGroupIndex('attr2');
$hdfobj->_buildGroupIndex('attr1','attr3');

$baseline = 
"{
    attr1$;attr2 =>     {
        dudeman23$;What?? =>         [
            /mygroup/subgroup,
            /mygroup,
            /dude2,
            /,
        ]
    }
    attr1$;attr3 =>     {
    }
    attr2 =>     {
        What?? =>         [
            /mygroup/subgroup,
            /mygroup,
            /dude2,
            /,
        ]
    }
}
";

#print $baseline;
#print recursiveDump($hdfobj->{groupIndex});
$result = recursiveDump($hdfobj->{groupIndex});
ok($testNo++,$baseline eq $result );



my @groups = $hdfobj->getGroupsByAttr( 'attr1'  => 'dudeman23',
					'attr2' => 'What??');
$baseline = 
q![
    /mygroup/subgroup,
    /mygroup,
    /dude2,
    /,
]
!;
# print recursiveDump(\@groups);
$result = recursiveDump(\@groups);
ok($testNo++,$baseline eq $result );

					
print "completed\n";


#  Testing utility functions:
sub ok {
        my $no = shift ;
        my $result = shift ;
        print "not " unless $result ;
        print "ok $no\n" ;
}

# Dump of recursive array/hash.
# We Could use Data:Dumper for this but it doesn't 
#  order the keys, which causes problems 
#  in regression testing on different platforsm
sub recursiveDump{
	my ($ref, $level) = @_;
	
	$level = 1 unless( defined($level));
	
	my $returnString; # String to return
	
	my $levelspace = '    ';  # Space used to indent
	
	my $indent = $levelspace x $level;
	my $unindent = $levelspace x ($level-1) ;
	
	my $displayedData = $ref;
	
	my $arrayFlag = 0;
	my @sortedKeys;
	
	 if( ref $ref eq 'ARRAY'){  # arrays are converted to hashes with indexes numbers
				    # as keys for display
		$displayedData = {};
		@$displayedData{0..$#$ref} = @$ref;
		
		$returnString = $unindent."[\n";
		$arrayFlag = 1;
		@sortedKeys = (0..$#$ref);
	 }
	 else{
		$returnString = $unindent."{\n";	
		@sortedKeys = sort keys %$displayedData;

	}

	 my $value;
	 foreach my $key(@sortedKeys){
	 	
		$value = $displayedData->{$key};
		
		if( ref( $value) ){
			$returnString .= $indent.$key." => " unless( $arrayFlag); # dumping hash Ref
			$returnString .= recursiveDump($value,$level+1);
		}
		else{
			$returnString .= $indent.$value.",\n" if( $arrayFlag); # dumping array Ref
			$returnString .= $indent.$key.' => '.$value.",\n" unless( $arrayFlag); # dumping hash Ref
			
		}
		
	}
	
	$returnString .= $unindent."}\n" unless($arrayFlag); # Dumping hash ref
	$returnString .= $unindent."]\n" if($arrayFlag); # Dumping aray ref
		
	$returnString;
	
}

		
