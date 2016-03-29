-- http://postgrest.com/examples/users/

-- parameters
-- {
--     "DATABASE": 'activities',
--     "LC_COLLATE": 'cs_CZ.UTF-8',
--     "LC_CTYPE": 'cs_CZ.UTF-8'
-- }

-- CREATE DATABASE activities
--   WITH OWNER = postgres
--        ENCODING = 'UTF8'
--        TABLESPACE = pg_default
--        LC_COLLATE = 'cs_CZ.UTF-8'
--        LC_CTYPE = 'cs_CZ.UTF-8'
--        CONNECTION LIMIT = -1;


#########################
-- SWITCH TO activities
#########################





-- We create a database schema especially for auth information. We'll also need the postgres extension pgcrypto.

create extension if not exists pgcrypto;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- We put things inside the basic_auth schema to hide
-- them from public view. Certain public procs/views will
-- refer to helpers and tables inside.
create schema if not exists basic_auth;

-- Next a table to store the mapping from usernames and passwords to database roles. The code below includes triggers and functions to encrypt the password and ensure the role exists.

create table if not exists
basic_auth.users (
  email    text primary key check ( email ~* '^.+@.+\..+$' ),
  pass     text not null check (length(pass) < 512),
  role     name not null check (length(role) < 512),
  verified boolean not null default false
  -- If you like add more columns, or a json column
);

create or replace function
basic_auth.check_role_exists() returns trigger
  language plpgsql
  as $$
begin
  if not exists (select 1 from pg_roles as r where r.rolname = new.role) then
    raise foreign_key_violation using message =
      'unknown database role: ' || new.role;
    return null;
  end if;
  return new;
end
$$;

drop trigger if exists ensure_user_role_exists on basic_auth.users;
create constraint trigger ensure_user_role_exists
  after insert or update on basic_auth.users
  for each row
  execute procedure basic_auth.check_role_exists();

create or replace function
basic_auth.encrypt_pass() returns trigger
  language plpgsql
  as $$
begin
  if tg_op = 'INSERT' or new.pass <> old.pass then
    new.pass = crypt(new.pass, gen_salt('bf'));
  end if;
  return new;
end
$$;

drop trigger if exists encrypt_pass on basic_auth.users;
create trigger encrypt_pass
  before insert or update on basic_auth.users
  for each row
  execute procedure basic_auth.encrypt_pass();

-- With the table in place we can make a helper to check passwords. It returns the database role for a user if the email and password are correct.

create or replace function
basic_auth.user_role(email text, pass text) returns name
  language plpgsql
  as $$
begin
  return (
  select role from basic_auth.users
   where users.email = user_role.email
     and users.pass = crypt(user_role.pass, users.pass)
  );
end;
$$;

-- Password Reset
-- When a user requests a password reset or signs up we create a token they will use later to prove their identity. The tokens go in this table.

drop type if exists token_type_enum cascade;
create type token_type_enum as enum ('validation', 'reset');

create table if not exists
basic_auth.tokens (
  token       uuid primary key,
  token_type  token_type_enum not null,
  email       text not null references basic_auth.users (email)
                on delete cascade on update cascade,
  created_at  timestamptz not null default current_date
);

-- In the main schema (as opposed to the basic_auth schema) we expose a password reset request function. HTTP clients will call it. The function takes the email address of the user.
create or replace function
request_password_reset(email text) returns void
  language plpgsql
  as $$
declare
  tok uuid;
begin
  delete from basic_auth.tokens
   where token_type = 'reset'
     and tokens.email = request_password_reset.email;

  select gen_random_uuid() into tok;
  insert into basic_auth.tokens (token, token_type, email)
         values (tok, 'reset', request_password_reset.email);
  perform pg_notify('reset',
    json_build_object(
      'email', request_password_reset.email,
      'token', tok,
      'token_type', 'reset'
    )::text
  );
end;
$$;

-- This function does not send any emails. It sends a postgres NOTIFY command. External programs such as a mailer listen for this event and do the work. The most robust way to process these signals is by pushing them onto work queues. Here are two programs to do that:
--     aweber/pgsql-listen-exchange for RabbitMQ
--     SpiderOak/skeeter for ZeroMQ
-- For experimentation you don't need that though. Here's a sample Node program that listens for the events and logs them to stdout.
-- var PS = require('pg-pubsub');
-- if(process.argv.length !== 3) {
--   console.log("USAGE: DB_URL");
--   process.exit(2);
-- }
-- var url  = process.argv[2],
--     ps   = new PS(url);
-- // password reset request events
-- ps.addChannel('reset', console.log);
-- // email validation required event
-- ps.addChannel('validate', console.log);
-- // modify me to send emails

-- Once the user has a reset token they can use it as an argument to the password reset function, calling it through the PostgREST RPC interface.
create or replace function
reset_password(email text, token uuid, pass text)
  returns void
  language plpgsql
  as $$
declare
  tok uuid;
begin
  if exists(select 1 from basic_auth.tokens
             where tokens.email = reset_password.email
               and tokens.token = reset_password.token
               and token_type = 'reset') then
    update basic_auth.users set pass=reset_password.pass
     where users.email = reset_password.email;

    delete from basic_auth.tokens
     where tokens.email = reset_password.email
       and tokens.token = reset_password.token
       and token_type = 'reset';
  else
    raise invalid_password using message =
      'invalid user or token';
  end if;
  delete from basic_auth.tokens
   where token_type = 'reset'
     and tokens.email = reset_password.email;

  select uuid_generate_v4() into tok;
  insert into basic_auth.tokens (token, token_type, email)
         values (tok, 'reset', reset_password.email);
  perform pg_notify('reset',
    json_build_object(
      'email', reset_password.email,
      'token', tok
    )::text
  );
end;
$$;

-- Email Validation
-- This is similar to password resets. Once again we generate a token. It differs in that there is a trigger to send validations when a new login is added to the users table.
create or replace function
basic_auth.send_validation() returns trigger
  language plpgsql
  as $$
declare
  tok uuid;
begin
  select uuid_generate_v4() into tok;
  insert into basic_auth.tokens (token, token_type, email)
         values (tok, 'validation', new.email);
  perform pg_notify('validate',
    json_build_object(
      'email', new.email,
      'token', tok,
      'token_type', 'validation'
    )::text
  );
  return new;
end
$$;

drop trigger if exists send_validation on basic_auth.users;
create trigger send_validation
  after insert on basic_auth.users
  for each row
  execute procedure basic_auth.send_validation();

  -- Editing Own User
  -- We'll construct a redacted view for users. It hides passwords and shows only those users whose roles the currently logged in user has db permission to access.
  create or replace view users as
select actual.role as role,
       '***'::text as pass,
       actual.email as email,
       actual.verified as verified
from basic_auth.users as actual,
     (select rolname
        from pg_authid
       where pg_has_role(current_user, oid, 'member')
     ) as member_of
where actual.role = member_of.rolname;
  -- can also add restriction that current_setting('postgrest.claims.email')
  -- is equal to email so that user can only see themselves

-- Using this view clients can see themeslves and any other users with the right db roles. This view does not yet support inserts or updates because not all the columns refer directly to underlying columns. Nor do we want it to be auto-updatable because it would allow an escalation of privileges. Someone could update their own row and change their role to become more powerful.
-- We'll handle updates with a trigger, but we'll need a helper function to prevent an escalation of privileges.
create or replace function
basic_auth.clearance_for_role(u name) returns void as
$$
declare
  ok boolean;
begin
  select exists (
    select rolname
      from pg_authid
     where pg_has_role(current_user, oid, 'member')
       and rolname = u
  ) into ok;
  if not ok then
    raise invalid_password using message =
      'current user not member of role ' || u;
  end if;
end
$$ LANGUAGE plpgsql;

-- With the above function we can now make a safe trigger to allow user updates.
create or replace function
update_users() returns trigger
language plpgsql
AS $$
begin
  if tg_op = 'INSERT' then
    perform basic_auth.clearance_for_role(new.role);

    insert into basic_auth.users
      (role, pass, email, verified)
    values
      (new.role, new.pass, new.email,
      coalesce(new.verified, false));
    return new;
  elsif tg_op = 'UPDATE' then
    -- no need to check clearance for old.role because
    -- an ineligible row would not have been available to update (http 404)
    perform basic_auth.clearance_for_role(new.role);

    update basic_auth.users set
      email  = new.email,
      role   = new.role,
      pass   = new.pass,
      verified = coalesce(new.verified, old.verified, false)
      where email = old.email;
    return new;
  elsif tg_op = 'DELETE' then
    -- no need to check clearance for old.role (see previous case)

    delete from basic_auth.users
     where basic_auth.email = old.email;
    return null;
  end if;
end
$$;

drop trigger if exists update_users on users;
create trigger update_users
  instead of insert or update or delete on
    users for each row execute procedure update_users();

-- Permissions 1
-- Basic table-level permissions. We'll add an the authenticator role which can't do anything itself other than switch into other roles as directed by JWT.
create role anon;
create role authenticator noinherit;
grant anon to authenticator;

grant usage on schema public, basic_auth to anon;

-- Finally add a public function people can use to sign up. You can hard code a default db role in it. It alters the underlying basic_auth.users so you can set whatever role you want without restriction.
create or replace function
signup(email text, pass text) returns void
as $$
  insert into basic_auth.users (email, pass, role) values
    (signup.email, signup.pass, 'anon');
$$ language sql;


-- Generating JWT
-- As mentioned at the start, clients authenticate with JWT. PostgREST has a special convention to allow your sql functions to return JWT. Any function that returns a type whose name ends in jwt_claims will have its return value encoded. For instance, let's make a login function which consults our users table.
-- First create a return type:
drop type if exists basic_auth.jwt_claims cascade;
create type basic_auth.jwt_claims AS (role text, email text);

-- And now the function:
create or replace function
login(email text, pass text) returns basic_auth.jwt_claims
  language plpgsql
  as $$
declare
  _role name;
  result basic_auth.jwt_claims;
begin
  select basic_auth.user_role(email, pass) into _role;
  if _role is null then
    raise invalid_password using message = 'invalid user or password';
  end if;
  -- TODO; check verified flag if you care whether users
  -- have validated their emails
  select _role as role, login.email as email into result;
  return result;
end;
$$;

-- An API request to login would look like this.
-- POST /rpc/login
-- { "email": "foo@bar.com", "pass": "foobar" }
-- Response
-- {
--   "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJlbWFpbCI6ImZvb0BiYXIuY29tIiwicm9sZSI6ImF1dGhvciJ9.KHwYdK9dAMAg-MGCQXuDiFuvbmW-y8FjfYIcMrETnto"
-- }
-- Try decoding the token at jwt.io. (It was encoded with a secret of secret which is the default.) To use this token in a future API request include it in an Authorization request header.
-- Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJlbWFpbCI6ImZvb0BiYXIuY29tIiwicm9sZSI6ImF1dGhvciJ9.KHwYdK9dAMAg-MGCQXuDiFuvbmW-y8FjfYIcMrETnto

-- Same-Role Users
-- You may not want a separate db role for every user. You can distinguish one user from another in SQL by examining the JWT claims which PostgREST makes available in the SQL variable postgrest.claims. Here's a function to get the email of the currently authenticated user.
create or replace function
basic_auth.current_email() returns text
  language plpgsql
  as $$
begin
  return current_setting('postgrest.claims.email');
exception
  -- handle unrecognized configuration parameter error
  when undefined_object then return '';
end;
$$;
-- Remember that the login function set the claims email and role. You can modify login to set other claims as well if they are useful for your other SQL functions to reference later.


-- Permissions 2
-- Basic table-level permissions. We'll add an the authenticator role which can't do anything itself other than switch into other roles as directed by JWT.
-- anon can create new logins
grant insert on table basic_auth.users, basic_auth.tokens to anon;
grant select on table pg_authid, basic_auth.users to anon;
grant execute on function
  login(text,text),
  request_password_reset(text),
  reset_password(text,uuid,text),
  signup(text, text)
  to anon;

-- Conclusion
-- This section explained the implementation details for building a password based authentication system in pure sql. The next example will put it to work in a multi-tenant blogging API.




-- ACTIVITIES
SET timezone = 'UTC'

-- as we will transfer ids from api.parldata.eu, we will use integer for id, otherwise would be bigserial:
create table if not exists
people (
  id         integer primary key,
  family_name   text not null,
  given_name    text not null,
  attributes    jsonb
);

-- as we will transfer ids from api.parldata.eu, we will use integer for id, otherwise would be bigserial:
create table if not exists
organizations (
  id         integer primary key,
  name   text not null,
  classification    text not null,
  founding_date date not null,
  dissolution_date  date,
  attributes jsonb
);

create table if not exists
    memberships (
        person_id   integer,
        organization_id integer,
        start_date  date not null,
        end_date    date,
        constraint memberships_pkey primary key (person_id,organization_id,start_date),
        CONSTRAINT memberships_person_id_fkey FOREIGN KEY (person_id)
            REFERENCES public.people (id) MATCH SIMPLE
            ON UPDATE NO ACTION ON DELETE NO ACTION,
        CONSTRAINT memberships_organization_id_fkey FOREIGN KEY (organization_id)
            REFERENCES public.organizations (id) MATCH SIMPLE
            ON UPDATE NO ACTION ON DELETE NO ACTION
    );

create table if not exists
    activities (
        id  bigserial primary key,
        classification   text not null,
        name   text,
        start_date  timestamp with time zone,
        source_code text,
        attributes jsonb,
        constraint activities_pkey unique (classification, source_code)
    );

create table if not exists
    activityships (
        person_id   integer not null,
        activity_id integer not null,
        constraint activityships_pkey primary key (person_id,activity_id),
        CONSTRAINT activityships_person_id_fkey FOREIGN KEY (person_id)
            REFERENCES public.people (id) MATCH SIMPLE
            ON UPDATE NO ACTION ON DELETE NO ACTION,
        CONSTRAINT activityships_activities_id_fkey FOREIGN KEY (activity_id)
            REFERENCES public.activities (id) MATCH SIMPLE
            ON UPDATE NO ACTION ON DELETE NO ACTION
    );


CREATE OR REPLACE VIEW public.people_in_organizations AS
    SELECT tpeople.id, tpeople.family_name, tpeople.given_name, tpeople.attributes,
    torganizations.id as organization_id,torganizations.name as organization_name,
    torganizations.attributes as organization_attributes,
    tmemberships.start_date,tmemberships.end_date
    FROM people as tpeople
    LEFT JOIN memberships as tmemberships
    ON tpeople.id = tmemberships.person_id
    LEFT JOIN organizations as torganizations
    ON tmemberships.organization_id = torganizations.id

CREATE OR REPLACE VIEW public.people_in_political_groups AS
    SELECT tpeople.id,
       tpeople.family_name,
       tpeople.given_name,
       tpeople.attributes,
       torganizations.id AS organization_id,
       torganizations.name AS organization_name,
       torganizations.attributes AS organization_attributes,
       tmemberships.start_date,
       tmemberships.end_date
      FROM people tpeople
        LEFT JOIN memberships tmemberships ON tpeople.id = tmemberships.person_id
        LEFT JOIN organizations torganizations ON tmemberships.organization_id = torganizations.id
     WHERE torganizations.classification = 'political group'::text;

-- Permissions
--
-- On top of the authenticator and anon access granted in the previous example, blogs have an author role with extra permissions.
create role author;
grant author to authenticator;

-- authors can edit comments/posts
grant select, insert, update, delete
  on basic_auth.tokens, basic_auth.users to author;
-- grant select, insert, update, delete
--   on table people, organizations, memberships, activities, activityships, people to author;
grant select, insert, update, delete
    on all tables in schema public to author;

grant select
    on all tables in schema public to anon;

grant usage, select on sequence activities_id_seq to author;
grant usage on schema public, basic_auth to anon, author;

-- Finally we need to modify the users view from the previous example. This is because all authors share a single db role. We could have chosen to assign a new role for every author (all inheriting from author) but we choose to tell them apart by their email addresses. The addition below prevents authors from seeing each others' info in the users view.
create or replace view users as
  select actual.role as role,
         '***'::text as pass,
         actual.email as email,
         actual.verified as verified
  from basic_auth.users as actual,
       (select rolname
          from pg_authid
         where pg_has_role(current_user, oid, 'member')
       ) as member_of
  where actual.role = member_of.rolname
  and (
      actual.role <> 'author'
      or email = basic_auth.current_email()
  );

 #    # # ###### #    #  ####
 #    # # #      #    # #
 #    # # #####  #    #  ####
 #    # # #      # ## #      #
  #  #  # #      ##  ## #    #
   ##   # ###### #    #  ####
--Views

-- Current MPs
-- DROP VIEW public.current_people;

CREATE OR REPLACE VIEW public.current_people AS
 SELECT p.id AS person_id,
    p.family_name,
    p.given_name,
    p.attributes AS person_attributes,
    m.start_date AS person_current_chamber_start_date,
    round(date_part('epoch'::text, age(m.start_date) / 3600::double precision / 24::double precision)) AS duration_in_current_chamber,
    o2.id AS political_group_id,
    o2.name AS political_group_name,
    m2.start_date AS person_current_politicial_group_start_date,
    o2.attributes AS political_group_attributes,
    o3.id AS region_id,
    o3.name AS region_name,
    o3.attributes AS region_attributes
   FROM people p
     LEFT JOIN memberships m ON p.id = m.person_id
     LEFT JOIN organizations o ON m.organization_id = o.id
     LEFT JOIN memberships m2 ON p.id = m2.person_id
     LEFT JOIN organizations o2 ON m2.organization_id = o2.id
     LEFT JOIN memberships m3 ON p.id = m3.person_id
     LEFT JOIN organizations o3 ON m3.organization_id = o3.id
  WHERE m.end_date IS NULL AND o.classification = 'chamber'::text AND m2.end_date IS NULL AND m3.end_date IS NULL AND o2.classification = 'political group'::text AND o3.classification = 'region'::text;

ALTER TABLE public.current_people
  OWNER TO postgres;
GRANT ALL ON TABLE public.current_people TO postgres;
GRANT SELECT ON TABLE public.current_people TO anon;
GRANT SELECT ON TABLE public.current_people TO author;

-- Current political groups
-- DROP VIEW public.current_political_groups;
CREATE OR REPLACE VIEW public.current_political_groups AS
    SELECT *
    FROM organizations
    WHERE classification='political group'
    AND dissolution_date is NULL;

    ALTER TABLE public.current_political_groups
      OWNER TO postgres;
    GRANT ALL ON TABLE public.current_political_groups TO postgres;
    GRANT SELECT ON TABLE public.current_political_groups TO anon;
    GRANT SELECT ON TABLE public.current_political_groups TO author;


-- Activities of current MPs in current term
-- Note: Bill proposals with more authors are there several times, one replication for each author
-- DROP VIEW public.current_activities_of_current_people;
CREATE OR REPLACE VIEW public.current_activities_of_current_people AS
    SELECT
    cp.person_id,
    cp.family_name,
    cp.given_name,
    a.id as activity_id,
    a.name as activity_name,
    a.start_date as activity_start_date,
    a.source_code as activity_source_code,
    a.classification as activity_classification,
    a.attributes as activity_attributes
    FROM current_people as cp
    LEFT JOIN activityships as s
    ON cp.person_id = s.person_id
    LEFT JOIN activities as a
    ON a.id = s.activity_id
    WHERE cp.person_current_chamber_start_date < a.start_date;

    ALTER TABLE public.current_activities_of_current_people
      OWNER TO postgres;
    GRANT ALL ON TABLE public.current_activities_of_current_people TO postgres;
    GRANT SELECT ON TABLE public.current_activities_of_current_people TO anon;
    GRANT SELECT ON TABLE public.current_activities_of_current_people TO author;


-- Bill proposals as first author of current MPs in current term
--DROP VIEW public.current_bill_proposals_as_first_author_of_current_people;
CREATE OR REPLACE VIEW public.current_bill_proposals_as_first_author_of_current_people AS
    SELECT *
    FROM current_activities_of_current_people
    WHERE activity_classification = 'bill proposal'
    AND activity_attributes->'people'->'person_ids'->>0 = cast(person_id as text);

    ALTER TABLE public.current_bill_proposals_as_first_author_of_current_people
      OWNER TO postgres;
    GRANT ALL ON TABLE public.current_bill_proposals_as_first_author_of_current_people TO postgres;
    GRANT SELECT ON TABLE public.current_bill_proposals_as_first_author_of_current_people TO anon;
    GRANT SELECT ON TABLE public.current_bill_proposals_as_first_author_of_current_people TO author;

-- Number of activities per person of current MPs in current term
-- DROP VIEW public.number_of_current_activities_of_current_people;
CREATE OR REPLACE VIEW public.number_of_current_activities_of_current_people AS
    SELECT
        person_id,
        activity_classification,
        count(*) as count
    FROM current_activities_of_current_people as cacp
    GROUP BY person_id, activity_classification
    ORDER BY count DESC

    ALTER TABLE public.number_of_current_activities_of_current_people
      OWNER TO postgres;
    GRANT ALL ON TABLE public.number_of_current_activities_of_current_people TO postgres;
    GRANT SELECT ON TABLE public.number_of_current_activities_of_current_people TO anon;
    GRANT SELECT ON TABLE public.number_of_current_activities_of_current_people TO author;

-- Number of bill proposals as first author of current MPs in current ter
-- DROP VIEW public.number_of_current_bill_proposals_as_facp;
CREATE OR REPLACE VIEW number_of_current_bill_proposals_as_facp AS
    SELECT
        person_id,
        count(*) as count
    FROM current_activities_of_current_people as cacp
    WHERE activity_classification = 'bill proposal'
    AND activity_attributes->'people'->'person_ids'->>0 = cast(person_id as text)
    GROUP BY person_id
    ORDER BY count DESC

    ALTER TABLE public.number_of_current_bill_proposals_as_facp
      OWNER TO postgres;
    GRANT ALL ON TABLE public.number_of_current_bill_proposals_as_facp TO postgres;
    GRANT SELECT ON TABLE public.number_of_current_bill_proposals_as_facp TO anon;
    GRANT SELECT ON TABLE public.number_of_current_bill_proposals_as_facp TO author;


-- Quantiles
--DROP TYPE activity_quantile CASCADE;
--DROP TYPE activity_classification CASCADE;
CREATE TYPE activity_quantile AS (activity_classification text, quantile float, count integer);
CREATE TYPE activity_classification AS (activity_classification text);

-- DROP FUNCTION activity_quantiles();
CREATE OR REPLACE FUNCTION activity_quantiles() RETURNS SETOF activity_quantile AS
$BODY$
    DECLARE
    	a activity_quantile%rowtype;
    	b activity_classification%rowtype;
    	qs float[] := array[0.2,0.33,0.4,0.5,0.6,0.67,0.8,1];
    	q float;
    BEGIN

        -- ordinary activities
        FOREACH q IN ARRAY qs
    	LOOP
        FOR b IN
            SELECT distinct(activity_classification) FROM current_activities_of_current_people
    		LOOP
    			FOR a IN
    				SELECT * FROM
    				(SELECT b.activity_classification::text as activity_classification, q::float as quantile, count::integer
    				FROM number_of_current_activities_of_current_people
    				WHERE activity_classification = b.activity_classification
    				OFFSET round((SELECT count(*) FROM current_people)*q)
    				LIMIT 1) as t1
    				UNION ALL

    				SELECT * FROM (
    				SELECT b.activity_classification::text as activity_classification, q::float as quantile, 0::integer as count
    				WHERE NOT EXISTS
    					(
    					SELECT count
    					FROM number_of_current_activities_of_current_people
    					WHERE activity_classification = b.activity_classification
    					OFFSET round((SELECT count(*) FROM current_people)*q)
    					)
    				) as t2
    			LOOP
    				RETURN NEXT a;
    			END LOOP;
    		END LOOP;

        -- bill proposal as first author
    	FOR a IN
    		SELECT * FROM(
    		SELECT
    			'bill proposal as first author'::text,
    			q::float as quantile,
    			count::integer
    		FROM
    			number_of_current_bill_proposals_as_facp
    		OFFSET round((SELECT count(*) FROM current_people)*q)
    		LIMIT 1) as t3
    		UNION ALL
    		SELECT * FROM (
    				SELECT
    				'bill proposal as first author'::text,
    				q::float as quantile,
    				0::integer
    			WHERE NOT EXISTS (
    				SELECT count
    				FROM number_of_current_bill_proposals_as_facp
    				OFFSET round((SELECT count(*) FROM current_people)*q)
    			)
    		) as t4
    		LOOP
    			RETURN NEXT a;
    		END LOOP;
    	END LOOP;
    END
$BODY$
LANGUAGE plpgsql;

ALTER FUNCTION public.activity_quantiles()
  OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.activity_quantiles() TO postgres;
GRANT EXECUTE ON FUNCTION public.activity_quantiles() TO anon;
GRANT EXECUTE ON FUNCTION public.activity_quantiles() TO author;

--SELECT * FROM activity_quantiles();

-- DROP MATERIALIZED VIEW activity_quantiles;
CREATE MATERIALIZED VIEW activity_quantiles AS
	SELECT * FROM activity_quantiles()

    ALTER TABLE public.activity_quantiles OWNER TO postgres;
    GRANT ALL ON TABLE public.activity_quantiles TO postgres;
    GRANT SELECT ON TABLE public.activity_quantiles TO anon;
    GRANT SELECT ON TABLE public.activity_quantiles TO author;


-- Activity with its quantiles for current MPs
-- DROP VIEW current_people_activity_quantiles;
CREATE OR REPLACE VIEW current_people_activity_quantiles AS
    -- ordinary activities
    SELECT
    	n.person_id,
    	qs.activity_classification,
    	max(n.count) as count,
    	min(qs.quantile) as quantile,
    	max(qs.count) as quantile_count
    FROM
    activity_quantiles as qs
    LEFT JOIN
    number_of_current_activities_of_current_people as n
    ON n.activity_classification = qs.activity_classification
    WHERE n.count >= qs.count
    --AND n.activity_classification = 'oral interpellation'
    GROUP BY qs.activity_classification, person_id
UNION ALL
    -- bill proposal as first author
    SELECT
    	n.person_id,
    	'bill proposal as first author',
    	max(n.count) as count,
    	min(qs.quantile) as quantile,
    	max(qs.count) as quantile_count
     FROM
    activity_quantiles as qs
    CROSS JOIN
    number_of_current_bill_proposals_as_facp as n
    WHERE qs.activity_classification = 'bill proposal as first author'
    AND n.count >= qs.count
    GROUP BY person_id
    ORDER BY person_id;

    ALTER TABLE public.current_people_activity_quantiles
      OWNER TO postgres;
    GRANT ALL ON TABLE public.current_people_activity_quantiles TO postgres;
    GRANT SELECT ON TABLE public.current_people_activity_quantiles TO anon;
    GRANT SELECT ON TABLE public.current_people_activity_quantiles TO author;

-- Traffic lights
-- DROP VIEW current_people_traffic_lights;
CREATE OR REPLACE VIEW current_people_traffic_lights AS
    SELECT
    	cp.person_id,
    	cacp.activity_classification,
    	--pa.count,
    	CASE
    		WHEN LEAST(pa.quantile,1) <= 0.33 THEN 'green'
    		WHEN LEAST(pa.quantile,1) <= 0.67 THEN 'yellow'
    		ELSE 'red'
    	END as traffic_light
    FROM current_people as cp
    CROSS JOIN
    (SELECT distinct(activity_classification) FROM current_activities_of_current_people
	UNION ALL
	SELECT 'bill proposal as first author'::text WHERE NOT EXISTS (SELECT * FROM people WHERE 0=1)
    )
    as cacp
    LEFT JOIN
    current_people_activity_quantiles AS pa
    ON cp.person_id = pa.person_id AND cacp.activity_classification = pa.activity_classification;

    ALTER TABLE public.current_people_traffic_lights
      OWNER TO postgres;
    GRANT ALL ON TABLE public.current_people_traffic_lights TO postgres;
    GRANT SELECT ON TABLE public.current_people_traffic_lights TO anon;
    GRANT SELECT ON TABLE public.current_people_traffic_lights TO author;

-- Stars
-- DROP VIEW current_people_stars;
CREATE OR REPLACE VIEW current_people_stars AS
    SELECT
    	cp.person_id,
    	cacp.activity_classification,
    	--pa.count,
    	CASE
    		WHEN LEAST(pa.quantile,1) <= 0.2 THEN 5
    		WHEN LEAST(pa.quantile,1) <= 0.4 THEN 4
            WHEN LEAST(pa.quantile,1) <= 0.6 THEN 3
            WHEN LEAST(pa.quantile,1) <= 0.8 THEN 2
    		ELSE 1
    	END as stars
    FROM current_people as cp
    CROSS JOIN
    (SELECT distinct(activity_classification) FROM current_activities_of_current_people
	UNION ALL
	SELECT 'bill proposal as first author'::text WHERE NOT EXISTS (SELECT * FROM people WHERE 0=1)
    )
    as cacp
    LEFT JOIN
    current_people_activity_quantiles AS pa
    ON cp.person_id = pa.person_id AND cacp.activity_classification = pa.activity_classification;

    ALTER TABLE public.current_people_stars
      OWNER TO postgres;
    GRANT ALL ON TABLE public.current_people_stars TO postgres;
    GRANT SELECT ON TABLE public.current_people_stars TO anon;
    GRANT SELECT ON TABLE public.current_people_stars TO author;

-- function to refresh the view on every update of activities
-- DROP FUNCTION refresh_current_people_activity_quantiles();
CREATE OR REPLACE FUNCTION refresh_current_people_activity_quantiles() RETURNS TRIGGER AS
	$$
	BEGIN
        REFRESH MATERIALIZED VIEW activity_quantiles;
	END;
	$$
	LANGUAGE plpgsql;

    ALTER FUNCTION public.refresh_current_people_activity_quantiles()
      OWNER TO postgres;
    GRANT EXECUTE ON FUNCTION public.refresh_current_people_activity_quantiles() TO postgres;
    GRANT EXECUTE ON FUNCTION public.refresh_current_people_activity_quantiles() TO anon;
    GRANT EXECUTE ON FUNCTION public.refresh_current_people_activity_quantiles() TO author;

CREATE TRIGGER refresh_current_people_activity_quantiles
	AFTER UPDATE ON activities
	EXECUTE PROCEDURE refresh_current_people_activity_quantiles();
