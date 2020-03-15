/*
This script creates the staging table needed for the import_data python notebook to work.
	Run this script before the Python notebook.

*/
CREATE TABLE public.citi_staging
(
    tripduration int,
    starttime timestamp ,
    stoptime timestamp ,
    start_station_id bigint,
    start_station_name varchar,
    start_station_latitude float,
    start_station_longitude float,
    end_station_id bigint,
    end_station_name varchar,
    end_station_latitude float,
    end_station_longitude float,
    bikeid bigint,
    usertype varchar,
    birth_year int,
    gender int
)
TABLESPACE pg_default;

ALTER TABLE public.citi_staging
    OWNER to postgres;

		 
