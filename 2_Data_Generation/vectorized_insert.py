"""
======================================================================================
Project: High-Performance Data Pipeline for Tier-1 Crypto Exchange
Author: Sajjad Fazeli
Description: Demonstrates advanced data engineering techniques using Pandas, NumPy, 
             and SQLAlchemy's fast_executemany to insert 1,000,000+ relational 
             records into SQL Server in under 3 minutes.
Techniques: Vectorization, Statistical Distributions (Lognormal/Exponential).
======================================================================================
"""

import pandas as pd
import numpy as np
from sqlalchemy import create_engine
from faker import Faker
import uuid
import time

# Database connection settings
# TODO: Update 'server' with your local SQL Server instance name
server = '.'
database = 'MegaExchangeDB'
connection_string = f"mssql+pyodbc://@{server}/{database}?driver=ODBC+Driver+17+for+SQL+Server&Trusted_Connection=yes"

# Create SQLAlchemy engine with fast_executemany enabled for extreme performance
engine = create_engine(connection_string, fast_executemany=True)

# Initialize Faker and set seeds for reproducibility
fake = Faker()
Faker.seed(42)
np.random.seed(42)

# Configuration for data generation volume
NUM_USERS = 50_000
NUM_ORDERS = 1_000_000

print("🚀 Starting High-Performance Data Generation (Vectorized)...")
start_time = time.time()

# ==========================================
# Phase 1: Generate User Data (Security.Users)
# ==========================================
print(f"Generating {NUM_USERS} Users...")

# Utilizing list comprehensions for high-speed UUID and Email generation
user_ids = [str(uuid.uuid4()) for _ in range(NUM_USERS)]
emails = [f"{fake.user_name()}_{i}@example.com" for i in range(NUM_USERS)]

# Vectorized random choice using NumPy for probability distributions
statuses = np.random.choice(['ACTIVE', 'SUSPENDED', 'BANNED'], size=NUM_USERS, p=[0.95, 0.04, 0.01])
is_pro_trader = np.random.choice([True, False], size=NUM_USERS, p=[0.02, 0.98]) # 2% are Pro Traders

users_df = pd.DataFrame({
    'UserID': user_ids,
    'Email': emails,
    'PasswordHash': 'hashed_password_placeholder',
    'Status': statuses,
    'IsProTrader': is_pro_trader
})

# Bulk insert into SQL Server
users_df.to_sql('Users', con=engine, schema='Security', if_exists='append', index=False, chunksize=10000)

# ==========================================
# Phase 2: Generate Wallet Balances (Wallet.Balances)
# ==========================================
print("Generating Wallet Balances...")

# Every user gets 2 wallets (AssetID 1=BTC, AssetID 2=USDT) using NumPy tiling
wallet_user_ids = np.repeat(user_ids, 2)
wallet_asset_ids = np.tile([1, 2], NUM_USERS)

# Realistic wealth distribution using Lognormal distribution (few wealthy, many standard users)
available_balances = np.random.lognormal(mean=2, sigma=1.5, size=NUM_USERS * 2)
available_balances = np.round(available_balances, 4)

balances_df = pd.DataFrame({
    'BalanceID': [str(uuid.uuid4()) for _ in range(NUM_USERS * 2)],
    'UserID': wallet_user_ids,
    'AssetID': wallet_asset_ids,
    'Available': available_balances,
    'Locked': 0.0
})

balances_df.to_sql('Balances', con=engine, schema='Wallet', if_exists='append', index=False, chunksize=10000)

# ==========================================
# Phase 3: Generate High-Frequency Trading Orders (Trading.Orders)
# ==========================================
print(f"Generating {NUM_ORDERS} Orders (HFT Simulation)...")

# Fast random sampling of users to act as traders
order_user_ids = np.random.choice(user_ids, size=NUM_ORDERS)

# Simulate BTC prices normally distributed around $60,000
prices = np.random.normal(loc=60000, scale=1500, size=NUM_ORDERS)
# Simulate order sizes using Exponential distribution (many small trades, few massive trades)
amounts = np.random.exponential(scale=0.5, size=NUM_ORDERS) 

orders_df = pd.DataFrame({
    'OrderID': [str(uuid.uuid4()) for _ in range(NUM_ORDERS)],
    'UserID': order_user_ids,
    'MarketID': 1, # Targeting BTC/USDT market
    'Side': np.random.choice(['BUY', 'SELL'], size=NUM_ORDERS),
    'OrderType': np.random.choice(['MARKET', 'LIMIT'], size=NUM_ORDERS, p=[0.7, 0.3]),
    'Price': np.round(prices, 2),
    'Amount': np.round(amounts, 4),
    'Filled': np.round(amounts, 4), 
    'Status': 'FILLED'
})

# Adjust Dataframe based on business logic: Market orders do not have a set limit price
orders_df.loc[orders_df['OrderType'] == 'MARKET', 'Price'] = None

orders_df.to_sql('Orders', con=engine, schema='Trading', if_exists='append', index=False, chunksize=10000)

execution_time = round(time.time() - start_time, 2)
print(f"✅ Success! Generated and inserted {NUM_USERS*3 + NUM_ORDERS} records in {execution_time} seconds.")