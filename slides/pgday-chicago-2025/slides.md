---
theme: default
title: Start with a Clean Slate
class: text-center
drawings:
  persist: false
transition: fade
mdc: true
---

<h1>
<span id="up"> Start with a Clean Slate: </span>
<div id="low">
Setting Up Integration Tests with <span id="pg"> PostgreSQL </span>
</div>
</h1>

PGDay Chicago 2025

Doğaç Eldenk

<style>
#pg {
  background-color: #336791;
  background-image: linear-gradient(45deg, #008bb9 20%, #0064a5 40%);
  background-size: 100%;
  -webkit-background-clip: text;
  -moz-background-clip: text;
  -webkit-text-fill-color: transparent;
  -moz-text-fill-color: transparent;
}

#low {
  font-size: 0.7em
}
</style>

---

# Table of contents

<Toc text-sm minDepth="1" maxDepth="2" />

---

# Introduction

I am currently a Senior Software engineer @ Carbon Health since 2020.

- Started programming in 2013 to mod games.

- **B.S. in Computer Science** - Bilkent University, Graduated 2022.

- **Open-source contributor** - Armeria, kotlinx, protobuf etc.

- **Platform Engineer** - Working at the Platform team since 2022.

- **Hobbies** - Running, piano, speedcubing, DIY tech...

<style>

</style>

---

# Background

Carbon Health is a tech-enabled clinic company. Our providers and patients use our mobile and web-based application to manage their care.

- Our tech-stack consists of a monolithic server supported by 30+ micro-services. 

- We host our services on cloud, our primary choice of database is PostgreSQL.

- We have over 500 tables serving more than 10TBs* of data.

- We have about 6 distinct development teams.

<!--
We should define our environment, constraints and our goal before we get into the problem.
-->

---
transition: slide-left
hideInToc: true
---

# Background

Our Platform Team's responsibilities include but not limited to, 
- Architectural decisions
- Core library development
- CI/CD pipelines
- Authorization & Auditing
- Infrastructure management
- Database migrations
- Cost & Performance monitoring

---

# Integration Tests

Integration testing checks whether different parts of a system work together correctly as a whole.
Unit testing focuses on testing individual components.

<table>
  <thead>
    <tr>
      <th>Feature</th>
      <th>Unit Testing</th>
      <th>Integration Testing</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><span v-mark.underline.red="1">Isolation</span></td>
      <td>+++</td>
      <td><span v-mark.circle.orange="3">+</span></td>
    </tr>
    <tr>
      <td><span v-mark.underline.red="2">Speed</span></td>
      <td>+++</td>
      <td><span v-mark.circle.orange="3">+</span></td>
    </tr>
    <tr>
      <td>Failure Detection</td>
      <td>+</td>
      <td>+++</td>
    </tr>
    <tr>
      <td>Coverage</td>
      <td>+</td>
      <td>+++</td>
    </tr>
  </tbody>
</table>

<!--
In complex environments, unit tests fall short. You can mock the DB but can never test the real interaction.
Such as transactions and queries.
-->

---
hideInToc: true
---

# Integration Tests

- Test isolation is important, but the database is stateful.
  - Foreign keys and dependencies make initialization hard.
  - Re-usable _scenarios_ are created to help developers build tests.
- No guarantee if tests leave the DB state clean.
- Wrapping tests in transactions?
  - Adds unintentional behavior.


<div mt-10 />

<v-clicks>

1. Fresh DB per Test 
1. Clean all tables
1. ??? (Our solution)

</v-clicks> 

---

 
# A new DB for each test

First glance, it sounds like re-creating the DB before each test would be a good start to ensure our state is clean and our tests will run consistently.

- 400+ Tables

- 1,600+ Migration files
  - Can take a schema dump with `rake db:schema:dump`.
  - Can use `TEMPLATE` databases.

- Can create multiple schemas or databases.  
  - Tests *might* run in parallel 

- Each test is fully isolated.



---

## Implementation

````md magic-move
```scala{*}{lines:true}
// File: SimpleSpec.scala

import org.scalatest.funsuite.AnyFunSuite

class SimpleSpec extends AnyFunSuite {

  private val repository = TestDependencies.getDefault[ApptRepository]

  test("Table empty") {
    val rows = repository.getAll()
    assert(rows.isEmpty())
  }

  test("Inserts and fetches a row") {
    repository.add(sampleAppt)
    val result = repository.query(id = sampleAppt.id)

    assert(result.count() == 1)
    assert(result[1] == sampleAppt)
  }

}
```
```scala{7,8|all}{lines:true}
// File: SimpleSpec.scala

import org.scalatest.funsuite.AnyFunSuite

class SimpleSpec extends AnyFunSuite with BeforeAndAfterEach {

  override def beforeEach() = { DBProvider.createFresh() }
  override def afterEach() = { DBProvider.destroy() }

  private val repository = TestDependencies.getDefault[ApptRepository]

  test("Table empty") {
    val rows = repository.getAll()
    assert(rows.isEmpty())
  }

  test("Inserts and fetches a row") {
    repository.add(sampleAppt)
    val result = repository.query(id = sampleAppt.id)

    assert(result.count() == 1)
    assert(result[1] == sampleAppt)
  }

}
```
```scala{*|7,10,13}{lines:true}
// File: WithDBTrait.scala

import org.scalatest.funsuite.AnyFunSuite

trait CleanDBBetweenTests extends BeforeAndAfterEach with BeforeAndAfterAll { this: Suite =>
 override def beforeAll(): Unit = {
   DBProvider.createFresh()
 }
 override def beforeEach(): Unit = {
   DBProvider.createFresh()
 }
 override def afterAll(): Unit = {
   DBProvider.destroy()
 }
}
```
```scala{*}{lines:true}
// File: DBProvider.scala

object DBProvider {
  def createFresh() = {
    exec("rake db:create && rake db:schema:load")
  } 

  def destroy() = {
    exec("rake db:drop")   
  } 
}
```
```scala{*}{lines:true}
// File: WithDBTrait.scala

import org.scalatest.funsuite.AnyFunSuite

trait CleanDBBetweenTests extends BeforeAndAfterEach with BeforeAndAfterAll { this: Suite =>
 override def beforeAll(): Unit = {
   DBProvider.createFresh()
 }
 override def beforeEach(): Unit = {
   DBProvider.createFresh()
 }
 override def afterAll(): Unit = {
   DBProvider.destroy()
 }
}
```
```scala{5|all}{lines:true}
// File: SimpleSpec.scala

import org.scalatest.funsuite.AnyFunSuite

class SimpleSpec extends AnyFunSuite with CleanDBBetweenTests {

  private val repository = TestDependencies.getDefault[ApptRepository]

  test("Table empty") {
    val rows = repository.getAll()
    assert(rows.isEmpty())
  }

  test("Inserts and fetches a row") {
    repository.add(sampleAppt)
    val result = repository.query(id = sampleAppt.id)

    assert(result.count() == 1)
    assert(result[1] == sampleAppt)
  }

}
```
````

---

## Cons

- **Speed**: Initialization takes 400 milliseconds __*__

- Can sacrifice some stability by creating a DB per _spec_ rather than test.
  - Still need to figure out how to keep DB state consistent among test cases.

<div mt-10/>


<v-click> 

> __*__ Combined with 9000+ tests in total, only initialization takes a little over <span v-mark.underline.red="-1"> 1 hour </span>.
</v-click>


---

# Delete all tables

- Initial approach, hand-crafted list of tables.
  
  - Order of tables matter, as foreign keys prevent deletion. __*__
  
  - Some tables might be missing from the list.

- Theoretically faster than re-creating the entire DB.

  - Make sure you send all deletes in one connection.

- Sequences and materialized views need special attention.

<div mt-30/>

<v-click>

> _**Note**_: `TRUNCATE` had **significantly** worse performance than `DELETE`, as no test-case generated huge amounts of data.
</v-click>

<!--
  The specific order is hard to figure out as the exception might occur at a random test at a random point, there is no
  guarantee that newly written tests work even though the existing ones work.
-->

---

## Implementation

````md magic-move
```scala{*}{lines:true}
// File: WithDBTrait.scala

import org.scalatest.funsuite.AnyFunSuite

trait CleanDBBetweenTests extends BeforeAndAfterEach with BeforeAndAfterAll { this: Suite =>
 override def beforeAll(): Unit = {
   cleanAllTables()
 }
 override def beforeEach(): Unit = {
   cleanAllTables()
 }
 override def afterAll(): Unit = {
   cleanAllTables()
 }

 def cleanAllTables(): Unit = {
    finishOperation(sql"""DELETE FROM appts""")
    finishOperation(sql"""DELETE FROM patients""")
    finishOperation(sql"""DELETE FROM practices""")
    // ...
 }
}
```
````

---
hideInToc: true
---

## Implementation

```scala{7|17-39|20}{lines:true, maxHeight:'90%'}
// File: WithDBTrait.scala

import org.scalatest.funsuite.AnyFunSuite

trait CleanDBBetweenTests extends BeforeAndAfterEach with BeforeAndAfterAll { this: Suite =>
 override def beforeAll(): Unit = {
   setupFunctions()
   cleanAllTables()
 }
 override def beforeEach(): Unit = {
   cleanAllTables()
 }
 override def afterAll(): Unit = {
   cleanAllTables()
 }

 def setupFunctions(): Unit = {
  """
    CREATE OR REPLACE FUNCTION delete_tables() RETURNS int AS $$
  """ + List("appts", "patients", "practices").map(tableName =>
    """
    BEGIN
      EXECUTE 'DELETE FROM ${tableName}';
      EXCEPTION WHEN OTHERS THEN
    END;
    """
  ).joinToString("\n") + """
      END LOOP;
    RETURN 0;
    END $$ LANGUAGE plpgsql;
  """.sql()
 }

 def cleanAllTables(): Unit = {
   sql"""SELECT delete_tables()"""
 }
}
```

---

# Final Solution

Before starting to explain the solution we have came up with, let's visit what we have learned so far.

- Before each test, our tables should be fresh.

- Cleaning the DB state should be as fast as possible.

  - _We have over 9000+ test cases. Test should as fast as possible in local and CI for the ideal development experience._

- Hand-crafted table list is annoying, entropy always wins.

<div mt-10/>

<v-click>

> What if we record the tables that are used and wipe only them?

</v-click>

---

## Implementation

<div mt-10/>

Let's create a table to record the tables that are used during test runs.

```sql
CREATE TABLE IF NOT EXISTS test_access(table_name varchar(256) not null primary key);
```

<v-click>

Later, create a function / trigger that adds a given table name to the list. 

```sql
CREATE OR REPLACE FUNCTION add_table_to_accessed_list() RETURNS TRIGGER AS $$
BEGIN
 --- Assuming that the table name is passed as the first argument to the function.
 INSERT INTO test_access VALUES (TG_ARGV[0]) ON CONFLICT DO NOTHING;
 RETURN NEW;
END $$ LANGUAGE PLPGSQL;
```

</v-click>

<v-click>

We would like to setup triggers to all existing tables. This trigger will be executed before every insert, which ensures we capture all tables that are altered during the test run.

</v-click>

---
hideInToc: true
---

## Implementation

<div mt-10/>

```sql{*|1-8|9-10|11|12-14|15-22|23-25}{lines: true, maxHeight: '90%'}
CREATE OR REPLACE FUNCTION setup_access_triggers(schemas text[]) RETURNS int AS $$
DECLARE tables CURSOR FOR
 SELECT table_name, table_schema FROM information_schema.tables
   WHERE table_schema = ANY(schemas)
     AND table_type = 'BASE TABLE' --- Exclude views.
     AND table_name NOT IN ('test_access', 'schema_migrations'); 
     --- Prevent recursion when an insertion happens to 'test_access' table.
BEGIN
 --- Create a table to store the list of tables that have been accessed.
 EXECUTE 'CREATE TABLE IF NOT EXISTS test_access(table_name varchar(256) not null primary key);';
 FOR stmt IN tables LOOP
   --- If the trigger exists, first drop it so we can re-create.
   EXECUTE 'DROP TRIGGER IF EXISTS "' || stmt.table_name || '_access_trigger" ON "' ||
          stmt.table_schema || '"."'|| stmt.table_name || '"';  
   --- Create the on insert trigger.
   --- This calls `add_table_to_accessed_list` everytime a row is inserted into the table with table name.
   --- The table name also includes the table schema.
   EXECUTE 'CREATE TRIGGER "' || stmt.table_name || '_access_trigger"' ||
           ' BEFORE INSERT ON "' || stmt.table_schema ||'"."'|| stmt.table_name || '"' ||
           ' FOR EACH STATEMENT ' ||
           ' EXECUTE PROCEDURE public.add_table_to_accessed_list (''"'||
           stmt.table_schema ||'"."'|| stmt.table_name ||'"'')';
 END LOOP;
RETURN 0;
END $$ LANGUAGE plpgsql;
```

---
hideInToc: true
---

## Implementation

<div mt-10/>

```sql{*|1-4|5-8|9-16|17-22}{lines: true, maxHeight: '90%'}
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
```

---
hideInToc: true
---

## Implementation

<div mt-10/>

```scala{*|2,6}{lines: true}
def clearAccessedTables(): Unit = {
 finishOperation(sql"""SELECT public.delete_from_accessed_tables()""".as[Int])
}

def setupTestTriggers(): Unit = {
  finishOperation(sql"""SELECT public.setup_access_triggers(array['test_schema'])""".as[Int])
}

trait CleanDBBetweenTests extends BeforeAndAfterEach with BeforeAndAfterAll { this: Suite =>
 override def beforeAll(): Unit = {
   setupTestTriggers()
   clearAccessedTables()
 }
 override def beforeEach(): Unit = {
   clearAccessedTables()
 }
 override def afterAll(): Unit = {
   clearAccessedTables()
 }
}
```

---

## Installing

Install as a system admin,

```sh
curl -sSL https://raw.githubusercontent.com/dogacel/pg_test_table_track/main/install.sh | bash
```

<v-click>

Install for your docker image (_**Recommended**_)

```sh
❯ curl -sSL https://raw.githubusercontent.com/dogacel/pg_test_table_track/main/install_docker.sh | \
  bash -s \
    "$DB_CONTAINER_NAME" \
    "$DB_NAME" \
    "$POSTGRES_USER"
```
</v-click>


<v-click>

<div mt-30/>

> _**Note:**_ PostgreSQL docker containers are encouraged to be used in CI/CD pipelines.

</v-click>
---

# Future Work

- Support global constant rows.

- Reset sequences, materialized views.

- Unlogged tables.


---

# Results

We are using this test setup since May 2023 and we haven't faced any isolation or stability issues so far. Only issues were related to tests not extending the `CleanDBTrait`, which is pretty easy to solve.

- We have seen a reduction of around 30% in our CI runtimes. 

- Our number of tests is growing faster than ever, when we initially implemented this improvement, we only had 6700 test cases.

---

# Final Remarks

Thank you for listening!

<hr />

<div style="display: flex; align-items: center; justify-content: space-between; margin-top: 2em;">

  <div style="flex: 1; padding-right: 2em;">

  GitHub Repository for PostgreSQL Extension:  
  ### [Dogacel/pg_test_table_track](https://github.com/Dogacel/pg_test_table_track)

  <br />

  Original blog post:  
  ### [blog.dogac.dev/pg-test-table-track](https://blog.dogac.dev)

  </div>

  <div style="flex: 0 0 auto; margin-right: 3em;">
    <img src="/images/qr.webp" alt="QR Code" style="width: 300px;" />
  </div>

</div>
