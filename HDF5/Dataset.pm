package PDL::HDF5::Dataset;

use Carp;

=head1 NAME

PDL::HDF5::Dataset - PDL::HDF5 Helper Object representing HDF5 datasets.

=head1 DESCRIPTION

This is a helper-object used by PDL::HDF5 to interface with HDF5 format's dataset objects.
Information on the HDF5 Format can be found
at the NCSA's web site at http://hdf.ncsa.uiuc.edu/ .

=head1 SYNOPSIS

See L<PDL::HDF5>

=head1 MEMBER DATA

=over 1

=item datasetID

ID number given to the dataset by the HDF5 library

=item datasetname

Name of the dataset. 

=item groupID

groupID of the HDF file that owns this dataset.

=item groupName

group Name of the HDF file that owns this dataset.

=back

=head1 METHODS

####---------------------------------------------------------

=head2 new

=for ref

PDL::HDF5::Dataset Constructor - creates new object

B<Usage:>

=for usage

This object will usually be created using the calling format detailed in the L<SYNOPSIS>. The 
following syntax is used by the L<PDL::HDF5> object to build the object.
   
   $a = new PDL::HDF5:Dataset( name => $name, groupName => $groupName, groupID => $groupID );
	Args:
	$name				Name of the dataset
	$groupName			Filename that owns this group
	$groupID			groupID of the file that owns this group

=cut

sub new{

	my $type = shift;
	my %parms = @_;
	my $self = {};

	my @DataMembers = qw( name groupName groupID );
	my %DataMembers;
	@DataMembers{ @DataMembers } = @DataMembers; # hash for quick lookup
	# check for proper supplied names:
	my $varName;
	foreach $varName(keys %parms){
 		unless( defined($DataMembers{$varName})){
			carp("Error Calling ".__PACKAGE__." Constuctor\n  \'$varName\' not a valid data member\n"); 
			return undef;
		}
 		unless( defined($parms{$varName})){
			carp("Error Calling ".__PACKAGE__." Constuctor\n  \'$varName\' not supplied\n"); 
			return undef;
		}
		$self->{$varName} = $parms{$varName};
	}
	
	my $groupID = $self->{groupID};
	my $groupName = $self->{groupName};
	my $name = $self->{name};
	my $datasetID;

	#####
	# Turn Error Reporting off for the following, so H5 lib doesn't complain
	#  if the group isn't found.
	PDL::HDF5::H5errorOff();
	my $rc = PDL::HDF5::H5Gget_objinfo($groupID, $name,1,0);
	PDL::HDF5::H5errorOn();
	# See if the dataset exists:
	if(  $rc >= 0){ 
		#DataSet Exists open it:
		$datasetID = PDL::HDF5::H5Dopen($groupID, $name);
		if($datasetID < 0 ){
			carp "Error Calling ".__PACKAGE__." Constuctor: Can't open existing dataset '$name'\n";
			return undef;
		}

	}
	else{  # dataset didn't exist, set datasetID = 0
		## (Have to put off opening the dataset
		### until it is written to (Must know dims, etc to create)
		$datasetID = 0;
	}
                             

	$self->{datasetID} = $datasetID;

	bless $self, $type;

	return $self;
}	

=head2 DESTROY

=for ref

PDL::HDF5::Dataset Destructor - Closes the dataset object

B<Usage:>

=for usage

   No Usage. Automatically called
   
    
=cut


sub DESTROY {
  my $self = shift;
  my $datasetID = $self->{datasetID};

  if( $datasetID && (H5Dclose($self->{datasetID}) < 0 )){
	warn("Error closing HDF5 Dataset '".$self->{name}."' in file:group: '".$self->{filename}.":".$self->{group}."'\n");
  }

}

=head2 set

=for ref

Write data to the HDF5 dataset

B<Usage:>

=for usage

 $dataset->set($pdl);     # Write the array data in the dataset

=cut


#############################################################################
# Mapping of PDL types to HDF5 types for writing to a dataset
#
#   Mapping of PDL types to what HDF5 calls them while we are dealing with them 
#   outside of the HDF5 file.
%PDLtoHDF5internalTypeMapping = (
	$PDL::Types::PDL_B	=>	PDL::HDF5::H5T_NATIVE_CHAR(),
	$PDL::Types::PDL_S	=> 	PDL::HDF5::H5T_NATIVE_SHORT(),
	$PDL::Types::PDL_L	=> 	PDL::HDF5::H5T_NATIVE_LONG(),
        $PDL::Types::PDL_F	=>	PDL::HDF5::H5T_NATIVE_FLOAT(),
	$PDL::Types::PDL_D	=>	PDL::HDF5::H5T_NATIVE_DOUBLE(),
);
#   Mapping of PDL types to what types they are written to in the HDF5 file.
#   For 64 Bit machines, we might need to modify this with some smarts to determine
#   what is appropriate
%PDLtoHDF5fileMapping = (
	$PDL::Types::PDL_B	=>	PDL::HDF5::H5T_STD_I8BE(),
	$PDL::Types::PDL_S	=> 	PDL::HDF5::H5T_STD_I16BE(),
	$PDL::Types::PDL_L	=> 	PDL::HDF5::H5T_STD_I32BE(),
        $PDL::Types::PDL_F	=>	PDL::HDF5::H5T_IEEE_F32BE(),
	$PDL::Types::PDL_D	=>	PDL::HDF5::H5T_IEEE_F64BE(),
);



sub set{

	$self = shift;

	my ($pdl) = @_;


	my $groupID = $self->{groupID};
	my $datasetID = $self->{datasetID};
	my $name = $self->{name};

	my $type = $pdl->get_datatype; # get PDL datatype

	unless( defined($PDLtoHDF5internalTypeMapping{$type}) ){
		carp "Error Calling ".__PACKAGE__."::set: Can't map PDL type to HDF5 datatype\n";
		return undef;
	}
	my $internalhdf5_type = $PDLtoHDF5internalTypeMapping{$type};

	unless( defined($PDLtoHDF5fileMapping{$type}) ){
		carp "Error Calling ".__PACKAGE__."::set: Can't map PDL type to HDF5 datatype\n";
		return undef;
	}	
	my $hdf5Filetype = $PDLtoHDF5fileMapping{$type};

	my @dims = reverse($pdl->dims); # HDF5 stores columns/rows in reverse order than pdl

	
	
        my $dims = PDL::HDF5::packList(@dims);
   		
	
	my $dataspaceID = PDL::HDF5::H5Screate_simple(scalar(@dims), $dims , $dims);
        if( $dataspaceID < 0 ){
		carp("Can't Open Dataspace in ".__PACKAGE__.":set\n");
		return undef;
	}

	if( $datasetID == 0){  # Dataset not created yet
	
	       # /* Create the dataset. */
		$datasetID = PDL::HDF5::H5Dcreate($groupID, $name, $hdf5Filetype, $dataspaceID, 
                PDL::HDF5::H5P_DEFAULT());
		if( $datasetID < 0){
			carp("Can't Create Dataspace in ".__PACKAGE__.":set\n");
			return undef;
		}
		$self->{datasetID} = $datasetID;
	}

	# Write the actual data:
        $data = ${$pdl->get_dataref};
	

	if( PDL::HDF5::H5Dwrite($datasetID, $internalhdf5_type, PDL::HDF5::H5S_ALL(), PDL::HDF5::H5S_ALL(), PDL::HDF5::H5P_DEFAULT(),
		$data) < 0 ){ 

		carp("Error Writing to dataset in ".__PACKAGE__.":set\n");
		return undef;

	}
	

	# /* Terminate access to the data space. */
	carp("Can't close Dataspace in ".__PACKAGE__.":set\n") if( PDL::HDF5::H5Sclose($dataspaceID) < 0);

	return 1;

}


=head2 get

=for ref

Rdad data from a HDF5 dataset to a PDL

B<Usage:>

=for usage

 $pdl = $dataset->get;     # Read the Array from the HDF5 dataset, create a PDL from it
		       	   #  and put in $pdl

The mapping of HDF5 datatypes in the file to PDL datatypes in memory will be according
to the following table.

 HDF5 File Type				PDL Type
 ------------------------               -----------------
 PDL::HDF5::H5T_STD_I8BE()	=> 	$PDL::Types::PDL_B
 PDL::HDF5::H5T_STD_I8LE()	=> 	$PDL::Types::PDL_B,
 PDL::HDF5::H5T_STD_I16BE()	=> 	$PDL::Types::PDL_S,
 PDL::HDF5::H5T_STD_I16LE()	=> 	$PDL::Types::PDL_S,
 PDL::HDF5::H5T_STD_I32BE()	=> 	$PDL::Types::PDL_L,
 PDL::HDF5::H5T_STD_I32LE()	=> 	$PDL::Types::PDL_L,
 PDL::HDF5::H5T_IEEE_F32BE()	=>	$PDL::Types::PDL_F,
 PDL::HDF5::H5T_IEEE_F32LE()	=>	$PDL::Types::PDL_F,
 PDL::HDF5::H5T_IEEE_F64BE()	=>	$PDL::Types::PDL_D,
 PDL::HDF5::H5T_IEEE_F64LE()	=>	$PDL::Types::PDL_D

For HDF5 File types not in this table, this method will attempt to
map it to the default PDL type PDL_D.


=cut


#############################################################################
# Mapping of HDF5 file types to PDL types
#   For 64 Bit machines, we might need to modify this with some smarts to determine
#   what is appropriate
%HDF5toPDLfileMapping = (
	 PDL::HDF5::H5T_STD_I8BE()	=> 	$PDL::Types::PDL_B,
	 PDL::HDF5::H5T_STD_I8LE()	=> 	$PDL::Types::PDL_B,
	 PDL::HDF5::H5T_STD_I16BE()	=> 	$PDL::Types::PDL_S,
	 PDL::HDF5::H5T_STD_I16LE()	=> 	$PDL::Types::PDL_S,
	 PDL::HDF5::H5T_STD_I32BE()	=> 	$PDL::Types::PDL_L,
	 PDL::HDF5::H5T_STD_I32LE()	=> 	$PDL::Types::PDL_L,
	 PDL::HDF5::H5T_IEEE_F32BE()	=>	$PDL::Types::PDL_F,
	 PDL::HDF5::H5T_IEEE_F32LE()	=>	$PDL::Types::PDL_F,
	 PDL::HDF5::H5T_IEEE_F64BE()	=>	$PDL::Types::PDL_D,
	 PDL::HDF5::H5T_IEEE_F64LE()	=>	$PDL::Types::PDL_D
);



sub get{

	$self = shift;

	my $pdl;


	my $groupID = $self->{groupID};
	my $datasetID = $self->{datasetID};
	my $name = $self->{name};

	# Get the HDF5 file datatype;
        my $HDF5type = PDL::HDF5::H5Dget_type($datasetID );
	unless( $HDF5type >= 0 ){
		carp "Error Calling ".__PACKAGE__."::get: Can't get HDF5 Dataset type.\n";
		return undef;
	}

	# Map the HDF5 file datatype to a PDL datatype
	my $PDLtype = $PDL::Types::PDL_D; # Default type is double
	if( defined($HDF5toPDLfileMapping{$HDF5type}) ){
		$PDLtype = $HDF5toPDLfileMapping{$HDF5type};
	}

	# Get the HDF5 internal datatype that corresponds to the PDL type
	unless( defined($PDLtoHDF5internalTypeMapping{$PDLtype}) ){
		carp "Error Calling ".__PACKAGE__."::set: Can't map PDL type to HDF5 datatype\n";
		return undef;
	}
	my $internalhdf5_type = $PDLtoHDF5internalTypeMapping{$PDLtype};


	my $dataspaceID = PDL::HDF5::H5Dget_space($datasetID);
	if( $dataspaceID < 0 ){
		carp("Can't Open Dataspace in ".__PACKAGE__.":get\n");
		carp("Can't close Datatype in ".__PACKAGE__.":get\n") if( PDL::HDF5::H5Tclose($HDF5type) < 0);
		return undef;
	}


	# Get the number of dims:
	my $Ndims = PDL::HDF5::H5Sget_simple_extent_ndims($dataspaceID);
 	if( $Ndims < 0 ){
		carp("Can't Get Number of Dims in  Dataspace in ".__PACKAGE__.":get\n");
		carp("Can't close Datatype in ".__PACKAGE__.":get\n") if( PDL::HDF5::H5Tclose($HDF5type) < 0);
		return undef;
	}


	# Initialize Dims structure:
	my @dims = ( 0..($Ndims-1)); 
        my $dims = PDL::HDF5::packList(@dims);
	my $dims2 = PDL::HDF5::packList(@dims);

        my $rc = PDL::HDF5::H5Sget_simple_extent_dims($dataspaceID, $dims, $dims2 );

	if( $rc != $Ndims){
		carp("Error getting number of dims in dataspace in ".__PACKAGE__.":get\n");
		carp("Can't close Datatype in ".__PACKAGE__.":get\n") if( PDL::HDF5::H5Tclose($HDF5type) < 0);
		carp("Can't close DataSpace in ".__PACKAGE__.":get\n") if( PDL::HDF5::H5Sclose($dataspaceID) < 0);
		return undef;
	}

	@dims = PDL::HDF5::unpackList($dims); # get the dim sizes from the binary structure

	$pdl = PDL->null;
	$pdl->set_datatype($PDLtype);
	$pdl->setdims([reverse @dims]);  # HDF5 stores columns/rows in reverse order than pdl

	my $nelems = 1;
	foreach (@dims){ $nelems *= $_; }; # calculate the number of elements

	my $datasize = $nelems * PDL::howbig($pdl->get_datatype);
	my $data = pack("x$datasize"); # create empty space for the data

	# Read the data:
        $rc = PDL::HDF5::H5Dread($datasetID, $internalhdf5_type, PDL::HDF5::H5S_ALL(), PDL::HDF5::H5S_ALL(), 
		   PDL::HDF5::H5P_DEFAULT(),
                    $data);

	if( $rc < 0 ){
		carp("Error reading data from file in ".__PACKAGE__.":get\n");
		carp("Can't close Datatype in ".__PACKAGE__.":get\n") if( PDL::HDF5::H5Tclose($HDF5type) < 0);
		carp("Can't close DataSpace in ".__PACKAGE__.":get\n") if( PDL::HDF5::H5Sclose($dataspaceID) < 0);
		return undef;
	}

	# Update the PDL data with the data read from the file
	${$pdl->get_dataref()} = $data;
	$pdl->upd_data();


	# /* Terminate access to the data space. */
	carp("Can't close Dataspace in ".__PACKAGE__.":get\n") if( PDL::HDF5::H5Sclose($dataspaceID) < 0);

	# /* Terminate access to the data type. */
	carp("Can't close Datatype in ".__PACKAGE__.":get\n") if( PDL::HDF5::H5Tclose($HDF5type) < 0);
	return $pdl;

}




=head2 attrSet

=for ref

Set the value of an attribute(s)

Currently the only attribute types supported are null-terminated strings.

B<Usage:>

=for usage

   $dataset->attrSet( 'attr1' => 'attr1Value',
   		    'attr2' => 'attr2 value', 
		    .
		    .
		    .
		   );

Returns undef on failure, 1 on success.

=cut

sub attrSet {
	my $self = shift;

	my %attrs = @_; # get atribute hash
	
	my $datasetID = $self->{datasetID};

	unless( $datasetID){ # Error checking
		carp("Can't Set Attribute for empty dataset. Try writing some data to it first:\n");
		carp("    in file:group: '".$self->{filename}.":".$self->{group}."'\n");
		return undef;
	}
	
	my($key,$value);

	my $typeID; # id used for attribute
	my $dataspaceID; # id used for the attribute dataspace
	
	my $attrID;
	foreach $key( sort keys %attrs){
		
		$value = $attrs{$key};
		
		# Create Null-Terminated String Type 
		$typeID = PDL::HDF5::H5Tcopy(PDL::HDF5::H5T_C_S1());
		PDL::HDF5::H5Tset_size($typeID, length($value)); # make legth of type eaual to length of $value
		$dataspaceID = PDL::HDF5::H5Screate_simple(0, 0, 0);

		#Note: If a attr already exists, then it will be deleted an re-written
		# Delete the attribute first
		PDL::HDF5::H5errorOff();  # keep h5 lib from complaining
		PDL::HDF5::H5Adelete($datasetID, $key);
		PDL::HDF5::H5errorOn();

		
		$attrID = PDL::HDF5::H5Acreate($datasetID, $key, $typeID, $dataspaceID, PDL::HDF5::H5P_DEFAULT());

		if($attrID < 0 ){
			carp "Error in ".__PACKAGE__." attrSet; Can't create attribute '$key'\n";

			PDL::HDF5::H5Sclose($dataspaceID);
			PDL::HDF5::H5Tclose($typeID); # Cleanup
			return undef;
		}
		
		# Write the attribute data.
		if( PDL::HDF5::H5Awrite($attrID, $typeID, $value) < 0){
			carp "Error in ".__PACKAGE__." attrSet; Can't write attribute '$key'\n";
			PDL::HDF5::H5Aclose($attrID);
			PDL::HDF5::H5Sclose($dataspaceID);
			PDL::HDF5::H5Tclose($typeID); # Cleanup
			return undef;
		}
		
		# Cleanup
		PDL::HDF5::H5Aclose($attrID);
		PDL::HDF5::H5Sclose($dataspaceID);
		PDL::HDF5::H5Tclose($typeID);

			
	}
	
	return 1;
  
}

=head2 attrDel

=for ref

Delete attribute(s)

B<Usage:>

=for usage

 $dataset->attrDel( 'attr1', 
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
	
	my $datasetID = $self->{datasetID};

	my $attr;
	my $rc; #Return code returned by H5Adelete
	foreach $attr( @attrs ){
		

		# Note: We don't consider errors here as cause for aborting, we just
		#  complain using carp
		if( PDL::HDF5::H5Adelete($datasetID, $attr) < 0){
			carp "Error in ".__PACKAGE__." attrDel; Error Deleting attribute '$attr'\n";
		}
		
	}
	
	return 1;
  
}


=head2 attrs

=for ref

Get a list of all attribute names associated with a dataset


B<Usage:>

=for usage

   @attrs = $dataset->attrs;


=cut

sub attrs {
	my $self = shift;

	my $datasetID = $self->{datasetID};
	
	my $defaultMaxSize = 256; # default max size of a attribute name

	my $noAttr = PDL::HDF5::H5Aget_num_attrs($datasetID); # get the number of attributes

	my $attrIndex = 0; # attribute Index

	my @attrNames = ();
	my $attributeID;
	my $attrNameSize; # size of the attribute name
	my $attrName;     # attribute name

	# Go thru each attribute and get the name
	for( $attrIndex = 0; $attrIndex < $noAttr; $attrIndex++){

		$attributeID = PDL::HDF5::H5Aopen_idx($datasetID, $attrIndex );

		if( $attributeID < 0){
			carp "Error in ".__PACKAGE__." attrs; Error Opening attribute number $attrIndex\n";
			next;
		}

	      	#init attrname to 256 length string (Maybe this not necessary with
		#  the typemap)
		$attrName = ' ' x 256;
		
		# Get the name
		$attrNameSize = PDL::HDF5::H5Aget_name($attributeID, 256, $attrName ); 

		# If the name is greater than 256, try again with the proper size:
		if( $attrNameSize > 256 ){
			$attrName = ' ' x $attrNameSize;
			$attrNameSize = PDL::HDF5::H5Aget_name($attributeID, $attrNameSize, $attrName ); 

		}

		push @attrNames, $attrName;

		# Close the attr:
		PDL::HDF5::H5Aclose($attributeID);
	}


	
	return @attrNames;
  
}

1;

