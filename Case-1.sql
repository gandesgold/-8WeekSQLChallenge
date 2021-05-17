-- #8WeekSQLChallenge with Danny Ma (https://8weeksqlchallenge.com/case-study-1/)

-- Case 1: Danny's Diner
-- Tools: PostgreSQL

-- Questions:

-- 1. What is the total amount each customer spent at the restaurant?

select
	customer_id,
	sum(price) as total_price
from 
	sales s
	inner join menu m on s.product_id = m.product_id 
group by customer_id
order by customer_id;


-- Result
customer_id|total_price|
-----------+-----------+
A          |         76|
B          |         74|
C          |         36|


-- 2. How many days has each customer visited the restaurant?

select 
	customer_id,
	count(distinct order_date) as days_visited
from sales
group by customer_id;


-- Result
customer_id|days_visited|
-----------+------------+
A          |           4|
B          |           6|
C          |           2|


-- 3. What was the first item from the menu purchased by each customer?

with ranked_product as(
	select 
		*,
		RANK() over (partition by customer_id order by order_date) as product_rank 
	from sales
)

select distinct
	rp.customer_id,
	rp.order_date,
	m.product_name
from ranked_product rp
	inner join menu m on rp.product_id = m.product_id 
where product_rank = 1
order by
	customer_id,
	order_date;

-- Result:
customer_id|order_date|product_name|
-----------+----------+------------+
A          |2021-01-01|curry       |
A          |2021-01-01|sushi       |
B          |2021-01-01|curry       |
C          |2021-01-01|ramen       |


-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

select 
	product_name,
	count(*)
from sales s
	inner join menu m on s.product_id = m.product_id 
group by product_name
limit 1;

-- Result:
product_name|count|
------------+-----+
ramen       |    8|


-- 5. Which item was the most popular for each customer?

with purchases as (
	select 
		s.customer_id,
		m.product_name,
		count(*) as times_purchased
	from sales s
		inner join menu as m on s.product_id = m.product_id
	group by
		s.customer_id,
		m.product_name
	order by s.customer_id, count(*) desc
)
, rank_item as (
	select *,
			rank() over (partition by customer_id order by times_purchased desc) as most_popular
	from purchases
)
select 
	customer_id,
	product_name,
	times_purchased
from rank_item
where most_popular = 1
;

-- Result:
customer_id|product_name|times_purchased|
-----------+------------+---------------+
A          |ramen       |              3|
B          |sushi       |              2|
B          |curry       |              2|
B          |ramen       |              2|
C          |ramen       |              3|


-- 6. Which item was purchased first by the customer after they became a member?

-- a. Create a temporary membership table

Drop table if exists temp_membership_ranked;
Create temporary table temp_membership_ranked as 
with memb as (
	select
		s.customer_id,
		s.order_date,
		s.product_id,
		m.product_name,
		m.price,
		mb.join_date,
		case when (s.order_date >= mb.join_date) then 'Y' else 'N' end as membership
	from sales s
	left join members mb 
		on s.customer_id = mb.customer_id
	inner join menu m
		on s.product_id = m.product_id
)
select 
	*,
	rank() over (partition by customer_id, membership order by order_date) as product_rank_asc,
	rank() over (partition by customer_id, membership order by order_date desc) as product_rank_desc
from memb
;

select
	customer_id,
	order_date,
	product_name,
	membership
from temp_membership_ranked
where product_rank_asc = 1 and membership = 'Y'
order by
	customer_id,
	order_date
;

-- Result:
customer_id|order_date|product_name|membership|
-----------+----------+------------+----------+
A          |2021-01-07|curry       |Y         |
B          |2021-01-11|sushi       |Y         |


-- 7. Which item was purchased just before the customer became a member?

select 
	customer_id,
	order_date,
	product_name,
	membership
from temp_membership_ranked
where join_date is not null -- considers member only
and product_rank_desc = 1 and membership = 'N'
order by
	customer_id,
	order_date;
	
-- Result:
customer_id|order_date|product_name|membership|
-----------+----------+------------+----------+
A          |2021-01-01|curry       |N         |
A          |2021-01-01|sushi       |N         |
B          |2021-01-04|sushi       |N         |
	

-- 8. What is the total items and amount spent for each member before they became a member?

select 
	customer_id,
	count(product_id) as products,
	sum(price) as amount_spent
from temp_membership_ranked
where membership = 'N'
	 and join_date is not null -- considers member only
group by 
	customer_id;

-- Result:
customer_id|products|amount_spent|
-----------+--------+------------+
A          |       2|          25|
B          |       3|          40|


-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

select 
	customer_id,
	sum(case when product_name = 'sushi' then (price *10 * 2) else (price * 10) end) as points
from temp_membership_ranked
where 
	membership = 'Y'
group by
	customer_id;

-- Result:
customer_id|points|
-----------+------+
A          |   510|
B          |   440|


-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

with dates as (
	select 
		*,
		'2021-01-31' as end_of_jan,
		join_date + 7 as first_week,
		('2021-01-31' - join_date) as member_days,
		('2021-01-31' - join_date) / 7 as member_weeks
	from temp_membership_ranked
	where 
		membership = 'Y'
)
	select
		customer_id,
		SUM(case when order_date < first_week then (price * 10 * 2) else (price * 10) end ) as points_eoj
	from dates
	group by
	customer_id;

-- Result:
customer_id|points_eoj|
-----------+----------+
A          |      1020|
B          |       440|


-- BONUS QUESTIONS: Join All the Things

select
	customer_id,
	order_date,
	product_name,
	price,
	membership,
	case when membership = 'Y' then product_rank_asc else null end as ranking
FROM temp_membership_ranked;

-- Result:
customer_id|order_date|product_name|price|membership|ranking|
-----------+----------+------------+-----+----------+-------+
A          |2021-01-01|curry       |   15|N         |       |
A          |2021-01-01|sushi       |   10|N         |       |
A          |2021-01-07|curry       |   15|Y         |      1|
A          |2021-01-10|ramen       |   12|Y         |      2|
A          |2021-01-11|ramen       |   12|Y         |      3|
A          |2021-01-11|ramen       |   12|Y         |      3|
B          |2021-01-01|curry       |   15|N         |       |
B          |2021-01-02|curry       |   15|N         |       |
B          |2021-01-04|sushi       |   10|N         |       |
B          |2021-01-11|sushi       |   10|Y         |      1|
B          |2021-01-16|ramen       |   12|Y         |      2|
B          |2021-02-01|ramen       |   12|Y         |      3|
C          |2021-01-01|ramen       |   12|N         |       |
C          |2021-01-01|ramen       |   12|N         |       |
C          |2021-01-07|ramen       |   12|N         |       |
