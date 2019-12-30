select first_name , last_name from customers T inner join orders S on
(T.id = S.customer_id) where (state = 'PAID');

select distinct * from books B inner join rates R
on (B.isbn like R.book_id) where
(rate > 4);


select first_name , last_name from customers T inner join orders S on
(select to_char(S.date , 'M') = '1' AND (select to_char(S.date , 'D') < '10'));

-- test later
select book_id from 
(
select date , max(count) ,book_id from (
select A.id , date , count(amount) , book_id  from 
orders A left join orders_details B  on
A.id = B.order_id group by (id ,book_id ) having (book_id is not null)
) as G group by (date , book_id)) as S;


-- test

SELECT
    books.isbn,
    books.publication_date,
    publishers.name AS publisher,
    authors.id
  FROM books
    JOIN publishers ON books.publisher = publishers.id join books_authors on books_authors.book_id = books.isbn
    join authors on books_authors.author_id = authors.id  order by books.id;


select genre_id , sum(amount) , sum(amount * price) , avg(rate) from (
select genre_id , amount , price , A.book_id , rate  from (orders_details  A inner join books_genres B on (A.book_id = B.book_id)) inner join books C
on (A.book_id = C.isbn) inner join rates G on (A.book_id = G.book_id)) as O group by genre_id;

select count(isbn) from books where (edition > 1 and sold_count > 1000);

select count(isbn) from books A inner join books_discounts B on (A.isbn = B.book_id) WHERE
B.discount_id is  not null;

select first_name , second_name from authors A WHERE
(A.id in (select author_id from books_authors where book_id is not null));

select count(A.id) from publishers A inner join orders_details B on 
A.id = (select publisher from books where isbn = B.book_id);

select first_name , last_name from customers where (phone_number like '0911%');