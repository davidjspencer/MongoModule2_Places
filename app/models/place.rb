class Place 
	attr_accessor :id, :formatted_address, :location, :address_components

	def initialize params
		@id 								= params[:_id].to_s
		@formatted_address 	= params[:formatted_address]
		@address_components = params[:address_components].map {|ac| AddressComponent.new(ac)} if params[:address_components]
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

  
end