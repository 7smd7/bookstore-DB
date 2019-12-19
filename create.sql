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

CREATE FUNCTION has_bought()
  RETURNS TRIGGER AS $$
BEGIN
  IF (SELECT count(book_id) AS a
      FROM orders_details
        JOIN orders ON orders_details.order_id = orders.id
      WHERE customer_id = new.customer_id AND book_id LIKE new.book_id) = 0
  THEN RAISE EXCEPTION 'CUSTOMER HAS NOT BOUGHT THIS BOOK'; END IF;

--   IF (SELECT count(book_id)
--       FROM reviews
--       WHERE
--         book_id LIKE new.book_id AND customer_id = new.customer_id) > 0
--   THEN
--     DELETE FROM reviews
--     WHERE customer_id = NEW.customer_id AND book_id LIKE NEW.book_id; ------WTF??
--   END IF;
  RETURN new;
END; $$LANGUAGE plpgsql;


CREATE FUNCTION give_discount()
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


CREATE FUNCTION is_phonenumber()
  RETURNS TRIGGER AS $$
DECLARE tmp NUMERIC;
BEGIN
  IF (length(new.phone_number) != 11)
    THEN RAISE EXCEPTION 'INVALID PHONE NUMBER';
  END IF;
  tmp = new.phone_number :: NUMERIC;
  RETURN new;
  EXCEPTION WHEN OTHERS
  THEN RAISE EXCEPTION 'INVALID PHONE NUMBER';
  RETURN new;
END; $$LANGUAGE plpgsql;


CREATE FUNCTION is_isbn()
  RETURNS TRIGGER AS $$
DECLARE tmp NUMERIC DEFAULT 11;
BEGIN
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
          AND ((tmp = 10 AND substr(new.isbn, 13, 1) = 'X')
               OR tmp = substr(NEW.isbn, 13, 1) :: NUMERIC))
  )
  THEN
    RETURN NEW;
  END IF;
  RAISE EXCEPTION 'INVALID ISBN';
END; $$ LANGUAGE plpgsql;


CREATE FUNCTION set_rank()
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

  quantity = (SELECT coalesce(sum(orders_details.amount), 0) --WTF coalesce
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


CREATE FUNCTION is_available()
  RETURNS TRIGGER AS $$
BEGIN
  IF new.amount <= 0
  THEN
    RETURN NULL;
  END IF;
  IF new.amount > (SELECT books.available_quantity
                   FROM books
                   WHERE new.book_id = books.isbn
                   LIMIT 1) ---??WTF limit
  THEN
    RAISE EXCEPTION 'NOT AVAILABLE';
  END IF;
  RETURN new;
END; $$LANGUAGE plpgsql;


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
  isbn               VARCHAR PRIMARY KEY,
  title              VARCHAR(100) NOT NULL,
  publication_date   DATE CHECK (publication_date <= now()),
  edition            INT,
  available_quantity INT  NOT NULL DEFAULT 0 CHECK (available_quantity >= 0),
  price              NUMERIC(6, 2) CHECK (price > 0),
  publisher          SERIAL REFERENCES publishers (id) ON DELETE CASCADE 
);

CREATE TABLE books_authors (
  book_id    VARCHAR REFERENCES books (isbn) ON DELETE CASCADE,
  author_id   SERIAL REFERENCES authors (id) ON DELETE CASCADE,
  PRIMARY KEY (book_id, author_id)
);

CREATE TABLE books_genres (
  book_id  VARCHAR REFERENCES books (isbn) ON DELETE CASCADE,
  genre_id SERIAL REFERENCES genres (id) ON DELETE CASCADE,
  PRIMARY KEY (book_id, genre_id)
);

CREATE TABLE customers (
  id           SERIAL PRIMARY KEY,
  first_name   VARCHAR(100)        NOT NULL,
  last_name    VARCHAR(100)        NOT NULL,
  login        VARCHAR(100) UNIQUE NOT NULL,
  passwordHash VARCHAR(100)                ,
  phone_number VARCHAR(9)
);

CREATE TABLE addresses (
  id           SERIAL PRIMARY KEY,
  postal_code  VARCHAR(6)          NOT NULL,
  street       VARCHAR(100)        NOT NULL,
  building_no  VARCHAR(5)          NOT NULL,
  flat_no      VARCHAR(5)                  ,
  city         VARCHAR(100)        NOT NULL
);


CREATE TABLE customers_addresses (
  customers_id SERIAL REFERENCES customers (id) ON DELETE CASCADE,
  addresses_id SERIAL REFERENCES addresses (id) ON DELETE CASCADE,
  PRIMARY KEY (customers_id, addresses_id)
);


CREATE TABLE shippers (
  id           SERIAL PRIMARY KEY,
  name         VARCHAR(100) NOT NULL,
  phone_number VARCHAR(9)
);

CREATE TABLE discounts (
  id    SERIAL PRIMARY KEY,
  name  VARCHAR(100),
  value NUMERIC(2, 2) DEFAULT 0 CHECK (value >= 0.00 AND value <= 1.00)
);

CREATE TABLE customers_discounts (
  customer_id SERIAL REFERENCES customers (id) ON DELETE CASCADE,
  discount_id SERIAL REFERENCES discounts (id) ON DELETE CASCADE
);

CREATE TABLE books_discounts (
  book_id     VARCHAR REFERENCES books (isbn) ON DELETE CASCADE,
  discount_id SERIAL REFERENCES discounts (id) ON DELETE CASCADE
);

CREATE TABLE orders (
  id          SERIAL PRIMARY KEY,
  customer_id SERIAL NOT NULL REFERENCES customers (id) ON DELETE CASCADE,
  date        DATE DEFAULT now() CHECK (date <= now()),
  discount_id BIGINT REFERENCES discounts (id) ON DELETE CASCADE,
  shipper     BIGINT NOT NULL REFERENCES shippers (id) ON DELETE CASCADE,
  state       VARCHAR DEFAULT 'AWAITING'
    CHECK (state = 'AWAITING' OR state = 'PAID' OR state = 'SENT')
);

CREATE TABLE orders_details (
  book_id  VARCHAR REFERENCES books (isbn) ON DELETE CASCADE,
  order_id BIGINT NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
  amount   INTEGER CHECK (amount > 0)
);

CREATE TABLE reviews (
  id          SERIAL PRIMARY KEY,
  book_id     VARCHAR NOT NULL REFERENCES books (isbn) ,
  customer_id BIGINT  NOT NULL REFERENCES customers (id) ,
  review      VARCHAR(1000)  NOT NULL ,
  date        DATE 
);

CREATE TABLE rates (
  id          SERIAL PRIMARY KEY,
  book_id     VARCHAR NOT NULL REFERENCES books (isbn) ON DELETE CASCADE,
  customer_id BIGINT  NOT NULL REFERENCES customers (id) ON DELETE CASCADE,
  rates       INTEGER CHECK (review BETWEEN 0 AND 10),
  date        DATE DEFAULT now()
);