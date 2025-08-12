create table regions (
	region_id serial primary key,
	region_name varchar(20) not null
);

copy regions from 'C:\Program Files\PostgreSQL\17\data\sales\regions.csv' delimiter ',' csv header;

select * from regions;

update regions set region_name = 'North' where region_id = 1;
update regions set region_name = 'West' where region_id = 2;
update regions set region_name = 'East' where region_id = 3;
update regions set region_name = 'South' where region_id = 4;
update regions set region_name = 'Central' where region_id = 5;

create table products (
	product_id serial primary key,
	product_name varchar(30) not null,
	category varchar(30) not null,
	unit_cost float not null
);

select * from products;

copy products from 'C:\Program Files\PostgreSQL\17\data\sales\products.csv' delimiter ',' csv header;

create table sales (
	sale_id serial primary key,
	product_id int not null,
	region_id int not null, 
	sale_date date not null,
	quantity int not null,
	unit_price float not null,
	total_amount float not null,
	foreign key (product_id) references products(product_id),
	foreign key (region_id) references regions(region_id)
);

select * from sales;

copy sales from 'C:\Program Files\PostgreSQL\17\data\sales\sales.csv' delimiter ',' csv header;

alter table products 
alter column unit_cost type numeric(10, 2)
using unit_cost::numeric;

alter table sales
alter column unit_price type numeric(10, 2)
using unit_price::numeric;

alter table sales
alter column total_amount type numeric(10, 2)
using total_amount::numeric;

-- latihan --
-- total penjualan
select sum(total_amount) as total_penjualan from sales;
-- rata rata barang terjual tiap transaksi
select ceiling(avg(quantity)) as rata_rata_terjual from sales;
-- cek harga tertinggi dan terendah dari seluruh unit
select max(unit_price) as harga_tertinggi, min(unit_price) as harga_terendah from sales;
-- cek total barang terjual dan total penjualan
select sum(quantity) as total_quantity, sum(total_amount) as total_penjualan from sales;

-- cek total penjualan dari tiap category
select products.category, sum(sales.total_amount) as total_penjualan from products 
join sales 
on products.product_id = sales.product_id
group by products.category;
-- cek total penjualan dari tiap bulan
select 
	extract(year from sale_date) as tahun, 
	extract(month from sale_date) as bulan, 
	sum(total_amount) as total_penjualan 
from 
	sales
group by 
	tahun, 
	bulan
order by 
	tahun, 
	bulan;
-- cek total penjualan 2024
select sum(total_amount) as total_penjualan_2024 from sales
where extract(year from sale_date)='2024';
-- cek total_penjualan untuk product milk
select sum(sales.total_amount) as penjualan_milk from products
join sales
on sales.product_id = products.product_id
where products.product_name = 'Milk';
-- cek total penjualan region west
select sum(sales.total_amount) from regions
join sales
on regions.region_id = sales.region_id
where regions.region_name = 'West';

-- rownumber
-- beri nomor urut transaksi dari terbaru hingga terlama
select product_id, region_id, sale_date, quantity, unit_price, total_amount,
	row_number() over(order by sale_date DESC) as urutan
from sales;
-- rank
-- cek top 2 produk dengan total terjual terbanyak per kategori
WITH ProductSales AS (
    -- Step 1: Calculate total quantity for each product
    SELECT
        p.category,
        p.product_name,
        SUM(s.quantity) AS total_quantity
    FROM
        sales s
    JOIN
        products p ON s.product_id = p.product_id
    GROUP BY
        p.category,
        p.product_name
),
RankedSales AS (
    -- Step 2: Rank the products within each category
    SELECT
        category,
        product_name,
        total_quantity,
        RANK() OVER (PARTITION BY category ORDER BY total_quantity DESC) AS sales_rank
    FROM
        ProductSales
)
-- Step 3: Filter for the top 5 in each category
SELECT
    category,
    product_name,
    total_quantity,
    sales_rank
FROM
    RankedSales
WHERE
    sales_rank <= 2;
-- lag
-- hitung selisih total penjualan bulan ini dengan sebelumnya
WITH MonthlySales AS (
    SELECT
        EXTRACT(YEAR FROM sale_date) AS tahun,
        EXTRACT(MONTH FROM sale_date) AS bulan,
        SUM(total_amount) AS total_penjualan
    FROM
        sales
    GROUP BY
        tahun, bulan
)
SELECT
    tahun,
    bulan,
    total_penjualan,
    LAG(total_penjualan, 1, 0) OVER (ORDER BY tahun, bulan) AS penjualan_bulan_lalu,
	total_penjualan - LAG(total_penjualan, 1, 0) OVER (ORDER BY tahun, bulan) AS selisih_penjualan
FROM
    MonthlySales
ORDER BY
    tahun, bulan;

-- CTE Pipeline 1
WITH raw_data AS (
	select *
	from sales
	where quantity > 0
),
clean_data AS (
	select 
		raw_data.*,
		products.product_name,
		category
	from raw_data
	join products
	on raw_data.product_id = products.product_id
)
select 
	category,
	sum(total_amount) as total_penjualan
from clean_data
group by category;

-- CTE Pipeline 2
WITH monthly_sales AS (
	select 
		extract(year from sale_date) AS tahun,
		extract(month from sale_date) AS bulan,
		sum(total_amount) as total_penjualan
	from sales
	group by tahun, bulan
),
monthly_growth AS (
	select
		monthly_sales.*,
		lag(total_penjualan, 1, 0) over(order by tahun, bulan) as bulan_sebelumnya,
		total_penjualan - lag(total_penjualan, 1, 0) over(order by tahun, bulan) as MoM
	from monthly_sales
)
select *
from monthly_growth
where MoM > 0
order by tahun, bulan;