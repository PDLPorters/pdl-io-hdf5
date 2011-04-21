package PDL::IO::HDF5::Group;


use Carp;

use strict;

=head1 NAME

PDL::IO::HDF5::Group - PDL::IO::HDF5 Helper Object representing HDF5 groups.

=head1 DESCRIPTION

This is a helper-object used by PDL::IO::HDF5 to interface with HDF5 format's group objects.
Information on the HDF5 Format can be found
at the NCSA's web site at http://hdf.ncsa.uiuc.edu/ .

=head1 SYNOPSIS

See L<PDL::IO::HDF5>

=head1 MEMBER DATA

=over 1

=item ID

ID number given to the group by the HDF5 library

=item name

Name of the group. (Absolute to the root group '/'. e.g. /maingroup/subgroup)

=item parent

Ref to parent object (file or group) that owns this group.

=item fileObj

Ref to the L<PDL::IO::HDF5> object that owns this object.

=back

=head1 METHODS

####---------------------------------------------------------

=head2 new

=for ref

PDL::IO::HDF5::Group Constructor - creates new object

B<Usage:>

=for usage

This object will usually be created using the calling format detailed in the L<SYNOPSIS>. The 
following syntax is used by the L<PDL::IO::HDF5> object to build the object.
   
   $a = new PDL::IO::HDF5:Group( name => $name, parent => $parent,
   			      fileObj => $fileObj );
	Args:
	$name				Name of the group (relative to the parent)
	$parent				Parent Object that owns this group
	$fileObj                        PDL::HDF (Top Level) object that owns this group.

=cut

sub new{

	my $type = shift;
	my %parms = @_;
	my $self = {};

	my @DataMembers = qw( name parent fileObj);
	my %DataMembers;
	@DataMembers{ @DataMembers } = @DataMembers; # hash for quick lookup
	# check for proper supplied names:
	my $varName;
	foreach $varName(keys %parms){
 		unless( defined($DataMembers{$varName})){
			carp("Error Calling ".__PACKAGE__." Constuctor\n  \'$varName\' not a valid data member\n"); 
			return undef;
		}
		$self->{$varName} = $parms{$varName};
	}
	
	my $parent = $self->{parent};
	my $parentID = $parent->IDget;
	my $parentName = $parent->nameGet;
	my $groupName = $self->{name};
	my $groupID;
	
	# Adjust groupname to be absolute:
	if( $parentName ne '/') {  # Parent is not the root group
		$self->{name} = "$parentName/$groupName";
	}
	else{  # Parent is root group
		$self->{name} = "$parentName$groupName";
	}

	

	# Turn Error Reporting off for the following, so H5 lib doesn't complain
	#  if the group isn't found.
	PDL::IO::HDF5::H5errorOff();
	my $rc = PDL::IO::HDF5::H5Gget_objinfo($parentID, $groupName,1,0);
	PDL::IO::HDF5::H5errorOn();
	# See if the group exists:
	if(  $rc >= 0){ 
		#Group Exists open it:
		$groupID = PDL::IO::HDF5::H5Gopen($parentID, $groupName);
	}
	else{  # group didn't exist, create it:
		$groupID = PDL::IO::HDF5::H5Gcreate($parentID, $groupName, 0);
		# Clear-out the attribute index, it is no longer valid with the updates
		#  we just made.
		$self->{fileObj}->clearAttrIndex;

	}
	# Try Opening the Group First (Assume it already exists)

	if($groupID < 0 ){
		carp "Error Calling ".__PACKAGE__." Constuctor: Can't open or create group '$groupName'\n";
		return undef;
	}
		
	
	$self->{ID} = $groupID;

	bless $self, $type;

	return $self;
}	

=head2 DESTROY

=for ref

PDL::IO::HDF5 Destructor - Closes the HDF5::Group Object.

B<Usage:>

=for usage

   No Usage. Automatically called
   

=cut


sub DESTROY {
  my $self = shift;
  #print "In Group DEstroy\n";
  if( PDL::IO::HDF5::H5Gclose($self->{ID}) < 0){
	warn("Error closing HDF5 Group '".$self->{name}."' in file '".$self->{parentName}."'\n");
  }

}

=head2 attrSet

=for ref

Set the value of an attribute(s)

Attribute types supported are null-terminated strings and PDL matrices

B<Usage:>

=for usage

   $group->attrSet( 'attr1' => 'attr1Value',
   		    'attr2' => 'attr2 value', 
                    'attr3' => $pdl,
		    .
		    .
		    .
		   );

Returns undef on failure, 1 on success.

=cut

sub attrSet {
	my $self = shift;
	
	# Attribute setting for groups is exactly like datasets
	#  Call datasets directly (This breaks OO inheritance, but is 
	#   better than duplicating code from the dataset object here
	return $self->PDL::IO::HDF5::Dataset::attrSet(@_);

  
}


=head2 attrGet

=for ref

Get the value of an attribute(s)

Currently the only attribute types supported are null-terminated strings.

B<Usage:>

=for usage

   my @attrs = $group->attrGet( 'attr1', 'attr2');


=cut

sub attrGet {
	my $self = shift;
	
	
	# Attribute reading for groups is exactly like datasets
	#  Call datasets directly (This breaks OO inheritance, but is 
	#   better than duplicating code from the dataset object here
	return $self->PDL::IO::HDF5::Dataset::attrGet(@_);


}


=head2 attrDel

=for ref

Delete attribute(s)

B<Usage:>

=for usage

   $group->attrDel( 'attr1', 
      		    'attr2',
		    .
		    .
		    .
		   );

Returns undef on failure, 1 on success.

=cut

sub attrDel {
	my $self = shift;

	my @attrs = @_; # get atribute names
	
	my $groupID = $self->{ID};
	
	my $attr;
	my $rc; #Return code returned by H5Adelete
	foreach $attr( @attrs ){
		

		# Note: We don't consider errors here as cause for aborting, we just
		#  complain using carp
		if( PDL::IO::HDF5::H5Adelete($groupID, $attr) < 0){
			carp "Error in ".__PACKAGE__." attrDel; Error Deleting attribute '$attr'\n";
		}
		
	}
	# Clear-out the attribute index, it is no longer valid with the updates
	#  we just made.
	$self->{fileObj}->clearAttrIndex;
	
	return 1;
  
}


=head2 attrs

=for ref

Get a list of all attribute names in a group


B<Usage:>

=for usage

   @attrs = $group->attrs;


=cut

sub attrs {
	my $self = shift;

	my $groupID = $self->{ID};
	
	my $defaultMaxSize = 256; # default max size of a attribute name

	my $noAttr = PDL::IO::HDF5::H5Aget_num_attrs($groupID); # get the number of attributes

	my $attrIndex = 0; # attribute Index

	my @attrNames = ();
	my $attributeID;
	my $attrNameSize; # size of the attribute name
	my $attrName;     # attribute name

	# Go thru each attribute and get the name
	for( $attrIndex = 0; $attrIndex < $noAttr; $attrIndex++){

		$attributeID = PDL::IO::HDF5::H5Aopen_idx($groupID, $attrIndex );

		if( $attributeID < 0){
			carp "Error in ".__PACKAGE__." attrs; Error Opening attribute number $attrIndex\n";
			next;
		}

	      	#init attrname to 256 length string (Maybe this not necessary with
		#  the typemap)
		$attrName = ' ' x 256;
		
		# Get the name
		$attrNameSize = PDL::IO::HDF5::H5Aget_name($attributeID, 256, $attrName ); 

		# If the name is greater than 256, try again with the proper size:
		if( $attrNameSize > 256 ){
			$attrName = ' ' x $attrNameSize;
			$attrNameSize = PDL::IO::HDF5::H5Aget_name($attributeID, $attrNameSize, $attrName ); 

		}

		push @attrNames, $attrName;

		# Close the attr:
		PDL::IO::HDF5::H5Aclose($attributeID);
	}


	
	return @attrNames;
  
}


=head2 dataset

=for ref

Open an existing or create a new dataset in a group.

B<Usage:>

=for usage

   $dataset = $group->dataset('newdataset');

Returns undef on failure, 1 on success.

=cut

sub dataset {
	my $self = shift;

	my $name = $_[0];

	my $groupID = $self->{ID}; # get the group name of the current group
	
	my $dataset = PDL::IO::HDF5::Dataset->new( name=> $name, parent => $self,
					 fileObj => $self->{fileObj} );

}



=head2 datasets

=for ref

Get a list of all dataset names in a group. (Relative to the current group)


B<Usage:>

=for usage

   @datasets = $group->datasets;


=cut

sub datasets {
	my $self = shift;

	my $groupID = $self->{ID};
	
	my @totalDatasets = PDL::IO::HDF5::H5GgetDatasetNames($groupID,".");
	
		
	
	return @totalDatasets;
  
}

=head2 group

=for ref

Open an existing or create a new group in an existing group.

B<Usage:>

=for usage

   $newgroup = $oldgroup->group("newgroup");

Returns undef on failure, 1 on success.

=cut

sub group {
	my $self = shift;

	my $name = $_[0]; # get the group name
	
	
	my $group =  new PDL::IO::HDF5::Group( name=> $name, parent => $self,
					fileObj => $self->{fileObj}  );
					

	return $group;

}




=head2 groups

=for ref

Get a list of all group names in a group. (Relative to the current group)


B<Usage:>

=for usage

   @groupNames = $group->groups;


=cut

sub groups {
	my $self = shift;

	my $groupID = $self->{ID};
	
	my @totalgroups = PDL::IO::HDF5::H5GgetGroupNames($groupID,'.');
	
		
	
	return @totalgroups;
  
}


=head2 _buildAttrIndex

=for ref

Internal Recursive Method to build the attribute index hash
for the object

For the purposes of indexing groups by their attributes, the attributes are 
applied hierarchial. i.e. any attributes of the higher level groups are assumed to be 
apply for the lower level groups.


B<Usage:>

=for usage

   $group->_buildAttrIndex($index, $currentAttrs);

    
 Input/Output:

         $index:        Total Index hash ref
	 $currentAttrs: Hash refs of the attributes valid 
	                for the current group.
	                


=cut

sub _buildAttrIndex{

	my ($self, $index, $currentAttrs) = @_;
	
	# Take care of any attributes in the current group
	my @attrs = $self->attrs;
	
	my @attrValues = $self->attrGet(@attrs);
	
	# Get the group name
	my $groupName = $self->nameGet;
	
	my %indexElement; # element of the index for this group
	
	%indexElement = %$currentAttrs; # Initialize index element
				        # with attributes valid at the 
					# group above
					
	# Add (or overwrite) attributes for this group
	#    i.e. local group attributes take precedence over
	#         higher-level attributes
	@indexElement{@attrs} = @attrValues;
	
	$index->{$groupName} = \%indexElement;
	
	 
	# Now Do any subgroups: 
	my @subGroups = $self->groups;
	my $subGroup;
	
	foreach $subGroup(@subGroups){
		$self->group($subGroup)->_buildAttrIndex($index,\%indexElement);
	}
	
}

=head2 IDget

=for ref

Returns the HDF5 library ID for this object

B<Usage:>

=for usage

 my $ID = $groupObj->IDget;

=cut

sub IDget{

	my $self = shift;
	
	return $self->{ID};
		
}

=head2 nameGet

=for ref

Returns the HDF5 Group Name for this object. (Relative to the root group)

B<Usage:>

=for usage

 my $name = $groupObj->nameGet;

=cut

sub nameGet{

	my $self = shift;
	
	return $self->{name};
		
}

1;

