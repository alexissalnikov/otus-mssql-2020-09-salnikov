--1. Все товары, в которых в название есть пометка urgent или название начинается с Animal
SELECT [StockItemID]
      ,[StockItemName]
  FROM [Warehouse].[StockItems]
  WHERE StockItemName like 'Animal%' or StockItemName like '%urgent%';

--2. Поставщиков, у которых не было сделано ни одного заказа (потом покажем как это делать через подзапрос, сейчас сделайте через JOIN)
SELECT s.[SupplierID]
      ,s.[SupplierName]
  FROM [Purchasing].[Suppliers] s
  LEFT JOIN [Purchasing].[SupplierTransactions] st
  ON s.SupplierID = st.SupplierID
  WHERE st.SupplierID IS NULL;

--3. Продажи с названием месяца, в котором была продажа, номером квартала, к которому относится продажа, включите также к какой трети года относится дата - каждая треть по 4 месяца,
-- дата забора заказа должна быть задана, с ценой товара более 100$ либо количество единиц товара более 20.
  SELECT
     o.OrderID
	,o.OrderDate
	,CONVERT(nvarchar(3), o.OrderDate, 0) AS SaleMonth
	,(MONTH(o.OrderDate) + 2) / 3 AS SaleQuarter
	,(MONTH(o.OrderDate) + 3) / 4 AS SaleYearThird
  FROM [Sales].[Orders] o
  INNER JOIN [Sales].[OrderLines] ol on ol.OrderID = o.OrderID and (ol.Quantity > 20 or ol.UnitPrice > 100) and o.[PickingCompletedWhen] is not null
   
-- Добавьте вариант этого запроса с постраничной выборкой пропустив первую 1000 и отобразив следующие 100 записей. Соритровка должна быть по номеру квартала, трети года, дате продажи.
  SELECT
     o.OrderID
	,o.OrderDate
	,CONVERT(nvarchar(3), o.OrderDate, 0) AS SaleMonth
	,(MONTH(o.OrderDate) + 2) / 3 AS SaleQuarter
	,(MONTH(o.OrderDate) + 3) / 4 AS SaleYearThird
  FROM [Sales].[Orders] o
  INNER JOIN [Sales].[OrderLines] ol on ol.OrderID = o.OrderID and (ol.Quantity > 20 or ol.UnitPrice > 100) and o.[PickingCompletedWhen] is not null
  ORDER BY (MONTH(o.OrderDate) + 2) / 3, (MONTH(o.OrderDate) + 3) / 4, o.OrderDate
  OFFSET 1000 ROWS FETCH NEXT 100 ROWS ONLY

--4. Заказы поставщикам, которые были исполнены за 2014й год с доставкой Road Freight или Post, добавьте название поставщика, им¤ контактного лица принимавшего заказ
SELECT distinct po.PurchaseOrderID, s.SupplierName, p.FullName
  FROM [WideWorldImporters].[Purchasing].[PurchaseOrders] po
  INNER JOIN [Application].[DeliveryMethods] dm on po.DeliveryMethodID = dm.DeliveryMethodID and dm.DeliveryMethodName in ('Road Freight','Post')
  INNER JOIN [Purchasing].[Suppliers] s on po.SupplierID = s.SupplierID
  INNER JOIN [Application].[People] p on po.ContactPersonID = p.PersonID
  INNER JOIN [Warehouse].[StockItemTransactions] sit on sit.PurchaseOrderID = po.PurchaseOrderID
  --WHERE po.ExpectedDeliveryDate between '20140101' and '20141231' ----в предположении, что заказ "исполнен", если ожидаемая дата в диапазоне дат
  WHERE sit.TransactionOccurredWhen > '20140101' and sit.TransactionOccurredWhen < '20150101'  --в предположении, что заказ "исполнен", если поступил на склад

--5. 10 последних по дате продаж с именем клиента и именем сотрудника, который оформил заказ.
SELECT TOP(10)
    o.OrderID
   ,o.OrderDate
   ,pcust.FullName AS ClientName
   ,pemp.FullName AS SalespersonName
  FROM [Sales].[Orders] o
  INNER JOIN [Application].[People] pemp on o.SalespersonPersonID = pemp.PersonID
  INNER JOIN [Application].[People] pcust on o.ContactPersonID = pcust.PersonID
  ORDER BY o.OrderDate DESC  --возможно стоит добавить LastEditedWhen

--6. Все ид и имена клиентов и их контактные телефоны, которые покупали товар Chocolate frogs 250g
SELECT distinct
    pcust.PersonID
   ,pcust.FullName
   ,pcust.PhoneNumber
  FROM [Sales].[OrderLines] ol
  INNER JOIN [Sales].[Orders] o on ol.OrderID = o.OrderID
  INNER JOIN [Application].[People] pcust on o.ContactPersonID = pcust.PersonID
  WHERE ol.Description = 'Chocolate frogs 250g'
 
 --Более корректный запрос, поскольку в [Sales].[OrderLines] может быть что угодно, а важно наименование складской позиции [StockItemName] из [Warehouse].[StockItems]
 SELECT distinct
    pcust.PersonID
   ,pcust.FullName
   ,pcust.PhoneNumber
  FROM  [Warehouse].[StockItems] si
  INNER JOIN [Sales].[OrderLines] ol on si.StockItemID = ol.StockItemID
  INNER JOIN [Sales].[Orders] o on ol.OrderID = o.OrderID
  INNER JOIN [Application].[People] pcust on o.ContactPersonID = pcust.PersonID
  WHERE si.StockItemName = 'Chocolate frogs 250g'