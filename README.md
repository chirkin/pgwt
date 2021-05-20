# PGWT (PostgreSQL Web Tool)

This project is still under early development and is not fully production-ready, you probably should well understand how it works if you want to use it in production.

## Motivation

Wouldn't it be nice to be able to handle HTTP requests inside PostgreSQL?
This is the tool that does just that.

## Why you need it

Classic backend implementation using PostgreSQL as data store implements business logic on its side. However, in pursuit of production, optimization and rationalization, part of the business logic tends to be implemented on the database side in the form of triggers, stored procedures etc. So why not transfer all the business logic of your project to the database? In fact, this is a good idea in many cases, and it served as the starting point for the implementation of this project.

It is possible to implement business logic in stored procedures, but if you ever need to handle HTTP requests or implement a restful API for your database, you will need middleware. This project serves as one of such possible implementations.

## How it works

To show you the basic idea, here is an example of a simple request handler. It is a PL/pgSQL procedure:

```sql
CREATE OR REPLACE FUNCTION www_main.index(IN _pgwt.request, OUT _pgwt.response)
  LANGUAGE plpgsql
AS $$
--
-- Index page
--
-- uri: /
-- methods: GET
--
BEGIN
  $2.body = 'Hello from PGWT!';
  $2.headers = json_build_object('Content-Type', 'text/html');
END;
$$;
```

PGWT handles requests via [Openresty](https://openresty.org) because it offers the power of `Nginx` and other useful things. You can control the request processing and modify the handler if you wish. You will also be able to implement specific endpoints in your API that PGWT is not intended for (e.g. file uploading/downloading).

## Concepts

While implementing a RESTful API, you may face a problem with several different zones (e.g. public and administrative) using common mechanisms for request processing, authentication etc. PGWT uses the term `area` and the `$pgwt_area` variable defined inside the Nginx `location` accepted by the request handler. You can implement any number of nginx locations using a custom configuration for different areas. For PGWT, the API zone is represented as a database schema with the name `www_[area]`, for example [a4irkin/pgwt](https://hub.docker.com/r/a4irkin/pgwt) docker image is configured to handle only one area (`main`), so the database needs a `www_main` schema present.

Each HTTP request is passed to the `pgwt.request()` function, where routing takes place based on the request type and URL path, as well as `area`. After successful routing, the request goes to the API area handler function. You can customize the request handler: `www_[area].request_handler(_pgwt.request, _pgwt.response)`. If you don't, the default handler will be used.

Every time you add or remove an endpoint handler function or change it, you need to call `pgwt.init()` so PGWT can parse endpoint functions and rebuild a route table. The endpoint handler function header has a special format:

```
--
-- Endpoint description
--
-- uri: [regexp string]
-- methods: [GET|POST|PATCH|PUT|DELETE|OPTIONS]
-- custom_attributeN: value
--
```

The title goes first, then the endpoint attributes. Required attributes: `uri`,` methods`. You can define custom attributes for an area and get them in the area request handler function, I will showcase this in the examples.

## Installation

You can install the PGWT request handler in the `lua` directory of your Openresty server and implement an Nginx `location` so that the PGWT can accept requests to the database. You can also use the ready-to-use [a4irkin/pgwt](https://hub.docker.com/r/a4irkin/pgwt) docker image.

```shell
docker network create pgwt

docker run -itd \
  --name postgres \
  --network=pgwt \
  -p 5432:5432 \
  -e POSTGRES_PASSWORD=test \
  postgres:latest

docker run -itd \
  --name pgwt-openresty \
  --network=pgwt \
  -p 8080:8080 \
  -e PGWT_CONN_HOST=postgres \
  -e PGWT_CONN_DB=postgres \
  -e PGWT_CONN_USER=postgres \
  -e PGWT_CONN_PASSWORD=test \
  a4irkin/pgwt:latest
```

You also need to install PGWT in PostgreSQL:

```shell
cd src
psql -h localhost -U postgres -1f deploy.sql -v schema_owner=postgres
```

## Examples

You can find some examples in the examples directory of this project. Let's look at the simplest example of using PGWT. To do this, we will create a `www_main` schema in the database. This schema will store the main area endpoint handlers:

```sql
CREATE SCHEMA www_main;
```

Let's define our first API endpoint function:

```sql
CREATE OR REPLACE FUNCTION www_main.first(IN _pgwt.request, OUT _pgwt.response)
  LANGUAGE plpgsql
AS $$
--
-- First endpoint
--
-- uri: /first
-- methods: GET
--
DECLARE
  a_arg1 text = $1.args->>'arg1';
BEGIN
  $2.body = 'Hello, arg1 = '||COALESCE(a_arg1, 'null');
  $2.headers = json_build_object('Content-Type', 'text/html');
END;
$$;
```

Now, we need PGWT to see our new function and build routes:

```sql
SELECT pgwt.init();
```

Now you can check this:

```shell
curl http://localhost:8080/first?arg1=works
```

As mentioned earlier, you can define custom attributes for functions which describe area endpoints by defining the `func_attrs` table in the `area` schema, inheriting it from `pgwt.func_attrs`. Let's suppose some endpoints are private, for this we define the attribute `priv`:

```sql
CREATE TABLE www_main.func_attrs() INHERITS (pgwt.func_attrs);
INSERT INTO www_main.func_attrs (nm, multiple, acceptable_values) VALUES
  ('priv', false, '{true}')
;
```

You should now be able to add a new `priv` attribute to your endpoint functions:

```sql
CREATE OR REPLACE FUNCTION www_main.private(IN _pgwt.request, OUT _pgwt.response)
  LANGUAGE plpgsql
AS $$
--
-- Private endpoint
--
-- uri: /private
-- methods: GET
-- priv: true
--
BEGIN
  $2.body = json_build_object('message', 'This is a private endpoint');
END;
$$;
```

To implement authentication logic, we can add a custom request handler for the main area:

```sql
CREATE OR REPLACE FUNCTION www_main._request_handler(
  IN _pgwt.request, OUT _pgwt.response
)
 LANGUAGE plpgsql
AS $$
--
-- Custom request handler for main area
--
BEGIN
  IF $1.route.func_attrs ? 'priv' AND NOT $1.cookies ? 'AUTH' THEN
    PERFORM pgwt.http_error(401, 'Unauthorized');
  END IF;

  EXECUTE 'SELECT (r).* FROM '
    ||quote_ident('www_'||$1.area)||'.'
    ||quote_ident($1.route.proname)||'($1) r'
    INTO $2
    USING $1;
END;
$$;
```

Now, endpoint `/private` can be accessed only if AUTH cookie exists.

## Functions

* `pgwt.init()` returns `void` - (re)initialize pgwt routes
* `pgwt.error(a_msg text[, a_code text])` - generate user-level error
* `pgwt.error(a_cond boolean, a_msg text[, a_code text])` - generate user-level
error if condition true
* `pgwt.http_error(a_status int, a_msg text[, a_raw_error boolean = false])` - generate http error
* `pgwt.http_error(a_status int, a_msg json[, a_raw_error boolean = false])` - generate http error
* `pgwt.raise(a_msg text)` - raise exception, visible in response body

## Types

```
                  Composite type "_pgwt.request"
       Column       |    Type     | Collation | Nullable | Default
--------------------+-------------+-----------+----------+---------
 area               | text        |           |          |
 host               | text        |           |          |
 path               | text        |           |          |
 args               | jsonb       |           |          |
 remote_addr        | inet        |           |          |
 remote_host        | text        |           |          |
 user_agent         | text        |           |          |
 cookies            | hstore      |           |          |
 body               | json        |           |          |
 body_raw           | text        |           |          |
 params             | hstore      |           |          |
 method             | text        |           |          |
 server_host        | text        |           |          |
 server_addr        | text        |           |          |
 headers            | json        |           |          |
 route              | _pgwt.route |           |          |
 custom             | jsonb       |           |          |
 resp_headers       | json        |           |          |
 status             | smallint    |           |          |
 body_bytes_sent    | bigint      |           |          |
 request_completion | text        |           |          |
```

```
         Composite type "_pgwt.response"
  Column  |  Type   | Collation | Nullable | Default
----------+---------+-----------+----------+---------
 body     | text    |           |          |
 status   | integer |           |          |
 headers  | jsonb   |           |          |
 commands | jsonb   |           |          |
```

```
              Table "_pgwt.route"
         Column          |  Type   | Collation | Nullable | Default
-------------------------+---------+-----------+----------+---------
 id                      | text    |           | not null |
 nspname                 | text    |           | not null |
 proname                 | text    |           | not null |
 area                    | text    |           | not null |
 nm                      | text    |           | not null |
 comments                | text    |           | not null |
 params                  | text[]  |           | not null |
 regexp_path             | text    |           | not null |
 func_attrs              | jsonb   |           | not null |
 custom_request_handler  | boolean |           | not null | false
 custom_response_handler | boolean |           | not null | false
```

## Recommendations

To make it easier to redeploy database schema, I separate functionality from data. I recommend that you take this approach too. Store all tables in schemas, for example: `_data`, `_usr`, `_sys`, `_etc`. Store functionality in schemas: `data`, `usr`, `sys`, `etc`. This way you can always redeploy functional schemas safely in one transaction. You can use my [pgver](https://github.com/chirkin/pgver) script for this, which is also used by PGWT.

## Security

I recommend that you create a custom role:

```sql
CREATE ROLE nginx WITH LOGIN ENCRYPTED PASSWORD 'password';
GRANT USAGE ON SCHEMA pgwt TO nginx;
GRANT CONNECT TO DATABASE postgres TO nginx;
```

This role will only have access to PGWT functionality. By gaining access to the DB from this role, an attacker will not be able to do anything other than what is provided by your API.
