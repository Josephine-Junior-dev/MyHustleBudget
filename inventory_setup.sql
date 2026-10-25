-- MyHustleBudget Buying & Selling inventory setup
-- Run this entire file in Supabase SQL Editor for the existing project.
-- Uses only the dedicated myhustlebudget schema; does not touch garage tables.
create table if not exists myhustlebudget.inventory_products (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 business_id uuid not null references myhustlebudget.businesses(id) on delete cascade,
 product_name text not null, product_code text,
 buying_price numeric(14,2) not null default 0 check (buying_price >= 0),
 selling_price numeric(14,2) not null default 0 check (selling_price >= 0),
 other_cost_per_unit numeric(14,2) not null default 0 check (other_cost_per_unit >= 0),
 quantity_in_stock integer not null default 0 check (quantity_in_stock >= 0),
 total_quantity_purchased integer not null default 0 check (total_quantity_purchased >= 0),
 created_at timestamptz not null default now()
);
create table if not exists myhustlebudget.inventory_sales (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 business_id uuid not null references myhustlebudget.businesses(id) on delete cascade,
 product_id uuid not null references myhustlebudget.inventory_products(id) on delete restrict,
 quantity integer not null check (quantity > 0),
 unit_selling_price numeric(14,2) not null check (unit_selling_price >= 0),
 total_amount numeric(14,2) not null check (total_amount >= 0),
 cost_of_goods numeric(14,2) not null check (cost_of_goods >= 0),
 other_costs numeric(14,2) not null default 0 check (other_costs >= 0),
 profit numeric(14,2) not null, payment_method text not null default 'cash',
 sale_date date not null default current_date, created_at timestamptz not null default now()
);
create index if not exists inventory_products_user_business_idx on myhustlebudget.inventory_products(user_id,business_id);
create index if not exists inventory_sales_user_business_date_idx on myhustlebudget.inventory_sales(user_id,business_id,sale_date desc);
create index if not exists inventory_sales_product_idx on myhustlebudget.inventory_sales(product_id);
alter table myhustlebudget.inventory_products enable row level security;
alter table myhustlebudget.inventory_sales enable row level security;
revoke all on myhustlebudget.inventory_products from anon;
revoke all on myhustlebudget.inventory_sales from anon;
grant usage on schema myhustlebudget to authenticated;
grant select,insert,update,delete on myhustlebudget.inventory_products to authenticated;
grant select,insert,update,delete on myhustlebudget.inventory_sales to authenticated;
drop policy if exists inventory_products_select_own on myhustlebudget.inventory_products;
create policy inventory_products_select_own on myhustlebudget.inventory_products for select to authenticated using ((select auth.uid())=user_id);
drop policy if exists inventory_products_insert_own on myhustlebudget.inventory_products;
create policy inventory_products_insert_own on myhustlebudget.inventory_products for insert to authenticated with check ((select auth.uid())=user_id and exists (select 1 from myhustlebudget.businesses b where b.id=business_id and b.user_id=(select auth.uid())));
drop policy if exists inventory_products_update_own on myhustlebudget.inventory_products;
create policy inventory_products_update_own on myhustlebudget.inventory_products for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id and exists (select 1 from myhustlebudget.businesses b where b.id=business_id and b.user_id=(select auth.uid())));
drop policy if exists inventory_products_delete_own on myhustlebudget.inventory_products;
create policy inventory_products_delete_own on myhustlebudget.inventory_products for delete to authenticated using ((select auth.uid())=user_id);
drop policy if exists inventory_sales_select_own on myhustlebudget.inventory_sales;
create policy inventory_sales_select_own on myhustlebudget.inventory_sales for select to authenticated using ((select auth.uid())=user_id);
drop policy if exists inventory_sales_insert_own on myhustlebudget.inventory_sales;
create policy inventory_sales_insert_own on myhustlebudget.inventory_sales for insert to authenticated with check ((select auth.uid())=user_id);
drop policy if exists inventory_sales_update_own on myhustlebudget.inventory_sales;
create policy inventory_sales_update_own on myhustlebudget.inventory_sales for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
drop policy if exists inventory_sales_delete_own on myhustlebudget.inventory_sales;
create policy inventory_sales_delete_own on myhustlebudget.inventory_sales for delete to authenticated using ((select auth.uid())=user_id);

create or replace function myhustlebudget.record_inventory_sale(
 p_product_id uuid,p_quantity integer,p_unit_selling_price numeric,p_payment_method text,p_sale_date date
) returns uuid language plpgsql security invoker set search_path='' as $$
declare
 v_product myhustlebudget.inventory_products%rowtype;
 v_sale_id uuid; v_total numeric(14,2); v_cost numeric(14,2); v_other numeric(14,2); v_profit numeric(14,2);
 v_method text; v_date date;
begin
 if (select auth.uid()) is null then raise exception 'You must sign in to record a sale.'; end if;
 if p_quantity is null or p_quantity<1 then raise exception 'Quantity sold must be at least one.'; end if;
 if p_unit_selling_price is null or p_unit_selling_price<0 then raise exception 'Selling price must be zero or greater.'; end if;
 select * into v_product from myhustlebudget.inventory_products
 where id=p_product_id and user_id=(select auth.uid()) for update;
 if not found then raise exception 'Product not found or access denied.'; end if;
 if v_product.quantity_in_stock<p_quantity then raise exception 'Not enough stock available.'; end if;
 v_total:=round(p_quantity*p_unit_selling_price,2);
 v_cost:=round(p_quantity*v_product.buying_price,2);
 v_other:=round(p_quantity*v_product.other_cost_per_unit,2);
 v_profit:=v_total-v_cost-v_other; v_method:=coalesce(nullif(p_payment_method,''),'cash'); v_date:=coalesce(p_sale_date,current_date);
 insert into myhustlebudget.inventory_sales(user_id,business_id,product_id,quantity,unit_selling_price,total_amount,cost_of_goods,other_costs,profit,payment_method,sale_date)
 values((select auth.uid()),v_product.business_id,v_product.id,p_quantity,p_unit_selling_price,v_total,v_cost,v_other,v_profit,v_method,v_date)
 returning id into v_sale_id;
 update myhustlebudget.inventory_products set quantity_in_stock=quantity_in_stock-p_quantity
 where id=v_product.id and user_id=(select auth.uid());
 insert into myhustlebudget.transactions(user_id,business_id,transaction_type,category,description,amount,transaction_date,payment_method)
 values((select auth.uid()),v_product.business_id,'income','sales','Product sale: '||v_product.product_name,v_total,v_date,v_method);
 if v_cost+v_other>0 then
  insert into myhustlebudget.transactions(user_id,business_id,transaction_type,category,description,amount,transaction_date,payment_method)
  values((select auth.uid()),v_product.business_id,'expense','stock','Cost of goods sold: '||v_product.product_name,v_cost+v_other,v_date,v_method);
 end if;
 return v_sale_id;
end; $$;
revoke all on function myhustlebudget.record_inventory_sale(uuid,integer,numeric,text,date) from public,anon;
grant execute on function myhustlebudget.record_inventory_sale(uuid,integer,numeric,text,date) to authenticated;
