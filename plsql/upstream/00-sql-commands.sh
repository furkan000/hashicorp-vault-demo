docker volume create oracle-oradata
# docker run -d --name oracle-db -p 1521:1521 --network=host container-registry.oracle.com/database/enterprise:latest
docker run -d --name oracle-db -p 1521:1521 --network=host container-registry.oracle.com/database/enterprise:19.19.0.0

docker logs -f oracle-db

docker exec -it oracle-db bash
sqlplus / as sysdba
alter user sys identified by Password1;

ALTER SESSION SET CONTAINER = ORCLPDB1;


# 1. Create the OWNER user
CREATE USER owner IDENTIFIED BY owner_pwd 
DEFAULT TABLESPACE users
TEMPORARY TABLESPACE temp
QUOTA UNLIMITED ON users;

GRANT CREATE SESSION TO owner;
GRANT CREATE TABLE TO owner;
GRANT CREATE VIEW TO owner;
GRANT CREATE SEQUENCE TO owner;
GRANT CREATE PROCEDURE TO owner;

# 2. Create the APP user (no DDL)
CREATE USER app
IDENTIFIED BY app_pwd
DEFAULT TABLESPACE users
TEMPORARY TABLESPACE temp;

GRANT CREATE SESSION TO app;
GRANT CREATE SYNONYM TO app;

# 3. Connect as OWNER and create tables
CONNECT owner/owner_pwd@ORCLPDB1

CREATE TABLE employees (
    id        NUMBER PRIMARY KEY,
    name      VARCHAR2(100)
);

INSERT INTO employees (id, name) VALUES (1, 'Alice');

# 4. Grant data access to APP
GRANT SELECT, INSERT, UPDATE, DELETE
ON owner.employees
TO app;

COMMIT;

# 5. Create synonyms in APP
CONNECT app/app_pwd@ORCLPDB1;
CREATE SYNONYM employees FOR owner.employees;

# 6. Test setup
SELECT * FROM employees;
