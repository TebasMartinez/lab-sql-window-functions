USE sakila;

# CHALLENGE 1
# This challenge consists of three exercises that will test your ability to use the SQL RANK() function. 
# You will use it to rank films by their length, their length within the rating category, 
# and by the actor or actress who has acted in the greatest number of films.

# 1. Rank films by their length and create an output table that includes the title, length, 
# and rank columns only. Filter out any rows with null or zero values in the length column.
SELECT title, length, 
	DENSE_RANK() OVER (ORDER BY length) as `rank`
FROM film
WHERE length IS NOT NULL;

# 2. Rank films by length within the rating category and create an output table that includes the title, 
# length, rating and rank columns only. Filter out any rows with null or zero values in the length column.
SELECT title, rating, length, 
	DENSE_RANK() OVER (PARTITION BY rating ORDER BY length) as `rank`
FROM film
WHERE length IS NOT NULL;

# 3. Produce a list that shows for each film in the Sakila database, the actor or actress who has acted 
# in the greatest number of films, as well as the total number of films in which they have acted. 
# Hint: Use temporary tables, CTEs, or Views when appropiate to simplify your queries.
CREATE TEMPORARY TABLE films_per_actor AS
SELECT actor_id,
	COUNT(film_id) AS total_films_acted
FROM film_actor
GROUP BY actor_id
ORDER BY total_films_acted DESC;

-- If there's a tie on the first place, shows all actors in first place
WITH actors_per_film AS (
SELECT title, 
	actor.actor_id, 
	CONCAT(actor.first_name, " ", actor.last_name) AS actor_name, 
    total_films_acted,
	DENSE_RANK() OVER (PARTITION BY film_id ORDER BY total_films_acted DESC) AS `rank`
FROM actor
INNER JOIN film_actor USING(actor_id)
INNER JOIN film USING(film_id)
INNER JOIN films_per_actor USING(actor_id) 
ORDER BY title, total_films_acted DESC)
SELECT title, actor_name, total_films_acted
FROM actors_per_film
WHERE `rank` = 1;

-- If there's a tie on the first place, shows only one actor
WITH actors_per_film AS (
SELECT title, 
	actor.actor_id, 
	CONCAT(actor.first_name, " ", actor.last_name) AS actor_name, 
    total_films_acted,
	ROW_NUMBER() OVER (PARTITION BY film_id ORDER BY total_films_acted DESC) AS `row`
FROM actor
INNER JOIN film_actor USING(actor_id)
INNER JOIN film USING(film_id)
INNER JOIN films_per_actor USING(actor_id)
ORDER BY title, total_films_acted DESC)
SELECT title, actor_name, total_films_acted
FROM actors_per_film
WHERE `row` = 1;

# CHALLENGE 2
# This challenge involves analyzing customer activity and retention in the Sakila database to gain insight into business performance. 
# By analyzing customer behavior over time, businesses can identify trends and make data-driven decisions to improve customer retention and increase revenue.

# The goal of this exercise is to perform a comprehensive analysis of customer activity 
# and retention by conducting an analysis on the monthly percentage change in the number of active customers and the number of retained customers. 
# Use the Sakila database and progressively build queries to achieve the desired outcome.

# Step 1. Retrieve the number of monthly active customers, i.e., the number of unique customers who rented a movie in each month.
CREATE TEMPORARY TABLE customers_per_month AS
SELECT YEAR(rental_date) AS year,
	MONTH(rental_date) AS month, 
	COUNT(DISTINCT customer_id) as total_customers
FROM rental
GROUP BY year, month
ORDER BY year, month;

SELECT * FROM customers_per_month;

# Step 2. Retrieve the number of active users in the previous month.
WITH cpm_with_previous AS (
SELECT year,
	month, 
	total_customers,
	LAG(total_customers, 1) OVER (ORDER BY year, month) AS previous_month
FROM customers_per_month)

# Step 3. Calculate the percentage change in the number of active customers between the current and previous month.
SELECT year,
	month, 
	total_customers,
    previous_month,
    ((total_customers - previous_month) / previous_month) * 100 AS percentage_change
FROM cpm_with_previous;

#### UNFINISHED ####
# Step 4. Calculate the number of retained customers every month, i.e., customers who rented movies in the current and previous months.
CREATE TEMPORARY TABLE customer_ids_per_month AS 
	SELECT YEAR(rental_date) AS year,
	MONTH(rental_date) AS month, 
    customer_id
    FROM rental;
    
SELECT * FROM customer_ids_per_month;

CREATE TEMPORARY TABLE months AS 
	SELECT DISTINCT YEAR(rental_date) AS year,
	MONTH(rental_date) AS month
    FROM rental;
    
WITH months_with_previous AS (
	SELECT DISTINCT year,
	month,
    LAG(month) OVER (PARTITION BY year ORDER BY month) AS previous_month,
    LAG(year) OVER (PARTITION BY year ORDER BY month) AS previous_year
    FROM months
)
SELECT c.year,
	c.month,
    previous_month,
	COUNT(customer_id) AS retained_customers
    FROM customer_ids_per_month c
    INNER JOIN months_with_previous USING(month)
    WHERE customer_id IN (SELECT customer_id
							FROM customer_ids_per_month c2
                            WHERE c2.month = months_with_previous.previous_month
                            AND c2.year = months_with_previous.previous_year)
    GROUP BY year, month;

# From Nur's lab:

WITH customer_monthly_activity AS (
    SELECT DISTINCT
        YEAR(rental_date) AS rental_year,
        MONTH(rental_date) AS rental_month, 
        customer_id,
        LAG(YEAR(rental_date)) OVER (
            PARTITION BY customer_id 
            ORDER BY YEAR(rental_date), MONTH(rental_date)
        ) AS prev_year,
        LAG(MONTH(rental_date)) OVER (
            PARTITION BY customer_id 
            ORDER BY YEAR(rental_date), MONTH(rental_date)
        ) AS prev_month
    FROM RENTAL
)
SELECT 
    rental_year,
    rental_month, 
    COUNT(customer_id) AS total_customers,
    SUM(CASE 
        -- Normal case: same year, previous month
        WHEN prev_year = rental_year AND prev_month = rental_month - 1 THEN 1
        -- Year boundary case: Dec → Jan
        WHEN prev_year = rental_year - 1 AND prev_month = 12 AND rental_month = 1 THEN 1
        ELSE 0 
    END) AS retained_customers
FROM customer_monthly_activity
GROUP BY rental_year, rental_month
ORDER BY rental_year, rental_month;

