-------------------------------------------------
----- Drop table, view, function and rule -------
-------------------------------------------------
DROP TABLE IF EXISTS rates CASCADE;
DROP TABLE IF EXISTS books CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS genres CASCADE;
DROP TABLE IF EXISTS authors CASCADE;
DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS shippers CASCADE;
DROP TABLE IF EXISTS addresses CASCADE;
DROP TABLE IF EXISTS discounts CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS employees CASCADE;
DROP TABLE IF EXISTS publishers CASCADE;
DROP TABLE IF EXISTS books_genres CASCADE;
DROP TABLE IF EXISTS books_authors CASCADE;
DROP TABLE IF EXISTS orders_details CASCADE;
DROP TABLE IF EXISTS books_discounts CASCADE;
DROP TABLE IF EXISTS customers_addresses CASCADE;
DROP TABLE IF EXISTS customers_discounts CASCADE;
-------------------------------------------------
DROP FUNCTION IF EXISTS is_phonenumber();
DROP FUNCTION IF EXISTS give_discount();
DROP FUNCTION IF EXISTS is_available();
DROP FUNCTION IF EXISTS has_bought();
DROP FUNCTION IF EXISTS set_rank();
DROP FUNCTION IF EXISTS is_isbn();
DROP FUNCTION IF EXISTS add_price();
DROP FUNCTION IF EXISTS sold_update();
-------------------------------------------------
DROP VIEW IF EXISTS book_adder;
DROP VIEW IF EXISTS books_rank;
--------------------------------f-----------------
DROP RULE IF EXISTS adder
ON book_adder;
-------------------------------------------------
------------- Function of trigger----------------
-------------------------------------------------
-- Before, on reviews: check that the costumer has bought the book that have review.
CREATE OR REPLACE FUNCTION has_bought()
  RETURNS TRIGGER AS $$
BEGIN
  IF (SELECT count(book_id) AS a
      FROM orders_details
        JOIN orders ON orders_details.order_id = orders.id
      WHERE customer_id = new.customer_id AND book_id = new.book_id) = 0
  THEN RAISE EXCEPTION 'CUSTOMER HAS NOT BOUGHT THIS BOOK'; END IF;
  RETURN new;
END; $$LANGUAGE plpgsql;

CREATE or replace FUNCTION has_rated()
  RETURNS TRIGGER AS $$
BEGIN
-- to-do update average
UPDATE books s SET (avg_rate) =
    (SELECT avg(rate) FROM rates d
     WHERE d.book_id = s.isbn);
  RETURN new;
 
END; $$LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sold_update()
RETURNS TRIGGER AS $$
BEGIN
IF(new.state = 'PAID' and old.state = 'AWAITING') THEN
UPDATE books
SET    sold_count = sold_count + (select sum(amount) from orders_details where isbn = book_id)
WHERE  (isbn = (select book_id from orders_details where order_id  = new.id limit 1));
END IF;
return new;
END; $$LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION add_price()
RETURNS TRIGGER AS $$
DECLARE price NUMERIC(10,2);
DECLARE delta_price NUMERIC(10,2);
BEGIN
IF TG_OP = 'UPDATE' THEN
price = (select books.price from books where isbn = old.book_id);
delta_price = (new.amount - old.amount) * price;
update orders
set total_price =  (total_price + delta_price) where id = new.order_id;
END IF;
IF TG_OP = 'INSERT' THEN
price = (select books.price from books where isbn = new.book_id);
delta_price = (new.amount) * price;
update orders
set  total_price =  (total_price + delta_price) where id = new.order_id;
END IF;
return new;
END; $$LANGUAGE plpgsql;


-- Before, on rates: check that the costumer has bought the book that have rated.
CREATE OR REPLACE FUNCTION has_bought_rates()
  RETURNS TRIGGER AS $$
BEGIN
 
  IF (SELECT count(book_id) AS a
      FROM orders_details
        JOIN orders ON orders_details.order_id = orders.id
      WHERE customer_id = new.customer_id AND book_id = new.book_id) = 0
  THEN RAISE EXCEPTION 'CUSTOMER HAS NOT BOUGHT THIS BOOK'; END IF;

  IF (SELECT count(book_id)
      FROM rates
      WHERE
        book_id = new.book_id AND customer_id = new.customer_id) > 0
  THEN
    DELETE FROM rates
    WHERE customer_id = NEW.customer_id AND book_id = NEW.book_id;
  END IF;
 
  RETURN new;
END; $$LANGUAGE plpgsql;

-- Before, on orders: give the max(discount) for give costumer discount in new order.
CREATE OR REPLACE FUNCTION give_discount()
  RETURNS TRIGGER AS $$
DECLARE id  BIGINT DEFAULT NULL;
        val NUMERIC DEFAULT NULL;
BEGIN
  val = (SELECT max(discounts.value)
         FROM discounts
           JOIN customers_discounts ON discounts.id = customers_discounts.discount_id
         WHERE customer_id = new.customer_id);
  id = (SELECT discounts.id
        FROM discounts
          JOIN customers_discounts ON discounts.id = customers_discounts.discount_id
        WHERE customer_id = new.customer_id AND discounts.value = val);
  new.discount_id = id;
  RETURN new;
END; $$LANGUAGE plpgsql;

-- Before, on shipper and costumer: validate phone number.
CREATE OR REPLACE FUNCTION is_phonenumber()
  RETURNS TRIGGER AS $$
DECLARE
    tmp NUMERIC;
BEGIN
  IF (length(new.phone_number) != 11)
    THEN RAISE EXCEPTION 'INVALID PHONE NUMBER: length';
  END IF;
  tmp = new.phone_number :: NUMERIC;
  RETURN new;
  EXCEPTION WHEN invalid_text_representation
  THEN RAISE EXCEPTION 'INVALID PHONE NUMBER: not numeric';
END; $$LANGUAGE plpgsql;

-- Before, on book: validate ISBN.
--https://en.wikipedia.org/wiki/International_Standard_Book_Number#ISBN-10_check_digit_calculation
CREATE OR REPLACE FUNCTION is_isbn()
  RETURNS TRIGGER AS $$
DECLARE tmp NUMERIC DEFAULT 11;
BEGIN
  --isbn10 format: x-xxx-xxxxx-x
  -- tmp is 11-remainder, so last char should equal tmp
  IF (length(new.isbn) = 13)
  THEN tmp = (11 - (
                     substr(NEW.isbn, 1, 1) :: NUMERIC * 10 +
                     substr(NEW.isbn, 3, 1) :: NUMERIC * 9 +
                     substr(NEW.isbn, 4, 1) :: NUMERIC * 8 +
                     substr(NEW.isbn, 5, 1) :: NUMERIC * 7 +
                     substr(NEW.isbn, 7, 1) :: NUMERIC * 6 +
                     substr(NEW.isbn, 8, 1) :: NUMERIC * 5 +
                     substr(NEW.isbn, 9, 1) :: NUMERIC * 4 +
                     substr(NEW.isbn, 10, 1) :: NUMERIC * 3 +
                     substr(NEW.isbn, 11, 1) :: NUMERIC * 2)
                   % 11) % 11;
                   
  END IF;

  --isbn13 format: xxx-xx-xxxxx-xx-x
  IF ((length(NEW.isbn) = 17
       AND (
             substr(NEW.isbn, 1, 1) :: NUMERIC +
             substr(NEW.isbn, 2, 1) :: NUMERIC * 3 +
             substr(NEW.isbn, 3, 1) :: NUMERIC +
             substr(NEW.isbn, 5, 1) :: NUMERIC * 3 +
             substr(NEW.isbn, 6, 1) :: NUMERIC +
             substr(NEW.isbn, 8, 1) :: NUMERIC * 3 +
             substr(NEW.isbn, 9, 1) :: NUMERIC +
             substr(NEW.isbn, 10, 1) :: NUMERIC * 3 +
             substr(NEW.isbn, 11, 1) :: NUMERIC +
             substr(NEW.isbn, 12, 1) :: NUMERIC * 3 +
             substr(NEW.isbn, 14, 1) :: NUMERIC +
             substr(NEW.isbn, 15, 1) :: NUMERIC * 3)
           % 10 = substr(NEW.isbn, 17, 1) :: NUMERIC)
      OR (length(new.isbn) = 13
          AND ((tmp = 10 AND substr(new.isbn, 13, 1) = 'X'
          )
               OR tmp = substr(NEW.isbn, 13, 1) :: NUMERIC))
  )
  THEN
    RETURN NEW;
  END IF;
  RAISE EXCEPTION 'INVALID ISBN';
END; $$ LANGUAGE plpgsql;


-- After, on order details: Check how much costumer of new order have bought, So give to costumer discount for next order.
CREATE OR REPLACE FUNCTION set_rank()
  RETURNS TRIGGER AS $$
DECLARE
  val      NUMERIC DEFAULT 0;
  quantity BIGINT;
  disc     RECORD;
  customer BIGINT;
BEGIN
  customer = (SELECT customer_id
              FROM orders
              WHERE id = new.order_id);

  quantity = (SELECT coalesce(sum(orders_details.amount), 0)
              FROM orders
                LEFT JOIN orders_details ON orders.id = orders_details.order_id
              WHERE orders.customer_id = customer
              LIMIT 1);

  FOR disc IN SELECT
                customer_id,
                discount_id
              FROM customers_discounts
                LEFT JOIN discounts ON discounts.id = customers_discounts.discount_id
              WHERE customer_id = customer AND
                    (discounts.name LIKE 'Bronze Client Rank' OR discounts.name LIKE 'Silver Client Rank' OR
                     discounts.name LIKE 'Gold Client Rank' OR discounts.name LIKE 'Platinum Client Rank')
              LIMIT 1 LOOP

    val = (SELECT coalesce(max(discounts.value), 0)
           FROM discounts
           WHERE discounts.id = disc.discount_id);

    IF quantity > 40 AND val < 0.12
    THEN
      DELETE FROM customers_discounts
      WHERE discount_id = disc.discount_id AND customer_id = customer;
      INSERT INTO customers_discounts (customer_id, discount_id) VALUES (customer, 4);
    ELSIF quantity > 30 AND val < 0.08
      THEN
        DELETE FROM customers_discounts
        WHERE discount_id = disc.discount_id AND customer_id = customer;
        INSERT INTO customers_discounts (customer_id, discount_id) VALUES (customer, 3);
    ELSIF quantity > 20 AND val < 0.05
      THEN
        DELETE FROM customers_discounts
        WHERE discount_id = disc.discount_id AND customer_id = customer;
        INSERT INTO customers_discounts (customer_id, discount_id) VALUES (customer, 2);
    END IF;
  END LOOP;

  IF quantity > 10 AND val < 0.03 AND disc IS NULL
  THEN
    INSERT INTO customers_discounts (customer_id, discount_id) VALUES (customer, 1);
  END IF;

  RETURN new;
END; $$LANGUAGE plpgsql;

-- Before, on order details: Check that is available the amount of books that costumer ordered.

CREATE OR REPLACE FUNCTION is_paid()
RETURNS TRIGGER AS $$
DECLARE new_amount integer ;
BEGIN
  IF((select state from orders where new.order_id = id ) = 'PAID')
  THEN
  new_amount = (SELECT books.available_quantity
                   FROM books
                   WHERE new.book_id = books.isbn
                   LIMIT 1) - new.amount;
            UPDATE books
      
            set available_quantity = new_amount WHERE isbn = new.book_id  ;
  END IF;
  RETURN new;
END; $$LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION is_available()
  RETURNS TRIGGER AS $$
   DECLARE
   new_amount integer ;

BEGIN
if(TG_OP = 'UPDATE' and new.book_id != old.book_id) THEN
  new.book_id = old.book_id;
  RAISE EXCEPTION 'You can not change the isbn';
  END IF;
  IF new.amount <= 0
  THEN
  return null;
  END IF;
  IF new.amount > (SELECT books.available_quantity
                   FROM books
                   WHERE new.book_id = books.isbn
                   LIMIT 1)
  THEN
    RAISE EXCEPTION 'NOT AVAILABLE';
  END IF;
  RETURN new;
END; $$LANGUAGE plpgsql;
 
 
-------------------------------------------------
---------------- Create table -------------------
-------------------------------------------------
CREATE TABLE authors (
  id           SERIAL PRIMARY KEY,
  first_name   VARCHAR(100),
  second_name  VARCHAR(100),
  company_name VARCHAR(100),
  CHECK ((first_name IS NOT NULL AND second_name IS NOT NULL)
        OR company_name IS NOT NULL)
);

CREATE TABLE genres (
  id   SERIAL PRIMARY KEY,
  name VARCHAR(100) UNIQUE NOT NULL
);


CREATE TABLE publishers (
  id   SERIAL PRIMARY KEY,
  name VARCHAR(100) UNIQUE NOT NULL
);
 
CREATE TABLE books (
  --isbn13 format: xxx-xx-xxxxx-xx-x
  --isbn10 format: x-xxx-xxxxx-x
  id  serial UNIQUE,
  isbn               VARCHAR PRIMARY KEY NOT NULL,
  title              VARCHAR(100) NOT NULL,
  publication_date   DATE CHECK (publication_date <= now()),
  edition            INT NOT NULL,
  available_quantity INT  NOT NULL DEFAULT 0 CHECK (available_quantity >= 0),
  price              NUMERIC(6, 2) CHECK (price > 0) NOT NULL ,
  publisher          SERIAL REFERENCES publishers (id) ON DELETE CASCADE ,
  avg_rate           numeric(4,2),
  sold_count         Integer default 0 not NULL
);
 
CREATE TABLE books_authors (
  id           SERIAL PRIMARY KEY,
  book_id    VARCHAR REFERENCES books (isbn) ON DELETE CASCADE,
  author_id   SERIAL REFERENCES authors (id) ON DELETE CASCADE
--   ,PRIMARY KEY (book_id, author_id)
);

CREATE TABLE books_genres (
  id           SERIAL PRIMARY KEY,
  book_id  VARCHAR REFERENCES books (isbn) ON DELETE CASCADE,
  genre_id SERIAL REFERENCES genres (id) ON DELETE CASCADE
--   ,PRIMARY KEY (book_id, genre_id)
);

CREATE TABLE customers (
  id           SERIAL PRIMARY KEY,
  first_name   VARCHAR(100)        NOT NULL,
  last_name    VARCHAR(100)        NOT NULL,
  login        VARCHAR(100) UNIQUE NOT NULL,
  passwordHash VARCHAR(100) NOT NULL          ,
  phone_number VARCHAR(11) NOT NULL
);

CREATE TABLE addresses (
  id SERIAL PRIMARY key,
  postal_code  VARCHAR(6)          NOT NULL,
  street       VARCHAR(100)        NOT NULL,
  building_no  VARCHAR(5)          NOT NULL,
  flat_no      VARCHAR(5)          NOT NULL        ,
  city         VARCHAR(100)        NOT NULL,
  UNIQUE (postal_code , street , building_no , flat_no , city)
);
 

CREATE TABLE customers_addresses (
  id           SERIAL PRIMARY KEY,
  customers_id INTEGER REFERENCES customers (id) ON DELETE CASCADE ,
  addresses_id INTEGER REFERENCES addresses (id) ON DELETE CASCADE
--   ,PRIMARY KEY (customers_id, addresses_id)
);

CREATE TABLE shippers (
  id           SERIAL PRIMARY KEY,
  name         VARCHAR(100) NOT NULL,
  phone_number VARCHAR(11) NOT NULL
);

CREATE TABLE discounts (
  id    SERIAL PRIMARY KEY,
  name  VARCHAR(100),
  value NUMERIC(2, 2) DEFAULT 0 CHECK (value >= 0.00 AND value <= 1.00)
);

CREATE TABLE customers_discounts (
  id          SERIAL PRIMARY KEY,
  customer_id SERIAL REFERENCES customers (id) ON DELETE CASCADE,
  discount_id SERIAL REFERENCES discounts (id) ON DELETE CASCADE
);

CREATE TABLE books_discounts (
  id           SERIAL PRIMARY KEY,
  book_id     VARCHAR REFERENCES books (isbn) ON DELETE CASCADE,
  discount_id SERIAL REFERENCES discounts (id) ON DELETE CASCADE
);

CREATE TABLE orders(
  id          SERIAL PRIMARY KEY, 
  customer_id SERIAL NOT NULL REFERENCES customers (id) ON DELETE CASCADE, 
  date        DATE DEFAULT now() CHECK (date <= now()), 
  discount_id BIGINT REFERENCES discounts (id) ON DELETE CASCADE, 
  shipper     BIGINT NOT NULL REFERENCES shippers (id) ON DELETE CASCADE, 
  state       VARCHAR DEFAULT 'AWAITING' 
    CHECK (state = 'AWAITING' OR state = 'PAID' OR state = 'SENT'),
  reference_code char(16) not null, 
  address_id integer not null REFERENCES addresses(id),
  total_price numeric(10,2) default 0 
 );  
 
CREATE TABLE orders_details (
  id           SERIAL PRIMARY KEY,
  book_id VARCHAR    REFERENCES books (isbn) ON DELETE CASCADE,  
  order_id BIGINT NOT NULL REFERENCES orders (id) ON DELETE CASCADE, 
  amount   INTEGER CHECK (amount > 0) --
);

CREATE TABLE reviews (
  id          SERIAL PRIMARY KEY,
  book_id     VARCHAR NOT NULL REFERENCES books (isbn) ,
  customer_id BIGINT  NOT NULL REFERENCES customers (id) ,
  review      VARCHAR(1000)  NOT NULL ,
  date        DATE DEFAULT now() CHECK (date <= now())
);

CREATE TABLE rates (
  id          SERIAL PRIMARY KEY,
  book_id     VARCHAR NOT NULL REFERENCES books (isbn) ON DELETE CASCADE,
  customer_id BIGINT  NOT NULL REFERENCES customers (id) ON DELETE CASCADE,
  rate    INTEGER CHECK (rate BETWEEN 0 AND 10),
  date        DATE DEFAULT now() CHECK (date <= now())
);
-------------------------------------------------
------------ Create unique index ----------------
-------------------------------------------------
CREATE UNIQUE INDEX authors_ind_1
  ON authors (first_name, second_name)
  WHERE company_name IS NULL;
CREATE UNIQUE INDEX authors_ind_2
  ON authors (company_name)
  WHERE company_name IS NOT NULL;

-------------------------------------------------
--------------- Create trigger ------------------
-------------------------------------------------
CREATE TRIGGER rank_setter
AFTER INSERT OR UPDATE ON orders_details
FOR EACH ROW EXECUTE PROCEDURE set_rank();

CREATE TRIGGER discounter
BEFORE INSERT OR UPDATE ON orders
FOR EACH ROW EXECUTE PROCEDURE give_discount();
 
CREATE TRIGGER total_price
BEFORE INSERT OR UPDATE on orders_details
FOR EACH ROW EXECUTE PROCEDURE add_price(); 

CREATE TRIGGER sold_book_update
AFTER INSERT OR UPDATE on orders
FOR EACH ROW EXECUTE PROCEDURE sold_update();

drop trigger sold_book_update on orders;
CREATE TRIGGER isbn_check
BEFORE INSERT OR UPDATE ON books
FOR EACH ROW EXECUTE PROCEDURE is_isbn();

CREATE TRIGGER phonenumber_check_customers
BEFORE INSERT OR UPDATE ON shippers
FOR EACH ROW EXECUTE PROCEDURE is_phonenumber();

CREATE TRIGGER phonenumber_check_shippers
BEFORE INSERT OR UPDATE ON shippers
FOR EACH ROW EXECUTE PROCEDURE is_phonenumber();

CREATE TRIGGER hasbook_check
BEFORE INSERT OR UPDATE ON rates
FOR EACH ROW EXECUTE PROCEDURE has_bought_rates();

CREATE TRIGGER hasbook_check
BEFORE INSERT OR UPDATE ON reviews
FOR EACH ROW EXECUTE PROCEDURE has_bought();

CREATE TRIGGER hasrated
after INSERT on rates
FOR EACH ROW EXECUTE PROCEDURE has_rated();


CREATE TRIGGER available_check
BEFORE INSERT OR UPDATE ON orders_details
FOR EACH ROW EXECUTE PROCEDURE is_available();

CREATE TRIGGER paid_check
AFTER INSERT OR UPDATE ON orders_details
FOR EACH ROW EXECUTE PROCEDURE is_paid();
-------------------------------------------------
---------------- Create View --------------------
-------------------------------------------------

--under construction
 
CREATE VIEW book_adder AS (
  SELECT
    books.isbn,
    books.title,
    books.publication_date,
    books.edition,
    books.available_quantity,
    books.price,
    publishers.name AS publisher,
    authors.id
  FROM books
    JOIN publishers ON books.publisher = publishers.id join books_authors on books_authors.book_id = books.isbn
    join authors on books_authors.author_id = authors.id  order by books.id
) ;


CREATE OR REPLACE VIEW books_rank AS (
  SELECT
    isbn,
    title,
    rate,
    sold,
    array(SELECT DISTINCT name
          FROM books_genres
            JOIN genres ON books_genres.genre_id = genres.id
          WHERE book_id LIKE isbn) AS genres
  FROM (SELECT
          books.isbn                   AS isbn,
          title                        AS title,
          avg(rates.rate) :: NUMERIC(4, 2) AS  rate,
          sold_count     AS sold
        FROM books
          JOIN rates ON books.isbn = rates.book_id
        GROUP BY books.isbn) AS o
  ORDER BY sold DESC, rate DESC
);
--
-- SET enable_nestloop=0;
-- SELECT 'postgresql' AS dbms,t.table_catalog,t.table_schema,t.table_name,c.column_name,c.ordinal_position,c.data_type,c.character_maximum_length,n.constraint_type,k2.table_schema,k2.table_name,k2.column_name FROM information_schema.tables t NATURAL LEFT JOIN information_schema.columns c LEFT JOIN(information_schema.key_column_usage k NATURAL JOIN information_schema.table_constraints n NATURAL LEFT JOIN information_schema.referential_constraints r)ON c.table_catalog=k.table_catalog AND c.table_schema=k.table_schema AND c.table_name=k.table_name AND c.column_name=k.column_name LEFT JOIN information_schema.key_column_usage k2 ON k.position_in_unique_constraint=k2.ordinal_position AND r.unique_constraint_catalog=k2.constraint_catalog AND r.unique_constraint_schema=k2.constraint_schema AND r.unique_constraint_name=k2.constraint_name WHERE t.TABLE_TYPE='BASE TABLE' AND t.table_schema NOT IN('information_schema','pg_catalog');
