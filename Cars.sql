-- Oracle
CREATE TABLE "Ashley"."CARS" 
(
	"MANUFACTURER" VARCHAR2(10 BYTE) PRIMARY KEY, 
	"TYPE" VARCHAR2(20 BYTE) PRIMARY KEY, 
	"MIN_PRICE" NUMBER(19,2), 
	"PRICE" NUMBER(19,2)
);

-- MySQL
create table Ashley.CARS 
(
	MANUFACTURER nvarchar(10) not null, 
	TYPE nvarchar(20) not null, 
	MIN_PRICE float(19,2), 
	PRICE float(19,2),
    	primary key (MANUFACTURER, TYPE)
) engine=InnoDB default charset=utf8;
