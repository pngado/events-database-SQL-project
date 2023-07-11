/*

Skills used: Correlated subquery, Pattern matching, Complex joins, NVL function, SQL View, Stored Procedure, Stored Function, Trigger

*/


-- List the names of all the client companies and the events that have been run for them or are currently booked

SELECT DISTINCT C.clientCompanyName, E.eventName
FROM Clients C, Events E
WHERE C.clientID = E.clientID;

-- List all the venues and the events they will be hired for in June 2018

SELECT DISTINCT V.venueName, E.eventName
FROM Venues V, EventVenues EV, Events E
WHERE V.venueID = EV.venueID(+) 
AND EV.eventID = E.eventID(+) 
AND TO_CHAR(bookingDate, 'MON-YYYY') = 'JUN-2018';

-- List those venues that have never been booked

SELECT V.venueName
FROM Venues V
WHERE V.venueID NOT IN (SELECT venueID
                        FROM EventVenues);

-- Find the least expensive venue that will accommodate 120 people

SELECT V.venueName, V.costPerDay
FROM Venues V
WHERE V.costPerDay = (SELECT MIN(costPerDay)
                      FROM Venues
                      WHERE venueCapacity >= 120);

-- Find businesses that have sponsored more than three events

SELECT S.businessID, S.businessName
FROM Sponsors S, EventSponsors ES
WHERE S.businessID = ES.businessID
GROUP BY (S.businessID, S.businessName)
HAVING COUNT(S.businessID) > 3;

-- Retrieve the promoter that has sold the highest number of tickets for each event 

SELECT E.eventID, E.eventName, P.promoterID, P.promoterBusinessName
FROM Events E, Tickets T, Promoters P
WHERE E.eventID = T.eventID AND T.promoterID = P.PromoterID
GROUP BY (E.eventID, E.eventName, P.promoterID, P.promoterBusinessName)
HAVING COUNT(P.promoterID) = (SELECT MAX(COUNT(T1.promoterID))
                              FROM Tickets T1
                              WHERE T1.eventID = E.eventID
                              GROUP BY (T1.promoterID));


-- List all the event clients whose first name or last name starts with 'P'

SELECT clientContactFirstName, clientContactLastName
FROM Clients
WHERE UPPER(clientContactFirstName) LIKE 'P%' 
OR UPPER(clientContactLastName) LIKE 'P%';


-- Create a view EventCost that contains for each event the eventID, eventName and the total cost of running the event

CREATE OR REPLACE VIEW EventCost AS
SELECT R1.eventID, E.eventName, totalCostVenue + NVL(totalCostEquip,0) + NVL(totalCostCatSec,0) AS totalCost
FROM Events E,
(SELECT EV.eventID, SUM(V.costPerDay) AS totalCostVenue
FROM EventVenues EV, Venues V
WHERE EV.venueID = V.venueID
GROUP BY EV.eventID) R1,
(SELECT EE.eventID, SUM (EE.unitPrice * EE.quantity * EE.noOfDays)
AS totalCostEquip
FROM EventEquipments EE
GROUP BY eventID) R2,
(SELECT ES.eventID, SUM (ES.eventCharge) AS totalCostCatSec
FROM EventServices ES
GROUP BY ES.eventID) R3
WHERE E.eventID = R1.eventID(+) AND R1.eventID = R2.eventID(+) 
AND R1.eventID = R3.eventID(+);

-- Create a stored procedure that receives a date as input, and displays the event(s) that take place on that day and their start times

CREATE OR REPLACE PROCEDURE eventTimesOnDay (dateRequired DATE)
AS
CURSOR cEventDetails IS
SELECT E.eventName, EV.bookingDate
FROM Events E, EventVenues EV
WHERE TO_CHAR(EV.bookingDate, 'DD-MON-YYYY') = TO_CHAR(dateRequired, 'DD-MON-YYYY')
AND EV.eventID = E.eventID;

BEGIN

DBMS_OUTPUT.PUT_LINE('Events on ' || TO_CHAR(dateRequired, 'Day, MONTH DD, YYYY') || ':');

FOR ptr IN cEventDetails LOOP
DBMS_OUTPUT.PUT_LINE('Event Name: ' || ptr.eventName);
DBMS_OUTPUT.PUT_LINE('Time: ' || TO_CHAR(ptr.bookingDate, 'HH:MI am'));
END LOOP;

END eventTimesOnDay;
/

-- Create a stored procedure that receives an event id as input and displays the number of tickets remaining for each date that the event is on

CREATE OR REPLACE PROCEDURE ticketsRemaining (inputEventID Events.eventID%TYPE)
AS
numAvailTickets NUMBER;
numRemTickets NUMBER;
CURSOR cTicketsSold IS
SELECT TO_CHAR(T.ticketDate, 'DD-MON-YYYY, HH:MI am') AS tDate, COUNT(T.ticketNumber) AS numSoldTic
FROM Tickets T
WHERE T.eventID = inputEventID
GROUP BY (T.ticketDate);

BEGIN

SELECT E.venueCapacityRequired
INTO numAvailTickets
FROM Events E
WHERE E.eventID = inputEventID;

DBMS_OUTPUT.PUT_LINE('Tickets remaining for event id:' || inputEventID);

FOR ptr IN cTicketsSold LOOP
numRemTickets := numAvailTickets - ptr.numSoldTic;
DBMS_OUTPUT.PUT_LINE('Date and time: ' || ptr.tDate);
DBMS_OUTPUT.PUT_LINE('Number of tickets remaining ' || numRemTickets);
END LOOP;

END ticketsRemaining;
/

-- Create a stored function that takes event id as its input and returns the ticket sales status of that event 

CREATE OR REPLACE FUNCTION ticketStatus (inputEventID Events.eventID%TYPE) 
RETURN VARCHAR2 IS
numTicAvail NUMBER;
numTicSold NUMBER;
numEventTimes NUMBER;

BEGIN
SELECT E.venueCapacityRequired
INTO numTicAvail
FROM Events E
WHERE E.eventID = inputEventID;

SELECT COUNT(*)
INTO numEventTimes
FROM EventVenues
WHERE eventID = inputEventID;

SELECT COUNT(T.ticketNumber)
INTO numTicSold
FROM Tickets T
WHERE T.eventID = inputEventID;

numTicAvail := numTicAvail * numEventTimes;

IF numTicSold = numTicAvail THEN
RETURN 'Sold Out';

ELSIF (numTicSold / numTicAvail) > 0.75 THEN
RETURN 'Get in Quick!';

ELSIF (numTicSold / numTicAvail) > 0.5 THEN
RETURN 'Selling Steadily';

ELSE
RETURN 'More Promotion Required!';
END IF;

END ticketStatus;
/

-- Create a trigger to raise an error when an attempt is made to insert a promoter twice into the system

CREATE OR REPLACE TRIGGER checkPromoter
BEFORE INSERT ON Promoters FOR EACH ROW
DECLARE
    promoterCount INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO promoterCount
    FROM Promoters
    WHERE promoterBusinessName = :new.promoterBusinessName
    AND streetAddress = :new.streetAddress 
    AND suburb = :new.suburb 
    AND postcode = :new.postcode;

    IF promoterCount > 0 THEN
        RAISE_APPLICATION_ERROR(-20000, 'Promoter with these details is already in the system');
    END IF;
END checkPromoter;
/

