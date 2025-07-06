
/*ADVANCED SQL SALES DATA ANALYSIS PROJECT*/


/*CHANGE OVER TIME ANALYSIS ( To find trend and saisonality)*/

SELECT
	YEAR(order_date) OrderYear,
	MONTH(order_date) OrderMonth,
	SUM(sales_amount) TotalSales,
	COUNT(quantity) TotalQuantity
FROM dbo.[gold.fact_sales]
WHERE YEAR(order_date) IS NOT NULL
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY YEAR(order_date), MONTH(order_date)

--CUMULATIVE ANALYSIS
--WE ARE CALCULATING THE RUNNING TOTAL SALE TO FIND THE EVOLUTION OF THE BUSINSS OVER TIME AND COMPARE TO A TARGETED VALUE
SELECT 
	YearOrder,
	TotalSales,
	SUM(TotalSales) OVER (ORDER BY YearOrder) RunningTotalSales,
	AVG(AvgPrice) OVER (ORDER BY  YearOrder) MovingAvg
FROM 
(
SELECT 
	YEAR(order_date)YearOrder,
	SUM(sales_amount) TotalSales,
	AVG(price) AvgPrice
FROM [dbo].[gold.fact_sales]
WHERE YEAR(order_date) IS NOT NULL
GROUP BY YEAR(order_date)
)r

/* OVER TIME SALES PERFORMANCE ANALYSIS COMPARE TO THE AVERAGE SALES*/
  
 SELECT 
	YearOrder,
	product_name,
	TotalSales,
	AVG(TotalSales) OVER (PARTITION BY product_name) AvgSALES,
	(TotalSales -AVG(TotalSales) OVER (PARTITION BY product_name)) TargetGap ,
	CASE
		WHEN (TotalSales -AVG(TotalSales) OVER (PARTITION BY product_name))  < 0 THEN 'PoorPerformance'
		WHEN (TotalSales -AVG(TotalSales) OVER (PARTITION BY product_name))  > 0 THEN 'GoodPerformance' 
	ELSE 'AVG'END Comment
FROM
(
SELECT
	YEAR(order_date) YearOrder,
	product_name,
	SUM(sales_amount) TotalSales
FROM [dbo].[gold.fact_sales] SA
JOIN [dbo].[gold.dim_products] PO
ON SA.product_key = PO.product_key
WHERE YEAR(order_date) is not null
GROUP BY product_name, YEAR(order_date)
)r

/* YEAR OVER YEAR PERFORMANCE ANALYSIS BY SUBCATEGORY */

WITH PerformanceA AS 
(
  SELECT
	YEAR(order_date) YearOrder,
	subcategory,
	SUM(sales_amount) TotalSales
FROM [dbo].[gold.fact_sales] SA
JOIN [dbo].[gold.dim_products] PO
ON SA.[product_key] = PO.[product_key]
WHERE YEAR(order_date) is not null AND subcategory iS NOT NULL
GROUP BY  PO.subcategory, YEAR(order_date)
)
SELECT 
	YearOrder,
	subcategory,
	TotalSales,
	AVG(TotalSales) OVER (PARTITION BY subcategory) AvegSALES,
	(TotalSales - AVG(TotalSales) OVER (PARTITION BY subcategory)) TargetGap,
	CASE
		WHEN (TotalSales - AVG(TotalSales) OVER (PARTITION BY subcategory))  < 0 THEN 'BellowAVG'
		WHEN (TotalSales - AVG(TotalSales) OVER (PARTITION BY subcategory))  > 0 THEN 'AboveAVG' 
	ELSE 'AVG'
	END  as Comment,

		LAG([TotalSales]) OVER(PARTITION BY [subcategory] ORDER BY YearOrder DESC)  PySales,
		(TotalSales- LAG(TotalSales) OVER(PARTITION BY subcategory ORDER BY YearOrder DESC))  DiffPySales,
	CASE 
		WHEN (TotalSales - LAG(TotalSales) OVER(PARTITION BY subcategory ORDER BY YearOrder DESC)) > 0 THEN 'Increasing'
		WHEN (TotalSales - LAG(TotalSales) OVER(PARTITION BY subcategory ORDER BY YearOrder DESC)) < 0 THEN 'Decreasing'
	ELSE 'No Change'
	END AS prev
		FROM PerformanceA

/*PART TO THE WHOLE ANALYSIS 
We are comparing the contribution of each subcategory to the total sales*/
		
SELECT
	[subcategory],
	TotalSales,
	SUM(TotalSales) OVER() SumOfSales,
	CONCAT(ROUND((cast(TotalSales as float)/SUM(TotalSales) OVER())*100,2),'%') partInWhole
FROM 
(
SELECT
	subcategory,
	SUM(sales_amount) TotalSales
FROM [dbo].[gold.fact_sales] SA
left JOIN [dbo].[gold.dim_products] PO
ON SA.product_key = PO.product_key
WHERE YEAR([order_date]) is not null AND subcategory iS NOT NULL
GROUP BY  PO.subcategory
)t
order by partInWhole desc

                /* SEGEMENTATION ANALYSIS*/
 -- Cost segmentation
WITH CostSegment as 
(
SELECT
	product_key,
    cost,
	CASE
		WHEN cost < 100 THEN 'AcceptableCost'
		WHEN cost between 100 and 500 THEN 'ModerateCost'
		WHEN cost >500 THEN 'HighCost'
	END AS CostRange

FROM [dbo].[gold.dim_products]
)
SELECT
CostRange,
COUNT(product_key) totalCount
FROM CostSegment
GROUP BY  CostRange

--CUSTOMER SPENDING SEGMENTATION

WITH customer_spending AS 
(
SELECT
	CONCAT(last_name,' ',first_name)  full_name,
	SUM(sales_amount) TotalSales,
	MAX(order_date)  Last_order_date,
	MIN(order_date) Firs_Order_Date,
	DATEDIFF(MONTH, MIN(order_date),max(order_date)) livespan
FROM [dbo].[gold.dim_customers] C
JOIN [dbo].[gold.fact_sales] S
ON C.customer_key = S.customer_key
GROUP BY CONCAT(last_name,' ',first_name)
),New_measure AS
(
SELECT
	full_name,
	TotalSales,
	livespan,
	case
		when livespan >= 12 and TotalSales > 5000 then 'vip'
		when livespan >=12 and  TotalSales <= 5000 then 'regular'
	ELSE 'new customer'
	END customer_segmentation
	from customer_spending
)
select
customer_segmentation,
count(customer_segmentation) total_number
from 
New_measure 
group by customer_segmentation
order by total_number desc
/* Ovarall Customer report*/

 CREATE VIEW Customer_Report AS
WITH Main_Query AS 
(
SELECT
	s.order_number,
	s.order_date,
	s.sales_amount,
	s.quantity,
	s.product_key,
	c.customer_key,
	c.customer_number,
	CONCAT(first_name,' ',last_name) as customer_name,
	DATEDIFF(year,birthdate,GETDATE()) customer_age
FROM[dbo].[gold.dim_customers] C
LEFT JOIN [dbo].[gold.fact_sales] S
ON C.customer_key=S.customer_key
),Aggregated_values AS
(SELECT 
	customer_key,
	customer_number,
	customer_name,
	customer_age,
	DATEDIFF(MONTH, MIN([order_date]),max([order_date])) livespan,
	COUNT(DISTINCT order_number) AS total_orders,
	COUNT(distinct product_key) as total_product,
	SUM(sales_amount) Total_spend,
	SUM(quantity) total_quantity,
	--we are calculating the recency to see if the cutomer is still active or inactive
	datediff(Month,MAX(order_date),getdate()) as recency,
	SUM(sales_amount)/COUNT(DISTINCT order_number) Order_value
FROM Main_Query
 group by  customer_name, customer_number, customer_age, customer_key
)
SELECT 
	customer_name, 
	customer_number,
	customer_age,
	customer_key,
	total_orders,
	total_product,
	Total_spend,
	total_quantity,
	CASE	
		WHEN customer_age <20 THEN ' Under10'
		WHEN customer_age BETWEEN 20 AND 29 THEN '20-29'
		WHEN customer_age BETWEEN 30 AND 39 THEN '30-39'
		WHEN customer_age BETWEEN 40 AND 49 THEN '40-49'
	ELSE '50 and Above'
	END AS 'Age_Range',
	CASE
		WHEN livespan >= 12 and Total_spend > 5000 THEN'vip'
		WHEN livespan >=12 and  Total_spend <= 5000 THEN 'regular'
	ELSE 'new customer'
	END customer_segmentation,
		---Average monthly spend
		CASE 
			WHEN livespan = 0 THEN Total_spend 
	ELSE Total_spend/livespan 
	END Avg_monthly_spend
FROM Aggregated_values;

/*Ovarall Product report*/
CREATE VIEW Products_Report AS
WITH MainQuery AS 
(SELECT
	P.product_name,
	p.subcategory,
	p.category,
	P.cost,
	S.order_number,
	S.customer_key,
	P.product_key,
	S.sales_amount,
	S.quantity,
	S.order_date
FROM [dbo].[gold.fact_sales] S
LEFT JOIN [dbo].[gold.dim_products] P
ON P.product_key = S.product_key
WHERE order_date is not null

), AggregateQuery AS
(
SELECT 
	product_name,
	subcategory,
	cost,
	category,
	customer_key,
	COUNT(DISTINCT order_number) TotalOrder,
	COUNT(distinct customer_key) TotalCustomer,
	SUM(sales_amount) TotalRevenue,
	SUM(quantity) QuantitySold,
	MAX(order_date) LastOrderDate,
	DATEDIFF(MONTH, MIN(order_date),max(order_date)) ProductLivespan,
	ROUND(AVG(cast(sales_amount as float)/NULLIF(quantity,0)),2)   AvgSalingPrice
FROM MainQuery
GROUP BY product_name,subcategory,cost,category,customer_key	
)
SELECT
	product_name,
	subcategory,
	cost,
	category,
	customer_key,
	TotalOrder,
	TotalCustomer,
	TotalRevenue,
	QuantitySold,
	ProductLivespan,
	AvgSalingPrice,
	LastOrderDate,
	DATEDIFF(MONTH, LastOrderDate, GETDATE()) Recency,
	CASE 
		WHEN TotalRevenue >=10000 THEN 'MidRangeProduct'
		When TotalRevenue >=5000 THEN 'HighPerformersProducts'
	ELSE 'LowPerformer'
	END AS ProductPerformance,
	CASE
		WHEN TotalOrder = 0 THEN 0
	ELSE TotalRevenue/TotalOrder  
	END AS AvgRevenue,
	CASE
		WHEN ProductLivespan = 0 THEN TotalRevenue
	ELSE TotalRevenue/ProductLivespan 
	END AS MonthlyRevenue
	from AggregateQuery;
	
	
	

