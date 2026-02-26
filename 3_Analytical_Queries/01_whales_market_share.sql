/*
======================================================================================
Analytical Query: Exchange Whales Identification & Market Share Analysis
Author: Sajjad Fazeli
Description: Extracts the top 50 highest-volume traders ("Whales") from the simulated 
             1M+ order history. Calculates their exact market share using advanced 
             T-SQL window functions.
Techniques Used: Common Table Expressions (CTEs), Window Functions (RANK, SUM OVER), 
                 Data Formatting, and Aggregation.
======================================================================================
*/

USE MegaExchangeDB;
GO

WITH UserVolumes AS (
    -- Step 1: Calculate the total trading volume (in USD) for each user
    SELECT 
        UserID,
        COUNT(OrderID) AS TotalOrders,
        SUM(Amount * Price) AS TotalTradeVolumeUsd
    FROM [Trading].[Orders]
    WHERE Status = 'FILLED' AND Price IS NOT NULL
    GROUP BY UserID
),
WhaleRanking AS (
    -- Step 2: Rank users and calculate overall market share using Window Functions
    -- SUM(...) OVER() allows us to get the grand total without needing a subquery
    SELECT 
        UserID,
        TotalOrders,
        TotalTradeVolumeUsd,
        RANK() OVER(ORDER BY TotalTradeVolumeUsd DESC) AS WhaleRank,
        SUM(TotalTradeVolumeUsd) OVER() AS MarketTotalVolume,
        (TotalTradeVolumeUsd / SUM(TotalTradeVolumeUsd) OVER()) * 100 AS MarketSharePercentage
    FROM UserVolumes
)
-- Step 3: Format and retrieve the top 50 whales with their identity details
SELECT TOP 50
    W.WhaleRank,
    U.Email,
    CASE WHEN U.IsProTrader = 1 THEN 'Yes' ELSE 'No' END AS IsProTrader,
    W.TotalOrders,
    FORMAT(W.TotalTradeVolumeUsd, 'C', 'en-US') AS TotalVolumeUsd,
    ROUND(W.MarketSharePercentage, 4) AS MarketSharePercent
FROM WhaleRanking W
INNER JOIN [Security].[Users] U ON W.UserID = U.UserID
ORDER BY W.WhaleRank;