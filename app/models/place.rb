class Place 
	attr_accessor :id, :formatted_address, :location, :address_components

	def initialize params
		@id 								= params[:_id].to_s
		@formatted_address 	= params[:formatted_address]
		@address_components = params[:address_components].map {|a| AddressComponent.new(a)} if params[:address_components]
    @location 					= Point.new(params[:geometry][:geolocation])
	end

	def self.mongo_client
		Mongoid::Clients.default
	end
	
	def self.collection
		self.mongo_client['places']
	end

  def self.load_all(file_path) #accept a parameter of type IO with a JSON string of data
  	file=File.read(file_path)  #read the data from that input parameter
    hash = JSON.parse(file)		 #parse the JSON string into an array of Ruby hash objects representing places
    self.collection.insert_many(hash) #insert the array of hash objects into the places collection
  end


# Implement a class method called find_by_short_name that will 
# return a Mongo::Collection::View with a query to match documents 
# with a matching short_name within address_components. This method must:

# 		accept a String input parameter
# 		find all documents in the places collection with a matching address_components.short_name
# 		return the Mongo::Collection::View result
  def self.find_by_short_name short_name
  	collection.find(:"address_components.short_name" => short_name)
  end
  

# Implement a helper class method called to_places that will 
# accept a Mongo::Collection::View and return a collection 
# of Place instances. This method must:

# 			accept an input parameter
# 			iterate over contents of that input parameter
# 			change each document hash to a Place instance (Hint: Place.new)
# 			return a collection of results containing Place objects
  def self.to_places(places)
  	places.map { |p| Place.new(p) }
  end


# Implement a class method called find that will return an instance of Place 
# for a supplied id. This method must:

# 		accept a single String id as an argument
# 		convert the id to BSON::ObjectId form (Hint: BSON::ObjectId.from_string(s))
# 		find the document that matches the id
#     return an instance of Place initialized with the document if found
  def self.find id
  	b_id = { _id:BSON::ObjectId.from_string(id) }
  	place = collection.find(b_id).first
  	if !place.nil? 
  		return Place.new(place) 
  	end
	end


# Implement a class method called all that will return an instance of all 
# documents as Place instances. This method must:

# 	accept two optional arguments: offset and limit in that order. 
	 #offset must default to no offset and limit must default to no limit
# 	locate all documents within the places collection within paging limits
# 	return each document as in instance of a Place within a collection
	def self.all(offset=0, limit=nil)
		places = collection.find({}).skip(offset)
		places = places.limit(limit) if !limit.nil?
		places = to_places(places)
	end


# Implement an instance method called destroy in the Place model class 
# that will delete the document associated with its assigned id. 
#This method must:
# => accept no arguments
# => delete the document from the places collection that has an 
#    _id associated with the id of the instance.
	def destroy
		b_id = { _id:BSON::ObjectId.from_string(id) }
		self.class.collection.find(b_id).delete_one
	end


# Create a Place class method called get_address_components 
# that returns a collection of hash documents with 
# address_components and their associated _id, formatted_address 
# and location properties. Your method must:

# 		accept optional sort, offset, and limit parameters
# 		extract all address_component elements within each document 
				#contained within the collection (Hint: $unwind)
# 		return only the _id, address_components, formatted_address, 
				#and geometry.geolocation elements (Hint: $project)
# 		apply a provided sort or no sort if not provided (Hint: $sort and q.pipeline method)
# 		apply a provided offset or no offset if not provided (Hint: $skip and q.pipeline method)
# 		apply a provided limit or no limit if not provided (Hint: $limit and q.pipeline method)
# 		return the result of the above query (Hint: collection.find.aggregate(...))

	def self.get_address_components(sort=nil, offset=0, limit=nil)
		docs = []
		docs <<	{ :$unwind => "$address_components" }
		docs << { :$project => { address_components: "$address_components",
          								 formatted_address: "$formatted_address",
          								 "geometry.geolocation": "$geometry.geolocation" }}
		
		docs << { :$sort=>sort } 					if !sort.nil?
		docs << { :$skip=>offset } 				if offset !=0
		docs << { :$limit=>limit }					if !limit.nil?
		collection.find.aggregate(docs)
	end


# Create a Place class method called get_country_names that returns a 
# distinct collection of country names (long_names). Your method must:

# 		accept no arguments
# 		create separate documents for address_components.long_name and 
#							address_components.types (Hint: $project and $unwind)
# 		select only those documents that have a address_components.types 
#							element equal to "country" (Hint: $match)
# 		form a distinct list based on address_components.long_name (Hint: $group)
# 		return a simple collection of just the country names (long_name). 
#   	  			You will have to use application code to do this last step. (Hint: .to_a.map {|h| h[:_id]})

	def self.get_country_names
		self.collection.find.aggregate([ { :$unwind=>"$address_components" },
      															 { :$project=>{ long_name: "$address_components.long_name", types: "$address_components.types" }},
      															 { :$unwind=>"$types" },
      															 { :$match=>{ types: "country" }},
      															 { :$group=>{ _id: "$long_name" }} ]).to_a.map {|doc| doc[:_id]}
	end



# Create a Place class method called find_ids_by_country_code that will return 
# the id of each document in the places collection that has an 
# address_component.short_name of type country and matches the provided parameter. 
# This method must:

# 				accept a single country_code parameter
# 				locate each address_component with a matching short_name 
#								being tagged with the country type (Hint: $match)
# 				return only the _id property from the database (Hint: $project)
# 				return only a collection of _ids converted to Strings (Hint: .map {|doc| doc[:_id].to_s})

	def self.find_ids_by_country_code(country_code)
		self.collection.find.aggregate([ { :$match=>{ 'address_components.short_name': "#{country_code}" }},
																		 { :$project=>{ _id:1 }} ]).map {|doc| doc[:_id].to_s}
	end


# Create two Place class methods, one called create_indexes and the other remove_indexes. 
# These will be used to create and remove a 2dsphere index to your collection for 
# the geometry.geolocation property. 
# These methods must exhibit the following behavior:

# 	create_indexes must make sure the 2dsphere index is in place for 
# 				the geometry.geolocation property (Hint: Mongo::Index::GEO2DSPHERE)

	def self.create_indexes
		collection.indexes.create_one({ :'geometry.geolocation' => Mongo::Index::GEO2DSPHERE})
	end

# 	remove_indexes must make sure the 2dsphere index is removed from 
# 				the collection (Hint:     Place.collection.indexes.map {|r| r[:name] } 
					#displays the names of each index)

	def self.remove_indexes
		
		collection.indexes.drop_one('geometry.geolocation_2dsphere')
	end



# Create a Place class method called near that returns places that 
# are closest to provided Point. This method must:

# 		accept an input parameter of type Point (created earlier) and 
# 				an optional max_meters that defaults to no maximum
# 		performs a $near search using the 2dsphere index placed on 
# 				the geometry.geolocation property and the GeoJSON output 
# 				of point.to_hash (created earlier). (Hint: Query a 2dsphere Index)
# 		limits the maximum distance -- if provided -- in determining matches (Hint: $maxDistance)
# 		returns the resulting view (i.e., the result of find())

	def self.near(point, max_meters=nil)
		near = { "$geometry": point.to_hash }  #to_hash == {:type=>"Point", :coordinates=>[@longitude, @latitude]}
		near[:$maxDistance] = max_meters unless max_meters.nil?
		self.collection.find(:"geometry.geolocation"=>{:$near=>near})
	end

	# Create an instance method (also) called near that wraps the 
	# class method you just finished. This method must:

	# 		accept an optional parameter that sets a maximum distance threshold in meters
	# 		locate all places within the specified maximum distance threshold
	# 		return the collection of matching documents as a collection of 
	# 				Place instances using the to_places class method added earlier.

	def near(max_meters=nil)
		self.class.to_places(self.class.near(@location, max_meters))
	end


end





