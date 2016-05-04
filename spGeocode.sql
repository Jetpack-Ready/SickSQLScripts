USE [Salesforce_BI]
GO

/****** Object:  StoredProcedure [dbo].[spGeocode]    Script Date: 5/2/2016 11:12:56 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


/*

	Jake Shivers
	3/28/2016

	If a new lead comes in with a postal code, but not a state, this will update the state record.


*/


create procedure [dbo].[spGeocode]
	@Status varchar(40) = null output
	,@Address varchar(80) = null output
	,@City varchar(40) = null output
	,@State varchar(40) = null output
	,@Country varchar(40) = null output
	,@PostalCode varchar(20) = null output
	,@County varchar(40) = null output
	,@GPSLatitude numeric(9,6) = null output
	,@GPSLongitude numeric(9,6) = null output
	,@GPSLocationType varchar(40) = null output
	,@MapURL varchar(1024) = null output
as
begin
	SET NOCOUNT ON

	DECLARE @URL varchar(MAX)
	SET @URL = 'https://maps.google.com/maps/api/geocode/xml?sensor=false&address='
		+ CASE WHEN @Address IS NOT NULL THEN @Address ELSE '' END
		+ CASE WHEN @City IS NOT NULL THEN ', ' + @City ELSE '' END
		+ CASE WHEN @State IS NOT NULL THEN ', ' + @State ELSE '' END
		+ CASE WHEN @PostalCode IS NOT NULL THEN ', ' + @PostalCode ELSE '' END
		+ CASE WHEN @Country IS NOT NULL THEN ', ' + @Country ELSE '' end
		--+ '&key=AIzaSyAoe-N8kPjzf7sXKi5w1flqWL4Hp89zKX8'
	SET @URL = REPLACE(@URL, ' ', '+')
	
	--declare @Status varchar(40) = NULL --OUTPUT

	DECLARE @Response varchar(8000)
	DECLARE @XML xml
	DECLARE @Obj int 
	DECLARE @Result int 
	DECLARE @HTTPStatus int 
	DECLARE @ErrorMsg varchar(MAX)

	EXEC @Result = sp_OACreate 'MSXML2.ServerXMLHttp', @Obj OUT 

	begin try
		EXEC @Result = sp_OAMethod @Obj, 'open', NULL, 'GET', @URL, false
		EXEC @Result = sp_OAMethod @Obj, 'setRequestHeader', NULL, 'Content-Type', 'application/x-www-form-urlencoded'
		EXEC @Result = sp_OAMethod @Obj, send, NULL, ''
		EXEC @Result = sp_OAGetProperty @Obj, 'status', @HTTPStatus OUT 
		exec @Result = sp_OAGetProperty @Obj, 'responseXML.xml', @Response out 
	end try
	begin catch
		set @ErrorMsg = error_message()
	end catch

	exec @Result = sp_OADestroy @Obj

	if (@ErrorMsg is not null) or (@HTTPStatus <> 200)
	begin
		set @ErrorMsg = 'Error in spGeocode: ' + isnull(@ErrorMsg, 'HTTP result is: ' + cast(@HTTPStatus as varchar(10)))
		raiserror(@ErrorMsg, 16, 1, @HTTPStatus)
		return 
	end
	
	set @XML = cast(@Response as xml)
	
	set @Status = @XML.value('(/GeocodeResponse/status) [1]', 'varchar(40)')
	set @GPSLatitude = @XML.value('(/GeocodeResponse/result/geometry/location/lat) [1]', 'numeric(9,6)')
	set @GPSLongitude = @XML.value('(/GeocodeResponse/result/geometry/location/lng) [1]', 'numeric(9,6)')
	set @GPSLocationType = @XML.value('(GeocodeResponse/result/geometry/location_type) [1]', 'varchar(40)')
	
	set @City = @XML.value('(/GeocodeResponse/result/address_component[type="locality"]/long_name) [1]', 'varchar(40)') 
	set @State = @XML.value('(/GeocodeResponse/result/address_component[type="administrative_area_level_1"]/short_name) [1]', 'varchar(40)') 
	set @PostalCode = @XML.value('(/GeocodeResponse/result/address_component[type="postal_code"]/long_name) [1]', 'varchar(20)') 
	set @Country = @XML.value('(/GeocodeResponse/result/address_component[type="country"]/short_name) [1]', 'varchar(40)') 
	set @County = @XML.value('(/GeocodeResponse/result/address_component[type="administrative_area_level_2"]/short_name) [1]', 'varchar(40)') 
	
	set @Address = 
		isnull(@XML.value('(/GeocodeResponse/result/address_component[type="street_number"]/long_name) [1]', 'varchar(40)'), '???') + ' ' +
		isnull(@XML.value('(/GeocodeResponse/result/address_component[type="route"]/long_name) [1]', 'varchar(40)'), '???') 
	set @MapURL = 'http://maps.google.com/maps?f=q&hl=en&q=' + cast(@GPSLatitude as varchar(20)) + '+' + cast(@GPSLongitude as varchar(20))

	select
		@Status as Status
		,@GPSLatitude as GPSLatitude
		,@GPSLongitude as GPSLongitude
		,@GPSLocationType as GPSLocationType
		,@City as City
		,@State as [State]
		,@PostalCode as PostalCode
		,@Address as [Address]
		,@County as County
		,@Country as Country
		,@MapURL as MapURL
		,@XML as XMLResults

end
go


