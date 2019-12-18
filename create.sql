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