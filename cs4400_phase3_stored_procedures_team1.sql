-- CS4400: Introduction to Database Systems: Wednesday, July 12, 2023
-- Simple Airline Management System Course Project Mechanics [TEMPLATE] (v0)
-- Views, Functions & Stored Procedures

/* This is a standard preamble for most of our scripts.  The intent is to establish
a consistent environment for the database behavior. */
set global transaction isolation level serializable;
set global SQL_MODE = 'ANSI,TRADITIONAL';
set names utf8mb4;
set SQL_SAFE_UPDATES = 0;

set @thisDatabase = 'flight_tracking';
use flight_tracking;
-- -----------------------------------------------------------------------------
-- stored procedures and views
-- -----------------------------------------------------------------------------
/* Standard Procedure: If one or more of the necessary conditions for a procedure to
be executed is false, then simply have the procedure halt execution without changing
the database state. Do NOT display any error messages, etc. */

-- [_] supporting functions, views and stored procedures
-- -----------------------------------------------------------------------------
/* Helpful library capabilities to simplify the implementation of the required
views and procedures. */
-- -----------------------------------------------------------------------------
drop function if exists leg_time;
delimiter //
create function leg_time (ip_distance integer, ip_speed integer)
	returns time reads sql data
begin
	declare total_time decimal(10,2);
    declare hours, minutes integer default 0;
    set total_time = ip_distance / ip_speed;
    set hours = truncate(total_time, 0);
    set minutes = truncate((total_time - hours) * 60, 0);
    return maketime(hours, minutes, 0);
end //
delimiter ;

-- [1] add_airplane()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new airplane.  A new airplane must be sponsored
by an existing airline, and must have a unique tail number for that airline.
username.  An airplane must also have a non-zero seat capacity and speed. An airplane
might also have other factors depending on it's type, like skids or some number
of engines.  Finally, an airplane must have a new and database-wide unique location
since it will be used to carry passengers. */
-- -----------------------------------------------------------------------------
drop procedure if exists add_airplane;
delimiter //
create procedure add_airplane (in ip_airlineID varchar(50), in ip_tail_num varchar(50),
	in ip_seat_capacity integer, in ip_speed integer, in ip_locationID varchar(50),
    in ip_plane_type varchar(100), in ip_skids boolean, in ip_propellers integer,
    in ip_jet_engines integer)
sp_main: begin
##Checks requirement conditions before adding. 
##airlineID and locationID are foreign keys, so must be in airline and location tables respectively
##tail_number is a primary key attribute and cannot be null
##seat_capacity and speed must both be non-null and positive
if (ISNULL(ip_airlineID) = 0 and ip_airlineID in 
(select airlineID from airline) and ISNULL(ip_tail_num) = 0 and (ip_airlineID, ip_tail_num) not in 
(select airlineID, tail_num from airplane) 
and ISNULL(ip_locationID) = 0 and ip_locationID not in (select locationID from location)
and ISNULL(ip_seat_capacity) = 0 and ISNULL(ip_speed) = 0 and ip_seat_capacity > 0 and ip_speed > 0) THEN
insert into location values(ip_locationID);
insert into airplane values(ip_airlineID, ip_tail_num, ip_seat_capacity, 
ip_speed, ip_locationID, ip_plane_type, ip_skids,ip_propellers, ip_jet_engines);
END IF;
end //
delimiter ;

-- [2] add_airport()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new airport.  A new airport must have a unique
identifier along with a new and database-wide unique location if it will be used
to support airplane takeoffs and landings.  An airport may have a longer, more
descriptive name.  An airport must also have a city, state, and country designation. */
-- -----------------------------------------------------------------------------
drop procedure if exists add_airport;
delimiter //
create procedure add_airport (in ip_airportID char(3), in ip_airport_name varchar(200),
    in ip_city varchar(100), in ip_state varchar(100), in ip_country char(3), in ip_locationID varchar(50))
sp_main: begin
if (isnull(ip_airportID) = 0 and ip_airportID not in (select airportID from airport) 
and isnull(ip_city) = 0 and isnull(ip_state) = 0 and isnull(ip_country) = 0 
and isnull(ip_locationID) = 0 and ip_locationID not in (select locationID from location)) then
insert into location values(ip_locationID);
insert into airport values(ip_airportID, ip_airport_name, ip_city, ip_state, ip_country, ip_locationID);
end if;
end //
delimiter ;

-- [3] add_person()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new person.  A new person must reference a unique
identifier along with a database-wide unique location used to determine where the
person is currently located: either at an airport, or on an airplane, at any given
time.  A person must have a first name, and might also have a last name.

A person can hold a pilot role or a passenger role (exclusively).  As a pilot,
a person must have a tax identifier to receive pay, and an experience level.  As a
passenger, a person will have some amount of frequent flyer miles, along with a
certain amount of funds needed to purchase tickets for flights. */
-- -----------------------------------------------------------------------------
drop procedure if exists add_person;
delimiter //
create procedure add_person (in ip_personID varchar(50), in ip_first_name varchar(100),
    in ip_last_name varchar(100), in ip_locationID varchar(50), in ip_taxID varchar(50),
    in ip_experience integer, in ip_miles integer, in ip_funds integer)
sp_main: begin
if(isnull(ip_first_name) = 0 and isnull(ip_personID) = 0 and ip_personID not in (select personID from person) 
and ip_locationID in (select locationID from location)) then
insert into person values(ip_personID, ip_first_name, ip_last_name, ip_locationID);
if(isnull(ip_taxID) = 0) then #checks if the person is a pilot
insert into pilot values (ip_personID, ip_taxID, ip_experience, null);
else #if not a pilot, is a passenger
insert into passenger values (ip_personID, ip_miles, ip_funds);
end if;

end if;
end //
delimiter ;

-- [4] grant_or_revoke_pilot_license()
-- -----------------------------------------------------------------------------
/* This stored procedure inverts the status of a pilot license.  If the license
doesn't exist, it must be created; and, if it laready exists, then it must be removed. */
-- -----------------------------------------------------------------------------
drop procedure if exists grant_or_revoke_pilot_license;
delimiter //
create procedure grant_or_revoke_pilot_license (in ip_personID varchar(50), in ip_license varchar(100))
sp_main: begin
IF (isnull(ip_personID) = 0 and isnull(ip_license) = 0 and ip_personID in (select personID from pilot)) THEN
IF ((ip_personID, ip_license) in (select * from pilot_licenses))THEN
DELETE from pilot_licenses where (personID, license) = (ip_personID, ip_license);
ELSE
insert into pilot_licenses values(ip_personID, ip_license);
END IF;
END IF;
end //
delimiter ;

-- [5] offer_flight()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new flight.  The flight can be defined before
an airplane has been assigned for support, but it must have a valid route.  And
the airplane, if designated, must not be in use by another flight.  The flight
can be started at any valid location along the route except for the final stop,
and it will begin on the ground.  You must also include when the flight will
takeoff along with its cost. */
-- -----------------------------------------------------------------------------
drop procedure if exists offer_flight;
delimiter //
create procedure offer_flight (in ip_flightID varchar(50), in ip_routeID varchar(50),
    in ip_support_airline varchar(50), in ip_support_tail varchar(50), in ip_progress integer,
    in ip_airplane_status varchar(100), in ip_next_time time, in ip_cost integer)
sp_main: begin
<<<<<<< Updated upstream
=======
IF (ip_routeID not in (select routeID from route)) 
	then leave sp_main; END if; -- Valid route checking
    
IF (ip_support_tail is not null and ip_support_tail not in (select support_tail from flight where flight_id != ip_flightID))
	then leave sp_main; END if; -- Airplane not in use 
    
IF (ip_support_airline is not null and ip_support_tail not in 
 (select 1 from airplane where airlineID = ip_support_airline and tail_num = ip_support_tail))
	then leave sp_main; END if; -- Airplane conditional 
    
IF ip_progress >= (select max(sequence) from route_path where routeID = ip_routeID group by routeID)
	then leave sp_main; END if; -- checking for !final stop 

if (ip_flightID in (select flightID from flight)) then
	update flight
    set routeID = ip_routeID,
		support_airline = ip_support_airline,
        support_tail = ip_support_tail,
        progress = ip_progess,
        airplane_status = 'on_ground',
        next_time = ip_next_time,
        cost = ip_cost
    where flightID = ip_flightID; leave sp_main; END if;
    
insert into flight values (ip_flightID, ip_routeID, ip_support_airline, ip_support_tail, ip_progress, 
	ip_airplane_status, ip_next_time, ip_cost);
>>>>>>> Stashed changes

end //
delimiter ;


-- [6] flight_landing()
-- -----------------------------------------------------------------------------
/* This stored procedure updates the state for a flight landing at the next airport
along it's route.  The time for the flight should be moved one hour into the future
to allow for the flight to be checked, refueled, restocked, etc. for the next leg
of travel.  Also, the pilots of the flight should receive increased experience, and
the passengers should have their frequent flyer miles updated. */
-- -----------------------------------------------------------------------------
drop procedure if exists flight_landing;
delimiter //
create procedure flight_landing (in ip_flightID varchar(50))
sp_main: begin

DECLARE dist integer DEFAULT 0; # The distance of the leg just travelled. Used to reward FFM to passengers. 
DECLARE pos integer DEFAULT 0; #The leg sequence # most recently travelled

if(isnull(ip_flightID) = 0 and ip_flightID in (select flightID from flight) and
(select airplane_status from flight where flightID = ip_flightID) = 'in_flight') 
then #makes sure flight exists and is in the air
update flight #updates the attributes about the flight that need to be updated
set next_time = MOD(next_time + 10000, 240000), airplane_status = 'on_ground'
where flightID = ip_flightID;

update pilot
set experience = experience + 1
where commanding_flight = ip_flightID;

set pos = (select progress from flight where flightID = ip_flightID);
set dist = (select distance from leg where leg.legID in (select legID from route_path
where routeID in (select routeID from flight where flightID = ip_flightID) and sequence = pos));

update passenger
set miles = miles + dist
where personID in (select personID from person where locationID in 
(select locationID from airplane where (airlineID, tail_num) in 
(select support_airline, support_tail from flight where flightID = ip_flightID)));
end if;
end //
delimiter ;


-- [7] flight_takeoff()
-- -----------------------------------------------------------------------------
/* This stored procedure updates the state for a flight taking off from its current
airport towards the next airport along it's route.  The time for the next leg of
the flight must be calculated based on the distance and the speed of the airplane.
And we must also ensure that propeller driven planes have at least one pilot
assigned, while jets must have a minimum of two pilots. If the flight cannot take
off because of a pilot shortage, then the flight must be delayed for 30 minutes. */
-- -----------------------------------------------------------------------------
drop procedure if exists flight_takeoff;
delimiter //
create procedure flight_takeoff (in ip_flightID varchar(50))
sp_main: begin

declare legTime datetime default '00:00:00';
declare numpilots integer default 0;
# Krishnav make sure to increase progress by 1 here. I don't do it in flight_landing
<<<<<<< Updated upstream
set distance = 5;
set speedvar = (select speed from airplane where );

=======
-- set speedvar

IF (Select plane_type from airplane where tail_num = 
	(select support_tail from flight where flightID = ip_flightID) = 'prop') then set numpilots = 1;
		ELSE set numpilots = 2; END if;
IF (Select count(*) from pilot where commanding_flight = ip_flightID) != numpilots then
	update flight
    set next_time = add_time(next_time, '00:30:00')
    where flightID = ip_flightID;
    leave sp_main; END if;
    
    set legTime = leg_time((select distance from leg where legID in
		(select legID from route_path where (routeID, sequence) in
        (select routeID and progress from flight where flightID = ip_flightID))),
        (select speed from airplane where tail_num in
        (select support_tail from flight where flightID = ip_flightID)));
        
	update flight 
    set airplane_status = 'in flight',
    progress = progress + 1,
    next_time = addtime(next_time, legTime) 
    where flightID = ip_flightID;
>>>>>>> Stashed changes

end //
delimiter ;

call flight_takeoff('dl_10');

-- [8] passengers_board()
-- -----------------------------------------------------------------------------
/* This stored procedure updates the state for passengers getting on a flight at
its current airport.  The passengers must be at the same airport as the flight,
and the flight must be heading towards that passenger's desired destination.
Also, each passenger must have enough funds to cover the flight.  Finally, there
must be enough seats to accommodate all boarding passengers. */
-- -----------------------------------------------------------------------------
drop procedure if exists passengers_board;
delimiter //
create procedure passengers_board (in ip_flightID varchar(50))
sp_main: begin
DECLARE cap integer DEFAULT 0; #Total number of eligible passengers to board
DECLARE onboard integer DEFAULT 0; #The number of passengers currently on the plane
DECLARE ploc varchar(50); #the locationID of the airplane
DECLARE port varchar(50); #locationID of the airport where the airplane is currently located
DECLARE prog int default 0; #progress int value of the flight
DECLARE route varchar(50); #routeID of the flight
## Will only run if the airplane is currently on the ground
if((select airplane_status from flight where flightID = ip_flightID) = 'on_ground') then #OUTER LOOP 1

set prog = (select progress from flight where flightID = ip_flightID); #Gets progress value
set route = (select routeID from flight where flightID = ip_flightID); #Gets the routeID
set ploc = (select locationID from airplane where (airlineID, tail_num) in 
(select support_airline, support_tail from flight where flightID = ip_flightID));

# Makes sure the plane has a future destination
IF (prog < (select max(sequence) from route_path where routeID = route)) THEN
# Gets the airport the airplane currently is
IF (prog = 0) THEN 
set port = (select locationID from airport where airportID in (select departure from leg where legID in (
select legID from route_path where routeID = route and 1 = sequence)));
ELSE 
set port = (select locationID from airport where airportID in (select arrival from leg where legID in (
select legID from route_path where routeID = route and prog = sequence)));
END IF; 
set onboard = (select count(*) from person where personID in #Computes the number of people currently on the plane
(select personID from passenger) and locationID = ploc);

# Gets a list of all other flights currently at the same airport. Still have to implement. 
#select flightID from flight where flightID != ip_flightID and (select locationID from airport where airportID in 
#(select departure from leg where legID in (select legID from route_path where routeID in 
#(select routeID from flight where flightID != ip_flightID) and sequence =
 #(select progress from flight where progress = 0)))
 #union (select arrival from leg where legID in (select legID from route_path where routeID in 
#(select routeID from flight where flightID != ip_flightID) and sequence =
 #(select progress from flight where progress > 0)))
 #) = port;

# Uses above list to create a list of alternate airports offered by other flights. Still have to implement. 


# Counts the number of potential passengers. Checks if a destination offered by another flight is better (have to impelment)
set cap = (select count(*) from passenger_vacations where personID in 
(select personID from person where locationID = port) #finds all the people currently at the right airport
#checks if their destination is one of the stops
and airportID in (select airportID from airport where airportID in( 
select arrival from leg where legID in 
(select legID from route_path where routeID = route and sequence > prog))));
# Makes sure that people can actually board the plane
IF (cap + onboard <= (select seat_capacity from airplane where locationID = ploc) and cap > 0) THEN #OUTER LOOP 3


update person
set locationID = ploc
where personID in (select personID from passenger_vacations where airportID in (
select airportID from airport where airportID in(select arrival from leg where legID in 
(select legID from route_path where routeID = route and sequence > prog)))) and locationID = port;

END IF; ##OUTER LOOP 3
END IF; ##OUTER LOOP 2
END IF; ##OUTER LOOP 1
end //
delimiter ;

-- [9] passengers_disembark()
-- -----------------------------------------------------------------------------
/* This stored procedure updates the state for passengers getting off of a flight
at its current airport.  The passengers must be on that flight, and the flight must
be located at the destination airport as referenced by the ticket. */
-- -----------------------------------------------------------------------------
drop procedure if exists passengers_disembark;
delimiter //
create procedure passengers_disembark (in ip_flightID varchar(50))
sp_main: begin
declare arrivalAirport varchar(50);
if ip_flightID is null then leave sp_main; end if;
if ip_flightID not in (select flight_ID from flight) then leave sp_main; end if;


end //
delimiter ;

-- [10] assign_pilot()
-- -----------------------------------------------------------------------------
/* This stored procedure assigns a pilot as part of the flight crew for a given
flight.  The pilot being assigned must have a license for that type of airplane,
and must be at the same location as the flight.  Also, a pilot can only support
one flight (i.e. one airplane) at a time.  The pilot must be assigned to the flight
and have their location updated for the appropriate airplane. */
-- -----------------------------------------------------------------------------
drop procedure if exists assign_pilot;
delimiter //
create procedure assign_pilot (in ip_flightID varchar(50), ip_personID varchar(50))
sp_main: begin
DECLARE ploc varchar(50); # the locationID of the plane operating the flight
DECLARE ptype varchar(100); #propeller or jet
DECLARE port varchar(50);
DECLARE route varchar(50);


set ploc = (select locationID from airplane where (airlineID, tail_num) in 
(select support_airline, support_tail from flight where flightID = ip_flightID));
set ptype = (select plane_type from airplane where locationID = ploc);
set route = (select routeID from flight where flightID = ip_flightID);

if (ip_personID in (select personID from pilot) and (ip_personID, concat(ptype, 's')) in (select * from pilot_licenses)
and (select airplane_status from flight where flightID = ip_flightID) = 'on_ground') then

#Gets the current airport the plane is at
IF ((select progress from flight where flightID = ip_flightID) = 0) THEN 
set port = (select locationID from airport where airportID in (select departure from leg where legID in (
select legID from route_path where routeID = route and 1 = sequence)));
ELSE 
set port = (select locationID from airport where airportID in (select arrival from leg where legID in (
select legID from route_path where routeID = route and 
(select progress from flight where flightID = ip_flightID) = sequence)));
END IF; 


if ((select locationID from person where personID = ip_personID) = port) then
update person 
set locationID = ploc
where personID = ip_personID;
end if;
end if;
end //
delimiter ;

-- [11] recycle_crew()
-- -----------------------------------------------------------------------------
/* This stored procedure releases the assignments for a given flight crew.  The
flight must have ended, and all passengers must have disembarked. */
-- -----------------------------------------------------------------------------
drop procedure if exists recycle_crew;
delimiter //
create procedure recycle_crew (in ip_flightID varchar(50))
sp_main: begin
if ip_flightID is null then leave sp_main; end if;
#Check that the plane is empty
set onboard = (select count(*) from person where personID in #Computes the number of people currently on the plane
(select personID from passenger) and locationID = ploc);
if onboard = 0 and ((select airportID from airport where locationID = ploc) in (end)) then
#Remove Pilots
delete commanding_flight from pilot where commanding_flight like ip_flightID;
end if;
end //
delimiter ;

-- [12] retire_flight()
-- -----------------------------------------------------------------------------
/* This stored procedure removes a flight that has ended from the system.  The
flight must be on the ground, and either be at the start its route, or at the
end of its route.  And the flight must be empty - no pilots or passengers. */
-- -----------------------------------------------------------------------------
drop procedure if exists retire_flight;
delimiter //
create procedure retire_flight (in ip_flightID varchar(50))
sp_main: begin
DECLARE start varchar(50); #The airportID of the start airport
DECLARE end varchar(50); #The airportID of the end airport
DECLARE ploc varchar(50); #The locationID of the airplane
DECLARE port varchar(50); #the locationID of the airport currently at
DECLARE route varchar(50); #The routeID of the flight
DECLARE numLegs int default 0;

## MAKES SURE FLIGHT IS GROUNDED BEFORE RUNNING ANYTHING
if((select airplane_status from flight where flightID = ip_flightID) = 'on_ground') THEN #OUTER LOOP 1
#Gets the plane and plane location values stored
set ploc = (select locationID from airplane where (airlineID, tail_num) in 
(select support_airline, support_tail from flight where flightID = ip_flightID));


##MAKES SURE AIRPLANE IS EMPTY BEFORE RUNNING ANYTHING
IF ((select count(*) from person where locationID = ploc) = 0)
THEN   #OUTER LOOP 2
set route = (select routeID from flight where flightID = ip_flightID);
set numLegs = (select count(*) from route_path where routeID = route);
set start = (select airportID from airport where airportID in (
select departure from leg where legID in(
select legID from route_path where routeID = route and sequence = 1 #Gets the first leg of the sequence
)));

set end = (select airportID from airport where airportID in (
select arrival from leg where legID in(
select legID from route_path where routeID = route and sequence = numLegs #Gets the last leg of the sequence
)));

#Gets the locationID for the current airport
IF ((select progress from flight where flightID = ip_flightID) = 0) THEN 
set port = (select locationID from airport where airportID in (select departure from leg where legID in (
select legID from route_path where routeID = route and 1 = sequence)));
ELSE 
set port = (select locationID from airport where airportID in (select arrival from leg where legID in (
select legID from route_path where routeID = route and 
(select progress from flight where flightID = ip_flightID) = sequence)));
END IF; 


# Makes sure the airport is at either the start or the end of the route
IF ((select airportID from airport where locationID = port) in (start, end)) THEN #OUTER LOOP 3
delete from flight where flightID = ip_flightID; #Deletes the flight
END IF; ##OUTER LOOP 3
END IF; ##OUTER LOOP 2
END IF; ##OUTER LOOP 1
end //
delimiter ;

-- [13] simulation_cycle()
-- -----------------------------------------------------------------------------
/* This stored procedure executes the next step in the simulation cycle.  The flight
with the smallest next time in chronological order must be identified and selected.
If multiple flights have the same time, then flights that are landing should be
preferred over flights that are taking off.  Similarly, flights with the lowest
identifier in alphabetical order should also be preferred.

If an airplane is in flight and waiting to land, then the flight should be allowed
to land, passengers allowed to disembark, and the time advanced by one hour until
the next takeoff to allow for preparations.

If an airplane is on the ground and waiting to takeoff, then the passengers should
be allowed to board, and the time should be advanced to represent when the airplane
will land at its next location based on the leg distance and airplane speed.

If an airplane is on the ground and has reached the end of its route, then the
flight crew should be recycled to allow rest, and the flight itself should be
retired from the system. */
-- -----------------------------------------------------------------------------
drop procedure if exists simulation_cycle;
delimiter //
create procedure simulation_cycle ()
sp_main: begin

	DECLARE currentFlightID VARCHAR(50);
  DECLARE currentLegID VARCHAR(50);
  DECLARE currentProgress INT;
  DECLARE nextLegID VARCHAR(50);
  DECLARE nextTime TIME;
  DECLARE isLandingFlight BOOLEAN;
  
  -- Find the next flight to simulate (the one with the smallest next_time)
  SELECT flightID, progress, next_time, legID, 
         IF(airplane_status = 'in_flight', 1, 0) AS is_landing_flight
  INTO currentFlightID, currentProgress, nextTime, currentLegID, isLandingFlight
  FROM flight
  ORDER BY nextTime, isLandingFlight DESC, flightID
  LIMIT 1;
  
  -- Check if there's a flight to simulate
  WHILE currentFlightID IS NOT NULL DO
    -- If an airplane is in_flight and waiting to land
    IF currentProgress > 0 AND currentLegID IS NOT NULL AND currentTime < nextTime THEN
      SET currentTime = nextTime;
    END IF;
    
    -- If an airplane is in_flight and ready to reach the destination
    IF currentProgress > 0 AND currentLegID IS NOT NULL AND currentTime >= nextTime THEN
      UPDATE flight
      SET progress = currentProgress + 1,
          next_time = NULL
      WHERE flightID = currentFlightID;
    END IF;
    
    -- If an airplane is on_ground and waiting to takeoff
    IF currentProgress = 0 AND currentLegID IS NULL AND currentTime < nextTime THEN
      SET currentTime = nextTime;
    END IF;
    
    -- If an airplane is on_ground and ready to takeoff
    IF currentProgress = 0 AND currentLegID IS NULL AND currentTime >= nextTime THEN
      -- Get the next leg in the route, if any
      SELECT legID
      INTO nextLegID
      FROM route_path
      WHERE routeID = (SELECT routeID FROM flight WHERE flightID = currentFlightID)
      AND sequence = 1;
      
      IF nextLegID IS NOT NULL THEN
        -- Calculate the time needed for the next leg based on leg distance and airplane speed
        SELECT leg_distance / airplane_speed INTO @time_needed
        FROM leg
        JOIN airplane ON leg.airlineID = airplane.airlineID
        WHERE legID = nextLegID AND airplane.tail_num = (SELECT support_tail FROM flight WHERE flightID = currentFlightID);
        
        SET nextTime = ADDTIME(currentTime, @time_needed);
        UPDATE flight
        SET progress = 1,
            next_time = nextTime
        WHERE flightID = currentFlightID;
      ELSE
        -- If an airplane is on_ground and has reached the end of its route
        -- Update airplane crew and retire the flight
        UPDATE flight
        SET progress = -1, -- Marking as retired
            next_time = NULL
        WHERE flightID = currentFlightID;
        
        UPDATE airplane
        SET locationID = NULL -- Removing the airplane from the system
        WHERE airlineID = (SELECT support_airline FROM flight WHERE flightID = currentFlightID)
        AND tail_num = (SELECT support_tail FROM flight WHERE flightID = currentFlightID);
      END IF;
    END IF;
    
    -- Find the next flight to simulate (the one with the smallest next_time)
    SELECT flightID, progress, next_time, legID, 
           IF(airplane_status = 'in_flight', 1, 0) AS is_landing_flight
    INTO currentFlightID, currentProgress, nextTime, currentLegID, isLandingFlight
    FROM flight
    WHERE progress >= 0 -- Exclude retired flights
    ORDER BY nextTime, isLandingFlight DESC, flightID
    LIMIT 1;
  END WHILE;
end //
delimiter ;

-- [14] flights_in_the_air()
-- -----------------------------------------------------------------------------
/* This view describes where flights that are currently airborne are located. */
-- -----------------------------------------------------------------------------
create or replace view flights_in_the_air (departing_from, arriving_at, num_flights,
	flight_list, earliest_arrival, latest_arrival, airplane_list) as
select A.airportID, B.airportID, count(*), flightID, min(next_time), max(next_time), tail_num
from airport as A, airport as B, flight, airplane
where airplane_status = 'in_flight' and tail_num = support_tail
and A.airportID = (select departure from leg where legID in 
(select legID from route_path where (routeID in (select routeID from flight where airplane_status = 'in_flight')
and sequence = progress))) and B.airportID = (select arrival from leg where legID in 
(select legID from route_path where (routeID in (select routeID from flight where airplane_status = 'in_flight')
and sequence = progress))); 
-- [15] flights_on_the_ground()
-- -----------------------------------------------------------------------------
/* This view describes where flights that are currently on the ground are located. */
-- -----------------------------------------------------------------------------
create or replace view flights_on_the_ground (departing_from, num_flights,
	flight_list, earliest_arrival, latest_arrival, airplane_list) as 
select '_', '_', '_', '_', '_', '_';

-- [16] people_in_the_air()
-- -----------------------------------------------------------------------------
/* This view describes where people who are currently airborne are located. */
-- -----------------------------------------------------------------------------
create or replace view people_in_the_air (departing_from, arriving_at, num_airplanes,
	airplane_list, flight_list, earliest_arrival, latest_arrival, num_pilots,
	num_passengers, joint_pilots_passengers, person_list) as
select '_', '_', '_', '_', '_', '_', '_', '_', '_', '_', '_';

-- [17] people_on_the_ground()
-- -----------------------------------------------------------------------------
/* This view describes where people who are currently on the ground are located. */
-- -----------------------------------------------------------------------------
create or replace view people_on_the_ground (departing_from, airport, airport_name,
	city, state, country, num_pilots, num_passengers, joint_pilots_passengers, person_list) as
select '_', '_', '_', '_', '_', '_', '_', '_', '_', '_';

-- [18] route_summary()
-- -----------------------------------------------------------------------------
/* This view describes how the routes are being utilized by different flights. */
-- -----------------------------------------------------------------------------
create or replace view route_summary (route, num_legs, leg_sequence, route_length,
	num_flights, flight_list, airport_sequence) as
select '_', '_', '_', '_', '_', '_', '_';

-- [19] alternative_airports()
-- -----------------------------------------------------------------------------
/* This view displays airports that share the same city and state. */
-- -----------------------------------------------------------------------------
create or replace view alternative_airports (city, state, country, num_airports,
	airport_code_list, airport_name_list) as
select '_', '_', '_', '_', '_', '_';
