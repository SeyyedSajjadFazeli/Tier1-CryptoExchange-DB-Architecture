/*
======================================================================================
Project: MegaExchangeDB - Tier-1 Cryptocurrency Exchange Architecture
Author: Seyyed Sajjad Fazeli
Description: An enterprise-grade, highly normalized relational database architecture 
             designed for a cryptocurrency exchange. Includes 25 tables across 10 
             schemas (Trading, Security, Earn, Margin, Social, etc.).
======================================================================================
*/

CREATE DATABASE MegaExchangeDB;
GO
USE MegaExchangeDB;
GO

-- ==========================================
-- 0. SCHEMA DEFINITIONS
-- Grouping tables logically for microservices architecture
-- ==========================================
CREATE SCHEMA [Security];
CREATE SCHEMA [Compliance];
CREATE SCHEMA [Asset];
CREATE SCHEMA [Wallet];
CREATE SCHEMA [Fiat];
CREATE SCHEMA [Trading];
CREATE SCHEMA [Margin];
CREATE SCHEMA [Earn];
CREATE SCHEMA [Social];
CREATE SCHEMA [Support];
CREATE SCHEMA [Risk];
GO

-- ==========================================
-- 1. SECURITY & IDENTITY
-- ==========================================
CREATE TABLE [Security].[Users] (
    UserID UNIQUEIDENTIFIER DEFAULT NEWID() PRIMARY KEY,
    Email VARCHAR(150) UNIQUE NOT NULL,
    PasswordHash VARCHAR(255) NOT NULL,
    Status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (Status IN ('ACTIVE', 'SUSPENDED', 'BANNED')),
    IsProTrader BIT DEFAULT 0, -- Identifies if they can be copied in Social Trading
    CreatedAt DATETIME2 DEFAULT SYSUTCDATETIME()
);

CREATE TABLE [Security].[LoginHistory] (
    LogID BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserID UNIQUEIDENTIFIER NOT NULL,
    LoginTime DATETIME2 DEFAULT SYSUTCDATETIME(),
    IsSuccess BIT NOT NULL,
    DeviceMetadata NVARCHAR(MAX) CHECK (ISJSON(DeviceMetadata) = 1), -- JSON for IP, Browser, OS
    FOREIGN KEY (UserID) REFERENCES [Security].[Users](UserID)
);

CREATE TABLE [Security].[ApiKeys] (
    ApiKeyID UNIQUEIDENTIFIER DEFAULT NEWID() PRIMARY KEY,
    UserID UNIQUEIDENTIFIER NOT NULL,
    ApiKey VARCHAR(100) UNIQUE NOT NULL,
    ApiSecret VARCHAR(255) NOT NULL,
    Permissions INT DEFAULT 1, -- Bitwise permissions (1:Read, 2:Trade, 4:Withdraw)
    ExpiresAt DATETIME2 NULL,
    FOREIGN KEY (UserID) REFERENCES [Security].[Users](UserID)
);

-- ==========================================
-- 2. COMPLIANCE & KYC
-- ==========================================
CREATE TABLE [Compliance].[KycTiers] (
    TierID INT IDENTITY(1,1) PRIMARY KEY,
    TierName VARCHAR(50) NOT NULL,
    DailyWithdrawalLimitUsd DECIMAL(24,8) NOT NULL
);

CREATE TABLE [Compliance].[UserVerification] (
    VerificationID BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserID UNIQUEIDENTIFIER NOT NULL UNIQUE,
    TierID INT NOT NULL DEFAULT 1,
    FirstName NVARCHAR(100) NULL,
    LastName NVARCHAR(100) NULL,
    DateOfBirth DATE NULL,
    TaxIdNumber VARCHAR(50) NULL,
    FOREIGN KEY (UserID) REFERENCES [Security].[Users](UserID),
    FOREIGN KEY (TierID) REFERENCES [Compliance].[KycTiers](TierID)
);

CREATE TABLE [Compliance].[Documents] (
    DocumentID BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserID UNIQUEIDENTIFIER NOT NULL,
    DocumentType VARCHAR(50) NOT NULL,
    StorageUrl VARCHAR(500) NOT NULL,
    Status VARCHAR(20) DEFAULT 'PENDING',
    UploadedAt DATETIME2 DEFAULT SYSUTCDATETIME(),
    FOREIGN KEY (UserID) REFERENCES [Security].[Users](UserID)
);

-- ==========================================
-- 3. ASSET & NETWORKS
-- ==========================================
CREATE TABLE [Asset].[Assets] (
    AssetID INT IDENTITY(1,1) PRIMARY KEY,
    Symbol VARCHAR(15) UNIQUE NOT NULL,
    AssetClass VARCHAR(10) CHECK (AssetClass IN ('CRYPTO', 'FIAT', 'COMMODITY')),
    IsActive BIT DEFAULT 1
);

CREATE TABLE [Asset].[Networks] (
    NetworkID INT IDENTITY(1,1) PRIMARY KEY,
    NetworkName VARCHAR(50) UNIQUE NOT NULL,
    BlockTimeSeconds INT NULL
);

CREATE TABLE [Asset].[AssetNetworks] (
    AssetNetworkID INT IDENTITY(1,1) PRIMARY KEY,
    AssetID INT NOT NULL,
    NetworkID INT NOT NULL,
    ContractAddress VARCHAR(255) NULL,
    WithdrawalFee DECIMAL(24,8) NOT NULL,
    FOREIGN KEY (AssetID) REFERENCES [Asset].[Assets](AssetID),
    FOREIGN KEY (NetworkID) REFERENCES [Asset].[Networks](NetworkID)
);

-- ==========================================
-- 4. WALLET & FIAT GATEWAYS
-- ==========================================
CREATE TABLE [Wallet].[Balances] (
    BalanceID UNIQUEIDENTIFIER DEFAULT NEWID() PRIMARY KEY,
    UserID UNIQUEIDENTIFIER NOT NULL,
    AssetID INT NOT NULL,
    Available DECIMAL(38,18) DEFAULT 0,
    Locked DECIMAL(38,18) DEFAULT 0,
    FOREIGN KEY (UserID) REFERENCES [Security].[Users](UserID),
    FOREIGN KEY (AssetID) REFERENCES [Asset].[Assets](AssetID),
    CONSTRAINT UQ_User_Asset UNIQUE (UserID, AssetID)
);

CREATE TABLE [Wallet].[CryptoTransactions] (
    TxID BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserID UNIQUEIDENTIFIER NOT NULL,
    AssetNetworkID INT NOT NULL,
    TxType VARCHAR(10) CHECK (TxType IN ('DEPOSIT', 'WITHDRAWAL')),
    Amount DECIMAL(38,18) NOT NULL,
    TxHash VARCHAR(100) NULL UNIQUE,
    Status VARCHAR(20) DEFAULT 'PENDING',
    CreatedAt DATETIME2 DEFAULT SYSUTCDATETIME(),
    FOREIGN KEY (UserID) REFERENCES [Security].[Users](UserID),
    FOREIGN KEY (AssetNetworkID) REFERENCES [Asset].[AssetNetworks](AssetNetworkID)
);

CREATE TABLE [Fiat].[BankAccounts] (
    AccountID INT IDENTITY(1,1) PRIMARY KEY,
    UserID UNIQUEIDENTIFIER NOT NULL,
    BankName NVARCHAR(100) NOT NULL,
    IBAN VARCHAR(50) UNIQUE NOT NULL,
    IsVerified BIT DEFAULT 0,
    FOREIGN KEY (UserID) REFERENCES [Security].[Users](UserID)
);

CREATE TABLE [Fiat].[FiatTransactions] (
    FiatTxID BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserID UNIQUEIDENTIFIER NOT NULL,
    AccountID INT NOT NULL,
    AssetID INT NOT NULL,
    Direction VARCHAR(10) CHECK (Direction IN ('IN', 'OUT')),
    Amount DECIMAL(24,8) NOT NULL,
    ReferenceCode VARCHAR(50) UNIQUE NOT NULL,
    Status VARCHAR(20) DEFAULT 'PROCESSING',
    FOREIGN KEY (UserID) REFERENCES [Security].[Users](UserID),
    FOREIGN KEY (AccountID) REFERENCES [Fiat].[BankAccounts](AccountID),
    FOREIGN KEY (AssetID) REFERENCES [Asset].[Assets](AssetID)
);

-- ==========================================
-- 5. TRADING ENGINE
-- ==========================================
CREATE TABLE [Trading].[Markets] (
    MarketID INT IDENTITY(1,1) PRIMARY KEY,
    BaseAssetID INT NOT NULL,
    QuoteAssetID INT NOT NULL,
    MakerFee DECIMAL(5,4) NOT NULL,
    TakerFee DECIMAL(5,4) NOT NULL,
    FOREIGN KEY (BaseAssetID) REFERENCES [Asset].[Assets](AssetID),
    FOREIGN KEY (QuoteAssetID) REFERENCES [Asset].[Assets](AssetID)
);

CREATE TABLE [Trading].[Orders] (
    OrderID UNIQUEIDENTIFIER DEFAULT NEWID() PRIMARY KEY NONCLUSTERED,
    UserID UNIQUEIDENTIFIER NOT NULL,
    MarketID INT NOT NULL,
    Side VARCHAR(4) CHECK (Side IN ('BUY', 'SELL')),
    OrderType VARCHAR(20) CHECK (OrderType IN ('MARKET', 'LIMIT', 'STOP')),
    Price DECIMAL(38,18) NULL,
    Amount DECIMAL(38,18) NOT NULL,
    Filled DECIMAL(38,18) DEFAULT 0,
    Status VARCHAR(20) DEFAULT 'OPEN',
    CreatedAt DATETIME2 DEFAULT SYSUTCDATETIME(),
    FOREIGN KEY (UserID) REFERENCES [Security].[Users](UserID),
    FOREIGN KEY (MarketID) REFERENCES [Trading].[Markets](MarketID)
);
CREATE CLUSTERED INDEX CIX_Orders_CreatedAt ON [Trading].[Orders](CreatedAt);

CREATE TABLE [Trading].[Matches] (
    MatchID UNIQUEIDENTIFIER DEFAULT NEWID() PRIMARY KEY NONCLUSTERED,
    MarketID INT NOT NULL,
    MakerOrderID UNIQUEIDENTIFIER NOT NULL,
    TakerOrderID UNIQUEIDENTIFIER NOT NULL,
    Price DECIMAL(38,18) NOT NULL,
    Amount DECIMAL(38,18) NOT NULL,
    ExecutedAt DATETIME2 DEFAULT SYSUTCDATETIME()
);
CREATE CLUSTERED INDEX CIX_Matches_ExecutedAt ON [Trading].[Matches](ExecutedAt);

-- ==========================================
-- 6. MARGIN & FUTURES
-- ==========================================
CREATE TABLE [Margin].[Positions] (
    PositionID UNIQUEIDENTIFIER DEFAULT NEWID() PRIMARY KEY,
    UserID UNIQUEIDENTIFIER NOT NULL,
    MarketID INT NOT NULL,
    Side VARCHAR(5) CHECK (Side IN ('LONG', 'SHORT')),
    Leverage INT NOT NULL,
    EntryPrice DECIMAL(38,18) NOT NULL,
    Size DECIMAL(38,18) NOT NULL,
    LiquidationPrice DECIMAL(38,18) NOT NULL,
    IsClosed BIT DEFAULT 0,
    FOREIGN KEY (UserID) REFERENCES [Security].[Users](UserID),
    FOREIGN KEY (MarketID) REFERENCES [Trading].[Markets](MarketID)
);

CREATE TABLE [Margin].[FundingHistory] (
    FundingID BIGINT IDENTITY(1,1) PRIMARY KEY,
    MarketID INT NOT NULL,
    FundingRate DECIMAL(10,8) NOT NULL,
    Timestamp DATETIME2 DEFAULT SYSUTCDATETIME(),
    FOREIGN KEY (MarketID) REFERENCES [Trading].[Markets](MarketID)
);

-- ==========================================
-- 7. EARN (STAKING & YIELD)
-- ==========================================
CREATE TABLE [Earn].[Pools] (
    PoolID INT IDENTITY(1,1) PRIMARY KEY,
    AssetID INT NOT NULL,
    LockupDays INT NOT NULL,
    EstimatedAPY DECIMAL(5,2) NOT NULL,
    FOREIGN KEY (AssetID) REFERENCES [Asset].[Assets](AssetID)
);

CREATE TABLE [Earn].[UserStakes] (
    StakeID UNIQUEIDENTIFIER DEFAULT NEWID() PRIMARY KEY,
    UserID UNIQUEIDENTIFIER NOT NULL,
    PoolID INT NOT NULL,
    Amount DECIMAL(38,18) NOT NULL,
    StakedAt DATETIME2 DEFAULT SYSUTCDATETIME(),
    FOREIGN KEY (UserID) REFERENCES [Security].[Users](UserID),
    FOREIGN KEY (PoolID) REFERENCES [Earn].[Pools](PoolID)
);

CREATE TABLE [Earn].[YieldDistributions] (
    YieldID BIGINT IDENTITY(1,1) PRIMARY KEY,
    StakeID UNIQUEIDENTIFIER NOT NULL,
    RewardAmount DECIMAL(38,18) NOT NULL,
    DistributedAt DATE DEFAULT CAST(SYSUTCDATETIME() AS DATE),
    FOREIGN KEY (StakeID) REFERENCES [Earn].[UserStakes](StakeID)
);

-- ==========================================
-- 8. SOCIAL & COPY TRADING
-- ==========================================
CREATE TABLE [Social].[ProTraders] (
    ProID UNIQUEIDENTIFIER PRIMARY KEY,
    Bio NVARCHAR(500) NULL,
    PerformanceFeePercent DECIMAL(4,2) NOT NULL DEFAULT 10.00,
    TotalFollowers INT DEFAULT 0,
    FOREIGN KEY (ProID) REFERENCES [Security].[Users](UserID)
);

CREATE TABLE [Social].[CopySubscriptions] (
    SubscriptionID UNIQUEIDENTIFIER DEFAULT NEWID() PRIMARY KEY,
    FollowerID UNIQUEIDENTIFIER NOT NULL,
    ProID UNIQUEIDENTIFIER NOT NULL,
    AllocatedFunds DECIMAL(38,18) NOT NULL,
    Status VARCHAR(20) DEFAULT 'ACTIVE',
    FOREIGN KEY (FollowerID) REFERENCES [Security].[Users](UserID),
    FOREIGN KEY (ProID) REFERENCES [Social].[ProTraders](ProID)
);

-- ==========================================
-- 9. CUSTOMER SUPPORT / CRM
-- ==========================================
CREATE TABLE [Support].[Tickets] (
    TicketID BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserID UNIQUEIDENTIFIER NOT NULL,
    Subject NVARCHAR(200) NOT NULL,
    Category VARCHAR(50) NOT NULL,
    Status VARCHAR(20) DEFAULT 'OPEN',
    CreatedAt DATETIME2 DEFAULT SYSUTCDATETIME(),
    FOREIGN KEY (UserID) REFERENCES [Security].[Users](UserID)
);

CREATE TABLE [Support].[TicketMessages] (
    MessageID BIGINT IDENTITY(1,1) PRIMARY KEY,
    TicketID BIGINT NOT NULL,
    SenderType VARCHAR(10) CHECK (SenderType IN ('USER', 'AGENT')),
    MessageBody NVARCHAR(MAX) NOT NULL,
    SentAt DATETIME2 DEFAULT SYSUTCDATETIME(),
    FOREIGN KEY (TicketID) REFERENCES [Support].[Tickets](TicketID)
);

-- ==========================================
-- 10. RISK & DATA WAREHOUSE (ML-Ready)
-- ==========================================
CREATE TABLE [Risk].[UserBehaviorProfiles] (
    ProfileID BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserID UNIQUEIDENTIFIER NOT NULL,
    ProfileDate DATE NOT NULL,
    TradingVolume30D DECIMAL(38,18) DEFAULT 0,
    RiskScore DECIMAL(5,2) DEFAULT 0,
    CalculatedCLV DECIMAL(38,18) NULL,
    FOREIGN KEY (UserID) REFERENCES [Security].[Users](UserID),
    CONSTRAINT UQ_Risk_UserDate UNIQUE (UserID, ProfileDate)
);
GO

-- ==========================================
-- SEED DATA (Required for Foreign Keys in Data Generation)
-- ==========================================
-- 1. Insert Base Assets
INSERT INTO [Asset].[Assets] (Symbol, AssetClass, IsActive)
VALUES 
('BTC', 'CRYPTO', 1),   -- AssetID = 1
('USDT', 'CRYPTO', 1);  -- AssetID = 2
GO

-- 2. Insert Trading Market (BTC/USDT)
INSERT INTO [Trading].[Markets] (BaseAssetID, QuoteAssetID, MakerFee, TakerFee)
VALUES 
(1, 2, 0.0010, 0.0010); -- MarketID = 1
GO