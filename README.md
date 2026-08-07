# Olist E-Commerce Logistics Bottleneck & SLA Optimization

An end-to-end data analytics project investigating fulfillment bottlenecks, data hygiene, and customer satisfaction decay across **96,000+ orders** from Brazilian e-commerce platform Olist. 

Using **SQL** and **Excel**, this project audits data anomalies, disproves common operational assumptions regarding geographic distance, isolates root causes of fulfillment delays, and proposes actionable SLA strategies to protect review ratings.

---

## Executive Summary

* **The Problem:** Delivery delays trigger massive customer churn and negative reviews, but high-level correlations failed to explain why delays occur.
* **Core Insight:** Physical distance between buyer and seller only explains **7.8% of transit time variance** ($r = 0.28$). Delivery delays are overwhelmingly driven by **inter-state carrier transit friction (+19.91 days)** rather than seller dispatch latency or geographic kilometer distance ($r = 0.07$).
* **Business Impact:** Customer ratings collapse from **4.02 stars (On-Time)** down to **2.12 stars (4–7 days late)** and **1.69 stars (8+ days late)**.
* **Proposed Solution:** Implement an algorithmic **Inter-State ETA Buffer (+7 days)** during checkout to realign customer expectations with regional infrastructure constraints without incurring additional logistics costs.

---

## Data Hygiene & Outlier Audit

Before running bivariate correlations, an exploratory audit revealed severe data corruptions and extreme operational outliers:
* **Geolocation Errors:** Coordinates generating straight-line distances $>4,200\text{ km}$ (beyond Brazil's continental boundaries).
* **Lost Package Anomalies:** Orders with transit times up to $200+\text{ days}$ (representing lost cargo or retroactive manual system scans rather than standard courier shipping speeds).

### Impact of Outlier Filtering
Removing these extreme leverage points (**~0.08% of total orders**) restored bivariate statistical integrity:
* **Distance vs. Transit Time ($r$):** Corrected from an inflated $0.40$ down to **$0.28$** ($R^2 \approx 7.8\%$).
* **Distance vs. Delivery Delay ($r$):** Shifted from $0.06$ to **$0.07$**, confirming that distance has virtually no linear relationship with late deliveries.

---

## Deep-Dive Analysis & Findings

### 1. Customer Satisfaction Decay (The Delay Cliff)
Analysis of customer review scores across discrete delivery timing buckets reveals an immediate satisfaction crash:

| Delivery Performance Bucket | Avg Review Score (1–5 Stars) | Operational Takeaway |
| :--- | :---: | :--- |
| **Delivered Early** | **4.29** | "Under-promise, over-deliver" bonus (+0.27 vs. on-time). |
| **Delivered On Time** | **4.02** | Baseline expectation met. |
| **Slightly Late (1–3 Days)** | **3.27** | Immediate **-0.75 star penalty** for missing promised date. |
| **Moderately Late (4–7 Days)** | **2.12** | **The Rating Cliff:** Ratings collapse into failing territory. |
| **Severely Late (8+ Days)** | **1.69** | Bottoming-out effect; review scores max out on negative feedback. |

---

### 2. Fulfillment Lifecycle Breakdown
Deconstructing total order duration (`Purchase` $\rightarrow$ `Approval` $\rightarrow$ `Carrier Handoff` $\rightarrow$ `Customer Doorstep`) isolates where operational breakdowns occur:

| Operational Phase | On-Time Avg | Delayed Avg | Added Time Delta | % Share of Total Increase |
| :--- | :---: | :---: | :---: | :---: |
| **Payment Approval** | 0.42 days | 0.51 days | **+0.09 days** | 0.4% |
| **Seller Handling Time** | 2.60 days | 5.55 days | **+2.95 days** | 12.8% |
| **Carrier Transit Time** | 7.98 days | 27.89 days | **+19.91 days** | **86.8% (Primary Bottleneck)** |
| **Total Fulfillment Duration** | **11.00 days** | **33.95 days** | **+22.95 days** | **100.0%** |

* **Key Takeaway:** Carrier transit time accounts for **86.8% of total delay duration**. Delayed orders spend an average of **27.89 days in transit**.

---

### 3. The Inter-State Border Paradox
Cross-referencing shipping routes against regional geography revealed why transit times explode despite distance maintaining a weak correlation ($r = 0.07$):
* **Intra-State Shipments:** Shipments within the same state move efficiently through local hubs.
* **Inter-State Shipments:** Crossing state borders incurs a structural **+7 day transit penalty** due to state tax inspection checkpoints (*Posto Fiscal*), regional hub transfers, and fragmented courier networks.
* **Algorithm Blind Spot:** Olist's ETA algorithm promised an average of **22.65 days** for orders that ended up delayed vs. **23.82 days** for on-time orders—failing to account for inter-state logistics friction.

---

## Featured SQL Code

### Lifecycle Decomposition & Bottleneck Identification Query
```sql
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
```

### Lifecycle Decomposition & Bottleneck Identification Query
```sql
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
