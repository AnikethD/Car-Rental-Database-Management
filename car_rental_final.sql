DROP TABLE IF EXISTS CAR_TYPE, INSURANCE,RENTAL_LOCATION,CAR_INSURANCE,CAR,CAR_USER,USER_CREDENTIALS,CARD_DETAILS,RESERVATION,PAYMENT,OFFER_DETAILS,ADDITIONAL_DRIVER,ACCESSORIES,ACCESSORY_RESERVED;

CREATE TABLE RENTAL_LOCATION
(
  Rental_Location_ID INT PRIMARY KEY,  
  Phone CHAR(10) NOT NULL,
  Email VARCHAR(25),
  Area_Name VARCHAR(40) NOT NULL,
  State CHAR(2) NOT NULL
  CHECK (State ='KA'),
  Pin_Code CHAR(6) NOT NULL
);

CREATE TABLE CAR_TYPE
(
  Car_Type VARCHAR(15) PRIMARY KEY,
  Price_Per_Day  INT NOT NULL  
);

CREATE TABLE INSURANCE
(
  Insurance_Type VARCHAR(15) PRIMARY KEY,
  Bodily_Coverage  INT NOT NULL,
  Medical_Coverage  INT NOT NULL,
  Collision_Coverage  INT NOT NULL
);

CREATE TABLE CAR_INSURANCE
(
  Car_Type VARCHAR(15),
  Insurance_Type VARCHAR(15),
  Insurance_Price  INT NOT NULL,
  PRIMARY KEY(Car_Type,Insurance_Type),
  CONSTRAINT CARTYPEFK
  FOREIGN KEY (Car_Type) REFERENCES CAR_TYPE(Car_Type)
              ON DELETE CASCADE,
  CONSTRAINT INSURANCETYPEFK
  FOREIGN KEY (Insurance_Type) REFERENCES INSURANCE(Insurance_Type)
              ON DELETE CASCADE            
);

CREATE TABLE CAR_USER
(
  License_No VARCHAR(15) PRIMARY KEY,
  Fname VARCHAR(15) NOT NULL,
  Mname VARCHAR(1),
  Lname VARCHAR(15) NOT NULL,
  Email VARCHAR(25) NOT NULL UNIQUE,
  Address VARCHAR(100) NOT NULL,
  Phone CHAR(10) NOT NULL,
  DOB DATE NOT NULL,
  User_Type VARCHAR(10) NOT NULL
);

CREATE TABLE USER_CREDENTIALS
(
  Login_ID VARCHAR(15) PRIMARY KEY,
  Password VARCHAR(15) NOT NULL,
  Year_Of_Membership Char(4) NOT NULL 
  CHECK (Year_of_Membership>2000),
  License_No VARCHAR(15) NOT NULL,
  CONSTRAINT USRLIC
  FOREIGN KEY (License_No) REFERENCES CAR_USER(License_No)
              ON DELETE CASCADE
);

CREATE TABLE CARD_DETAILS
(
  Login_ID VARCHAR(15) NOT NULL,
  Name_On_Card VARCHAR(50) NOT NULL,
  Card_No CHAR(16) NOT NULL,
  Expiry_Date DATE NOT NULL,
  CVV CHAR(3) NOT NULL,
  Billing_Address VARCHAR(50) NOT NULL,
  PRIMARY KEY(Login_ID,Card_No),
  CONSTRAINT USRCARDFK
  FOREIGN KEY (Login_ID) REFERENCES USER_CREDENTIALS(Login_ID)
              ON DELETE CASCADE
);

CREATE TABLE CAR
(
  RFID CHAR(17) PRIMARY KEY,
  Rental_Location_ID INT NOT NULL,
  Reg_No VARCHAR(15) UNIQUE,
  Seating_Capacity INT NOT NULL,
  Car_Type VARCHAR(15) NOT NULL, 
  Model VARCHAR(20),
  Year CHAR(4),
  Color VARCHAR(10),
  CONSTRAINT CARRFIDTYPEFK
  FOREIGN KEY (Car_Type) REFERENCES CAR_TYPE(Car_Type)
              ON DELETE CASCADE,
  CONSTRAINT CARRFIDRENTALFK
  FOREIGN KEY (Rental_Location_ID) REFERENCES RENTAL_LOCATION(Rental_Location_ID)
              ON DELETE CASCADE ,
  CONSTRAINT CARSEATING CHECK (Seating_Capacity>2)            
);

CREATE TABLE OFFER_DETAILS
(
  Promo_Code VARCHAR(15) PRIMARY KEY,
  Description VARCHAR(50),
  Promo_Type VARCHAR(20) NOT NULL,
  Percentage DECIMAL(5,2),
  Cashback  INT,
  Status VARCHAR(10) NOT NULL
);

CREATE TABLE RESERVATION
(
  Reservation_ID INT PRIMARY KEY,
  Start_Date DATE NOT NULL,
  End_Date DATE NOT NULL,
  Meter_Start INT NOT NULL,
  Meter_End INT,
  Rental_Amount INT NOT NULL,
  Insurance_Amount  INT NOT NULL,
  Actual_End_Date DATE NULL,
  License_No VARCHAR(15) NOT NULL,
  RFID CHAR(17) NOT NULL,
  Promo_Code VARCHAR(15),
  Penalty_Amount  INT  DEFAULT 0,
  Tot_Amount  INT DEFAULT 0,
  Insurance_Type VARCHAR(15),
  Drop_Location_ID INT,  
  CONSTRAINT RSERVLOCATIONFK
  FOREIGN KEY (Drop_Location_ID) REFERENCES RENTAL_LOCATION(Rental_Location_ID)
              ON DELETE CASCADE,
  CONSTRAINT RESLICENSEFK
  FOREIGN KEY (License_No) REFERENCES CAR_USER(License_No)
              ON DELETE CASCADE,
  CONSTRAINT RFIDRESERVATIONFK
  FOREIGN KEY (RFID) REFERENCES CAR(RFID)
              ON DELETE CASCADE,
  CONSTRAINT PROMORESERVATIONFK
  FOREIGN KEY (Promo_Code) REFERENCES OFFER_DETAILS(Promo_Code)
              ON DELETE CASCADE,
  CONSTRAINT INSURESERVATIONFK
  FOREIGN KEY (Insurance_Type) REFERENCES INSURANCE(Insurance_Type)
              ON DELETE CASCADE
)engine=InnoDB;

CREATE TABLE PAYMENT
(
  Payment_ID INT PRIMARY KEY,
  Amount_Paid INT ,
  Card_No CHAR(16),
  Expiry_Date DATE,
  Name_On_Card VARCHAR(50),
  CVV CHAR(3),
  Billing_Address VARCHAR(50),
  Reservation_ID INT NOT NULL,
  Login_ID VARCHAR(15),
  Saved_Card_No CHAR(16),
  Paid_By_Cash CHAR(1),
  CONSTRAINT PAYMENTRESERVATIONFK
  FOREIGN KEY (Reservation_ID) REFERENCES RESERVATION(Reservation_ID)
              ON DELETE CASCADE,
  CONSTRAINT PAYMENTLOGINFK
  FOREIGN KEY (Login_ID,Saved_Card_No) REFERENCES CARD_DETAILS(Login_ID,Card_No)
              ON DELETE CASCADE
);

DELIMITER $$
CREATE TRIGGER offer_amount
BEFORE INSERT
ON reservation FOR EACH ROW
BEGIN
	DECLARE v1,v2,a1 INT;
    DECLARE ava VARCHAR(20);
	select offer.percentage,offer.Cashback,offer.Status INTO v1,v2,ava from offer_details as offer,accessories as acc where ((offer.Promo_Code=new.Promo_Code));
      if v1 is not null  then
            if (ava='Available') then 
                  SET new.Tot_Amount = new.Rental_Amount+new.Insurance_Amount+((v1/100)*(new.Rental_Amount+new.Insurance_Amount))+new.Penalty_Amount;
			else
				SET new.Tot_Amount = new.Rental_Amount+new.Insurance_Amount+new.Penalty_Amount;
              END IF;  
        else
			if (ava='Available') then 
				SET new.Tot_Amount = new.Rental_Amount+new.Insurance_Amount((v2))+new.Penalty_Amount; 
             else   
			    SET new.Tot_Amount = new.Rental_Amount+new.Insurance_Amount+new.Penalty_Amount;
             END IF;   
    END iF;
END $$
DELIMITER ;

DROP TRIGGER offer_amount;

delimiter |
CREATE TRIGGER rent_amt before insert on reservation
FOR EACH ROW
	BEGIN
		SET @carType=(select C.Car_Type from car as C where new.RFID=C.RFID);
        SET @price=(select Price_Per_Day from car_type where Car_Type=@carType);
        set new.Rental_Amount=@price*(datediff(new.Actual_End_Date,new.Start_Date));
     END |
     
delimiter ;


delimiter |
CREATE TRIGGER ins_amt before insert on reservation
FOR EACH ROW
	BEGIN
		SET @carType=(select C.Car_Type from car  C where new.RFID=C.RFID);
        SET @price=(select C.Insurance_Price from car_insurance C where(( C.Car_Type=@carType) and (C.Insurance_Type=new.Insurance_Type)));
        set new.Insurance_Amount=@price*(datediff(new.Actual_End_Date,new.Start_Date));
     END |
     
delimiter ;

delimiter |
CREATE TRIGGER date_check before insert on reservation
FOR EACH ROW
	BEGIN 
		if(DATEDIFF(new.Actual_End_Date,new.End_date)>0) then
               set new.Penalty_Amount=(DATEDIFF(new.Actual_End_Date,new.End_date)*50);
         END IF;
     END |
delimiter ;   

INSERT INTO RENTAL_LOCATION
(Rental_Location_ID,Phone,Email,Area_Name,State,Pin_Code) 
VALUES 
(101,'9726031111','zoom1@gmail.com','Basaweshwarnagar','KA',560079),
(102,'9726032222','zoom2@gmail.com',' Majestic','KA',560009),
(103,'9721903121','zoom3@gmail.com',' Whitefield','KA',560066),
(104,'721903121','zoom4@gmail.com','Electronic City','KA',560100),
(105,'9026981045','zoom5@gmail.com','Brigade Road','KA',560001);

INSERT INTO CAR_TYPE 
(Car_Type,Price_Per_Day) 
VALUES 
('Economy',100),
('Standard',200),
('SUV',300),
('MiniVan',400),
('Premium',500),
('Electric',1000);

INSERT INTO INSURANCE
(Insurance_Type,Bodily_Coverage,Medical_Coverage,Collision_Coverage) 
VALUES 
('Liability',2500.00,5000.00,0.00), 
('Comprehensive',5000.00,5000.00,5000.00);

INSERT INTO CAR_INSURANCE
(Car_Type,Insurance_Type,Insurance_Price)
VALUES
('Economy','Liability',100), 
('Standard','Liability',110),
('SUV','Liability',120),
('MiniVan','Liability',140),
('Premium','Liability',190),
('Economy','Comprehensive',200),
('Standard','Comprehensive',250),
('SUV','Comprehensive',300),
('MiniVan','Comprehensive',350),
('Premium','Comprehensive',500),
('Electric','Comprehensive',900);

INSERT INTO CAR_USER
(License_No,FName,MName,Lname,Email,Address,Phone,DOB,USER_TYPE)
VALUES
('KA031983642','Patric','G','Cummins','patric.c@gmail.com','#10 Wilson Garden,Bangalore','9022196058',('1970-01-10'),'Guest'),
('KA021495370','Brad',NULL,'Pitt','brad.pitt@gmail.com','#25 MG Road,Bangalore','8697891045',('1980-03-20'),'Customer'),
('KA028341025','Glenn',NULL,'Maxwell','glenm@gmail.com','#30 Richmond Road,Bangalore','8590125607',('1984-11-11'),'Customer'),
('KA029046432','Christiano',NULL,'Ronaldo','cr7@gmail.com','#7 VM Road,Bangalore','7048015647',('1987-04-24'),'Guest'),
('KA029785313','Leonardo',NULL,'Decaprio','ldc@gmail.com','#1 Church Street,Bangalore','9056010687',('1987-04-24'),'Customer');

INSERT INTO USER_CREDENTIALS
(Login_ID,Password,Year_Of_Membership,License_No)
VALUES
('Brad_P','ouatih','2019','KA021495370'),
('RDJ','marvel','2014','KA028341025'),
('LDC','inception','2015','KA029785313'),
('Chris_E','cap','2016','KA029046432'),
('Ben','strange','2016','KA021495370');

INSERT INTO CARD_DETAILS
(Login_ID,Name_On_Card,Card_No,Expiry_Date,CVV,Billing_Address)
VALUES
('Brad_P','Brad Pitt','4735111122223333',('2022-01-15'),'833','#25 MG Road,Bangalore'),
('LDC','Leo_De_Cap','4233908110921001',('2021-12-31'),'419','#1 Church Street,Bangalore'),
('Chris_E','Chris Evans','5123408110921001',('2022-10-31'),'820','#50 Ecity,Bangalore'),
('Ben','Benedict','3785032136469082',('2023-05-12'),'121','221 B Baker Street,Bangalore');

INSERT INTO CAR
(RFID,Rental_Location_ID,Reg_No,Seating_Capacity,Car_Type,Model,Year,Color)
VALUES
('F152206785240289',101,'KAF101',5,'Economy','i20','2007','Gold'),
('T201534710589051',101,'KYQ101',5,'Standard','Toyota Camry','2012','Grey'),
('E902103289341098',102,'XYZ671',5,'Premium','BMW X5','2015','Black'),
('R908891209418173',103,'DOP391',4,'SUV','Fortuner','2014','White'),
('N892993994858292',104,'RAC829',10,'MiniVan','Ertiga','2013','Black');

INSERT INTO OFFER_DETAILS
(PROMO_CODE,DESCRIPTION,PROMO_TYPE,PERCENTAGE,Cashback,Status)
VALUES
('CHRISTMAS10','Christmas 10% offer','Percentage',10.00,NULL,'Available'),
('July25','July Rs.250.00 discount','Cashback',NULL,250.00,'Expired'),
('MayDay1','May Day Rs.500 offer','Cashback',NULL,500.00,'Available'),
('NewYear10','New Year 10% offer','Percentage',10.00,NULL,'Available'),
('EASTER12','Easter 15% offer','Percentage',15.00,NULL,'Expired');

delimiter |
CREATE TRIGGER Tot_Amount before insert on reservation
FOR EACH ROW
	BEGIN
		DECLARE v1,v2 INT;
        select offer.Percentage,offer.Cashback into v1,v2 from offer_details as offer where new.Promo_Code=offer.Promo_Code;
		SET @availability=(select offer.STATUS from offer_details as offer where offer.Promo_Code=new.Promo_Code); 
        if v1 is not null then
             if (@availability='Available') then 
                 set new.Tot_Amount=(new.Rental_Amount+new.Insurance_Amount)-((v1/100)*(new.Rental_Amount+new.Insurance_Amount))+new.Penalty_amount;
			  else
                  set new.Tot_Amount=(new.Rental_Amount+new.Insurance_Amount)+new.Penalty_amount;
               END IF; 
         else         
                  if (@availability='Available') then 
                         set new.Tot_Amount=(new.Rental_Amount+new.Insurance_Amount+new.Penalty_Amount)-v2;
                   else      
                          set new.Tot_Amount=(new.Rental_Amount+new.Insurance_Amount)+new.Penalty_amount; 
                       
                    END IF;      
         END IF;
	 END |
delimiter ;

INSERT INTO RESERVATION
(Reservation_ID,Start_Date,End_Date,Meter_Start,Meter_End,Actual_End_Date,License_No,RFID,Promo_Code,Insurance_Type,Drop_Location_ID,Tot_Amount)
VALUES
(1,('2019-11-06'),('2019-11-12'),81256,81300,('2019-11-12'),'KA031983642','F152206785240289','NEWYEAR10','Liability',101,0),
(2,('2019-10-20'),('2019-10-24'),76524,76590,('2019-10-24'),'KA021495370','T201534710589051','EASTER12','Liability',101,0),
(3,('2019-12-06'),('2019-12-12'),82001,82222,('2019-12-15'),'KA021495370','N892993994858292','CHRISTMAS10','Comprehensive',104,0),
(4,('2019-09-01'),('2019-09-02'),51000,51100,('2019-09-02'),'KA021495370','R908891209418173','MAYDAY1','Comprehensive',103,0),
(5,('2019-08-13'),('2019-08-15'),51000,51100,('2019-08-15'),'KA029046432','E902103289341098','MAYDAY1','Comprehensive',105,0);

Delimiter |
CREATE TRIGGER amt_paid before insert on payment
FOR EACH ROW
	BEGIN
        DECLARE a1 INT;
        select r.Tot_Amount INTO a1 from reservation r where new.Reservation_ID=r.Reservation_ID;
        SET new.Amount_Paid =a1;
    
     END |
     
delimiter ;  

start transaction ;
INSERT INTO PAYMENT
(Payment_ID,Card_NO,Expiry_Date,Name_On_Card,CVV,Billing_Address,Reservation_ID,Login_ID,Saved_Card_No,Paid_By_Cash)
values (1001,'4735111122223333',('2022-01-15'),'Brad Pitt','100','#25 MG Road,Bangalore',1,'Brad_P','4735111122223333','N');

-- savepoint transaction1;

INSERT INTO PAYMENT
(Payment_ID,Card_NO,Expiry_Date,Name_On_Card,CVV,Billing_Address,Reservation_ID,Login_ID,Saved_Card_No,Paid_By_Cash) 
values (1002,'4233908110921001',('2021-12-31'),'Leo_De_Cap','419','#1 Church Street,Bangalore',5,'LDC','4233908110921001','N');

 rollback;

-- rollback to savepoint transaction1;
 commit;
-- commit;

INSERT INTO PAYMENT
(Payment_ID,Card_NO,Expiry_Date,Name_On_Card,CVV,Billing_Address,Reservation_ID,Login_ID,Saved_Card_No,Paid_By_Cash)
VALUES
(1003,NULL,NULL,NULL,NULL,NULL,5,NULL,NULL,'Y'),
(1004,NULL,NULL,NULL,NULL,NULL,3,NULL,NULL,'Y'),
(1005,NULL,NULL,NULL,NULL,NULL,4,NULL,NULL,'Y');

