# pg_test_table_track: PostgreSQL Unit Tests Table Cleanup Extension

A PostgreSQL extension to efficiently cleanup database in-between test runs.

> [!INFO]
>
> I also created a blog post which can be found [here](https://blog.dogac.dev/pg-test-table-track/).
> The slides are also published at [pgday.dogac.dev](https://pgday.dogac.dev/)
> Presented at [PGDay Chicago 2025](https://postgresql.us/events/pgdaychicago2025/schedule/session/1891-start-with-a-clean-slate-setting-up-integration-tests-with-postgresql/).

## Installation

### Prerequisites

- PostgreSQL installed (`pg_config` should be available)
- Git installed

If postgreSQL is installed locally,

```sh
curl -sSL https://raw.githubusercontent.com/dogacel/pg_test_table_track/main/install.sh | bash
```

If postgreSQL is installed inside a docker container,

```sh
curl -sSL https://raw.githubusercontent.com/dogacel/pg_test_table_track/main/install_docker.sh | bash -s $DB_CONTAINER_NAME $DB_NAME $POSGRES_USER
```
