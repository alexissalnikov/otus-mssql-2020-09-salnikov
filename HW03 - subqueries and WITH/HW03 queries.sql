--Подзапросы и CTE
--Для всех заданий где возможно, сделайте 2 варианта запросов:
--1) через вложенный запрос
--2) через WITH (для производных таблиц)

--1. Выберите сотрудников, которые являются продажниками, и еще не сделали ни одной продажи.
SELECT *
FROM [Application].[People] p
WHERE p.IsSalesperson = 1
  AND p.PersonID NOT IN
    (SELECT SalespersonPersonID
     FROM [Sales].Orders o);

--Или
SELECT *
FROM [Application].[People] p
WHERE p.IsSalesperson = 1
  AND NOT EXISTS
    (SELECT SalespersonPersonID
     FROM [Sales].Orders o
     WHERE p.PersonID = o.SalespersonPersonID);

--С WITH
WITH ActiveSalesPerson (PersonID) AS
  (SELECT SalespersonPersonID
   FROM [Sales].Orders o)
SELECT *
FROM [Application].[People] p
LEFT JOIN ActiveSalesPerson asp ON asp.PersonID = p.PersonID
WHERE p.IsSalesperson = 1
  AND asp.PersonID IS NULL;

--Тоже, но зато план такой же, как для первых двух
WITH ActiveSalesPerson (PersonID) AS
  (SELECT SalespersonPersonID
   FROM [Sales].Orders o)
SELECT *
FROM [Application].[People] p
WHERE p.IsSalesperson = 1
  AND NOT EXISTS
    (SELECT PersonID
     FROM ActiveSalesPerson asp
     WHERE asp.PersonID = p.PersonID);

--2. Выберите товары с минимальной ценой (подзапросом), 2 варианта подзапроса.
SELECT *
FROM [Warehouse].[StockItems] si
WHERE si.UnitPrice =
    (SELECT MIN(UnitPrice)
     FROM [Warehouse].[StockItems]);

--Дороже относительно предыдущего по плану, но пока не могу объяснить почему
SELECT *
FROM [Warehouse].[StockItems] si
WHERE si.UnitPrice <= ALL
    (SELECT UnitPrice
     FROM [Warehouse].[StockItems]);

--C WITH, аналогичен первому по плану
WITH MinPrice (UnitPriceMin) AS
  (SELECT MIN(UnitPrice) UnitPriceMin
   FROM [Warehouse].[StockItems])
SELECT si.*
FROM [Warehouse].[StockItems] si
INNER JOIN MinPrice mp ON si.UnitPrice = mp.UnitPriceMin;

--3. Выберите информацию по клиентам, которые перевели компании 5 максимальных платежей из [Sales].[CustomerTransactions] представьте 3 способа (в том числе с CTE)
SELECT c.CustomerID,
       CustomerName,
       t.TransactionAmount
FROM [Sales].[Customers] c
INNER JOIN
  (SELECT TOP(5) ct.CustomerID,
          [TransactionAmount]
   FROM [WideWorldImporters].[Sales].[CustomerTransactions] ct
   ORDER BY [TransactionAmount] DESC) t ON t.CustomerID = c.CustomerID;

WITH Top5BigPayments (CustomerID, TransactionAmount) AS
  (SELECT TOP(5) ct.CustomerID,
          [TransactionAmount]
   FROM [WideWorldImporters].[Sales].[CustomerTransactions] ct
   ORDER BY [TransactionAmount] DESC)
SELECT c.CustomerID,
       CustomerName,
       t.TransactionAmount
FROM [Sales].[Customers] c
INNER JOIN Top5BigPayments t ON t.CustomerID = c.CustomerID;

--C EXISTS жертвуем суммой платежа (без нее может быть непонятно, почему не 5 клиентов (ожидаемо), а 4)
WITH Top5BigPayments (CustomerID, TransactionAmount) AS
  (SELECT TOP(5) ct.CustomerID,
          [TransactionAmount]
   FROM [WideWorldImporters].[Sales].[CustomerTransactions] ct
   ORDER BY [TransactionAmount] DESC)
SELECT c.CustomerID,
       CustomerName--, t.TransactionAmount
FROM [Sales].[Customers] c
WHERE EXISTS
    (SELECT CustomerID
     FROM Top5BigPayments t
     WHERE t.CustomerID = c.CustomerID);

--4. Выберите города (ид и название), в которые были доставлены товары, входящие в тройку самых дорогих товаров, а также Имя сотрудника, который осуществлял упаковку заказов
SELECT DISTINCT c.DeliveryCityID,
                cities.CityName,
                p.FullName
FROM
  (SELECT TOP(3) WITH TIES [StockItemID],
                      [UnitPrice]
   FROM [Warehouse].[StockItems] si
   ORDER BY [UnitPrice] DESC) top3meg
INNER JOIN [Sales].[InvoiceLines] il ON il.StockItemID = top3meg.StockItemID
INNER JOIN [Sales].[Invoices] i ON il.InvoiceID = i.InvoiceID
INNER JOIN [Sales].[Customers] c ON c.CustomerID = i.CustomerID
INNER JOIN [Application].[Cities] cities ON cities.CityID = c.DeliveryCityID
INNER JOIN [Application].[People] p ON p.PersonID = i.PackedByPersonID;

WITH Top3MostExpensiveGoods (StockItemID, TransactionAmount) AS
  (SELECT TOP(3) WITH TIES [StockItemID],
                      [UnitPrice]
   FROM [Warehouse].[StockItems] si
   ORDER BY [UnitPrice] DESC)
SELECT DISTINCT c.DeliveryCityID,
                cities.CityName,
                p.FullName
FROM Top3MostExpensiveGoods top3meg
INNER JOIN [Sales].[InvoiceLines] il ON il.StockItemID = top3meg.StockItemID
INNER JOIN [Sales].[Invoices] i ON il.InvoiceID = i.InvoiceID
INNER JOIN [Sales].[Customers] c ON c.CustomerID = i.CustomerID
INNER JOIN [Application].[Cities] cities ON cities.CityID = c.DeliveryCityID
INNER JOIN [Application].[People] p ON p.PersonID = i.PackedByPersonID;

--5. Объясните, что делает и оптимизируйте запрос:
--SELECT
--Invoices.InvoiceID,
--Invoices.InvoiceDate,
--(SELECT People.FullName
--FROM Application.People
--WHERE People.PersonID = Invoices.SalespersonPersonID
--) AS SalesPersonName,
--SalesTotals.TotalSumm AS TotalSummByInvoice,
--(SELECT SUM(OrderLines.PickedQuantity*OrderLines.UnitPrice)
--FROM Sales.OrderLines
--WHERE OrderLines.OrderId = (SELECT Orders.OrderId
--FROM Sales.Orders
--WHERE Orders.PickingCompletedWhen IS NOT NULL
--AND Orders.OrderId = Invoices.OrderId)
--) AS TotalSummForPickedItems
--FROM Sales.Invoices
--JOIN
--(SELECT InvoiceId, SUM(Quantity*UnitPrice) AS TotalSumm
--FROM Sales.InvoiceLines
--GROUP BY InvoiceId
--HAVING SUM(Quantity*UnitPrice) > 27000) AS SalesTotals
--ON Invoices.InvoiceID = SalesTotals.InvoiceID
--ORDER BY TotalSumm DESC

--Похоже запрос служит для сверки общей стоимости товара из заказа с общей стоимостью товара по накладной (счету-фактуре?)
--для всех укомплектованных заказов общая стоимость которых по счету более 27000
--Может быть, для контроля изменения количества или стоимости товара относительно догворных значений (из заказа)
--С фамилями менеджеров, чтоб знать с кгого спрашивать

--Если двигаться в сторону ускорения, то логично сузить отправную выборку только до тех счетов, что удовлетворяют критерию (сумма по счету > 27 000)
--В приведенном запросе это условие налагается уже в самом конце
--Поместив это условие в WITH, можно заодно улучшить читабельность запроса
--Еще для читабельности можно то, с чем мы сравниваем, поместить еше в один подзапрос WITH
--Получим:
WITH SalesTotals AS
  (SELECT InvoiceId,
          SUM(Quantity*UnitPrice) AS TotalSumm
   FROM Sales.InvoiceLines
   GROUP BY InvoiceId
   HAVING SUM(Quantity*UnitPrice) > 27000),
     InvoiceTotals AS
  (SELECT o.OrderID,
          SUM(ol.PickedQuantity*ol.UnitPrice) AS TotalSumm
   FROM Sales.Orders o
   INNER JOIN Sales.OrderLines ol ON ol.OrderID = o.OrderID
   WHERE o.PickingCompletedWhen IS NOT NULL
   GROUP BY o.OrderID)
SELECT i.InvoiceID,
       i.InvoiceDate,
       p.FullName AS SalesPersonName,
       st.TotalSumm AS TotalSummByInvoice,
       it.TotalSumm AS TotalSummForPickedItems
FROM SalesTotals st
INNER JOIN Sales.Invoices i ON st.InvoiceID = i.InvoiceID
INNER JOIN InvoiceTotals it ON it.OrderID = i.OrderID
INNER JOIN Application.People p ON p.PersonID = i.SalespersonPersonID
ORDER BY st.TotalSumm DESC;

--План запроса пока не совсем прозрачная штука для меня (для моего запроса - это нижний). До сегодняшнего дня я только знал, что они существуют :)
--Как ни пытался переписывать запрос, ускорения не получалось, больше только вопросов
--Видно, что верхняя строка - это наш подзапрос SalesTotals. Двигаясь справа налево получаем наши 8 самых больших счета
--Вторая строка - получаем необходимые поля из Invoices для соединения с другими таблицами (заказы, менеджеры). И, судя по Cost 90%, это самая затратная часть. Но как без нее?
--Дальше идут заказы, 6% от всего запроса - найти PickingCompletedWhen IS NOT NULL. Здесь не очень понимаю, вроде бы написано Clustered Index Scan, но где там индекс с этим полем?
--В самом низу PERSONS, ее тоже нужно просканировать