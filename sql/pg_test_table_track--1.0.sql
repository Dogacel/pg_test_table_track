CREATE OR REPLACE FUNCTION add_table_to_accessed_list() RETURNS TRIGGER AS $$
BEGIN
 --- Assuming that the table name is passed as the first argument to the function.
 INSERT INTO test_access VALUES (TG_ARGV[0]) ON CONFLICT DO NOTHING;
 RETURN NEW;
END $$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION setup_access_triggers(schemas text[]) RETURNS int AS $$
DECLARE tables CURSOR FOR
 SELECT table_name, table_schema FROM information_schema.tables
   WHERE table_schema = ANY(schemas)
     AND table_type = 'BASE TABLE' --- Exclude views.
     AND table_name NOT IN ('test_access', 'schema_migrations'); --- Prevent recursion when an insertion happens to 'test_access' table.
BEGIN
 --- Create a table to store the list of tables that have been accessed.
 EXECUTE 'CREATE TABLE IF NOT EXISTS test_access(table_name varchar(256) not null primary key);';
 FOR stmt IN tables LOOP
   --- If the trigger exists, first drop it so we can re-create.
   EXECUTE 'DROP TRIGGER IF EXISTS "' || stmt.table_name || '_access_trigger" ON "' || stmt.table_schema || '"."'|| stmt.table_name || '"';
   --- Create the on insert trigger.
   --- This calls `add_table_to_accessed_list` everytime a row is inserted into the table with table name.
   --- The table name also includes the table schema.
   EXECUTE 'CREATE TRIGGER "' || stmt.table_name || '_access_trigger"' ||
           ' BEFORE INSERT ON "' || stmt.table_schema ||'"."'|| stmt.table_name || '"' ||
           ' FOR EACH ROW ' ||
           ' EXECUTE PROCEDURE public.add_table_to_accessed_list (''"'|| stmt.table_schema ||'"."'|| stmt.table_name ||'"'')';
 END LOOP;
RETURN 0;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION delete_from_accessed_tables() RETURNS int AS $$
DECLARE tables CURSOR FOR
 SELECT table_name FROM test_access;
BEGIN
--- Disable foreign key constraints temporarily. Without this, we need to clear tables in a specific order.
--- But it is very hard to find this order and this trick makes the process even faster.
--- Because we clear every table, we don't care about any foreign key constraints.
EXECUTE 'SET session_replication_role = ''replica'';';
--- Clear all tables that have been accessed.
FOR stmt IN tables LOOP
 BEGIN
   EXECUTE 'DELETE FROM '|| stmt.table_name;
   --- If we accessed a table that is dropped, an exception will occur. This ignored the exception.
   EXCEPTION WHEN OTHERS THEN
 END;
END LOOP;
--- Clear the list o accessed tables because those tables are now empty.
EXECUTE 'DELETE FROM test_access';
--- Turn foreign key constraints back on.
EXECUTE 'SET session_replication_role = ''origin'';';
RETURN 0;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION remove_access_triggers(schemas text[]) RETURNS int AS $$
DECLARE tables CURSOR FOR
 SELECT table_name, table_schema FROM information_schema.tables
   WHERE table_schema in ANY(schemas)
     AND table_type = 'BASE TABLE' --- Exclude views.
     AND table_name NOT IN ('test_access', 'schema_migrations'); 
     --- Prevent recursion when an insertion happens to 'test_access' table.
BEGIN
 --- Create a table to store the list of tables that have been accessed.
 EXECUTE 'CREATE TABLE IF NOT EXISTS test_access(table_name varchar(256) not null primary key);';
 FOR stmt IN tables LOOP
   --- If the trigger exists, first drop it so we can re-create.
   EXECUTE 'DROP TRIGGER IF EXISTS "' || stmt.table_name || '_access_trigger" ON "' || stmt.table_schema || '"."'|| stmt.table_name || '"';
 END LOOP;
 RETURN 0;
END $$ LANGUAGE plpgsql;

