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
	my $internalhdf5_type;  # hdf5 type that describes the way data is stored in memory
	my $hdf5Filetype;       # hdf5 type that describes the way data will be stored in the file.
	my @dims;               # hdf5 equivalent dims for the supplied PDL

	my $type = $pdl->get_datatype; # get PDL datatype
	if( $pdl->isa('PDL::Char') ){ #  Special Case for PDL::Char Objects (fixed length strings)
	
		@dims = $pdl->dims;
		my $length = shift @dims; # String length is the first dim of the PDL for PDL::Char
		# Create Null-Terminated String Type 
		$internalhdf5_type = PDL::HDF5::H5Tcopy(PDL::HDF5::H5T_C_S1());
		PDL::HDF5::H5Tset_size($internalhdf5_type, $length ); # make legth of type eaual to strings
		$hdf5Filetype =  $internalhdf5_type; # memory and file storage will be the same type
		
		@dims = reverse(@dims);  # HDF5 stores columns/rows in reverse order than pdl

	}
	else{   # Other PDL Types


		unless( defined($PDLtoHDF5internalTypeMapping{$type}) ){
			carp "Error Calling ".__PACKAGE__."::set: Can't map PDL type to HDF5 datatype\n";
			return undef;
		}
		$internalhdf5_type = $PDLtoHDF5internalTypeMapping{$type};
	
		unless( defined($PDLtoHDF5fileMapping{$type}) ){
			carp "Error Calling ".__PACKAGE__."::set: Can't map PDL type to HDF5 datatype\n";
			return undef;
		}	
		$hdf5Filetype = $PDLtoHDF5fileMapping{$type};


		@dims = reverse($pdl->dims); # HDF5 stores columns/rows in reverse order than pdl

	}


	
	
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

Get data from a HDF5 dataset to a PDL

B<Usage:>

=for usage

 $pdl = $dataset->get;     # Read the Array from the HDF5 dataset, create a PDL from it
		       	   #  and put in $pdl

The mapping of HDF5 datatypes in the file to PDL datatypes in memory will be according
to the following table.

 HDF5 File Type				PDL Type
 ------------------------               -----------------
 PDL::HDF5::H5T_C_S1()		=>      PDL::Char Object    (Special Case for Char Strings)
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

$H5T_STRING = PDL::HDF5::H5T_STRING();  #HDF5 string type

sub get{

	$self = shift;

	my $pdl;


	my $groupID = $self->{groupID};
	my $datasetID = $self->{datasetID};
	my $name = $self->{name};
	my $stringSize;  		# String size, if we are retrieving a string type
	my $PDLtype;     		# PDL type that the data will be mapped to
	my $internalhdf5_type; 		# Type that represents how HDF5 will store the data in memory (after retreiving from
					#  the file)

	my $ReturnType = 'PDL';	        # Default object returned is PDL. If strings are store, then this will
					# return PDL::Char

	# Get the HDF5 file datatype;
        my $HDF5type = PDL::HDF5::H5Dget_type($datasetID );
	unless( $HDF5type >= 0 ){
		carp "Error Calling ".__PACKAGE__."::get: Can't get HDF5 Dataset type.\n";
		return undef;
	}

	# Check for string type:
	if( PDL::HDF5::H5Tget_class($HDF5type ) == $H5T_STRING ){  # String type

		$stringSize = PDL::HDF5::H5Tget_size($HDF5type);
		unless( $stringSize >= 0 ){
			carp "Error Calling ".__PACKAGE__."::get: Can't get HDF5 String Datatype Size.\n";
			carp("Can't close Datatype in ".__PACKAGE__.":get\n") if( PDL::HDF5::H5Tclose($HDF5type) < 0);
			return undef;
		}

		$PDLtype = $PDL::Types::PDL_B; 
		$internalhdf5_type =  $HDF5type; # internal storage the same as the file storage.

		$ReturnType = 'PDL::Char';	 # For strings, we return a PDL::Char

	}
	else{  # Normal Numeric Type
		# Map the HDF5 file datatype to a PDL datatype
		$PDLtype = $PDL::Types::PDL_D; # Default type is double
		
		my $defaultType;
		foreach $defaultType( keys %HDF5toPDLfileMapping){
			if( PDL::HDF5::H5Tequal($defaultType,$HDF5type) > 0){
				$PDLtype = $HDF5toPDLfileMapping{$defaultType};
				last;
			}
		}
		
	
		# Get the HDF5 internal datatype that corresponds to the PDL type
		unless( defined($PDLtoHDF5internalTypeMapping{$PDLtype}) ){
			carp "Error Calling ".__PACKAGE__."::set: Can't map PDL type to HDF5 datatype\n";
			return undef;
		}
		$internalhdf5_type = $PDLtoHDF5internalTypeMapping{$PDLtype};
	}

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
		carp("Can't close DataSpace in ".__PACKAGE__.":get\n") if( PDL::HDF5::H5Sclose($dataspaceID) < 0);
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

	$pdl = $ReturnType->null;
	$pdl->set_datatype($PDLtype);
	my @pdldims;  # dims of the PDL
	if( defined( $stringSize )){  # String types
		
		@pdldims = ($stringSize,reverse(@dims)); # HDF5 stores columns/rows in reverse order than pdl,
							      #  1st PDL dim is the string length (for PDL::Char)
	}
	else{ # Normal Numeric types
		@pdldims = (reverse(@dims)); 		# HDF5 stores columns/rows in reverse order than pdl,
	}

	$pdl->setdims(\@pdldims);

	my $nelems = 1;
	foreach (@pdldims){ $nelems *= $_; }; # calculate the number of elements

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


=head2 dims

=for ref

Get the dims for a HDF5 dataset. For example, a 3 x 4 array would return a perl array
(3,4);

B<Usage:>

=for usage

 @pdl = $dataset->dims;    # Get an array of dims. 

=cut


sub dims{

	$self = shift;

	my $groupID = $self->{groupID};
	my $datasetID = $self->{datasetID};
	my $name = $self->{name};


	my $dataspaceID = PDL::HDF5::H5Dget_space($datasetID);
	if( $dataspaceID < 0 ){
		carp("Can't Open Dataspace in ".__PACKAGE__.":get\n");
		return undef;
	}


	# Get the number of dims:
	my $Ndims = PDL::HDF5::H5Sget_simple_extent_ndims($dataspaceID);
 	if( $Ndims < 0 ){
		carp("Can't Get Number of Dims in  Dataspace in ".__PACKAGE__.":get\n");
		return undef;
	}


	# Initialize Dims structure:
	my @dims = ( 0..($Ndims-1)); 
        my $dims = PDL::HDF5::packList(@dims);
	my $dims2 = PDL::HDF5::packList(@dims);

        my $rc = PDL::HDF5::H5Sget_simple_extent_dims($dataspaceID, $dims, $dims2 );

	if( $rc != $Ndims){
		carp("Error getting number of dims in dataspace in ".__PACKAGE__.":get\n");
		carp("Can't close DataSpace in ".__PACKAGE__.":get\n") if( PDL::HDF5::H5Sclose($dataspaceID) < 0);
		return undef;
	}

	@dims = PDL::HDF5::unpackList($dims); # get the dim sizes from the binary structure

	return reverse @dims;  # return dims in the order that PDL will store them
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
		PDL::HDF5::H5Tset_size($typeID, length($value) || 1 ); # make legth of type eaual to length of $value or 1 if zero
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

=head2 attrGet

=for ref

Get the value of an attribute(s)

Currently the only attribute types supported are null-terminated strings.

B<Usage:>

=for usage

   my @attrs = $dataset->attrGet( 'attr1', 'attr2');


=cut

sub attrGet {
	my $self = shift;

	my @attrs = @_; # get atribute array
	
	my $datasetID = $self->{datasetID};
	
	my($attrName,$attrValue);

	my @attrValues; #return array
	
	my $typeID; # id used for attribute
	my $dataspaceID; # id used for the attribute dataspace
	
	my $attrID;
	foreach $attrName( @attrs){
		
		$attrValue = undef;
		
		# Open the Attribute
		$attrID = PDL::HDF5::H5Aopen_name($datasetID, $attrName );
		unless( $attrID >= 0){
			carp "Error Calling ".__PACKAGE__."::attrget: Can't open HDF5 Attribute name '$attrName'.\n";
			next;
		}			
		 
		# Open the data-space
		$dataspaceID = PDL::HDF5::H5Aget_space($attrID);
		if( $dataspaceID < 0 ){
			carp("Can't Open Dataspace for Attribute name '$attrName' in  ".__PACKAGE__."::attrget\n");
			carp("Can't close Attribute in ".__PACKAGE__.":attrGet\n") if( PDL::HDF5::H5Aclose($attrID) < 0);
			next;
		}

		# Check to see if the dataspace is simple
		if( PDL::HDF5::H5Sis_simple($dataspaceID) < 0 ){
			carp("Warning: Non-Simple Dataspace for Attribute name '$attrName' ".__PACKAGE__."::attrget\n");
			carp("Can't close DataSpace in ".__PACKAGE__.":attrGet\n") if( PDL::HDF5::H5Sclose($dataspaceID) < 0);
			carp("Can't close Attribute in ".__PACKAGE__.":attrGet\n") if( PDL::HDF5::H5Aclose($attrID) < 0);
			next;
		}


		# Get the number of dims:
		my $Ndims = PDL::HDF5::H5Sget_simple_extent_ndims($dataspaceID);
		unless( $Ndims == 0){
			if( $Ndims < 0 ){
				carp("Warning: Can't Get Number of Dims in Attribute name '$attrName' Dataspace in ".__PACKAGE__.":get\n");
			}
			if( $Ndims > 0 ){
				carp("Warning: Non-Scalar Dataspace for Attribute name '$attrName' Dataspace in ".__PACKAGE__.":get\n");
			}			
			carp("Can't close DataSpace in ".__PACKAGE__.":attrGet\n") if( PDL::HDF5::H5Sclose($dataspaceID) < 0);
			carp("Can't close Attribute in ".__PACKAGE__.":attrGet\n") if( PDL::HDF5::H5Aclose($attrID) < 0);
			next;
		}


		# Get the HDF5 dataset datatype;
        	my $HDF5type = PDL::HDF5::H5Aget_type($attrID );
		unless( $HDF5type >= 0 ){
			carp "Error Calling ".__PACKAGE__."::attrGet: Can't get HDF5 Dataset type in Attribute name '$attrName'.\n";
			carp("Can't close DataSpace in ".__PACKAGE__.":attrGet\n") if( PDL::HDF5::H5Sclose($dataspaceID) < 0);
			carp("Can't close Attribute in ".__PACKAGE__.":attrGet\n") if( PDL::HDF5::H5Aclose($attrID) < 0);
			next;
		}
		
		# Get the size so we can allocate space for it
		my $size = PDL::HDF5::H5Tget_size($HDF5type);
		unless( $size){
			carp "Error Calling ".__PACKAGE__."::attrGet: Can't get HDF5 Dataset type size in Attribute name '$attrName'.\n";
			carp("Can't close Datatype in ".__PACKAGE__.":attrGet\n") if( PDL::HDF5::H5Tclose($HDF5type) < 0);
			carp("Can't close DataSpace in ".__PACKAGE__.":attrGet\n") if( PDL::HDF5::H5Sclose($dataspaceID) < 0);
			carp("Can't close Attribute in ".__PACKAGE__.":attrGet\n") if( PDL::HDF5::H5Aclose($attrID) < 0);
			next;
		}
		
		#init attr value to the length of the type
		$attrValue = ' ' x ($size);
		
		if( PDL::HDF5::H5Aread($attrID, $HDF5type, $attrValue) < 0 ){
			carp "Error Calling ".__PACKAGE__."::attrGet: Can't read Attribute Value for Attribute name '$attrName'.\n";
			carp("Can't close Datatype in ".__PACKAGE__.":attrGet\n") if( PDL::HDF5::H5Tclose($HDF5type) < 0);
			carp("Can't close DataSpace in ".__PACKAGE__.":attrGet\n") if( PDL::HDF5::H5Sclose($dataspaceID) < 0);
			carp("Can't close Attribute in ".__PACKAGE__.":attrGet\n") if( PDL::HDF5::H5Aclose($attrID) < 0);
			next;
		}			



		# Cleanup
		carp("Can't close Datatype in ".__PACKAGE__.":attrGet\n") if( PDL::HDF5::H5Tclose($HDF5type) < 0);
		carp("Can't close DataSpace in ".__PACKAGE__.":attrGet\n") if( PDL::HDF5::H5Sclose($dataspaceID) < 0);
		carp("Can't close Attribute in ".__PACKAGE__.":attrGet\n") if( PDL::HDF5::H5Aclose($attrID) < 0);


	}
	continue{
		
		push @attrValues, $attrValue;
	}

	return @attrValues;

}

1;

