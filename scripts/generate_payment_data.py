#!/usr/bin/env python3
"""Generate synthetic payment-domain CSV data using only Python stdlib."""
import argparse,csv,random
from datetime import datetime,timedelta
from pathlib import Path
FIRST=['Ava','Liam','Noah','Emma','Olivia','Mia','Ethan','Lucas','Sophia','Amelia','Mateo','Aria']
LAST=['Smith','Johnson','Brown','Garcia','Miller','Davis','Wilson','Martinez','Anderson','Taylor']
CITIES=[('Seattle','WA'),('Austin','TX'),('Chicago','IL'),('Miami','FL'),('Boston','MA'),('Denver','CO'),('San Jose','CA'),('Phoenix','AZ')]
CATEGORIES=['GROCERY','RESTAURANT','TRAVEL','HEALTHCARE','RETAIL','UTILITIES','ENTERTAINMENT','ECOMMERCE']
RISKS=['STANDARD','STANDARD','STANDARD','LOW','MEDIUM','HIGH']
METHODS=[(1,'VISA','CARD'),(2,'MASTERCARD','CARD'),(3,'AMEX','CARD'),(4,'ACH','BANK'),(5,'APPLE_PAY','WALLET'),(6,'GOOGLE_PAY','WALLET')]
STATUSES=['APPROVED','APPROVED','APPROVED','APPROVED','DECLINED','PENDING']

def write(path,header,rows):
    with path.open('w',newline='',encoding='utf-8') as f:
        w=csv.writer(f);w.writerow(header);w.writerows(rows)

def main():
    p=argparse.ArgumentParser();p.add_argument('--transactions',type=int,default=50000);p.add_argument('--customers',type=int,default=5000);p.add_argument('--merchants',type=int,default=500);p.add_argument('--seed',type=int,default=42);p.add_argument('--out',default='datasets/generated');a=p.parse_args()
    random.seed(a.seed);out=Path(a.out);out.mkdir(parents=True,exist_ok=True);base=datetime(2025,1,1);end=datetime(2026,8,1);span=(end-base).days
    customers=[]
    for cid in range(1,a.customers+1):
        fn,ln=random.choice(FIRST),random.choice(LAST);city,state=random.choice(CITIES);created=base-timedelta(days=random.randint(0,730));updated=created+timedelta(days=random.randint(0,500))
        customers.append([cid,f'{fn} {ln}',f'{fn.lower()}.{ln.lower()}{cid}@example.com',city,state,random.choice(RISKS),created.strftime('%Y-%m-%d %H:%M:%S'),updated.strftime('%Y-%m-%d %H:%M:%S')])
    write(out/'customers.csv',['customer_id','customer_name','email','city','state_code','risk_segment','created_at','updated_at'],customers)
    merchants=[]
    for mid in range(1,a.merchants+1):
        cat=random.choice(CATEGORIES);created=base-timedelta(days=random.randint(0,365));merchants.append([mid,f'{cat.title()} Merchant {mid}',cat,'US',random.choice(['ACTIVE','ACTIVE','ACTIVE','SUSPENDED']),created.strftime('%Y-%m-%d %H:%M:%S'),end.strftime('%Y-%m-%d %H:%M:%S')])
    write(out/'merchants.csv',['merchant_id','merchant_name','merchant_category','country_code','status','created_at','updated_at'],merchants)
    write(out/'payment_methods.csv',['payment_method_id','method_code','method_group','active_flag','updated_at'],[[i,c,g,'Y',end.strftime('%Y-%m-%d %H:%M:%S')] for i,c,g in METHODS])
    txns=[];refunds=[];cancels=[];rid=1;cid=1
    for tid in range(1,a.transactions+1):
        ts=base+timedelta(days=random.randint(0,span),seconds=random.randint(0,86399));status=random.choice(STATUSES);amount=round(random.uniform(1,2500),2);fee=round(amount*random.uniform(.001,.035),2);auth=f'AUTH{tid:010d}' if status=='APPROVED' else ''
        txns.append([tid,random.randint(1,a.customers),random.randint(1,a.merchants),random.randint(1,len(METHODS)),ts.strftime('%Y-%m-%d %H:%M:%S'),'PAYMENT',status,'USD',amount,fee,auth,'PAYMENTS_APP',ts.strftime('%Y-%m-%d %H:%M:%S')])
        if status=='APPROVED' and random.random()<0.035:
            rts=ts+timedelta(days=random.randint(1,30));refunds.append([rid,tid,rts.strftime('%Y-%m-%d %H:%M:%S'),round(amount*random.choice([.25,.5,1]),2),random.choice(['CUSTOMER_REQUEST','DUPLICATE','PRODUCT_RETURN']),'COMPLETED',rts.strftime('%Y-%m-%d %H:%M:%S')]);rid+=1
        if status in ('PENDING','APPROVED') and random.random()<0.01:
            cts=ts+timedelta(minutes=random.randint(1,180));cancels.append([cid,tid,cts.strftime('%Y-%m-%d %H:%M:%S'),random.choice(['CUSTOMER_CANCEL','TIMEOUT','MERCHANT_CANCEL']),cts.strftime('%Y-%m-%d %H:%M:%S')]);cid+=1
    # Deliberate DQ examples: negative amount and orphan merchant.
    if a.transactions>=2:
        txns[-1][8]=-25.00;txns[-2][2]=999999
    write(out/'payment_transactions.csv',['transaction_id','customer_id','merchant_id','payment_method_id','transaction_ts','transaction_type','status','currency_code','amount','processing_fee','authorization_code','source_system','updated_at'],txns)
    write(out/'refunds.csv',['refund_id','original_transaction_id','refund_ts','refund_amount','reason_code','status','updated_at'],refunds)
    write(out/'cancellations.csv',['cancellation_id','original_transaction_id','cancellation_ts','reason_code','updated_at'],cancels)
    print(f'Generated {len(customers):,} customers, {len(merchants):,} merchants, {len(txns):,} payments, {len(refunds):,} refunds, {len(cancels):,} cancellations in {out}')
if __name__=='__main__': main()
