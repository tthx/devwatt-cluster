create keyspace hr_keyspace with replication={'class':'NetworkTopologyStrategy', 'dataCenter-1':2, 'DataCenter-2':3, 'DataCenter-3':1};
use hr_keyspace;
CREATE TABLE employee(emp_id int PRIMARY KEY, emp_name text, emp_city text, emp_sal varint, emp_phone varint);
consistency LOCAL_QUORUM;
INSERT INTO employee(emp_id, emp_name, emp_city,emp_sal,emp_phone) VALUES(1, 'David', 'San Francisco', 50000, 983210987);
INSERT INTO employee(emp_id, emp_name, emp_city,emp_sal,emp_phone) VALUES(2, 'Robin', 'San Jose', 55000, 9848022339); 
INSERT INTO employee(emp_id, emp_name, emp_city,emp_sal,emp_phone) VALUES(3, 'Bob', 'Austin', 45000, 9848022330);
INSERT INTO employee(emp_id, emp_name, emp_city,emp_sal,emp_phone) VALUES(4, 'Monica', 'San Jose', 55000, 9458022330);
