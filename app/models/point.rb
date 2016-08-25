class Point
	attr_accessor	:longitude, :latitude

	#a to_hash instance method that will produce a GeoJSON Point hash
	def to_hash
		{type: "Point", coordinates: [@longitude, @latitude]}
	end

	# sets the attributes from a hash with keys lat and lng or GeoJSON Point format.
  def initialize params
    is_geo_json = params[:type] == "Point"
    if is_geo_json
      @longitude, @latitude = params[:coordinates]
    else
      @longitude, @latitude = params[:lng], params[:lat]
    end
  end
  
end
