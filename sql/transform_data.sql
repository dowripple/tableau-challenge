/*
Run this script after the import_data python notebook has been run.  This will create the warehouse tables that will be used
	to create cleaner, aggregated files for Tableau to use.  Using 2 years of CitiBike data!
*/	
-- citi station table
  CREATE TABLE citi_station
  		(station_id int not null,
		 station_name varchar,
		 station_latitude float not null,
		 station_longitude float,
		 first_used_datetime timestamp,
		 last_used_datetime timestamp,
		 PRIMARY KEY(station_id, station_latitude));

-- load the stations from the staging table
  INSERT INTO citi_station
  		(station_id,
		 station_name,
		 station_latitude,
		 station_longitude,
		 first_used_datetime,
		 last_used_datetime)
  SELECT cs.start_station_id,
  		 cs.start_station_name,
		 cs.start_station_latitude,
		 cs.start_station_longitude,
		 MIN(cs.starttime),
		 MAX(cs.starttime)
    FROM citi_staging cs LEFT OUTER JOIN citi_station s
	  ON cs.start_station_id = s.station_id
   WHERE s.station_id IS NULL
GROUP BY cs.start_station_id,
  		 cs.start_station_name,
		 cs.start_station_latitude,
		 cs.start_station_longitude;

  -- to make sure we don't miss any stations...
  INSERT INTO citi_station
  		(station_id,
		 station_name,
		 station_latitude,
		 station_longitude,
		 first_used_datetime,
		 last_used_datetime)  
  SELECT cs.end_station_id,
  		 cs.end_station_name,
		 cs.end_station_latitude,
		 cs.end_station_longitude,
		 MIN(cs.starttime),
		 MAX(cs.starttime)
    FROM citi_staging cs LEFT OUTER JOIN citi_station s
	  ON cs.end_station_id = s.station_id
   WHERE s.station_id IS NULL
GROUP BY cs.end_station_id,
  		 cs.end_station_name,
		 cs.end_station_latitude,
		 cs.end_station_longitude;

-- table to store the bike data
CREATE TABLE citi_bike
       (bikeid bigint,
	    first_used_datetime timestamp,
	    last_used_datetime timestamp,
	    number_of_trips int);

-- populate bike table, using a CTE
    WITH BikeList
	  AS
	   (
		  SELECT cs.bikeid,
		   		 MIN(starttime) AS First_Used_DateTime,
		   	     MAX(starttime) AS Last_Used_DateTime,
		   	     COUNT(*) AS Number_Of_Trips
			FROM citi_staging cs 
		GROUP BY cs.bikeid
       )
  INSERT INTO citi_bike	   
  SELECT *
    FROM BikeList;

-- main fact table for analysis
  CREATE TABLE citi_trips
  		(start_station_id bigint not null,
		 end_station_id bigint not null,
		 bikeid bigint not null,
		 starttime timestamp not null,
		 stoptime timestamp not null,
		 tripduration integer,
		 usertype varchar,
		 birth_year int,
		 gender int,
		 PRIMARY KEY(start_station_id, bikeid, starttime)
		);

-- load fact table from staging
  INSERT INTO citi_trips
  SELECT start_station_id,
  		 end_station_id,
		 bikeid,
		 starttime,
		 stoptime,
		 tripduration,
		 usertype,
		 birth_year,
		 gender
    FROM citi_staging
GROUP BY start_station_id,
  		 end_station_id,
		 bikeid,
		 starttime,
		 stoptime,
		 tripduration,
		 usertype,
		 birth_year,
		 gender;

/*
  This is the main view that will be used by tableau.  The data is collapsed by aggregating to the month/year, age_group, trip_duration_group and station start/end (or the route).  
  This will keep the file size somewhat down, but still yield some good info.
*/
  CREATE VIEW citi_trips_by_station_season_age_duration
  AS

  SELECT start_station_id,
  		 CASE WHEN EXTRACT(MONTH FROM starttime) BETWEEN 4 AND 10 THEN 'Summer'
			ELSE 'Winter'
		 END AS trip_season,
		 CASE 
		  	WHEN EXTRACT(YEAR FROM starttime)-birth_year < 18 THEN '< 18 yrs'
			WHEN EXTRACT(YEAR FROM starttime)-birth_year BETWEEN 18 AND 30 THEN '18-30 yrs'
			WHEN EXTRACT(YEAR FROM starttime)-birth_year BETWEEN 30 AND 40 THEN '30-40 yrs'
			WHEN EXTRACT(YEAR FROM starttime)-birth_year BETWEEN 40 AND 50 THEN '40-50 yrs'
			WHEN EXTRACT(YEAR FROM starttime)-birth_year BETWEEN 50 AND 60 THEN '50-60 yrs'
			ELSE 'Over 60 yrs'
		END AS age_group,
    	 CASE 
		 	WHEN tripduration < 300 THEN '< 5 minutes'
			WHEN tripduration < 900 THEN '5 to 15 minutes'
			WHEN tripduration < 1800 THEN '15 to 30 minutes'
			WHEN tripduration < 3600 THEN '30 minutes to 1 hour'
			WHEN tripduration < 7200 THEN '1 to 2 hours'
			WHEN tripduration < 18000 THEN '2 to 5 hours'
			WHEN tripduration < 43200 THEN '5 to 12 hours'
			ELSE 'overnight!'
		 END AS duration_category,
		 EXTRACT(YEAR FROM starttime) AS trip_year,
		 EXTRACT(MONTH FROM starttime) AS trip_month,
		 COUNT(*) AS number_of_trips
    FROM citi_trips
GROUP BY start_station_id,
  		 CASE WHEN EXTRACT(MONTH FROM starttime) BETWEEN 4 AND 10 THEN 'Summer'
			ELSE 'Winter'
		 END,
		 CASE 
		  	WHEN EXTRACT(YEAR FROM starttime)-birth_year < 18 THEN '< 18 yrs'
			WHEN EXTRACT(YEAR FROM starttime)-birth_year BETWEEN 18 AND 30 THEN '18-30 yrs'
			WHEN EXTRACT(YEAR FROM starttime)-birth_year BETWEEN 30 AND 40 THEN '30-40 yrs'
			WHEN EXTRACT(YEAR FROM starttime)-birth_year BETWEEN 40 AND 50 THEN '40-50 yrs'
			WHEN EXTRACT(YEAR FROM starttime)-birth_year BETWEEN 50 AND 60 THEN '50-60 yrs'
			ELSE 'Over 60 yrs'
		END,
    	 CASE 
		 	WHEN tripduration < 300 THEN '< 5 minutes'
			WHEN tripduration < 900 THEN '5 to 15 minutes'
			WHEN tripduration < 1800 THEN '15 to 30 minutes'
			WHEN tripduration < 3600 THEN '30 minutes to 1 hour'
			WHEN tripduration < 7200 THEN '1 to 2 hours'
			WHEN tripduration < 18000 THEN '2 to 5 hours'
			WHEN tripduration < 43200 THEN '5 to 12 hours'
			ELSE 'overnight!'
		 END,
		 EXTRACT(YEAR FROM starttime),
		 EXTRACT(MONTH FROM starttime);

/*
This view will count the # of trips by bike, with aggregations of:
	month
	season
	year
	trip duration

*/
CREATE VIEW bike_trips
AS

  SELECT bikeid,
  		 CASE WHEN EXTRACT(MONTH FROM starttime) BETWEEN 4 AND 10 THEN 'Summer'
			ELSE 'Winter'
		 END AS trip_season,
    	 CASE 
		 	WHEN tripduration < 300 THEN '< 5 minutes'
			WHEN tripduration < 900 THEN '5 to 15 minutes'
			WHEN tripduration < 1800 THEN '15 to 30 minutes'
			WHEN tripduration < 3600 THEN '30 minutes to 1 hour'
			WHEN tripduration < 7200 THEN '1 to 2 hours'
			WHEN tripduration < 18000 THEN '2 to 5 hours'
			WHEN tripduration < 43200 THEN '5 to 12 hours'
			ELSE 'overnight!'
		 END AS duration_category,
		 EXTRACT(YEAR FROM starttime) AS trip_year,
		 EXTRACT(MONTH FROM starttime) AS trip_month,
		 COUNT(*) AS number_of_trips
    FROM citi_trips
GROUP BY bikeid,
  		 CASE WHEN EXTRACT(MONTH FROM starttime) BETWEEN 4 AND 10 THEN 'Summer'
			ELSE 'Winter'
		 END,
    	 CASE 
		 	WHEN tripduration < 300 THEN '< 5 minutes'
			WHEN tripduration < 900 THEN '5 to 15 minutes'
			WHEN tripduration < 1800 THEN '15 to 30 minutes'
			WHEN tripduration < 3600 THEN '30 minutes to 1 hour'
			WHEN tripduration < 7200 THEN '1 to 2 hours'
			WHEN tripduration < 18000 THEN '2 to 5 hours'
			WHEN tripduration < 43200 THEN '5 to 12 hours'
			ELSE 'overnight!'
		 END,
		 EXTRACT(YEAR FROM starttime),
		 EXTRACT(MONTH FROM starttime);		 
