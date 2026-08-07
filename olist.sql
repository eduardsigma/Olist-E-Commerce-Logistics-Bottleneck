-- MY TABLES
select * from olist_customers_dataset ocd 
limit 10

select * from olist_geolocation_dataset ogd 
limit 10

select * from olist_order_items_dataset ooid 
limit 5

select * from olist_order_payments_dataset oopd 
limit 10

select * from olist_order_reviews_dataset oord 
limit 10

select * from olist_orders_dataset ood 


select * from olist_products_dataset opd 
limit 10

select * from olist_sellers_dataset osd 
limit 10

select * from product_category_name_translation pcnt 
limit 10







------------------- QUERIES	




select ood.order_status, ood.order_purchase_timestamp, ood.order_delivered_customer_date, ood.order_estimated_delivery_date, 
julianday(ood.order_delivered_customer_date) - julianday(ood.order_estimated_delivery_date) as delay_in_days
from olist_orders_dataset ood 
where ood.order_status = 'delivered' and julianday(ood.order_delivered_customer_date) > julianday(ood.order_estimated_delivery_date)
limit 10



-- AVG DELAY BY STATES
SELECT 
ocd.customer_state,
avg (case when julianday(ood.order_delivered_customer_date) > julianday(ood.order_estimated_delivery_date)
	then round(julianday(ood.order_delivered_customer_date) - julianday(ood.order_estimated_delivery_date), 2)
	else 0 end) as avg_delay
FROM olist_orders_dataset ood left join olist_customers_dataset ocd on ood.customer_id = ocd.customer_id 
WHERE ood.order_status = 'delivered'
group by ocd.customer_state 
order by avg_delay desc


-- AVG DELAY BY STATES WHEN DELAYED
SELECT 
ocd.customer_state,
avg(round(julianday(ood.order_delivered_customer_date) - julianday(ood.order_estimated_delivery_date), 2)) as avg_delay
FROM olist_orders_dataset ood left join olist_customers_dataset ocd on ood.customer_id = ocd.customer_id 
WHERE ood.order_status = 'delivered' and julianday(ood.order_delivered_customer_date) > julianday(ood.order_estimated_delivery_date)
group by ocd.customer_state 
order by avg_delay desc


-- AVG REVIEW BY STATE
select ocd.customer_state,
	avg(oord.review_score) as avg_review
from olist_orders_dataset ood 
	left join olist_customers_dataset ocd on ood.customer_id = ocd.customer_id
	left join olist_order_reviews_dataset oord on ood.order_id = oord.order_id 
group by ocd.customer_state 


-- AVG DELAY & AVG REVIEW
SELECT 
ocd.customer_state,
avg (case when julianday(ood.order_delivered_customer_date) > julianday(ood.order_estimated_delivery_date)
	then round(julianday(ood.order_delivered_customer_date) - julianday(ood.order_estimated_delivery_date), 2)
	else 0 end) as avg_delay,
ars.avg_review
FROM olist_orders_dataset ood left join olist_customers_dataset ocd on ood.customer_id = ocd.customer_id 
left join (select ocd.customer_state,
		avg(oord.review_score) as avg_review
	from olist_orders_dataset ood 
		left join olist_customers_dataset ocd on ood.customer_id = ocd.customer_id
		left join olist_order_reviews_dataset oord on ood.order_id = oord.order_id 
	group by ocd.customer_state
	)ars on ocd.customer_state = ars.customer_state 
WHERE ood.order_status = 'delivered'
group by ocd.customer_state 
order by ars.avg_review 

-- AVG DELAY & AVG REVIEW GEMINI
SELECT 
    ocd.customer_state,
    round(AVG(
        CASE 
            WHEN julianday(ood.order_delivered_customer_date) > julianday(ood.order_estimated_delivery_date)
            THEN ROUND(julianday(ood.order_delivered_customer_date) - julianday(ood.order_estimated_delivery_date), 2)
            ELSE 0 
        END
    ), 2) AS avg_delay,
    ROUND(AVG(oord.review_score), 2) AS avg_review
FROM olist_orders_dataset ood 
LEFT JOIN olist_customers_dataset ocd ON ood.customer_id = ocd.customer_id 
LEFT JOIN olist_order_reviews_dataset oord ON ood.order_id = oord.order_id 
WHERE ood.order_status = 'delivered'
GROUP BY ocd.customer_state 
ORDER BY avg_review ASC;


-- 	delays & distances
with clean_geolocation as(
	select 
		ogd.geolocation_zip_code_prefix,
		radians(avg(ogd.geolocation_lat)) as avg_lat,
		radians(avg(ogd.geolocation_lng)) as avg_lng
	from olist_geolocation_dataset ogd 
	group by geolocation_zip_code_prefix 
)
SELECT 
    ooid.order_id, 
6371 * acos(
    sin(cg.avg_lat) * sin(cg2.avg_lat) + 
    cos(cg.avg_lat) * cos(cg2.avg_lat) * cos(cg2.avg_lng - cg.avg_lng)
) AS distance_km,
case when julianday(ood.order_delivered_customer_date) > julianday(ood.order_estimated_delivery_date)
	then round(julianday(ood.order_delivered_customer_date) - julianday(ood.order_estimated_delivery_date), 2)
	else 0 end as delay
FROM olist_order_items_dataset ooid 
    LEFT JOIN olist_orders_dataset ood ON ooid.order_id = ood.order_id 
    LEFT JOIN olist_customers_dataset ocd ON ood.customer_id = ocd.customer_id
    LEFT JOIN olist_sellers_dataset osd ON ooid.seller_id = osd.seller_id 
    LEFT JOIN clean_geolocation cg ON ocd.customer_zip_code_prefix = cg.geolocation_zip_code_prefix 
    LEFT JOIN clean_geolocation cg2 ON osd.seller_zip_code_prefix = cg2.geolocation_zip_code_prefix
WHERE ood.order_status = 'delivered' and ooid.order_item_id = 1
  AND cg.avg_lat IS NOT NULL 
  AND cg2.avg_lat IS NOT NULL;


--  d = 6371 * arccos(sin(lat1)sin(lat2)) + cos(lat1)cos(lat2)cos(lng2-lng1))



-- distances & delievery time

with clean_geolocation as(
	select 
		ogd.geolocation_zip_code_prefix,
		radians(avg(ogd.geolocation_lat)) as avg_lat,
		radians(avg(ogd.geolocation_lng)) as avg_lng
	from olist_geolocation_dataset ogd 
	group by geolocation_zip_code_prefix 
)
SELECT 
    ooid.order_id, 
6371 * acos(
    sin(cg.avg_lat) * sin(cg2.avg_lat) + 
    cos(cg.avg_lat) * cos(cg2.avg_lat) * cos(cg2.avg_lng - cg.avg_lng)
) AS distance_km,
round(julianday(ood.order_delivered_customer_date) - julianday(ood.order_purchase_timestamp), 2) as delievery_time_days
FROM olist_order_items_dataset ooid 
    LEFT JOIN olist_orders_dataset ood ON ooid.order_id = ood.order_id 
    LEFT JOIN olist_customers_dataset ocd ON ood.customer_id = ocd.customer_id
    LEFT JOIN olist_sellers_dataset osd ON ooid.seller_id = osd.seller_id 
    LEFT JOIN clean_geolocation cg ON ocd.customer_zip_code_prefix = cg.geolocation_zip_code_prefix 
    LEFT JOIN clean_geolocation cg2 ON osd.seller_zip_code_prefix = cg2.geolocation_zip_code_prefix
WHERE ood.order_status = 'delivered' and ooid.order_item_id = 1
  AND cg.avg_lat IS NOT NULL 
  AND cg2.avg_lat IS NOT NULL;


-- delays classification
SELECT
    CASE
        WHEN julianday(DATE(ood.order_delivered_customer_date)) - julianday(DATE(ood.order_estimated_delivery_date)) < 0 
            THEN 'delivered_early'
        WHEN julianday(DATE(ood.order_delivered_customer_date)) - julianday(DATE(ood.order_estimated_delivery_date)) = 0 
            THEN 'delivered_on_time'
        WHEN julianday(DATE(ood.order_delivered_customer_date)) - julianday(DATE(ood.order_estimated_delivery_date)) BETWEEN 1 AND 3 
            THEN 'slightly_late'
        WHEN julianday(DATE(ood.order_delivered_customer_date)) - julianday(DATE(ood.order_estimated_delivery_date)) BETWEEN 4 AND 7 
            THEN 'moderately_late'
        ELSE 'severely_late (8+ days)'
    END AS delay_class,
    avg(oord.review_score) as avg_review
FROM olist_orders_dataset ood 
LEFT JOIN olist_order_reviews_dataset oord ON ood.order_id = oord.order_id 
WHERE ood.order_status = 'delivered' 
  AND oord.review_score IS NOT NULL
  AND ood.order_delivered_customer_date IS NOT NULL
GROUP BY delay_class 
ORDER BY avg_review

----------------------------- trying to figure out what causes the delays
SELECT
    CASE
        WHEN julianday(DATE(ood.order_delivered_customer_date)) <= julianday(DATE(ood.order_estimated_delivery_date)) 
            THEN '1. On-Time / Early'
        ELSE '2. Delayed'
    END AS delivery_status,
    COUNT(ood.order_id) AS total_orders,
    ROUND(AVG(julianday(ood.order_approved_at) - julianday(ood.order_purchase_timestamp)), 2) AS avg_approval_days,
    ROUND(AVG(julianday(ood.order_delivered_carrier_date) - julianday(ood.order_approved_at)), 2) AS avg_seller_handling_days,
    ROUND(AVG(julianday(ood.order_delivered_customer_date) - julianday(ood.order_delivered_carrier_date)), 2) AS avg_carrier_transit_days,
    ROUND(AVG(julianday(ood.order_delivered_customer_date) - julianday(ood.order_purchase_timestamp)), 2) AS avg_total_actual_days,
    ROUND(AVG(julianday(ood.order_estimated_delivery_date) - julianday(ood.order_purchase_timestamp)), 2) AS avg_estimated_days
FROM olist_orders_dataset ood
WHERE ood.order_status = 'delivered'
  AND ood.order_approved_at IS NOT NULL
  AND ood.order_delivered_carrier_date IS NOT NULL
  AND ood.order_delivered_customer_date IS NOT NULL
GROUP BY delivery_status;



SELECT
    CASE 
        WHEN ocd.customer_state = osd.seller_state THEN 'Intra-State (Same State)'
        ELSE 'Inter-State (Different State)'
    END AS route_type,
    COUNT(DISTINCT ood.order_id) AS total_orders,
    ROUND(AVG(julianday(ood.order_delivered_customer_date) - julianday(ood.order_delivered_carrier_date)), 2) AS avg_carrier_transit_days,
    ROUND(COUNT(CASE WHEN julianday(DATE(ood.order_delivered_customer_date)) > julianday(DATE(ood.order_estimated_delivery_date)) THEN 1 END) * 100.0 / COUNT(ood.order_id), 1) AS percent_delayed
FROM olist_orders_dataset ood
JOIN olist_customers_dataset ocd ON ood.customer_id = ocd.customer_id
JOIN olist_order_items_dataset ooid ON ood.order_id = ooid.order_id
JOIN olist_sellers_dataset osd ON ooid.seller_id = osd.seller_id
WHERE ood.order_status = 'delivered'
  AND ood.order_delivered_carrier_date IS NOT NULL
  AND ood.order_delivered_customer_date IS NOT NULL
GROUP BY route_type;












	
















